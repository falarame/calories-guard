"""
supabase_storage.py
Helper สำหรับอัปโหลดรูปภาพไปยัง Supabase Storage
"""

import os
import httpx
from uuid import uuid4
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

SUPABASE_URL    = os.getenv("SUPABASE_PROJECT_URL", "") or os.getenv("SUPABASE_URL", "")
# Prefer service-role key for backend uploads: it bypasses RLS, so the
# food-images bucket can tighten its INSERT/UPDATE/DELETE policies and
# still accept uploads from the backend. Fall back to the anon key only
# for local dev convenience.
SUPABASE_KEY    = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_ANON_KEY", "")
)
STORAGE_BUCKET  = os.getenv("SUPABASE_STORAGE_BUCKET", "food-images")

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "gif"}

MIME_MAP = {
    "jpg":  "image/jpeg",
    "jpeg": "image/jpeg",
    "png":  "image/png",
    "webp": "image/webp",
    "gif":  "image/gif",
}


AVATAR_BUCKET = "avatars"
_AVATAR_EXTS = ["jpg", "jpeg", "png", "webp", "gif"]

def _mime_from_bytes(data: bytes) -> tuple[str, str]:
    """คืน (ext, content_type) จาก magic bytes"""
    if data[:2] == b'\xff\xd8':
        return "jpg", "image/jpeg"
    if data[:4] == b'\x89PNG':
        return "png", "image/png"
    if data[:4] in (b'GIF8', b'GIF9'):
        return "gif", "image/gif"
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return "webp", "image/webp"
    return "jpg", "image/jpeg"


def _delete_supabase_object(bucket: str, path: str) -> None:
    """ลบไฟล์ใน Supabase Storage (ไม่ raise ถ้าไม่มีไฟล์)"""
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    headers = {"Authorization": f"Bearer {SUPABASE_KEY}"}
    httpx.delete(url, headers=headers, timeout=10)


def upload_avatar_to_supabase(file_bytes: bytes, user_id: int) -> str:
    """อัปโหลด avatar ไปยัง bucket 'avatars' ชื่อไฟล์ = {user_id}.{ext}
    - ตรวจ ext จาก magic bytes
    - ลบไฟล์ ext เก่าออกก่อน (กรณีเปลี่ยนนามสกุล เช่น .jpg → .png)
    - ใช้ x-upsert=true ถ้า ext เดิม (overwrite ไม่เพิ่มไฟล์)
    - คืน public URL
    """
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("ยังไม่ได้ตั้งค่า SUPABASE_PROJECT_URL หรือ SUPABASE_KEY ใน .env")

    ext, content_type = _mime_from_bytes(file_bytes)
    new_filename = f"{user_id}.{ext}"

    # ลบทุก extension ก่อนเสมอ (ทั้ง ext เดิมและต่าง ext) เพื่อ force fresh upload
    for old_ext in _AVATAR_EXTS:
        _delete_supabase_object(AVATAR_BUCKET, f"{user_id}.{old_ext}")

    upload_url = f"{SUPABASE_URL}/storage/v1/object/{AVATAR_BUCKET}/{new_filename}"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type":  content_type,
        "x-upsert":      "true",
    }
    response = httpx.post(upload_url, content=file_bytes, headers=headers, timeout=30)
    if response.status_code not in (200, 201):
        raise ValueError(f"Avatar upload ล้มเหลว: {response.status_code} — {response.text}")

    return f"{SUPABASE_URL}/storage/v1/object/public/{AVATAR_BUCKET}/{new_filename}"


def upload_to_supabase(file_bytes: bytes, original_filename: str, filename_override: str = None) -> str:
    """
    อัปโหลดไฟล์รูปไปยัง Supabase Storage bucket 'food-images'
    คืน public URL ของรูปที่อัปโหลด
    filename_override: ถ้าระบุ จะใช้ชื่อนี้ตรงๆ แทน UUID
    raises ValueError ถ้า config ไม่ครบหรือ upload ล้มเหลว
    """
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("ยังไม่ได้ตั้งค่า SUPABASE_PROJECT_URL หรือ SUPABASE_ANON_KEY ใน .env")

    ext = original_filename.rsplit(".", 1)[-1].lower() if "." in original_filename else "jpg"
    if ext not in ALLOWED_EXTENSIONS:
        ext = "jpg"

    if filename_override:
        # ใช้ชื่อที่ระบุ เช่น '103_kaijeawkung.jpg'
        safe = filename_override.replace(" ", "_")
        new_filename = safe if "." in safe else f"{safe}.{ext}"
    else:
        new_filename = f"food_{uuid4().hex}.{ext}"
    content_type = MIME_MAP.get(ext, "image/jpeg")

    upload_url = f"{SUPABASE_URL}/storage/v1/object/{STORAGE_BUCKET}/{new_filename}"

    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type":  content_type,
        "x-upsert":      "true",   # ถ้าชื่อซ้ำให้ replace
    }

    response = httpx.post(upload_url, content=file_bytes, headers=headers, timeout=30)

    if response.status_code not in (200, 201):
        raise ValueError(f"Supabase Storage upload ล้มเหลว: {response.status_code} — {response.text}")

    # Public URL (bucket ถูกตั้งเป็น public แล้ว)
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{STORAGE_BUCKET}/{new_filename}"
    return public_url
