from __future__ import annotations

import json
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from . import memo_service


app = FastAPI(
    title="Memo API",
    version="0.1.0",
    root_path="/agentV2/general-agent/vnc-app/memo/api"
)

# Allow CORS for local frontend development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class MemoCreate(BaseModel):
    title: str
    content: str
    tags: Optional[List[str]] = None


class MemoUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    tags: Optional[List[str]] = None


class MemoOut(BaseModel):
    id: int
    title: str
    content: str
    tags: List[str]
    created_at: str
    updated_at: str


def _parse_tags(tags_value) -> List[str]:
    if tags_value is None:
        return []
    if isinstance(tags_value, list):
        return [str(t) for t in tags_value]
    if isinstance(tags_value, str):
        try:
            parsed = json.loads(tags_value)
            if isinstance(parsed, list):
                return [str(t) for t in parsed]
        except Exception:
            pass
    return []


def _to_out(memo_dict: dict) -> MemoOut:
    return MemoOut(
        id=memo_dict["id"],
        title=memo_dict["title"],
        content=memo_dict["content"],
        tags=_parse_tags(memo_dict.get("tags")),
        created_at=memo_dict["created_at"],
        updated_at=memo_dict["updated_at"],
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/memos", response_model=MemoOut, status_code=201)
def create_memo_api(payload: MemoCreate):
    created = memo_service.create_memo(payload.title, payload.content, payload.tags)
    return _to_out(created)


@app.get("/memos/{memo_id}", response_model=MemoOut)
def get_memo_api(memo_id: int):
    memo = memo_service.get_memo(memo_id)
    if not memo:
        raise HTTPException(status_code=404, detail="Memo 不存在")
    return _to_out(memo)


@app.get("/memos", response_model=List[MemoOut])
def list_memos_api(
    search: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=None, ge=1),
    offset: int = Query(default=0, ge=0),
):
    memos = memo_service.list_memos(search=search, limit=limit, offset=offset)
    return [_to_out(m) for m in memos]


@app.put("/memos/{memo_id}", response_model=MemoOut)
def update_memo_api(memo_id: int, payload: MemoUpdate):
    try:
        updated = memo_service.update_memo(
            memo_id=memo_id,
            title=payload.title,
            content=payload.content,
            tags=payload.tags,
        )
    except ValueError:
        raise HTTPException(status_code=404, detail="Memo 不存在")
    return _to_out(updated)


@app.delete("/memos/{memo_id}")
def delete_memo_api(memo_id: int):
    ok = memo_service.delete_memo(memo_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Memo 不存在")
    return {"deleted": True}