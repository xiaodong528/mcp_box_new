from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from . import db


# Ensure DB schema exists when service loads
db.init_db()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _row_to_dict(row) -> Dict[str, Any]:
    return {k: row[k] for k in row.keys()}


def create_memo(title: str, content: str, tags: Optional[List[str]] = None) -> Dict[str, Any]:
    if not title or not content:
        raise ValueError("title 和 content 不可为空")
    tags_json = json.dumps(tags or [])
    created = _now_iso()
    with db.connect() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO memos (title, content, tags, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (title, content, tags_json, created, created),
        )
        memo_id = cur.lastrowid
        cur.execute("SELECT * FROM memos WHERE id=?", (memo_id,))
        row = cur.fetchone()
    return _row_to_dict(row)


def get_memo(memo_id: int) -> Optional[Dict[str, Any]]:
    with db.connect() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM memos WHERE id=?", (memo_id,))
        row = cur.fetchone()
        return _row_to_dict(row) if row else None


def list_memos(search: Optional[str] = None, limit: Optional[int] = None, offset: int = 0) -> List[Dict[str, Any]]:
    sql = "SELECT * FROM memos"
    params: List[Any] = []
    if search:
        sql += " WHERE title LIKE ? OR content LIKE ?"
        like = f"%{search}%"
        params.extend([like, like])
    sql += " ORDER BY updated_at DESC"
    if limit is not None:
        sql += " LIMIT ? OFFSET ?"
        params.extend([limit, offset])
    with db.connect() as conn:
        cur = conn.cursor()
        cur.execute(sql, tuple(params))
        rows = cur.fetchall()
        return [_row_to_dict(r) for r in rows]


def update_memo(
    memo_id: int,
    title: Optional[str] = None,
    content: Optional[str] = None,
    tags: Optional[List[str]] = None,
) -> Dict[str, Any]:
    # Fetch current data
    current = get_memo(memo_id)
    if not current:
        raise ValueError(f"Memo {memo_id} 不存在")
    new_title = title if title is not None else current["title"]
    new_content = content if content is not None else current["content"]
    new_tags = json.dumps(tags) if tags is not None else current["tags"]
    updated = _now_iso()
    with db.connect() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE memos
            SET title = ?, content = ?, tags = ?, updated_at = ?
            WHERE id = ?
            """,
            (new_title, new_content, new_tags, updated, memo_id),
        )
        cur.execute("SELECT * FROM memos WHERE id=?", (memo_id,))
        row = cur.fetchone()
    return _row_to_dict(row)


def delete_memo(memo_id: int) -> bool:
    with db.connect() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM memos WHERE id=?", (memo_id,))
        return cur.rowcount > 0