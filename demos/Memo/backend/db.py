import os
import sqlite3
from pathlib import Path
from typing import Optional


BASE_DIR = Path(__file__).resolve().parent.parent


def _get_db_path() -> Path:
    """Resolve the SQLite DB path, allowing override via MEMO_DB_PATH env."""
    override = os.environ.get("MEMO_DB_PATH")
    if override:
        return Path(override)
    return BASE_DIR / "memo.db"


DB_PATH = _get_db_path()


def connect() -> sqlite3.Connection:
    """Create a SQLite connection with Row factory for dict-like access."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create tables if they do not exist."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with connect() as conn:
        cur = conn.cursor()
        # Basic memo table: title, content, timestamps, optional tags (JSON string)
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS memos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                tags TEXT DEFAULT '[]',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        # Simple index to help recent queries
        cur.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_memos_updated_at
            ON memos(updated_at);
            """
        )
        conn.commit()


def table_exists(table_name: str) -> bool:
    with connect() as conn:
        cur = conn.cursor()
        cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,),
        )
        return cur.fetchone() is not None


def ensure_initialized() -> None:
    if not table_exists("memos"):
        init_db()