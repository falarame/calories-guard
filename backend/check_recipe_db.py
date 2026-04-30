"""Diagnostic script: check recipe-related tables in the DB."""
from database import get_db_connection
from psycopg2.extras import RealDictCursor

conn = get_db_connection()
if not conn:
    print("Cannot connect to DB — check .env")
    exit(1)

cur = conn.cursor(cursor_factory=RealDictCursor)

SEP = "-" * 60

# ── 1. recipes ──────────────────────────────────────────────
print(f"\n{'='*60}")
print("TABLE: recipes  (sample 5 rows)")
print(SEP)
cur.execute("""
    SELECT recipe_id, food_id, generated_by,
           length(instructions) AS instr_len,
           LEFT(instructions, 120) AS instructions_preview,
           ingredients_json IS NOT NULL AS has_ing_json,
           tools_json IS NOT NULL AS has_tools_json,
           tips_json IS NOT NULL AS has_tips_json
    FROM cleangoal.recipes
    WHERE deleted_at IS NULL
    ORDER BY recipe_id DESC LIMIT 5
""")
for r in cur.fetchall():
    print(dict(r))

# ── 2. recipe_steps ─────────────────────────────────────────
print(f"\n{'='*60}")
print("TABLE: recipe_steps  (count per recipe_id, top 5)")
print(SEP)
cur.execute("""
    SELECT recipe_id, COUNT(*) AS step_count,
           MIN(step_number) AS first_step, MAX(step_number) AS last_step
    FROM cleangoal.recipe_steps
    GROUP BY recipe_id
    ORDER BY recipe_id DESC LIMIT 5
""")
rows = cur.fetchall()
print(rows if rows else ">>> EMPTY — no rows in recipe_steps")

# ── 3. recipe_ingredients ────────────────────────────────────
print(f"\n{'='*60}")
print("TABLE: recipe_ingredients  (count per recipe_id, top 5)")
print(SEP)
cur.execute("""
    SELECT recipe_id, COUNT(*) AS ing_count
    FROM cleangoal.recipe_ingredients
    GROUP BY recipe_id
    ORDER BY recipe_id DESC LIMIT 5
""")
rows = cur.fetchall()
print(rows if rows else ">>> EMPTY — no rows in recipe_ingredients")

# ── 4. recipe_tools ──────────────────────────────────────────
print(f"\n{'='*60}")
print("TABLE: recipe_tools  (count per recipe_id, top 5)")
print(SEP)
cur.execute("""
    SELECT recipe_id, COUNT(*) AS tool_count
    FROM cleangoal.recipe_tools
    GROUP BY recipe_id
    ORDER BY recipe_id DESC LIMIT 5
""")
rows = cur.fetchall()
print(rows if rows else ">>> EMPTY — no rows in recipe_tools")

# ── 5. recipe_tips ───────────────────────────────────────────
print(f"\n{'='*60}")
print("TABLE: recipe_tips  (count per recipe_id, top 5)")
print(SEP)
cur.execute("""
    SELECT recipe_id, COUNT(*) AS tip_count
    FROM cleangoal.recipe_tips
    GROUP BY recipe_id
    ORDER BY recipe_id DESC LIMIT 5
""")
rows = cur.fetchall()
print(rows if rows else ">>> EMPTY — no rows in recipe_tips")

# ── 6. recipe_reviews ────────────────────────────────────────
print(f"\n{'='*60}")
print("TABLE: recipe_reviews  (all rows)")
print(SEP)
cur.execute("SELECT * FROM cleangoal.recipe_reviews ORDER BY created_at DESC LIMIT 10")
rows = cur.fetchall()
print([dict(r) for r in rows] if rows else ">>> EMPTY — no rows in recipe_reviews")

# ── 7. ingredients_json sample ───────────────────────────────
print(f"\n{'='*60}")
print("ingredients_json sample (first non-null recipe)")
print(SEP)
cur.execute("""
    SELECT recipe_id, ingredients_json, tools_json, tips_json
    FROM cleangoal.recipes
    WHERE ingredients_json IS NOT NULL AND deleted_at IS NULL
    ORDER BY recipe_id DESC LIMIT 1
""")
row = cur.fetchone()
if row:
    print("ingredients_json:", row["ingredients_json"])
    print("tools_json:", row["tools_json"])
    print("tips_json:", row["tips_json"])
else:
    print(">>> No recipe has ingredients_json set")

conn.close()
print(f"\n{'='*60}")
print("Done.")
