from typing import Optional

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Request
from psycopg2.extras import RealDictCursor
from slowapi import Limiter
from slowapi.util import get_remote_address

from database import get_db_connection
from supabase_storage import upload_to_supabase, upload_avatar_to_supabase, food_range_folder
from app.core.config import MAX_UPLOAD_SIZE, API_VERSION

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


@router.get("/")
def read_root():
    return {"message": "API is running with Infinite Meals & Image Upload!"}


@router.get("/health")
def health():
    """Liveness probe for Render/Railway/Docker health checks.

    `api_version` is included so clients (Flutter / admin-web) can surface
    an "update required" modal when the major segment no longer matches
    `kExpectedApiVersion`. See docs/CHANGELOG_API.md.
    """
    return {"status": "ok", "api_version": API_VERSION}


@router.get("/debug-auth")
def debug_auth(request: Request):
    """Debug endpoint — shows whether Authorization header is received. Remove after fix."""
    auth_header = request.headers.get("authorization", "")
    has_token = bool(auth_header.startswith("Bearer "))
    token_preview = auth_header[7:27] + "..." if has_token else None
    return {
        "code_version": "supabase-client-v1",
        "has_auth_header": has_token,
        "token_preview": token_preview,
    }


def _detect_mime_from_bytes(data: bytes) -> str | None:
    """ตรวจสอบประเภทไฟล์จาก magic bytes — ไม่พึ่ง Content-Type header ของ client"""
    if data[:2] == b'\xff\xd8':
        return 'image/jpeg'
    if data[:4] == b'\x89PNG':
        return 'image/png'
    if data[:4] in (b'GIF8', b'GIF9'):
        return 'image/gif'
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return 'image/webp'
    return None


@router.post("/upload-image/")
@limiter.limit("10/minute")
async def upload_image(
    request: Request,
    file: UploadFile = File(...),
    food_id: int = Form(None),
    user_id: int = Form(None),
):
    """อัปโหลดรูปภาพไปยัง Supabase Storage และคืน public URL.

    ถ้าส่ง ``food_id`` มาด้วย จะตั้งชื่อไฟล์เป็น ``{food_id}_{originalname}.ext``
    เพื่อให้ sync_food_images.py ค้นหาเจอได้อัตโนมัติ.
    """
    try:
        file_bytes = await file.read()
        if len(file_bytes) > MAX_UPLOAD_SIZE:
            raise HTTPException(status_code=413, detail="File too large. Maximum size is 5 MB.")
        if _detect_mime_from_bytes(file_bytes) is None:
            raise HTTPException(status_code=400, detail="File must be a valid image (JPEG, PNG, WebP, or GIF)")
        # Avatar upload → avatars bucket ชื่อไฟล์ = {user_id}.{ext}
        if user_id:
            public_url = upload_avatar_to_supabase(file_bytes, user_id)
            return {"url": public_url}
        # Food image upload → food-images bucket
        filename = file.filename or "image.jpg"
        override = None
        subfolder = None
        if food_id:
            ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "jpg"
            if ext not in ("jpg", "jpeg", "png", "webp", "gif"):
                ext = "jpg"
            override = f"{food_id}_{filename.rsplit('.', 1)[0]}.{ext}"
            subfolder = food_range_folder(food_id)
        public_url = upload_to_supabase(file_bytes, filename, filename_override=override, subfolder=subfolder)
        return {"url": public_url}
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload ล้มเหลว: {str(e)}")


@router.post("/upload_image")
@limiter.limit("10/minute")
async def upload_image_alt(request: Request, file: UploadFile = File(...)):
    """อัปโหลดรูปภาพไปยัง Supabase Storage (endpoint สำรอง)"""
    try:
        file_bytes = await file.read()
        if len(file_bytes) > MAX_UPLOAD_SIZE:
            raise HTTPException(status_code=413, detail="File too large. Maximum size is 5 MB.")
        if _detect_mime_from_bytes(file_bytes) is None:
            raise HTTPException(status_code=400, detail="File must be a valid image (JPEG, PNG, WebP, or GIF)")
        public_url = upload_to_supabase(file_bytes, file.filename)
        return {"image_url": public_url, "url": public_url, "message": "อัปโหลดรูปภาพสำเร็จ"}
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image upload failed: {str(e)}")


@router.get("/units")
def get_units():
    """คืนรายการหน่วยทั้งหมด พร้อม quantity"""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT unit_id, name, quantity FROM units ORDER BY unit_id")
        rows = cur.fetchall()
        return [dict(r) for r in rows]
    finally:
        if conn:
            conn.close()


@router.get("/unit_conversions")
def get_unit_conversions(from_unit_id: Optional[int] = None):
    """คืนตาราง unit_conversions ทั้งหมด หรือกรองด้วย from_unit_id"""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        if from_unit_id:
            cur.execute("""
                SELECT uc.conversion_id,
                       uc.from_unit_id,
                       fu.name AS from_unit_name,
                       uc.to_unit_id,
                       tu.name AS to_unit_name,
                       uc.factor,
                       uc.note
                FROM unit_conversions uc
                JOIN units fu ON fu.unit_id = uc.from_unit_id
                JOIN units tu ON tu.unit_id = uc.to_unit_id
                WHERE uc.from_unit_id = %s
                ORDER BY uc.conversion_id
            """, (from_unit_id,))
        else:
            cur.execute("""
                SELECT uc.conversion_id,
                       uc.from_unit_id,
                       fu.name AS from_unit_name,
                       uc.to_unit_id,
                       tu.name AS to_unit_name,
                       uc.factor,
                       uc.note
                FROM unit_conversions uc
                JOIN units fu ON fu.unit_id = uc.from_unit_id
                JOIN units tu ON tu.unit_id = uc.to_unit_id
                ORDER BY uc.conversion_id
            """)
        rows = cur.fetchall()
        return [dict(r) for r in rows]
    finally:
        if conn:
            conn.close()
