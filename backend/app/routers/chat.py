"""
Chat endpoints for AI Coach + 3-agent nutrition pipeline.

Hardening:
- Input sanitization (trim, strip control chars, cap at 2000 chars)
- 30s timeout so a wedged LLM call doesn't tie up a worker
- Rate limit: 10 requests/hour per remote IP
"""
import re
import concurrent.futures

from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from chatbot_agent import CoachingAgent
from ai_models.multi_agent_system import NutritionMultiAgent, NutritionAnalysisAgent
from app.models.schemas import ChatMessage, MealEstimateRequest
from app.core.config import AI_ENABLED
from app.core.observability import track, note_failure

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


def _require_ai_enabled() -> None:
    """Raise 503 if operators have flipped the AI kill switch.

    Config flag AI_ENABLED is read at startup; toggling it requires a
    Railway restart (env-var propagation). This is intentional: we want
    a clear, audit-logged change rather than silent per-request drift.
    """
    if not AI_ENABLED:
        raise HTTPException(
            status_code=503,
            detail="AI temporarily unavailable",
        )

coach_agent = CoachingAgent()
_multi_agent = NutritionMultiAgent()
_nutrition_agent = NutritionAnalysisAgent()

_AI_TIMEOUT_SEC = 30
_MAX_MSG_LEN = 2000
# strip control chars except tab/newline
_CONTROL_CHAR_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def _sanitize_message(msg: str) -> str:
    s = (msg or "").strip()
    s = _CONTROL_CHAR_RE.sub("", s)
    if len(s) > _MAX_MSG_LEN:
        s = s[:_MAX_MSG_LEN]
    return s


def _run_with_timeout(fn, *args, **kwargs):
    """Run a blocking AI call in a thread and enforce _AI_TIMEOUT_SEC."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
        future = ex.submit(fn, *args, **kwargs)
        try:
            return future.result(timeout=_AI_TIMEOUT_SEC)
        except concurrent.futures.TimeoutError:
            raise HTTPException(status_code=504, detail="AI ตอบช้าเกินไป กรุณาลองใหม่")


@router.post("/api/chat/coach")
@limiter.limit("10/hour")
def chat_with_coach(request: Request, payload: ChatMessage):
    """พูดคุยกับ AI Coach ที่วิเคราะห์ประวัติการกินของคุณ"""
    _require_ai_enabled()
    msg = _sanitize_message(payload.message)
    if not msg:
        raise HTTPException(status_code=400, detail="ข้อความว่างเปล่า")
    with track("chat.coach", "POST /api/chat/coach",
               user_id=payload.user_id, msg_len=len(msg)):
        try:
            response_text = _run_with_timeout(
                coach_agent.generate_response, payload.user_id, msg
            )
            return {"response": response_text}
        except HTTPException:
            raise
        except Exception as e:
            note_failure("chat.coach", e, user_id=payload.user_id)
            raise HTTPException(status_code=500, detail=f"AI Coach Error: {str(e)}")


@router.post("/api/meals/estimate")
@limiter.limit("30/hour")
def estimate_meal_from_text(request: Request, payload: MealEstimateRequest):
    """
    Take free Thai text (e.g. "มื้อเช้ากินข้าวผัดกะเพรา 1 จาน ต้มยำกุ้ง ครึ่งถ้วย")
    and return per-item + total calorie/macro estimates.

    Food extraction uses pythainlp word segmentation + DB-backed dictionary,
    falling back to regex if pythainlp is unavailable. Unknown foods that
    LLM estimates get auto-inserted into temp_food for admin review
    (see NutritionAnalysisAgent._auto_add_temp_food).

    The client typically follows this with POST /meals/{user_id} to persist.
    """
    _require_ai_enabled()
    msg = _sanitize_message(payload.message)
    if not msg:
        raise HTTPException(status_code=400, detail="ข้อความว่างเปล่า")
    try:
        def _do():
            mentions = _nutrition_agent._extract_foods(msg)
            if not mentions:
                return {"items": [], "total": {"calories": 0, "protein": 0, "carbs": 0, "fat": 0},
                        "allergy_warnings": [], "meal_type": payload.meal_type,
                        "message": "ไม่พบเมนูอาหารในข้อความ"}
            info = _nutrition_agent._analyze_foods(mentions, [], payload.user_id)
            info["meal_type"] = payload.meal_type
            info["extracted"] = mentions
            return info
        return _run_with_timeout(_do)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Meal estimate error: {str(e)}")


@router.post("/api/chat/multi")
@limiter.limit("10/hour")
def chat_multi_agent(request: Request, payload: ChatMessage):
    """
    3-Agent AI pipeline:
      Agent1 (DataOrchestrator) -> Agent2 (NutritionAnalysis) -> Agent3 (ResponseComposer/LLM)
    """
    _require_ai_enabled()
    msg = _sanitize_message(payload.message)
    if not msg:
        raise HTTPException(status_code=400, detail="ข้อความว่างเปล่า")
    with track("chat.multi", "POST /api/chat/multi",
               user_id=payload.user_id, msg_len=len(msg)):
        try:
            response_text = _run_with_timeout(
                _multi_agent.run,
                payload.user_id, msg,
                lat=payload.lat, lng=payload.lng,
            )
            return {"response": response_text, "agent": "multi_3"}
        except HTTPException:
            raise
        except Exception as e:
            note_failure("chat.multi", e, user_id=payload.user_id)
            return {
                "response": (
                    "ขออภัยครับ ตอนนี้ AI Coach มีปัญหาในการประมวลผลชั่วคราว "
                    "แต่ระบบยังใช้งานได้อยู่ ลองถามใหม่อีกครั้ง หรือถามแบบสั้นลงได้นะครับ"
                ),
                "agent": "fallback",
                "error": "multi_agent_failed",
            }
