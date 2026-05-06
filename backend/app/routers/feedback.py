"""
POST /api/feedback — Flutter thumbs up/down on AI responses.

Stores ratings in ai_feedback table so n8n can:
  - Aggregate weekly review queue
  - Trigger fine-tune pipeline when labeled pairs hit threshold
"""
import logging
from typing import Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator

from auth.dependencies import get_current_user
from database import get_db_connection

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/feedback", tags=["feedback"])


class FeedbackRequest(BaseModel):
    query: str
    response: str
    rating: Literal["up", "down"]
    context_type: Literal["chat", "estimate"] = "chat"

    @field_validator("query", "response")
    @classmethod
    def _strip(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("must not be empty")
        return v[:2000]


class FeedbackResponse(BaseModel):
    id: int
    status: str


@router.post("", response_model=FeedbackResponse, status_code=201)
def submit_feedback(
    body: FeedbackRequest,
    current_user: dict = Depends(get_current_user),
) -> FeedbackResponse:
    user_id: Optional[int] = current_user.get("user_id")
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ai_feedback
                    (user_id, query, response, rating, context_type)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
                """,
                (user_id, body.query, body.response, body.rating, body.context_type),
            )
            row = cur.fetchone()
            conn.commit()
        return FeedbackResponse(id=row[0], status="saved")
    except Exception as exc:
        logger.exception("Failed to save feedback: %s", exc)
        raise HTTPException(status_code=500, detail="Could not save feedback")
    finally:
        conn.close()


@router.get("/stats")
def feedback_stats(current_user: dict = Depends(get_current_user)) -> dict:
    """Quick summary — used by n8n to decide when to trigger fine-tune."""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*) FILTER (WHERE rating = 'up')   AS thumbs_up,
                    COUNT(*) FILTER (WHERE rating = 'down') AS thumbs_down,
                    COUNT(*) FILTER (WHERE NOT used_in_training) AS unlabeled
                FROM ai_feedback
                """
            )
            row = cur.fetchone()
        return {
            "thumbs_up": row[0],
            "thumbs_down": row[1],
            "unlabeled": row[2],
        }
    finally:
        conn.close()
