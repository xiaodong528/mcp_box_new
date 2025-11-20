import os
import sys
from pathlib import Path

# Use a dedicated test DB
TEST_DB = Path(__file__).resolve().parent.parent / "backend" / ".test_memo.db"
os.environ["MEMO_DB_PATH"] = str(TEST_DB)

# Clean previous test DB
if TEST_DB.exists():
    TEST_DB.unlink()

# Ensure project root is importable when running as a script
ROOT = Path(__file__).resolve().parent.parent
root_str = str(ROOT)
if root_str not in sys.path:
    sys.path.insert(0, root_str)

from backend import memo_service  # noqa: E402


def run():
    print("Running backend smoke tests...\n")

    # Create
    m1 = memo_service.create_memo("第一次记录", "今天完成了数据库模块", ["工作", "进度"])
    assert m1["id"] > 0
    print("Create memo:", m1)

    # Get
    g = memo_service.get_memo(m1["id"])
    assert g is not None and g["title"] == "第一次记录"
    print("Get memo:", g)

    # List
    lst = memo_service.list_memos()
    assert len(lst) == 1
    print("List memos:", lst)

    # Update
    u = memo_service.update_memo(m1["id"], title="更新后的标题")
    assert u["title"] == "更新后的标题"
    print("Update memo:", u)

    # Search
    search = memo_service.list_memos(search="数据库")
    assert len(search) == 1
    print("Search memos:", search)

    # Delete
    ok = memo_service.delete_memo(m1["id"])
    assert ok is True
    after = memo_service.list_memos()
    assert len(after) == 0
    print("Delete memo ok, remaining:", after)

    print("\nAll backend smoke tests passed.")


if __name__ == "__main__":
    run()