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
