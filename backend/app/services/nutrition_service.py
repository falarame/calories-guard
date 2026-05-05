from datetime import date, datetime
from typing import Optional, List

from database import get_db_connection
from psycopg2.extras import RealDictCursor


def _age_from_birth(birth_date: Optional[date]) -> int:
    if not birth_date:
        return 20
    today = date.today()
    age = today.year - birth_date.year
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        age -= 1
    return max(age, 10)


def _compute_target_macros(user: dict) -> tuple:
    """
    คืน (target_protein, target_carbs, target_fat) อิงจากงานวิจัยทางโภชนาการ
    """
    cal = user.get('target_calories')
    if cal is None:
        cal = _compute_target_calories(user)
    cal = int(cal) if cal else 2000
    goal = (user.get('goal_type') or 'lose_weight').lower()

    w = float(user.get('current_weight_kg') or 0)
    if w <= 0:
        w = cal / 25

    if goal == 'maintain_weight':
        p_g = w * 1.6
        f_g = w * 1.0
    elif goal == 'gain_muscle':
        p_g = w * 2.0
        f_g = w * 1.0
    else:  # lose_weight
        p_g = w * 1.8
        f_g = w * 0.8

    p_cal = p_g * 4
    f_cal = f_g * 9
    c_cal = cal - (p_cal + f_cal)

    if c_cal < cal * 0.1:
        if goal == 'maintain_weight':
            p_ratio, c_ratio, f_ratio = 0.25, 0.45, 0.30
        elif goal == 'gain_muscle':
            p_ratio, c_ratio, f_ratio = 0.30, 0.50, 0.20
        else:
            p_ratio, c_ratio, f_ratio = 0.30, 0.40, 0.30
        return (int(round(cal * p_ratio / 4)), int(round(cal * c_ratio / 4)), int(round(cal * f_ratio / 9)))

    return (int(round(p_g)), int(round(c_cal / 4)), int(round(f_g)))


def _compute_target_calories(user: dict) -> int:
    """Daily Target = TDEE + (kg_per_week * 1100). BMR Mifflin-St Jeor, TDEE = BMR * factor."""
    w = float(user.get('current_weight_kg') or 0)
    h = float(user.get('height_cm') or 0)
    if w <= 0 or h <= 0:
        return 2000
    birth = user.get('birth_date')
    if isinstance(birth, str):
        birth = datetime.strptime(birth[:10], "%Y-%m-%d").date() if birth else None
    age = _age_from_birth(birth)
    gender = (user.get('gender') or 'male').lower()
    bmr = (10 * w) + (6.25 * h) - (5 * age) + (5 if gender == 'male' else -161)
    act = (user.get('activity_level') or 'sedentary').lower()
    factors = {
        'sedentary': 1.2,
        'lightly_active': 1.375,
        'moderately_active': 1.55,
        'very_active': 1.725,
        'extra_active': 1.9,
    }
    tdee = bmr * factors.get(act, 1.2)
    target_kg = float(user.get('target_weight_kg') or w)
    goal_start = user.get('goal_start_date')
    goal_end = user.get('goal_target_date')
    if isinstance(goal_start, str):
        goal_start = datetime.strptime(goal_start[:10], "%Y-%m-%d").date() if goal_start else None
    if isinstance(goal_end, str):
        goal_end = datetime.strptime(goal_end[:10], "%Y-%m-%d").date() if goal_end else None
    num_weeks = 12.0
    if goal_start and goal_end and goal_end > goal_start:
        num_weeks = max((goal_end - goal_start).days / 7.0, 1.0)
    kg_per_week = (target_kg - w) / num_weeks
    target_cal = int(round(tdee + (kg_per_week * 1100)))
    min_safe_cal = max(bmr, 1500) if gender == 'male' else max(bmr, 1200)
    if target_cal < min_safe_cal:
        target_cal = int(round(min_safe_cal))
    return target_cal


def _check_1700_calorie_warning(user_id: int, conn):
    now = datetime.now()
    if now.hour < 17:
        return
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        today_str = now.strftime('%Y-%m-%d')
        cur.execute("SELECT notification_id FROM notifications WHERE user_id = %s AND type = 'warning' AND DATE(created_at) = %s AND title = 'เตือน: แคลอรีวันนี้ยังต่ำเกินไป!'", (user_id, today_str))
        if cur.fetchone():
            return
        cur.execute("SELECT current_weight_kg, height_cm, birth_date, gender FROM users WHERE user_id = %s", (user_id,))
        user_row = cur.fetchone()
        if not user_row:
            return
        w = float(user_row.get('current_weight_kg') or 0)
        h = float(user_row.get('height_cm') or 0)
        birth = user_row.get('birth_date')
        if isinstance(birth, str):
            birth = datetime.strptime(birth[:10], "%Y-%m-%d").date() if birth else None
        age = _age_from_birth(birth)
        gender = (user_row.get('gender') or 'male').lower()
        bmr = (10 * w) + (6.25 * h) - (5 * age) + (5 if gender == 'male' else -161)
        min_safe_cal = max(bmr, 1500) if gender == 'male' else max(bmr, 1200)
        cur.execute("SELECT COALESCE(SUM(total_calories_intake), 0) as cal FROM daily_summaries WHERE user_id = %s AND date_record = %s", (user_id, today_str))
        daily_row = cur.fetchone()
        today_cal = float(daily_row['cal']) if daily_row else 0.0
        if today_cal < min_safe_cal:
            msg = f"ขณะนี้เวลา {now.strftime('%H:%M')} น. คุณเพิ่งทานไปเพียง {int(today_cal)} kcal. ควรทานให้ถึงระะดับขั้นต่ำความปลอดภัย ({int(min_safe_cal)} kcal) เพื่อรักษาระบบเผาผลาญนะ"
            cur.execute("""
                INSERT INTO notifications (user_id, title, message, type)
                VALUES (%s, 'เตือน: แคลอรีวันนี้ยังต่ำเกินไป!', %s, 'warning')
            """, (user_id, msg))
            conn.commit()
    except Exception as e:
        print(f"Warning Check Error: {e}")
        conn.rollback()


def normalize_calories(values: List[float]) -> float:
    if not values:
        return 0.0
    valid = [v for v in values if v is not None and v >= 0]
    if len(valid) < 3:
        return valid[0] if valid else 0.0
    return sum(valid) / len(valid)


def atwater_calories(protein: float, carbs: float, fat: float) -> float:
    return (protein * 4) + (carbs * 4) + (fat * 9)


def _meal_type_to_enum(meal_type: str):
    m = {"meal_1": "breakfast", "meal_2": "lunch", "meal_3": "dinner", "meal_4": "snack"}
    return m.get(meal_type, meal_type)
