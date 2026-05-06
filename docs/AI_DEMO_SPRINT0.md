# Sprint 0 — AI Quality Baseline (1-Day Demo)

**Date:** 2026-05-06
**Goal:** สร้าง measurable baseline สำหรับ AI 4 components แล้ววางแผน 4 สัปดาห์ขยับเข้าสู่ 85% accuracy

---

## TL;DR

| Component | Metric | Baseline | Target | Gap |
|---|---|---:|---:|---:|
| **Food Extraction** | F1 score | **0.30** | ≥ 0.85 | **-0.55** |
| **Meal Estimate (LLM)** | MAPE (lower=better) | **91.6%** | ≤ 15% | **-76.6 pp** |
| **Coach Response** | rubric pass rate | **70.0%** | ≥ 85% | **-15.0 pp** |
| **Scope Guard** | min(precision,recall) | **0.90** | ≥ 0.95 | **-0.05** |

**Overall verdict:** Scope guard ใกล้ผ่าน, food extraction ห่างไกลเพราะ DB lexicon เล็ก, meal estimate พังเพราะ 1.5B model ไม่ตามรูปแบบ JSON, coach response ปานกลาง

---

## What We Built Today (Sprint 0 deliverables)

1. **Refactor cleanup** — ลบ multi-agent code ที่ไม่ใช้, รวม `/api/chat/multi` ให้เรียก `CoachAgent`, rename `multi_agent.py` → `nutrition_analysis.py`
2. **Switch base model** — `deepseek-r1:8b` → `deepseek-r1:1.5b` (พอดีกับ VRAM 4GB ของเครื่อง dev)
3. **Eval harness** — [backend/tests/eval/run_eval.py](../backend/tests/eval/run_eval.py) รันได้ end-to-end
4. **Golden datasets** — 80 hand-labeled examples (20 ต่อ component)
5. **Baseline numbers** — ดู TL;DR ด้านบน

---

## Where the Gaps Come From

### Food Extraction (F1 0.30 → 0.85)

ใช้ DB lexicon (113 dishes ใน `foods` + 10 regional names) + fallback dictionary 50 ตัว — ครอบคลุมไม่พอ ตัวอย่างที่หาไม่เจอ: `ข้าวผัดกะเพราไก่`, `ข้าวมันไก่`, `ก๋วยเตี๋ยวต้มยำหมูสับ`, `ข้าวคลุกกะปิ`, `ข้าวเหนียวหมูปิ้ง`, `เย็นตาโฟทะเลรวม`

**แผน Week 2:** ขยาย `foods` เป็น 300+ dishes + `food_regional_names` เป็น 100+ aliases → คาดว่า F1 จะกระโดดเป็น 0.70-0.80

### Meal Estimate (MAPE 91.6% → ≤15%)

16/20 calls fail ที่ขั้น JSON parse — `deepseek-r1:1.5b` ภาษาไทย + JSON format ไม่แม่น output เป็น free text แทน strict JSON

**แผน Week 2-4:**
- Week 2: เพิ่ม few-shot examples ใน `MEAL_ESTIMATE_SYSTEM_PROMPT` (5-10 ตัวอย่างให้ model copy style)
- Week 4: fine-tune LoRA บน DeepSeek-R1-Distill-Qwen-1.5B ด้วย dataset 200+ Thai food → JSON examples (ใช้ notebook ที่มีอยู่)

### Coach Response (70% → 85%)

Failure modes:
- `is_thai` 70% — บางครั้ง model ตอบ English/mixed
- `relevant` 65% — model ตอบไม่ตรงกับ keyword nutrition
- 6 LLM failures (timeout/empty)

**แผน Week 2:** ปรับ `COACH_SYSTEM_PROMPT` ให้ enforce Thai + add decision tree
**แผน Week 4:** fine-tune ปิด gap ที่เหลือ

### Scope Guard (0.90 → 0.95)

ตอนนี้ใช้ keyword presence แบบ permissive — false positive 1 ตัว (น่าจะเป็น "แปลภาษาอังกฤษเป็นไทย" จับคำว่า "ภาษา")

**แผน Week 2:** เพิ่ม negative keywords + dual-check rule (มี nutrition keyword **และ** ไม่มี off-topic keyword)

---

## 4-Week Roadmap (เป้า 85%)

| Week | Activity | Expected Outcome |
|---|---|---|
| **Week 1** | ขยาย eval set 20→200, production logging, calibrate judge | datasets ครบ, มี real-traffic data เริ่มไหล |
| **Week 2** | Prompt engineering + lexicon (foods 113→300, regional 10→100) | Food F1 0.30→0.75, Scope ≥0.95, Meal MAPE down to ~50% |
| **Week 3** | Admin labeling workflow + Flutter feedback widget | Labeled training data ≥100 pairs ใหม่ |
| **Week 4** | LoRA fine-tune ใน [notebooks/deepseek_finetune.ipynb](../notebooks/deepseek_finetune.ipynb) → Ollama Modelfile | Coach 70→85%+, Meal MAPE down to ≤15% |

---

## How to Reproduce

```bash
# 1. Ollama serving deepseek-r1:1.5b
docker compose -f ollama/docker-compose.yml up -d
docker exec caloriesguard-ollama ollama pull deepseek-r1:1.5b

# 2. Run eval suite (~5 min on 4GB VRAM, ~260s in our run)
cd backend
python -m tests.eval.run_eval

# 3. View raw output
cat backend/logs/eval_last.json
```

Skip LLM portion when offline:
```bash
python -m tests.eval.run_eval --skip-llm
```

---

## Files Touched

| Path | Change |
|---|---|
| [backend/ai_models/multi_agent.py](../backend/ai_models/multi_agent.py) | DELETED (renamed → `nutrition_analysis.py`, NutritionMultiAgent removed) |
| [backend/ai_models/nutrition_analysis.py](../backend/ai_models/nutrition_analysis.py) | NEW — only `NutritionAnalysisAgent` class |
| [backend/ai_models/__init__.py](../backend/ai_models/__init__.py) | drop NutritionMultiAgent re-export |
| [backend/app/routers/chat.py](../backend/app/routers/chat.py) | `/api/chat/multi` → CoachAgent |
| [backend/app/core/config.py](../backend/app/core/config.py) | default model → `deepseek-r1:1.5b` |
| [docker-compose.yml](../docker-compose.yml) | `OLLAMA_MODEL: deepseek-r1:1.5b` |
| [ollama/.env](../ollama/.env) | `OLLAMA_PRELOAD_MODEL=deepseek-r1:1.5b` |
| [backend/tests/eval/](../backend/tests/eval/) | NEW — full eval harness (4 metrics, 4 datasets, run_eval.py) |

**Tests:** 88/89 pass (1 pre-existing recipe failure unrelated to AI).
