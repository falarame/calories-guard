import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

import httpx

from app.core.config import (
    SMTP_SERVER, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD,
    FROM_EMAIL, FROM_NAME,
)

RESEND_API_KEY   = os.getenv("RESEND_API_KEY", "")
SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY", "")


def send_email(to_email: str, subject: str, html_body: str) -> bool:
    # ── SendGrid (HTTPS — works on Railway) ──────────────────────────────
    if SENDGRID_API_KEY:
        try:
            resp = httpx.post(
                "https://api.sendgrid.com/v3/mail/send",
                headers={"Authorization": f"Bearer {SENDGRID_API_KEY}"},
                json={
                    "personalizations": [{"to": [{"email": to_email}]}],
                    "from": {"email": FROM_EMAIL, "name": FROM_NAME},
                    "subject": subject,
                    "content": [{"type": "text/html", "value": html_body}],
                },
                timeout=10,
            )
            if resp.status_code in (200, 202):
                print(f"[Email] ✅ SendGrid sent to {to_email}: {subject}")
                return True
            print(f"[Email] SendGrid error {resp.status_code}: {resp.text}")
            return False
        except Exception as e:
            print(f"[Email] SendGrid exception for {to_email}: {e}")
            return False

    # ── Resend (HTTPS fallback) ───────────────────────────────────────────
    if RESEND_API_KEY:
        try:
            resp = httpx.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {RESEND_API_KEY}"},
                json={
                    "from": f"{FROM_NAME} <{FROM_EMAIL}>",
                    "to": [to_email],
                    "subject": subject,
                    "html": html_body,
                },
                timeout=10,
            )
            if resp.status_code in (200, 201):
                print(f"[Email] ✅ Resend sent to {to_email}: {subject}")
                return True
            print(f"[Email] Resend error {resp.status_code}: {resp.text}")
            return False
        except Exception as e:
            print(f"[Email] Resend exception for {to_email}: {e}")
            return False

    # ── SMTP fallback (local dev) ─────────────────────────────────────────
    if not SMTP_USERNAME or not SMTP_PASSWORD:
        print(f"[Email] Not configured. Would send to {to_email}: {subject}")
        return False
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{FROM_NAME} <{FROM_EMAIL}>"
        msg["To"] = to_email
        msg.attach(MIMEText(html_body, "html"))
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=10) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(FROM_EMAIL, to_email, msg.as_string())
        print(f"[Email] ✅ SMTP sent to {to_email}: {subject}")
        return True
    except Exception as e:
        print(f"[Email] Failed to send to {to_email}: {e}")
        return False


def send_welcome_email(email: str, username: str) -> bool:
    subject = "ยินดีต้อนรับสู่ Calories Guard!"
    html = f"""
    <html>
    <body style="font-family: sans-serif; padding: 20px;">
        <h2>สวัสดีครับ/ค่ะ {username}!</h2>
        <p>ขอบคุณที่สมัครสมาชิก <strong>Calories Guard</strong></p>
        <p>ตอนนี้คุณสามารถเริ่มติดตามการรับประทานอาหารและเป้าหมายสุขภาพของคุณได้แล้ว</p>
        <p>หากมีคำถาม ติดต่อเราได้เสมอ</p>
        <br>
        <p>ด้วยความปรารถนาดี,<br>ทีมงาน Calories Guard</p>
    </html>
    """
    return send_email(email, subject, html)


def send_verification_email(email: str, username: str, code: str) -> bool:
    subject = "ยืนยันอีเมลของคุณ - Calories Guard"
    html = f"""
    <html>
    <body style="font-family: sans-serif; padding: 20px;">
        <h2>สวัสดีครับ/ค่ะ {username}!</h2>
        <p>กรุณายืนยันอีเมลของคุณเพื่อเริ่มใช้งาน</p>
        <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3>รหัสยืนยันของคุณ: <strong>{code}</strong></h3>
        </div>
        <p>ขอบคุณที่ร่วมเป็นส่วนหนึ่งกับเรา</p>
    </body>
    </html>
    """
    return send_email(email, subject, html)


def send_food_request_notification(food_name: str, tf_id: int, submitted_by: str = "ผู้ใช้") -> bool:
    from app.core.config import ADMIN_NOTIFY_EMAIL, ADMIN_URL
    if not ADMIN_NOTIFY_EMAIL:
        print("[Email] ADMIN_NOTIFY_EMAIL not set, skipping food request notification")
        return False

    recipients = [e.strip() for e in ADMIN_NOTIFY_EMAIL.split(",") if e.strip()]
    if not recipients:
        return False

    if ADMIN_URL:
        button_html = (
            '<div style="margin-top: 20px; text-align: center;">'
            '<a href="' + ADMIN_URL + '" target="_blank"'
            ' style="display: inline-block; background: #628141; color: white;'
            ' text-decoration: none; padding: 12px 28px; border-radius: 8px;'
            ' font-size: 15px; font-weight: bold;">'
            'ไปหน้า Admin Panel'
            '</a></div>'
        )
    else:
        button_html = ""

    subject = f"[CaloriesGuard] มีคำขอเพิ่มเมนูใหม่: {food_name}"
    html = f"""
    <html>
    <body style="font-family: sans-serif; padding: 20px; background: #f9f9f9;">
      <div style="max-width: 480px; margin: auto; background: white; border-radius: 12px;
                  padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
        <h2 style="color: #628141; margin-top: 0;">🍽️ คำขอเพิ่มเมนูใหม่</h2>
        <table style="width:100%; border-collapse: collapse; font-size: 14px;">
          <tr>
            <td style="padding: 8px 0; color: #666;">ชื่อเมนู</td>
            <td style="padding: 8px 0; font-weight: bold;">{food_name}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #666;">Request ID</td>
            <td style="padding: 8px 0;"># {tf_id}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #666;">ส่งโดย</td>
            <td style="padding: 8px 0;">{submitted_by}</td>
          </tr>
        </table>
        {button_html}
        <p style="margin-top: 16px; font-size: 12px; color: #aaa;">
          Calories Guard Admin Notification
        </p>
      </div>
    </body>
    </html>
    """
    results = [send_email(email, subject, html) for email in recipients]
    return any(results)


def send_invite_email(email: str, inviter_name: str, invite_url: str) -> bool:
    """Send a referral invite to a friend on behalf of `inviter_name`."""
    subject = f"{inviter_name} ชวนคุณมาใช้ Calories Guard 🎁"
    html = f"""
    <html>
    <body style="font-family: sans-serif; padding: 20px; background: #f9f9f9;">
      <div style="max-width: 520px; margin: auto; background: white; border-radius: 12px;
                  padding: 28px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
        <h2 style="color: #628141; margin-top: 0;">🎉 {inviter_name} ส่งคำเชิญถึงคุณ!</h2>
        <p style="font-size: 15px; color: #333; line-height: 1.6;">
          คุณได้รับเชิญให้มาใช้ <strong>Calories Guard</strong> —
          แอปดูแลโภชนาการและสุขภาพ ที่ช่วยบันทึกแคลอรี่และเป้าหมายของคุณได้ง่ายๆ
        </p>
        <div style="background: #E8EFCF; padding: 14px 18px; border-radius: 10px; margin: 20px 0;
                    color: #3D5A27; font-size: 14px;">
          ✨ สมัครผ่านลิงก์นี้รับ <strong>20 gems ฟรี</strong> เริ่มต้นทันที!
        </div>
        <div style="text-align: center; margin: 28px 0;">
          <a href="{invite_url}" target="_blank"
             style="display: inline-block; background: #628141; color: white;
                    text-decoration: none; padding: 14px 32px; border-radius: 10px;
                    font-size: 16px; font-weight: bold;">
            เปิดลิงก์เชิญ
          </a>
        </div>
        <p style="color: #888; font-size: 12px; word-break: break-all;">
          ถ้ากดปุ่มไม่ได้ คัดลอกลิงก์นี้ไปวางในเบราว์เซอร์:<br>
          {invite_url}
        </p>
        <p style="color: #aaa; font-size: 12px; margin-top: 24px;">
          ลิงก์นี้จะหมดอายุภายใน 14 วัน
        </p>
      </div>
    </body>
    </html>
    """
    return send_email(email, subject, html)


def send_password_reset_email(email: str, username: str, code: str) -> bool:
    subject = "รีเซ็ตรหัสผ่าน - Calories Guard"
    html = f"""
    <html>
    <body style="font-family: sans-serif; padding: 20px;">
        <h2>สวัสดีครับ/ค่ะ {username}</h2>
        <p>คุณได้ร้องขอการรีเซ็ตรหัสผ่าน</p>
        <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3>รหัสยืนยันของคุณ: <strong>{code}</strong></h3>
        </div>
        <p>รหัสนี้จะหมดอายุภายใน 15 นาที</p>
        <p>หากคุณไม่ได้ร้องขอการรีเซ็ตรหัสผ่าน กรุณาเพิกเฉยต่ออีเมลนี้</p>
        <br>
        <p>ด้วยความปรารถนาดี,<br>ทีมงาน Calories Guard</p>
    </body>
    </html>
    """
    return send_email(email, subject, html)
