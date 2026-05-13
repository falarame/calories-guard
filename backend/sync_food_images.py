"""
sync_food_images.py
-----------------------------------------------------
ดึงรายชื่อไฟล์ทั้งหมดจาก Supabase Storage bucket
แล้ว match กับ food_id โดยใช้เลขนำหน้าในชื่อไฟล์
เช่น  01_khaomankaitom.jpg  →  food_id = 1
      17_larbmoo.jpg         →  food_id = 17

วิธีใช้:
  python sync_food_images.py                    # dry-run ดูผลก่อน
  python sync_food_images.py --apply            # update จริง (root bucket)
  python sync_food_images.py --folder food      # ระบุ subfolder
  python sync_food_images.py --folder food --apply
"""

import os
import re
import sys
import httpx
from dotenv import load_dotenv
from database import get_db_connection

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_PROJECT_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "")
BUCKET       = os.getenv("SUPABASE_STORAGE_BUCKET", "food-images")

DRY_RUN = "--apply" not in sys.argv

FOLDER = ""
for i, arg in enumerate(sys.argv):
    if arg == "--folder" and i + 1 < len(sys.argv):
        FOLDER = sys.argv[i + 1].strip("/")


def list_bucket_files() -> list[dict]:
    url = f"{SUPABASE_URL}/storage/v1/object/list/{BUCKET}"
    headers = {"Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json"}
    body = {"prefix": f"{FOLDER}/" if FOLDER else "", "limit": 10000, "offset": 0}
    res = httpx.post(url, json=body, headers=headers, timeout=30)
    res.raise_for_status()
    return res.json()


def public_url(filename: str) -> str:
    path = f"{FOLDER}/{filename}" if FOLDER else filename
    return f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{path}"


def extract_id(filename: str) -> int | None:
    """ดึงเลขนำหน้าชื่อไฟล์  เช่น '04_khaomoodang.jpg' หรือ '51 Sea bass.jpg' → 4, 51"""
    m = re.match(r"^(\d+)[_\-\s]", filename)
    return int(m.group(1)) if m else None


def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("❌ ยังไม่ได้ตั้งค่า SUPABASE_PROJECT_URL หรือ SUPABASE_ANON_KEY ใน .env")
        sys.exit(1)

    print(f"📦 Bucket: {BUCKET}  |  Folder: '{FOLDER or '(root)'}'\n")

    # ดึงไฟล์จาก bucket
    files = list_bucket_files()
    image_files = [f["name"] for f in files if f.get("name") and not f["name"].endswith("/")]
    print(f"พบไฟล์ใน bucket: {len(image_files)} ไฟล์")

    # ดึงอาหารจาก DB (เป็น dict food_id → food_name)
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT food_id, food_name FROM foods ORDER BY food_id")
    food_map = {r[0]: r[1] for r in cur.fetchall()}
    print(f"พบเมนูในฐานข้อมูล: {len(food_map)} รายการ\n")

    updates = []   # (food_id, food_name, filename, url)
    unmatched = []

    for fname in image_files:
        fid = extract_id(fname)
        if fid and fid in food_map:
            updates.append((fid, food_map[fid], fname, public_url(fname)))
        else:
            unmatched.append(fname)

    # แสดงผล
    print(f"{'='*65}")
    print(f"✅ Match ได้: {len(updates)} รายการ")
    for food_id, food_name, fname, _ in sorted(updates):
        print(f"  [{food_id:3}] {food_name:<35} ← {fname}")

    if unmatched:
        print(f"\n⚠️  Match ไม่ได้ (ไม่มีเลขนำหน้า หรือ food_id ไม่มีในDB): {len(unmatched)} ไฟล์")
        for f in unmatched:
            print(f"  - {f}")

    print(f"{'='*65}")

    if DRY_RUN:
        print("\n⚡ DRY-RUN — ยังไม่ update จริง")
        print("   รัน: python sync_food_images.py --folder food --apply")
        conn.close()
        return

    # UPDATE จริง
    for food_id, _, _, url in updates:
        cur.execute("UPDATE foods SET image_url = %s WHERE food_id = %s", (url, food_id))

    conn.commit()
    conn.close()
    print(f"\n✅ Updated {len(updates)} rows เรียบร้อย!")


if __name__ == "__main__":
    main()
