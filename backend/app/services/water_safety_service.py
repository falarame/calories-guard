from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime


DEFAULT_WATER_TARGET_ML = 2000
LOW_WATER_CUTOFF_HOUR = 18
LOW_WATER_RATIO = 0.75
SEVERE_LOW_WATER_RATIO = 0.5


@dataclass(frozen=True)
class WaterSafetyFinding:
    code: str
    severity: str
    title: str
    message: str
    notification_type: str = "tip"

    def as_dict(self) -> dict[str, str]:
        return {
            "code": self.code,
            "severity": self.severity,
            "title": self.title,
            "message": self.message,
            "type": self.notification_type,
        }


def classify_water_safety(
    *,
    amount_ml: int,
    date_record: date,
    target_ml: int = DEFAULT_WATER_TARGET_ML,
    now: datetime | None = None,
) -> list[WaterSafetyFinding]:
    now = now or datetime.now()
    target_ml = max(int(target_ml or DEFAULT_WATER_TARGET_ML), 1)
    amount_ml = max(int(amount_ml or 0), 0)

    should_evaluate = (
        date_record < now.date()
        or (date_record == now.date() and now.hour >= LOW_WATER_CUTOFF_HOUR)
    )
    if not should_evaluate or amount_ml >= target_ml:
        return []

    ratio = amount_ml / target_ml
    remaining = max(target_ml - amount_ml, 0)

    if ratio < SEVERE_LOW_WATER_RATIO:
        return [
            WaterSafetyFinding(
                code="severe_low_water",
                severity="warning",
                title="วันนี้ดื่มน้ำน้อยมาก",
                message=(
                    f"วันนี้บันทึกน้ำไว้ {amount_ml} ml จากเป้าหมาย {target_ml} ml "
                    f"ยังขาดประมาณ {remaining} ml ควรค่อยๆ จิบน้ำเพิ่มก่อนจบวัน"
                ),
            )
        ]

    if ratio < LOW_WATER_RATIO:
        return [
            WaterSafetyFinding(
                code="low_water",
                severity="info",
                title="วันนี้น้ำยังไม่ถึงเป้า",
                message=(
                    f"วันนี้บันทึกน้ำไว้ {amount_ml} ml จากเป้าหมาย {target_ml} ml "
                    f"ยังขาดประมาณ {remaining} ml"
                ),
            )
        ]

    return []


def insert_water_safety_notifications(
    conn,
    user_id: int,
    findings: list[WaterSafetyFinding],
) -> None:
    if not findings:
        return
    cur = conn.cursor()
    for finding in findings:
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
