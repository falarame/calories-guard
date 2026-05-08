"""
run_migrations.py
รัน migration SQL files บน local หรือ Supabase PostgreSQL ตามลำดับ
รองรับ schema_migrations table เพื่อ track ว่า migration ไหนรันแล้ว
"""

import os
import sys
from pathlib import Path
import psycopg2
from dotenv import load_dotenv

# โหลด .env จาก root หรือ backend
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

DB_MODE = os.getenv("DB_MODE", "local").lower()

def _build_config():
    database_url = os.getenv("DIRECT_DATABASE_URL") or os.getenv("DATABASE_URL")
    if database_url:
        return {
            "dsn": database_url,
            "label": "connection-string",
        }

    if DB_MODE == "supabase":
        return {
            "host":     os.getenv("SUPABASE_HOST"),
            "database": os.getenv("SUPABASE_NAME", "postgres"),
            "user":     os.getenv("SUPABASE_USER", "postgres"),
            "password": os.getenv("SUPABASE_PASSWORD"),
            "port":     os.getenv("SUPABASE_PORT", "5432"),
            "options":  "-c search_path=cleangoal,public",
            "sslmode":  "require",
        }
    else:
        return {
            "host":     os.getenv("DB_HOST", "localhost"),
            "database": os.getenv("DB_NAME", "cleangoal_db"),
            "user":     os.getenv("DB_USER", "postgres"),
            "password": os.getenv("DB_PASSWORD", ""),
            "port":     os.getenv("DB_PORT", "5432"),
            "options":  "-c search_path=cleangoal,public",
        }

MIGRATIONS_DIR = os.path.join(os.path.dirname(__file__), "migrations")

# ไฟล์ที่ต้องการรัน (เรียงลำดับ)
TARGET_MIGRATIONS = [
    "v8_add_macros_water_to_daily_summaries.sql",
    "v9_create_water_logs.sql",
    "v10_create_exercise_logs.sql",
    "v11_add_performance_indexes.sql",
    "v12_add_consent_and_detail_macros.sql",
    "v13_create_temp_and_verified_food.sql",
    "add_target_macros_to_users.sql",
    "v14_a_critical_fixes.sql",
    "v14_b_integrity.sql",
    "v14_c_deduplicate.sql",
    "v14_d_seed_units.sql",
    "v14_e_timestamptz.sql",
    "v14_f_drop_unused.sql",
    "v15_a_drop_public_leftovers.sql",
    "v15_b_function_search_path.sql",
    "v15_c_rls_policies.sql",
    "v15_d_storage_bucket_tighten.sql",
    "v15_e_users_soft_delete.sql",
    "v16_a_recipes_ai_fields.sql",
    "v17_recipe_consistency.sql",
    "v18_dishes_3nf_integrity.sql",
    "v19_detail_items_unit_fk.sql",
    "v20_regional_names_and_user_region.sql",
    "v21_drop_foods_legacy_columns.sql",
    "v22_drop_unused_tables.sql",
    "v24_audit_columns_and_sync_triggers.sql",
    "v25_restore_ingredients_relations.sql",
    "v26_food_versioning_and_log_snapshots.sql",
    "v27_seed_beverages_table.sql",
    "v28_thaifcd_import_foods.sql",
]


def ensure_schema_migrations(cur):
    """Create the migration tracking table if it does not exist.

    Supabase live already uses `version`; older local scripts used `name`.
    New databases should use `version`.
    """
    cur.execute("""
        CREATE TABLE IF NOT EXISTS cleangoal.schema_migrations (
            version     VARCHAR(255) PRIMARY KEY,
            applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """)


def get_migration_column(cur):
    cur.execute("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'cleangoal'
          AND table_name = 'schema_migrations'
          AND column_name IN ('version', 'name')
        ORDER BY CASE column_name WHEN 'version' THEN 0 ELSE 1 END
        LIMIT 1
    """)
    row = cur.fetchone()
    if not row:
        raise RuntimeError("cleangoal.schema_migrations has no version/name column")
    return row[0]


def get_applied_migrations(cur):
    """Return applied migration aliases.

    Historical rows are mixed: v8-v13 were stored as `file.sql`; v14+ were
    stored as `file` without extension. Keep both aliases so the runner is
    idempotent across existing Supabase and local databases.
    """
    column = get_migration_column(cur)
    cur.execute(f"SELECT {column} FROM cleangoal.schema_migrations")
    applied = set()
    for row in cur.fetchall():
        value = row[0]
        applied.add(value)
        stem = Path(value).stem
        applied.add(stem)
        applied.add(f"{stem}.sql")
    return applied


def record_migration(cur, filename):
    column = get_migration_column(cur)
    version = Path(filename).stem
    cur.execute(
        f"INSERT INTO cleangoal.schema_migrations ({column}) VALUES (%s) "
        f"ON CONFLICT ({column}) DO NOTHING",
        (version,),
    )


def run_migrations():
    mode_label = "Supabase" if DB_MODE == "supabase" else "Local"
    config = _build_config()
    connection_label = config.pop("label", None)

    print("=" * 60)
    print(f"Calories Guard — DB Migration Runner ({mode_label})")
    print("=" * 60)
    if "dsn" in config:
        print(f"DB: {connection_label}")
    else:
        host = config.get("host") or ""
        redacted_host = f"{host[:8]}..." if host else "missing"
        print(f"DB: {config.get('user')}@{redacted_host}:{config.get('port')}/{config.get('database')}")
    print()

    try:
        if "dsn" in config:
            conn = psycopg2.connect(config["dsn"])
            with conn.cursor() as cur:
                cur.execute("SET search_path TO cleangoal, public")
            conn.commit()
        else:
            conn = psycopg2.connect(**config)
        conn.autocommit = False
        cur = conn.cursor()
        print("Connected to database\n")
    except Exception as e:
        print(f"ERROR: Cannot connect to DB: {e}")
        sys.exit(1)

    try:
        # สร้างตาราง tracking
        ensure_schema_migrations(cur)
        conn.commit()

        applied = get_applied_migrations(cur)
        print(f"Already applied: {len(applied)} migration(s)\n")

        success = 0
        skipped = 0
        failed = 0

        for filename in TARGET_MIGRATIONS:
            if filename in applied:
                print(f"  SKIP: {filename} (already applied)")
                skipped += 1
                continue

            filepath = os.path.join(MIGRATIONS_DIR, filename)
            if not os.path.exists(filepath):
                print(f"  WARN: {filename} not found, skipping")
                continue

            print(f"  RUN:  {filename}")
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    sql = f.read()

                cur.execute(sql)
                record_migration(cur, filename)
                conn.commit()
                print(f"        OK")
                success += 1

            except Exception as e:
                conn.rollback()
                print(f"        FAILED: {e}")
                failed += 1
                break

        print()
        print("=" * 60)
        print(f"Summary: {success} applied | {skipped} skipped | {failed} failed")
        print("=" * 60)

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    run_migrations()
