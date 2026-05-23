from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Iterable

from psycopg2.extras import RealDictCursor


ACTIVITY_FACTORS = {
    "sedentary": 1.2,
    "lightly_active": 1.375,
    "moderately_active": 1.55,
    "very_active": 1.725,
    "extra_active": 1.9,
}

LOW_INTAKE_CUTOFF_HOUR = 17
SEVERE_LOW_INTAKE_KCAL = 800
MODERATE_DEFICIT_KCAL = 750
MODERATE_DEFICIT_RATIO = 0.25
SEVERE_DEFICIT_KCAL = 1000
SEVERE_DEFICIT_RATIO = 0.35
CONSECUTIVE_LOW_DAYS = 3


@dataclass(frozen=True)
class EnergyContext:
    user_id: int
    date_record: date
    total_intake: float
    has_food_log: bool
    gender: str
    bmr: float
    tdee: float
    target_calories: float
    min_safe_calories: float


@dataclass(frozen=True)
class NutritionSafetyFinding:
    code: str
    severity: str
    title: str
    message: str
    notification_type: str = "system_alert"

    def as_dict(self) -> dict[str, str]:
        return {
            "code": self.code,
            "severity": self.severity,
            "title": self.title,
            "message": self.message,
            "type": self.notification_type,
        }


def _age_from_birth(birth_date: Any, today: date | None = None) -> int:
    if not birth_date:
        return 20
    if isinstance(birth_date, str):
        birth_date = datetime.strptime(birth_date[:10], "%Y-%m-%d").date()
    today = today or date.today()
    age = today.year - birth_date.year
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        age -= 1
    return max(age, 10)


def compute_energy_context(
    *,
    user_id: int,
    user: dict[str, Any],
    total_intake: float,
    has_food_log: bool,
    date_record: date,
    today: date | None = None,
) -> EnergyContext:
    today = today or date.today()
    weight = float(user.get("current_weight_kg") or 0)
    height = float(user.get("height_cm") or 0)
    gender = (user.get("gender") or "male").lower()

    if weight <= 0 or height <= 0:
        bmr = 1500.0 if gender == "male" else 1200.0
    else:
        age = _age_from_birth(user.get("birth_date"), today)
        base = (10 * weight) + (6.25 * height) - (5 * age)
        bmr = base + 5 if gender == "male" else base - 161

    factor = ACTIVITY_FACTORS.get(
        (user.get("activity_level") or "sedentary").lower(),
        ACTIVITY_FACTORS["sedentary"],
    )
    tdee = bmr * factor
    sex_floor = 1500.0 if gender == "male" else 1200.0
    min_safe = max(bmr, sex_floor)
    target = float(user.get("target_calories") or tdee)

    return EnergyContext(
        user_id=user_id,
        date_record=date_record,
        total_intake=max(float(total_intake or 0), 0.0),
        has_food_log=has_food_log,
        gender=gender,
        bmr=bmr,
        tdee=tdee,
        target_calories=target,
        min_safe_calories=min_safe,
    )


def classify_calorie_safety(
    context: EnergyContext,
    *,
    now: datetime | None = None,
    recent_low_days: int = 0,
) -> list[NutritionSafetyFinding]:
    now = now or datetime.now()
    findings: list[NutritionSafetyFinding] = []

    if context.target_calories < context.min_safe_calories:
        findings.append(
            NutritionSafetyFinding(
                code="unsafe_target_calories",
                severity="danger",
                title="เป้าหมายแคลอรี่ต่ำเกินไป",
                message=(
                    f"เป้าหมายปัจจุบัน {int(context.target_calories)} kcal "
                    f"ต่ำกว่าขั้นต่ำความปลอดภัย {int(context.min_safe_calories)} kcal "
                    "ระบบควรปรับเป้าหมายขึ้นเพื่อหลีกเลี่ยง deficit ที่รุนแรงเกินไป"
                ),
            )
        )

    should_evaluate_low_intake = (
        context.date_record < now.date()
        or (
            context.date_record == now.date()
            and now.hour >= LOW_INTAKE_CUTOFF_HOUR
        )
    )
    if not should_evaluate_low_intake or not context.has_food_log:
        return findings

    deficit = max(context.tdee - context.total_intake, 0.0)
    deficit_ratio = deficit / context.tdee if context.tdee > 0 else 0.0

    if context.total_intake < SEVERE_LOW_INTAKE_KCAL:
        findings.append(
            NutritionSafetyFinding(
                code="severe_low_intake",
                severity="danger",
                title="แคลอรี่วันนี้ต่ำมาก",
                message=(
                    f"วันนี้บันทึกไว้เพียง {int(context.total_intake)} kcal "
                    f"ซึ่งต่ำกว่า {SEVERE_LOW_INTAKE_KCAL} kcal มากเกินไป "
                    "ควรเพิ่มมื้ออาหารที่มีโปรตีน คาร์บ และไขมันดี หรือปรึกษาผู้เชี่ยวชาญหากตั้งใจจำกัดอาหาร"
                ),
            )
        )
    elif context.total_intake < context.min_safe_calories:
        findings.append(
            NutritionSafetyFinding(
                code="below_safe_floor",
                severity="warning",
                title="แคลอรี่วันนี้ยังต่ำเกินไป",
                message=(
                    f"วันนี้บันทึกไว้ {int(context.total_intake)} kcal "
                    f"ต่ำกว่าขั้นต่ำความปลอดภัย {int(context.min_safe_calories)} kcal "
                    "การกินต่ำเกินไปอาจเพิ่มความเสี่ยงอ่อนเพลีย หิวมาก และเสียมวลกล้ามเนื้อ"
                ),
            )
        )
    elif deficit >= SEVERE_DEFICIT_KCAL and deficit_ratio >= SEVERE_DEFICIT_RATIO:
        findings.append(
            NutritionSafetyFinding(
                code="severe_deficit",
                severity="danger",
                title="deficit วันนี้สูงเกินไป",
                message=(
                    f"วันนี้ขาดจาก TDEE ประมาณ {int(deficit)} kcal "
                    f"({deficit_ratio * 100:.0f}% ของ TDEE) ซึ่งสูงเกินระดับที่ควรทำต่อเนื่อง "
                    "ควรเพิ่มพลังงานจากอาหารที่มีคุณภาพและติดตามอาการผิดปกติ"
                ),
            )
        )
    elif deficit >= MODERATE_DEFICIT_KCAL and deficit_ratio >= MODERATE_DEFICIT_RATIO:
        findings.append(
            NutritionSafetyFinding(
                code="large_deficit",
                severity="warning",
                title="deficit วันนี้ค่อนข้างสูง",
                message=(
                    f"วันนี้ขาดจาก TDEE ประมาณ {int(deficit)} kcal "
                    f"({deficit_ratio * 100:.0f}% ของ TDEE) "
                    "หากเกิดบ่อยควรปรับมื้ออาหารหรือเป้าหมายให้ปลอดภัยขึ้น"
                ),
            )
        )

    low_today = context.total_intake < context.min_safe_calories
    if low_today and recent_low_days + 1 >= CONSECUTIVE_LOW_DAYS:
        findings.append(
            NutritionSafetyFinding(
                code="consecutive_low_intake",
                severity="danger",
                title="กินต่ำกว่าขั้นต่ำต่อเนื่อง",
                message=(
                    f"พบการกินต่ำกว่าขั้นต่ำประมาณ {recent_low_days + 1} วันต่อเนื่อง "
                    "ควรหยุดเพิ่ม deficit และประเมินแผนอาหารใหม่เพื่อป้องกันผลเสียต่อสุขภาพ"
                ),
            )
        )

    return findings


def _fetch_user_and_daily_intake(
    conn,
    user_id: int,
    date_record: date,
) -> tuple[dict[str, Any] | None, float, bool]:
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(
        """
        SELECT gender, birth_date, height_cm, current_weight_kg,
               activity_level, target_calories
        FROM users
        WHERE user_id = %s
        """,
        (user_id,),
    )
    user = cur.fetchone()
    if not user:
        return None, 0.0, False

    cur.execute(
        """
        SELECT COALESCE(SUM(di.amount * di.cal_per_unit), 0) AS total_calories,
               COUNT(di.meal_id) AS item_count
        FROM meals m
        JOIN detail_items di ON di.meal_id = m.meal_id
        WHERE m.user_id = %s AND DATE(m.meal_time) = %s
        """,
        (user_id, date_record),
    )
    row = cur.fetchone() or {}
    total_intake = float(row.get("total_calories") or 0)
    has_food_log = int(row.get("item_count") or 0) > 0
    return dict(user), total_intake, has_food_log


def _count_recent_low_days(
    conn,
    user_id: int,
    before_date: date,
    min_safe_calories: float,
) -> int:
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(
        """
        SELECT ds.date_record, ds.total_calories_intake
        FROM daily_summaries ds
        WHERE ds.user_id = %s
          AND ds.date_record < %s
        ORDER BY ds.date_record DESC
        LIMIT %s
        """,
        (user_id, before_date, CONSECUTIVE_LOW_DAYS - 1),
    )
    rows: Iterable[dict[str, Any]] = cur.fetchall() or []
    count = 0
    for row in rows:
        intake = float(row.get("total_calories_intake") or 0)
        if intake <= 0 or intake >= min_safe_calories:
            break
        count += 1
    return count


def _insert_notification(conn, user_id: int, finding: NutritionSafetyFinding) -> None:
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO notifications (user_id, title, message, type)
        SELECT %s, %s, %s, %s
        WHERE NOT EXISTS (
            SELECT 1
            FROM notifications
            WHERE user_id = %s
              AND title = %s
              AND DATE(created_at) = CURRENT_DATE
        )
        """,
        (
            user_id,
            finding.title,
            finding.message,
            finding.notification_type,
            user_id,
            finding.title,
        ),
    )


def evaluate_and_persist_calorie_safety(
    conn,
    user_id: int,
    date_record: date,
    *,
    now: datetime | None = None,
) -> list[dict[str, str]]:
    user, total_intake, has_food_log = _fetch_user_and_daily_intake(
        conn, user_id, date_record
    )
    if not user:
        return []

    now = now or datetime.now()
    context = compute_energy_context(
        user_id=user_id,
        user=user,
        total_intake=total_intake,
        has_food_log=has_food_log,
        date_record=date_record,
        today=now.date(),
    )
    recent_low_days = _count_recent_low_days(
        conn, user_id, date_record, context.min_safe_calories
    )
    findings = classify_calorie_safety(
        context,
        now=now,
        recent_low_days=recent_low_days,
    )
    for finding in findings:
        _insert_notification(conn, user_id, finding)
    return [finding.as_dict() for finding in findings]
