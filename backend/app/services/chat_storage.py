"""
Chat attachment upload helper.

Wraps Supabase Storage uploads for the `chat-attachments` bucket. Reuses
the project's existing env vars (SUPABASE_PROJECT_URL + SUPABASE_SERVICE_ROLE_KEY)
from supabase_storage.py to stay consistent.

The bucket is expected to exist and be configured private. The backend uses
the service-role key (RLS-bypassing), so per-conversation membership checks
must happen inside the FastAPI handler BEFORE calling upload_chat_attachment().
"""

from __future__ import annotations

import os
from uuid import uuid4

import httpx

CHAT_BUCKET = "chat-attachments"

_ALLOWED_IMAGE_EXTS = {"jpg", "jpeg", "png", "webp", "gif", "heic"}
_ALLOWED_DOC_EXTS = {"pdf", "txt", "csv", "doc", "docx", "xls", "xlsx"}
_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB


def _supabase_creds() -> tuple[str, str]:
    url = os.getenv("SUPABASE_PROJECT_URL", "") or os.getenv("SUPABASE_URL", "")
    key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_KEY")
        or os.getenv("SUPABASE_ANON_KEY", "")
    )
    return url, key


def _ext_for(filename: str, fallback: str = "bin") -> str:
    if "." not in filename:
        return fallback
    ext = filename.rsplit(".", 1)[-1].lower()
    return ext if ext.isalnum() and len(ext) <= 5 else fallback


def _content_type_for(ext: str) -> str:
    return {
        "jpg":  "image/jpeg",
        "jpeg": "image/jpeg",
        "png":  "image/png",
        "webp": "image/webp",
        "gif":  "image/gif",
        "heic": "image/heic",
        "pdf":  "application/pdf",
        "txt":  "text/plain",
        "csv":  "text/csv",
    }.get(ext, "application/octet-stream")


def upload_chat_attachment(
    file_bytes: bytes,
    original_filename: str,
    conversation_id: int,
    sender_user_id: int,
) -> dict:
    """Upload a chat attachment. Returns {url, mime, size, name, kind}.

    Path scheme: `{conversation_id}/{sender_user_id}_{uuid}.{ext}` — keeps
    one folder per conversation so storage RLS can match on the path prefix.
    """
    if not file_bytes:
        raise ValueError("ไฟล์ว่าง")
    if len(file_bytes) > _MAX_UPLOAD_BYTES:
        raise ValueError(f"ไฟล์ใหญ่เกิน {_MAX_UPLOAD_BYTES // (1024*1024)} MB")

    url, key = _supabase_creds()
    if not url or not key:
        raise ValueError("Supabase storage not configured (SUPABASE_PROJECT_URL / SUPABASE_KEY)")

    ext = _ext_for(original_filename)
    if ext not in (_ALLOWED_IMAGE_EXTS | _ALLOWED_DOC_EXTS):
        raise ValueError(f"ไม่อนุญาตไฟล์นามสกุล .{ext}")

    kind = "image" if ext in _ALLOWED_IMAGE_EXTS else "file"
    content_type = _content_type_for(ext)
    object_path = f"{conversation_id}/{sender_user_id}_{uuid4().hex}.{ext}"
    upload_url = f"{url}/storage/v1/object/{CHAT_BUCKET}/{object_path}"

    response = httpx.post(
        upload_url,
        content=file_bytes,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": content_type,
            "x-upsert": "false",
        },
        timeout=30,
    )
    if response.status_code not in (200, 201):
        raise ValueError(f"Upload ล้มเหลว: {response.status_code} — {response.text}")

    public_url = f"{url}/storage/v1/object/public/{CHAT_BUCKET}/{object_path}"
    return {
        "url": public_url,
        "mime": content_type,
        "size": len(file_bytes),
        "name": original_filename,
        "kind": kind,
    }
