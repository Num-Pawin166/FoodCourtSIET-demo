// ระบบหลังบ้าน FoodCourt SIET — ร้านค้า (vendor) และผู้ดูแล (admin)
const API = '/api';
const state = {
  token: localStorage.getItem('fc_token'),
  user: null,
  poll: null,
  seenPending: null, // Set ของออเดอร์ pending ที่เคยเห็น (ใช้แจ้งเตือนออเดอร์ใหม่)
};

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const baht = (n) => '฿' + Number(n || 0).toLocaleString('th-TH');
const fmtTime = (iso) => (iso ? new Date(iso).toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' }) : '-');
const fmtDateTime = (iso) => new Date(iso).toLocaleString('th-TH', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const STATUS = {
  pending: 'รอรับออเดอร์', accepted: 'รับออเดอร์แล้ว', cooking: 'กำลังทำ',
  ready: 'พร้อมรับ', completed: 'รับอาหารแล้ว', cancelled: 'ยกเลิก',
};
const ROLE = { student: 'นักศึกษา', vendor: 'ร้านค้า', admin: 'ผู้ดูแล' };
const pill = (status) => `<span class="pill st-${status}">${STATUS[status]}</span>`;

async function api(path, { method = 'GET', body } = {}) {
  const res = await fetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && state.user) { logout(); throw new Error(data.error); }
  if (!res.ok) throw new Error(data.error || 'เกิดข้อผิดพลาด');
  return data;
}

function toast(msg, isErr = false) {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'toast show' + (isErr ? ' err' : '');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.className = 'toast'), 2500);
}

async function run(fn, okMsg) {
  try { await fn(); if (okMsg) toast(okMsg); } catch (e) { toast(e.message, true); }
}

// ---------- modal ฟอร์มกลาง ----------
function openModal({ title, fields, submitText = 'บันทึก', onSubmit }) {
  const dlg = $('#modal');
  const form = $('#modal-form');
  form.innerHTML = `<h2>${esc(title)}</h2>` + fields.map((f) => {
    const v = f.value ?? '';
    if (f.type === 'select') {
      return `<label>${esc(f.label)}<select name="${f.name}">${f.options.map((o) =>
        `<option value="${esc(o.value)}" ${String(o.value) === String(v) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select></label>`;
    }
    if (f.type === 'textarea') return `<label>${esc(f.label)}<textarea name="${f.name}" rows="2">${esc(v)}</textarea></label>`;
    if (f.type === 'checkbox') {
      return `<label class="row"><span class="switch"><input type="checkbox" name="${f.name}" ${v ? 'checked' : ''}><span></span></span>${esc(f.label)}</label>`;
    }
    if (f.type === 'pair') return `<div class="grid2">${f.items.map((x) => fieldInput(x)).join('')}</div>`;
    return fieldInput(f);
  }).join('') + `<p class="error" id="modal-error"></p>
    <div class="foot"><button type="button" class="btn ghost" value="cancel" id="modal-cancel">ยกเลิก</button>
    <button class="btn primary" value="ok">${esc(submitText)}</button></div>`;

  $('#modal-cancel').onclick = () => dlg.close();
  form.onsubmit = async (e) => {
    e.preventDefault();
    const data = {};
    const all = fields.flatMap((f) => (f.type === 'pair' ? f.items : [f]));
    for (const f of all) {
      const el = form.elements[f.name];
      data[f.name] = f.type === 'checkbox' ? el.checked : f.type === 'number' ? (el.value === '' ? undefined : Number(el.value)) : el.value;
    }
    try { await onSubmit(data); dlg.close(); } catch (err) { $('#modal-error').textContent = err.message; }
  };
  dlg.showModal();
  form.querySelector('input,select,textarea')?.focus();
}
function fieldInput(f) {
  return `<label>${esc(f.label)}<input name="${f.name}" type="${f.type || 'text'}" value="${esc(f.value ?? '')}"
    ${f.required ? 'required' : ''} ${f.placeholder ? `placeholder="${esc(f.placeholder)}"` : ''} ${f.type === 'number' ? 'step="1" min="0"' : ''}></label>`;
}

// ---------- auth ----------
$('#login-form').onsubmit = async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  $('#login-error').textContent = '';
  try {
    const { token, user } = await api('/auth/login', { method: 'POST', body: { username: fd.get('username'), password: fd.get('password') } });
    if (user.role === 'student') throw new Error('บัญชีนักศึกษาใช้งานผ่านแอปมือถือเท่านั้น');
    state.token = token;
    localStorage.setItem('fc_token', token);
    start(user);
  } catch (err) { $('#login-error').textContent = err.message; }
};
$('#logout').onclick = logout;

function logout() {
  state.token = null; state.user = null; state.seenPending = null;
  localStorage.removeItem('fc_token');
  clearInterval(state.poll);
  $('#app-view').classList.add('hidden');
  $('#login-view').classList.remove('hidden');
}

const NAV = {
  vendor: [['orders', 'ออเดอร์'], ['menu', 'จัดการเมนู'], ['shop', 'ข้อมูลร้าน']],
  admin: [['overview', 'ภาพรวม'], ['shops', 'ร้านค้า'], ['users', 'ผู้ใช้งาน'], ['all-orders', 'ออเดอร์ทั้งหมด']],
};
const PAGES = {};

function start(user) {
  state.user = user;
  $('#login-view').classList.add('hidden');
  $('#app-view').classList.remove('hidden');
  $('#who').innerHTML = `<b>${esc(user.name)}</b>${esc(ROLE[user.role])}${user.shop ? ' · ' + esc(user.shop.name) : ''}`;
  $('#nav').innerHTML = NAV[user.role].map(([k, label]) => `<a href="#${k}" data-k="${k}">${label}<span class="badge hidden" id="badge-${k}"></span></a>`).join('');
  if (!NAV[user.role].some(([k]) => k === location.hash.slice(1))) location.hash = NAV[user.role][0][0];
  render();
  clearInterval(state.poll);
  if (user.role === 'vendor') state.poll = setInterval(vendorTick, 5000);
}

window.addEventListener('hashchange', () => state.user && render());

function render() {
  const k = location.hash.slice(1);
  document.querySelectorAll('#nav a').forEach((a) => a.classList.toggle('active', a.dataset.k === k));
  const page = PAGES[k];
  if (page) page().catch((e) => toast(e.message, true));
}

// =====================================================================
//  ร้านค้า
// =====================================================================
function beep() {
  try {
    const ctx = (beep.ctx ||= new AudioContext());
    [0, 0.18].forEach((t) => {
      const o = ctx.createOscillator(); const g = ctx.createGain();
      o.frequency.value = 880; g.gain.value = 0.15;
      o.connect(g).connect(ctx.destination);
      o.start(ctx.currentTime + t); o.stop(ctx.currentTime + t + 0.12);
    });
  } catch { /* เบราว์เซอร์ไม่อนุญาตเสียง */ }
}

async function vendorTick() {
  const orders = await api('/vendor/orders?scope=active').catch(() => null);
  if (!orders) return;
  const pending = orders.filter((o) => o.status === 'pending');
  const badge = $('#badge-orders');
  if (badge) { badge.textContent = pending.length; badge.classList.toggle('hidden', !pending.length); }
  const newOnes = state.seenPending ? pending.filter((o) => !state.seenPending.has(o.id)) : [];
  state.seenPending = new Set(pending.map((o) => o.id));
  if (newOnes.length) { beep(); toast(`ออเดอร์ใหม่ ${newOnes.map((o) => o.queue_no).join(', ')}`); }
  if (location.hash === '#orders') renderBoard(orders, new Set(newOnes.map((o) => o.id)));
}

const BOARD_COLS = [
  ['pending', 'ออเดอร์ใหม่'], ['accepted', 'รับแล้ว'], ['cooking', 'กำลังทำ'], ['ready', 'พร้อมรับ'],
];
const ACTIONS = {
  pending: [['accepted', 'รับออเดอร์', 'primary'], ['cancelled', 'ปฏิเสธ', 'danger']],
  accepted: [['cooking', 'เริ่มทำ', 'primary'], ['cancelled', 'ยกเลิก', 'danger']],
  cooking: [['ready', 'ทำเสร็จแล้ว', 'primary']],
  ready: [['completed', 'ลูกค้ารับแล้ว', 'primary']],
};

PAGES.orders = async () => {
  const [shop, summary, orders] = await Promise.all([api('/vendor/shop'), api('/vendor/summary'), api('/vendor/orders?scope=active')]);
  state.seenPending ??= new Set(orders.filter((o) => o.status === 'pending').map((o) => o.id));
  $('#main').innerHTML = `
    <div class="page-head">
      <div><h1>ออเดอร์</h1><div class="muted">${esc(shop.name)} · อัปเดตอัตโนมัติทุก 5 วินาที</div></div>
      <label class="row" style="font-size:15px;color:var(--ink)">
        <span class="switch"><input type="checkbox" id="open-toggle" ${shop.is_open ? 'checked' : ''}><span></span></span>
        <span id="open-label">${shop.is_open ? 'ร้านเปิดรับออเดอร์' : 'ร้านปิดอยู่'}</span>
      </label>
    </div>
    <div class="tiles">
      <div class="tile"><div class="label">ออเดอร์วันนี้</div><div class="value">${summary.orders}</div><div class="sub">ยกเลิก ${summary.cancelled}</div></div>
      <div class="tile"><div class="label">ยอดขายวันนี้</div><div class="value">${baht(summary.revenue)}</div></div>
      <div class="tile"><div class="label">คิวที่รอทำ</div><div class="value">${summary.in_progress}</div></div>
      <div class="tile"><div class="label">ขายดีวันนี้</div><div class="value" style="font-size:18px;padding-top:8px">${esc(summary.top_items[0]?.name || '-')}</div>
        <div class="sub">${summary.top_items[0] ? summary.top_items[0].qty + ' จาน' : ''}</div></div>
    </div>
    <div class="board" id="board"></div>
    <div class="card" style="margin-top:18px"><h2>ออเดอร์วันนี้ทั้งหมด</h2><div class="table-wrap" id="today-table"></div></div>`;
  $('#open-toggle').onchange = (e) => run(async () => {
    const s = await api('/vendor/shop', { method: 'PATCH', body: { is_open: e.target.checked } });
    $('#open-label').textContent = s.is_open ? 'ร้านเปิดรับออเดอร์' : 'ร้านปิดอยู่';
  }, e.target.checked ? 'เปิดร้านแล้ว' : 'ปิดร้านแล้ว');
  renderBoard(orders, new Set());
  renderTodayTable();
};

function renderBoard(orders, highlight) {
  const board = $('#board');
  if (!board) return;
  board.innerHTML = BOARD_COLS.map(([st, title]) => {
    const list = orders.filter((o) => o.status === st);
    return `<div class="col"><h3>${title}<span class="count">${list.length}</span></h3>
      ${list.map((o) => `
        <div class="order ${highlight.has(o.id) ? 'new' : ''}">
          <div class="row" style="justify-content:space-between"><span class="q">${esc(o.queue_no)}</span>
            <span class="pill st-role">รับ ${esc(o.pickup_time)} น.</span></div>
          <div class="meta">${esc(o.user.name)} · สั่งเมื่อ ${fmtTime(o.created_at)}</div>
          <ul>${o.items.map((i) => `<li>${esc(i.name)} × ${i.qty}</li>`).join('')}</ul>
          ${o.note ? `<div class="note">📝 ${esc(o.note)}</div>` : ''}
          <div class="row" style="justify-content:space-between">
            <b>${baht(o.total)}</b>
            <div class="actions">${ACTIONS[st].map(([to, label, cls]) =>
              `<button class="btn sm ${cls}" data-id="${o.id}" data-to="${to}">${label}</button>`).join('')}</div>
          </div>
        </div>`).join('') || '<div class="empty">ไม่มีออเดอร์</div>'}
    </div>`;
  }).join('');
  board.querySelectorAll('button[data-to]').forEach((b) => (b.onclick = () => changeStatus(Number(b.dataset.id), b.dataset.to)));
}

async function changeStatus(id, to) {
  if (to === 'cancelled') {
    return openModal({
      title: 'ยกเลิกออเดอร์', submitText: 'ยืนยันยกเลิก',
      fields: [{ name: 'reason', label: 'เหตุผล (ลูกค้าจะเห็น)', value: 'วัตถุดิบหมด', required: true }],
      onSubmit: async ({ reason }) => { await api(`/vendor/orders/${id}/status`, { method: 'PATCH', body: { status: to, reason } }); toast('ยกเลิกออเดอร์แล้ว'); PAGES.orders(); },
    });
  }
  await run(async () => { await api(`/vendor/orders/${id}/status`, { method: 'PATCH', body: { status: to } }); await PAGES.orders(); });
}

async function renderTodayTable() {
  const rows = await api('/vendor/orders?scope=today');
  $('#today-table').innerHTML = rows.length ? `<table><thead><tr><th>คิว</th><th>เวลาสั่ง</th><th>เวลารับ</th><th>ลูกค้า</th><th>รายการ</th><th class="num">ยอด</th><th>สถานะ</th></tr></thead><tbody>
    ${rows.map((o) => `<tr><td><b>${esc(o.queue_no)}</b></td><td>${fmtTime(o.created_at)}</td><td>${esc(o.pickup_time)}</td><td>${esc(o.user.name)}</td>
      <td>${o.items.map((i) => `${esc(i.name)} ×${i.qty}`).join(', ')}</td><td class="num">${baht(o.total)}</td><td>${pill(o.status)}</td></tr>`).join('')}
    </tbody></table>` : '<div class="empty">ยังไม่มีออเดอร์วันนี้</div>';
}

PAGES.menu = async () => {
  const menu = await api('/vendor/menu');
  $('#main').innerHTML = `
    <div class="page-head"><div><h1>จัดการเมนู</h1><div class="muted">${menu.length} เมนู · ปิดสวิตช์เมื่อเมนูหมด ลูกค้าจะสั่งไม่ได้</div></div>
      <button class="btn primary" id="add-menu">+ เพิ่มเมนู</button></div>
    <div class="card table-wrap"><table><thead><tr><th>ชื่อเมนู</th><th>รายละเอียด</th><th class="num">ราคา</th><th>มีขาย</th><th></th></tr></thead><tbody>
    ${menu.map((m) => `<tr><td><b>${esc(m.name)}</b></td><td class="muted">${esc(m.description)}</td><td class="num">${baht(m.price)}</td>
      <td><label class="switch"><input type="checkbox" data-avail="${m.id}" ${m.is_available ? 'checked' : ''}><span></span></label></td>
      <td class="num"><button class="btn sm" data-edit="${m.id}">แก้ไข</button> <button class="btn sm danger" data-del="${m.id}">ลบ</button></td></tr>`).join('')}
    </tbody></table>${menu.length ? '' : '<div class="empty">ยังไม่มีเมนู</div>'}</div>`;

  const form = (m = {}) => [
    { name: 'name', label: 'ชื่อเมนู', value: m.name, required: true },
    { name: 'description', label: 'รายละเอียด (เช่น พร้อมน้ำซุป)', type: 'textarea', value: m.description },
    { type: 'pair', items: [{ name: 'price', label: 'ราคา (บาท)', type: 'number', value: m.price, required: true }, { name: 'sort_order', label: 'ลำดับการแสดง', type: 'number', value: m.sort_order ?? 0 }] },
    { name: 'is_available', label: 'มีขาย', type: 'checkbox', value: m.is_available ?? true },
  ];
  $('#add-menu').onclick = () => openModal({
    title: 'เพิ่มเมนู', fields: form(),
    onSubmit: async (d) => { await api('/vendor/menu', { method: 'POST', body: d }); toast('เพิ่มเมนูแล้ว'); PAGES.menu(); },
  });
  document.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = () => {
    const m = menu.find((x) => x.id === Number(b.dataset.edit));
    openModal({ title: 'แก้ไขเมนู', fields: form(m), onSubmit: async (d) => { await api(`/vendor/menu/${m.id}`, { method: 'PATCH', body: d }); toast('บันทึกแล้ว'); PAGES.menu(); } });
  }));
  document.querySelectorAll('[data-del]').forEach((b) => (b.onclick = () => {
    const m = menu.find((x) => x.id === Number(b.dataset.del));
    if (confirm(`ลบเมนู "${m.name}" ?`)) run(async () => { await api(`/vendor/menu/${m.id}`, { method: 'DELETE' }); PAGES.menu(); }, 'ลบเมนูแล้ว');
  }));
  document.querySelectorAll('[data-avail]').forEach((c) => (c.onchange = () =>
    run(() => api(`/vendor/menu/${c.dataset.avail}`, { method: 'PATCH', body: { is_available: c.checked } }), c.checked ? 'เปิดขายแล้ว' : 'ตั้งเป็นหมดแล้ว')));
};

PAGES.shop = async () => {
  const s = await api('/vendor/shop');
  $('#main').innerHTML = `
    <div class="page-head"><div><h1>ข้อมูลร้าน</h1><div class="muted">ข้อมูลนี้แสดงในแอปของนักศึกษา</div></div></div>
    <form class="card" id="shop-form" style="max-width:560px;display:grid;gap:14px">
      <div class="row"><span class="pill st-role">คิว ${esc(s.code)}</span><b style="font-size:18px">${esc(s.name)}</b><span class="muted">${esc(s.category)}</span></div>
      <label>คำอธิบายร้าน<textarea name="description" rows="2">${esc(s.description)}</textarea></label>
      <div class="grid2"><label>เวลาเปิด<input type="time" name="open_time" value="${s.open_time}"></label>
        <label>เวลาปิด<input type="time" name="close_time" value="${s.close_time}"></label></div>
      <div class="grid2"><label>เวลารอขั้นต่ำ (นาที)<input type="number" min="0" name="prep_min" value="${s.prep_min}"></label>
        <label>เวลารอสูงสุด (นาที)<input type="number" min="0" name="prep_max" value="${s.prep_max}"></label></div>
      <label class="row" style="color:var(--ink)"><span class="switch"><input type="checkbox" name="is_open" ${s.is_open ? 'checked' : ''}><span></span></span>เปิดรับออเดอร์</label>
      <div><button class="btn primary">บันทึก</button></div>
      <p class="muted" style="margin:0;font-size:13px">ชื่อร้าน หมวดหมู่ และรหัสคิว แก้ไขได้โดยผู้ดูแลศูนย์อาหาร</p>
    </form>`;
  $('#shop-form').onsubmit = (e) => {
    e.preventDefault();
    const f = e.target.elements;
    run(() => api('/vendor/shop', { method: 'PATCH', body: {
      description: f.description.value, open_time: f.open_time.value, close_time: f.close_time.value,
      prep_min: Number(f.prep_min.value), prep_max: Number(f.prep_max.value), is_open: f.is_open.checked,
    } }), 'บันทึกข้อมูลร้านแล้ว');
  };
};

// =====================================================================
//  ผู้ดูแล
// =====================================================================
PAGES.overview = async () => {
  const s = await api('/admin/summary?days=14');
  const total14 = s.daily.reduce((t, d) => t + d.revenue, 0);
  const maxShop = Math.max(1, ...s.by_shop.map((x) => x.revenue));
  $('#main').innerHTML = `
    <div class="page-head"><div><h1>ภาพรวมศูนย์อาหาร</h1><div class="muted">ข้อมูล ณ ${new Date().toLocaleString('th-TH')}</div></div>
      <button class="btn ghost" id="refresh">รีเฟรช</button></div>
    <div class="tiles">
      <div class="tile"><div class="label">ออเดอร์วันนี้</div><div class="value">${s.today.orders}</div><div class="sub">กำลังดำเนินการ ${s.today.active}</div></div>
      <div class="tile"><div class="label">ยอดขายวันนี้</div><div class="value">${baht(s.today.revenue)}</div></div>
      <div class="tile"><div class="label">ยอดขาย 14 วัน</div><div class="value">${baht(total14)}</div></div>
      <div class="tile"><div class="label">ร้านเปิดอยู่</div><div class="value">${s.counts.shops_open}/${s.counts.shops}</div><div class="sub">นักศึกษา ${s.counts.students} คน</div></div>
    </div>
    <div class="two-col">
      <div class="card"><h2>ยอดขายรายวัน (14 วัน)</h2><div class="chart" id="daily-chart"></div></div>
      <div class="card"><h2>เมนูขายดี 14 วัน</h2><table><tbody>
        ${s.top_items.map((t, i) => `<tr><td>${i + 1}. <b>${esc(t.name)}</b><div class="muted" style="font-size:12px">${esc(t.shop_name)}</div></td><td class="num">${t.qty} จาน</td></tr>`).join('')}
      </tbody></table></div>
    </div>
    <div class="card"><h2>ยอดขายแยกตามร้าน (14 วัน)</h2>
      ${s.by_shop.map((x) => `<div class="hbar"><span>${esc(x.code)} · ${esc(x.name)}</span>
        <div class="track"><div class="fill" style="width:${(x.revenue / maxShop) * 100}%"></div></div>
        <span class="v">${baht(x.revenue)} · ${x.orders} ออเดอร์</span></div>`).join('')}
    </div>`;
  $('#refresh').onclick = () => PAGES.overview();
  drawBarChart($('#daily-chart'), s.daily.map((d) => ({
    label: new Date(d.date + 'T00:00:00+07:00').toLocaleDateString('th-TH', { day: 'numeric', month: 'short' }),
    value: d.revenue, tip: `${baht(d.revenue)} · ${d.orders} ออเดอร์`,
  })));
};

/** กราฟแท่งแกนเดียว พร้อม tooltip เมื่อชี้ */
function drawBarChart(el, data) {
  const W = el.clientWidth || 600, H = 240, pad = { l: 52, r: 8, t: 10, b: 26 };
  const max = Math.max(1, ...data.map((d) => d.value));
  const step = niceStep(max / 4);
  const top = Math.ceil(max / step) * step;
  const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;
  const bw = iw / data.length;
  const y = (v) => pad.t + ih - (v / top) * ih;
  let grid = '';
  for (let v = 0; v <= top; v += step) {
    grid += `<line x1="${pad.l}" x2="${W - pad.r}" y1="${y(v)}" y2="${y(v)}"/>
      <text x="${pad.l - 8}" y="${y(v) + 4}" text-anchor="end" class="ytick">${v.toLocaleString('th-TH')}</text>`;
  }
  const bars = data.map((d, i) => {
    const x = pad.l + i * bw + bw * 0.18, w = bw * 0.64, h = Math.max(0, pad.t + ih - y(d.value));
    const r = Math.min(4, w / 2, h);
    const yTop = pad.t + ih - h;
    // ปลายแท่งมน 4px ฐานตรง
    const path = h > 0 ? `M${x},${pad.t + ih} V${yTop + r} Q${x},${yTop} ${x + r},${yTop} H${x + w - r} Q${x + w},${yTop} ${x + w},${yTop + r} V${pad.t + ih} Z` : '';
    const every = Math.max(1, Math.ceil(data.length / Math.floor(iw / 56)));
    const showLabel = (data.length - 1 - i) % every === 0; // นับถอยจากวันล่าสุด กันป้ายชนกัน
    return `<rect class="hit" data-i="${i}" x="${pad.l + i * bw}" y="${pad.t}" width="${bw}" height="${ih}"/>
      <path class="bar ${i === data.length - 1 ? '' : 'dim'}" d="${path}"/>
      ${showLabel ? `<text x="${x + w / 2}" y="${H - 6}" text-anchor="middle">${esc(d.label)}</text>` : ''}`;
  }).join('');
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="ยอดขายรายวัน">
    <g class="grid axis">${grid}</g><g class="axis">${bars}</g></svg><div class="tooltip"></div>`;
  const tip = $('.tooltip', el);
  el.querySelectorAll('.hit').forEach((h) => {
    h.onmouseenter = () => {
      const d = data[h.dataset.i];
      tip.innerHTML = `<b>${esc(d.label)}</b><br>${esc(d.tip)}`;
      tip.style.left = `${((pad.l + (+h.dataset.i + 0.5) * bw) / W) * 100}%`;
      tip.style.top = `${y(d.value)}px`;
      tip.classList.add('show');
    };
    h.onmouseleave = () => tip.classList.remove('show');
  });
}
function niceStep(raw) {
  const p = 10 ** Math.floor(Math.log10(raw || 1));
  return [1, 2, 2.5, 5, 10].map((m) => m * p).find((s) => s >= raw) || p * 10;
}

PAGES.shops = async () => {
  const shops = await api('/admin/shops');
  $('#main').innerHTML = `
    <div class="page-head"><div><h1>ร้านค้า</h1><div class="muted">${shops.length} ร้าน</div></div>
      <button class="btn primary" id="add-shop">+ เพิ่มร้าน</button></div>
    <div class="card table-wrap"><table><thead><tr><th>คิว</th><th>ชื่อร้าน</th><th>หมวด</th><th>เวลาทำการ</th><th>สถานะ</th><th class="num">คิวรอ</th><th class="num">เมนู</th><th>บัญชีร้าน</th><th></th></tr></thead><tbody>
    ${shops.map((s) => `<tr><td><span class="pill st-role">${esc(s.code)}</span></td><td><b>${esc(s.name)}</b></td><td>${esc(s.category)}</td>
      <td>${s.open_time}–${s.close_time}</td><td><span class="pill st-${s.open_now ? 'open' : 'closed'}">${s.open_now ? 'เปิดอยู่' : 'ปิด'}</span></td>
      <td class="num">${s.queue_count}</td><td class="num">${s.menu_count}</td>
      <td>${s.owners.map((o) => esc(o.username)).join(', ') || '<span class="muted">-</span>'}</td>
      <td class="num"><button class="btn sm" data-edit="${s.id}">แก้ไข</button> <button class="btn sm danger" data-del="${s.id}">ลบ</button></td></tr>`).join('')}
    </tbody></table></div>`;
  const form = (s = {}) => [
    { type: 'pair', items: [{ name: 'code', label: 'รหัสคิว (A-Z)', value: s.code, required: true }, { name: 'category', label: 'หมวดหมู่', value: s.category ?? 'อาหารจานเดียว', required: true }] },
    { name: 'name', label: 'ชื่อร้าน', value: s.name, required: true },
    { name: 'description', label: 'คำอธิบาย', type: 'textarea', value: s.description },
    { type: 'pair', items: [{ name: 'open_time', label: 'เวลาเปิด', type: 'time', value: s.open_time ?? '07:30' }, { name: 'close_time', label: 'เวลาปิด', type: 'time', value: s.close_time ?? '17:00' }] },
    { type: 'pair', items: [{ name: 'prep_min', label: 'รอขั้นต่ำ (นาที)', type: 'number', value: s.prep_min ?? 5 }, { name: 'prep_max', label: 'รอสูงสุด (นาที)', type: 'number', value: s.prep_max ?? 10 }] },
    { name: 'is_open', label: 'เปิดรับออเดอร์', type: 'checkbox', value: s.is_open ?? true },
  ];
  $('#add-shop').onclick = () => openModal({ title: 'เพิ่มร้านค้า', fields: form(), onSubmit: async (d) => {
    await api('/admin/shops', { method: 'POST', body: d }); toast('เพิ่มร้านแล้ว — อย่าลืมสร้างบัญชีร้านในหน้าผู้ใช้งาน'); PAGES.shops();
  } });
  document.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = () => {
    const s = shops.find((x) => x.id === Number(b.dataset.edit));
    openModal({ title: `แก้ไข ${s.name}`, fields: form(s), onSubmit: async (d) => { await api(`/admin/shops/${s.id}`, { method: 'PATCH', body: d }); toast('บันทึกแล้ว'); PAGES.shops(); } });
  }));
  document.querySelectorAll('[data-del]').forEach((b) => (b.onclick = () => {
    const s = shops.find((x) => x.id === Number(b.dataset.del));
    if (confirm(`ลบร้าน "${s.name}" ?`)) run(async () => { await api(`/admin/shops/${s.id}`, { method: 'DELETE' }); PAGES.shops(); }, 'ลบร้านแล้ว');
  }));
};

PAGES.users = async () => {
  const role = PAGES.users.role ?? '';
  const q = PAGES.users.q ?? '';
  const [users, shops] = await Promise.all([api(`/admin/users?role=${role}&q=${encodeURIComponent(q)}`), api('/admin/shops')]);
  $('#main').innerHTML = `
    <div class="page-head"><div><h1>ผู้ใช้งาน</h1><div class="muted">${users.length} บัญชี</div></div>
      <button class="btn primary" id="add-user">+ เพิ่มผู้ใช้</button></div>
    <div class="row" style="margin-bottom:14px">
      <select id="f-role" style="width:auto"><option value="">ทุกบทบาท</option>${Object.entries(ROLE).map(([k, v]) => `<option value="${k}" ${k === role ? 'selected' : ''}>${v}</option>`).join('')}</select>
      <input id="f-q" placeholder="ค้นหาชื่อหรือรหัส" value="${esc(q)}" style="max-width:260px">
    </div>
    <div class="card table-wrap"><table><thead><tr><th>ชื่อผู้ใช้</th><th>ชื่อ</th><th>บทบาท</th><th>ร้าน</th><th>สถานะ</th><th></th></tr></thead><tbody>
    ${users.map((u) => `<tr><td><b>${esc(u.username)}</b></td><td>${esc(u.name)}</td><td><span class="pill st-role">${ROLE[u.role]}</span></td>
      <td>${esc(u.shop?.name || '-')}</td><td><span class="pill st-${u.is_active ? 'open' : 'closed'}">${u.is_active ? 'ใช้งาน' : 'ระงับ'}</span></td>
      <td class="num"><button class="btn sm" data-edit="${u.id}">แก้ไข</button></td></tr>`).join('')}
    </tbody></table></div>`;
  $('#f-role').onchange = (e) => { PAGES.users.role = e.target.value; PAGES.users(); };
  $('#f-q').onchange = (e) => { PAGES.users.q = e.target.value; PAGES.users(); };
  const shopOpts = [{ value: '', label: '— ไม่ผูกร้าน —' }, ...shops.map((s) => ({ value: s.id, label: `${s.code} · ${s.name}` }))];
  const roleOpts = Object.entries(ROLE).map(([value, label]) => ({ value, label }));
  $('#add-user').onclick = () => openModal({
    title: 'เพิ่มผู้ใช้',
    fields: [
      { name: 'username', label: 'ชื่อผู้ใช้ / รหัสนักศึกษา', required: true },
      { name: 'name', label: 'ชื่อ-นามสกุล', required: true },
      { name: 'password', label: 'รหัสผ่าน', type: 'password', required: true },
      { name: 'role', label: 'บทบาท', type: 'select', options: roleOpts, value: 'student' },
      { name: 'shop_id', label: 'ร้าน (สำหรับบัญชีร้านค้า)', type: 'select', options: shopOpts, value: '' },
    ],
    onSubmit: async (d) => { await api('/admin/users', { method: 'POST', body: d }); toast('เพิ่มผู้ใช้แล้ว'); PAGES.users(); },
  });
  document.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = () => {
    const u = users.find((x) => x.id === Number(b.dataset.edit));
    openModal({
      title: `แก้ไข ${u.username}`,
      fields: [
        { name: 'name', label: 'ชื่อ-นามสกุล', value: u.name, required: true },
        { name: 'role', label: 'บทบาท', type: 'select', options: roleOpts, value: u.role },
        { name: 'shop_id', label: 'ร้าน (สำหรับบัญชีร้านค้า)', type: 'select', options: shopOpts, value: u.shop?.id ?? '' },
        { name: 'password', label: 'ตั้งรหัสผ่านใหม่ (เว้นว่าง = ไม่เปลี่ยน)', type: 'password' },
        { name: 'is_active', label: 'เปิดใช้งานบัญชี', type: 'checkbox', value: u.is_active },
      ],
      onSubmit: async (d) => {
        if (!d.password) delete d.password;
        await api(`/admin/users/${u.id}`, { method: 'PATCH', body: d }); toast('บันทึกแล้ว'); PAGES.users();
      },
    });
  }));
};

PAGES['all-orders'] = async () => {
  const f = PAGES['all-orders'].filter ||= { shop_id: '', status: '', date: '' };
  const qs = new URLSearchParams(Object.entries(f).filter(([, v]) => v)).toString();
  const [orders, shops] = await Promise.all([api(`/admin/orders?${qs}`), api('/admin/shops')]);
  $('#main').innerHTML = `
    <div class="page-head"><div><h1>ออเดอร์ทั้งหมด</h1><div class="muted">แสดงล่าสุด ${orders.length} รายการ</div></div></div>
    <div class="row" style="margin-bottom:14px">
      <select id="f-shop" style="width:auto"><option value="">ทุกร้าน</option>${shops.map((s) => `<option value="${s.id}" ${String(s.id) === f.shop_id ? 'selected' : ''}>${esc(s.code)} · ${esc(s.name)}</option>`).join('')}</select>
      <select id="f-status" style="width:auto"><option value="">ทุกสถานะ</option>${Object.entries(STATUS).map(([k, v]) => `<option value="${k}" ${k === f.status ? 'selected' : ''}>${v}</option>`).join('')}</select>
      <input type="date" id="f-date" value="${f.date}" style="width:auto">
    </div>
    <div class="card table-wrap"><table><thead><tr><th>คิว</th><th>เวลาสั่ง</th><th>ร้าน</th><th>ลูกค้า</th><th>รายการ</th><th class="num">ยอด</th><th>สถานะ</th></tr></thead><tbody>
    ${orders.map((o) => `<tr><td><b>${esc(o.queue_no)}</b></td><td>${fmtDateTime(o.created_at)}</td><td>${esc(o.shop.name)}</td><td>${esc(o.user.name)}</td>
      <td>${o.items.map((i) => `${esc(i.name)} ×${i.qty}`).join(', ')}</td><td class="num">${baht(o.total)}</td><td>${pill(o.status)}</td></tr>`).join('')}
    </tbody></table>${orders.length ? '' : '<div class="empty">ไม่พบออเดอร์</div>'}</div>`;
  for (const [id, key] of [['f-shop', 'shop_id'], ['f-status', 'status'], ['f-date', 'date']]) {
    $('#' + id).onchange = (e) => { f[key] = e.target.value; PAGES['all-orders'](); };
  }
};

// ---------- boot ----------
(async () => {
  if (state.token) {
    try { const me = await api('/auth/me'); if (me.role !== 'student') return start(me); } catch { /* token หมดอายุ */ }
  }
  logout();
})();
