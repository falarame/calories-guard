import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

def get_db_connection():
    """Return PostgreSQL connection.

    Priority:
    1. DIRECT_DATABASE_URL or DATABASE_URL (full DSN)
    2. Individual vars based on DB_MODE:
       - supabase → SUPABASE_HOST/NAME/USER/PASSWORD/PORT
       - local    → DB_HOST/NAME/USER/PASSWORD/PORT
    """
    database_url = os.getenv("DIRECT_DATABASE_URL") or os.getenv("DATABASE_URL")

    if not database_url:
        mode = os.getenv("DB_MODE", "local").strip().lower()
        if mode == "supabase":
            host     = os.getenv("SUPABASE_HOST", "")
            dbname   = os.getenv("SUPABASE_NAME", "postgres")
            user     = os.getenv("SUPABASE_USER", "postgres")
            password = os.getenv("SUPABASE_PASSWORD", "")
            port     = os.getenv("SUPABASE_PORT", "5432")
        else:
            host     = os.getenv("DB_HOST", "localhost")
            dbname   = os.getenv("DB_NAME", "cleangoal_db")
            user     = os.getenv("DB_USER", "postgres")
            password = os.getenv("DB_PASSWORD", "")
            port     = os.getenv("DB_PORT", "5432")

        if not host or not password:
            print("[DB] ❌ DB credentials not set in .env")
            return None

        database_url = (
            f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
            "?sslmode=require"
        )

    try:
        conn = psycopg2.connect(database_url)
        with conn.cursor() as cur:
            cur.execute("SET search_path TO cleangoal, public")
        conn.commit()
        print("[DB] ✅ Connected to database successfully")
        return conn
    except Exception as e:
        print(f"[DB] ❌ Connection failed: {e}")
        return None
