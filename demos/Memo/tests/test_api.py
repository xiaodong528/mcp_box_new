import os
import sys
from pathlib import Path

# Use a dedicated test DB for API tests
TEST_DB = Path(__file__).resolve().parent.parent / "backend" / ".test_api.db"
os.environ["MEMO_DB_PATH"] = str(TEST_DB)
if TEST_DB.exists():
    TEST_DB.unlink()

# Ensure project root import when running as a module
ROOT = Path(__file__).resolve().parent.parent
root_str = str(ROOT)
if root_str not in sys.path:
    sys.path.insert(0, root_str)

from fastapi.testclient import TestClient  # noqa: E402
from backend.api import app  # noqa: E402


client = TestClient(app)


def run():
    print("Running API smoke tests...\n")

    # Create memo
    create_payload = {
        "title": "API 首条记录",
        "content": "通过 FastAPI 创建",
        "tags": ["工作", "进度"],
    }
    r = client.post("/memos", json=create_payload)
    assert r.status_code == 201, r.text
    m1 = r.json()
    memo_id = m1["id"]
    assert m1["tags"] == ["工作", "进度"]
    print("Create:", m1)

    # Get memo
    r = client.get(f"/memos/{memo_id}")
    assert r.status_code == 200
    g = r.json()
    assert g["title"] == "API 首条记录"
    print("Get:", g)

    # List memos
    r = client.get("/memos")
    assert r.status_code == 200
    lst = r.json()
    assert len(lst) == 1
    print("List:", lst)

    # Update memo
    r = client.put(f"/memos/{memo_id}", json={"title": "API 更新后的标题"})
    assert r.status_code == 200
    u = r.json()
    assert u["title"] == "API 更新后的标题"
    print("Update:", u)

    # Search
    r = client.get("/memos", params={"search": "FastAPI"})
    assert r.status_code == 200
    search = r.json()
    assert len(search) == 1
    print("Search:", search)

    # Delete memo
    r = client.delete(f"/memos/{memo_id}")
    assert r.status_code == 200
    assert r.json() == {"deleted": True}
    r = client.get("/memos")
    assert r.status_code == 200
    assert r.json() == []
    print("Delete ok, remaining:", r.json())

    print("\nAll API smoke tests passed.")


if __name__ == "__main__":
    run()