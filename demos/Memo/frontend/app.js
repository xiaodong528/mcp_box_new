const API_BASE = "http://127.0.0.1:8000";

const els = {
  createForm: document.getElementById("createForm"),
  title: document.getElementById("titleInput"),
  content: document.getElementById("contentInput"),
  tags: document.getElementById("tagsInput"),
  memoList: document.getElementById("memoList"),
  searchForm: document.getElementById("searchForm"),
  searchInput: document.getElementById("searchInput"),
  searchBtn: document.getElementById("searchBtn"),
  resetBtn: document.getElementById("resetBtn"),
};

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text}`);
  }
  return res.json();
}

function parseTags(input) {
  return (input || "")
    .split(",")
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

function renderMemos(items) {
  els.memoList.innerHTML = "";
  items.forEach((m) => {
    const div = document.createElement("div");
    div.className = "memo";

    const title = document.createElement("h3");
    title.textContent = m.title;

    const content = document.createElement("p");
    content.textContent = m.content;

    const meta = document.createElement("div");
    meta.className = "meta";
    meta.textContent = `#${(m.tags || []).join(", ")} · 更新: ${new Date(m.updated_at).toLocaleString()}`;

    const actions = document.createElement("div");
    actions.className = "actions";

    const editBtn = document.createElement("button");
    editBtn.className = "secondary";
    editBtn.textContent = "编辑";
    editBtn.onclick = () => showEdit(div, m);

    const delBtn = document.createElement("button");
    delBtn.className = "danger";
    delBtn.textContent = "删除";
    delBtn.onclick = async () => {
      if (!confirm("确认删除该备忘录？")) return;
      await request(`/memos/${m.id}`, { method: "DELETE" });
      await loadMemos();
    };

    actions.appendChild(editBtn);
    actions.appendChild(delBtn);

    div.appendChild(title);
    div.appendChild(content);
    div.appendChild(meta);
    div.appendChild(actions);
    els.memoList.appendChild(div);
  });
}

function showEdit(container, memo) {
  const form = document.createElement("div");
  form.className = "memo-edit";
  form.innerHTML = `
    <input type="text" class="edit-title" value="${memo.title}" />
    <textarea class="edit-content" rows="3">${memo.content}</textarea>
    <input type="text" class="edit-tags" value="${(memo.tags || []).join(", ")}" />
    <div class="actions">
      <button class="secondary save">保存</button>
      <button class="danger cancel">取消</button>
    </div>
  `;
  const [titleI, contentI, tagsI] = [
    form.querySelector(".edit-title"),
    form.querySelector(".edit-content"),
    form.querySelector(".edit-tags"),
  ];
  const saveBtn = form.querySelector(".save");
  const cancelBtn = form.querySelector(".cancel");

  saveBtn.onclick = async () => {
    const payload = {
      title: titleI.value,
      content: contentI.value,
      tags: parseTags(tagsI.value),
    };
    await request(`/memos/${memo.id}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
    await loadMemos();
  };
  cancelBtn.onclick = () => {
    form.remove();
  };
  container.appendChild(form);
}

async function loadMemos(search) {
  const params = new URLSearchParams();
  if (search && search.trim().length) params.set("search", search.trim());
  const items = await request(`/memos?${params.toString()}`);
  renderMemos(items);
}

els.createForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const payload = {
    title: els.title.value.trim(),
    content: els.content.value.trim(),
    tags: parseTags(els.tags.value),
  };
  if (!payload.title || !payload.content) {
    alert("标题和内容不可为空");
    return;
  }
  await request("/memos", { method: "POST", body: JSON.stringify(payload) });
  els.createForm.reset();
  await loadMemos();
});

els.searchForm.addEventListener("submit", (e) => {
  e.preventDefault();
  loadMemos(els.searchInput.value);
});
els.resetBtn.addEventListener("click", () => {
  els.searchInput.value = "";
  loadMemos();
});

// 初次加载
loadMemos().catch((err) => {
  console.error(err);
  alert("无法加载数据，请确认 API 已启动: " + API_BASE);
});