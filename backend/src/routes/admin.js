import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { db } from '../db.js';
import {
  HttpError, auth, serializeShop, serializeOrder, publicUser, localDate, isHHMM, requireInt,
} from '../util.js';

// หลังบ้านของ "แอดมินศูนย์อาหาร"
const r = Router();
r.use(auth('admin'));

// ---------- ภาพรวม ----------
r.get('/summary', (req, res) => {
  const days = Math.min(Math.max(Number(req.query.days) || 7, 1), 60);
  const today = localDate();
  const dates = [];
  for (let i = days - 1; i >= 0; i--) dates.push(localDate(new Date(Date.now() - i * 86400000)));

  const daily = db.prepare(
    `SELECT order_date AS date, COUNT(*) AS orders, COALESCE(SUM(total), 0) AS revenue
     FROM orders WHERE order_date >= ? AND status != 'cancelled' GROUP BY order_date`
  ).all(dates[0]);
  const byDate = Object.fromEntries(daily.map((d) => [d.date, d]));

  const byShop = db.prepare(
    `SELECT s.id, s.code, s.name, COUNT(o.id) AS orders, COALESCE(SUM(o.total), 0) AS revenue
     FROM shops s LEFT JOIN orders o ON o.shop_id = s.id AND o.order_date >= ? AND o.status != 'cancelled'
     GROUP BY s.id ORDER BY revenue DESC`
  ).all(dates[0]);

  const todayRow = db.prepare(
    `SELECT COUNT(*) AS orders, COALESCE(SUM(CASE WHEN status != 'cancelled' THEN total END), 0) AS revenue,
            SUM(status IN ('pending','accepted','cooking','ready')) AS active
     FROM orders WHERE order_date = ?`
  ).get(today);

  const topItems = db.prepare(
    `SELECT oi.name, s.name AS shop_name, SUM(oi.qty) AS qty
     FROM order_items oi JOIN orders o ON o.id = oi.order_id JOIN shops s ON s.id = o.shop_id
     WHERE o.order_date >= ? AND o.status != 'cancelled'
     GROUP BY oi.name, s.id ORDER BY qty DESC LIMIT 5`
  ).all(dates[0]);

  res.json({
    today: { date: today, orders: todayRow.orders, revenue: todayRow.revenue, active: todayRow.active || 0 },
    counts: {
      shops: db.prepare('SELECT COUNT(*) AS n FROM shops').get().n,
      shops_open: db.prepare('SELECT COUNT(*) AS n FROM shops WHERE is_open = 1').get().n,
      students: db.prepare(`SELECT COUNT(*) AS n FROM users WHERE role = 'student'`).get().n,
    },
    daily: dates.map((d) => ({ date: d, orders: byDate[d]?.orders || 0, revenue: byDate[d]?.revenue || 0 })),
    by_shop: byShop,
    top_items: topItems,
  });
});

// ---------- ร้านค้า ----------
function validateShop(b, partial) {
  const out = {};
  const str = (k, max, required) => {
    if (b[k] === undefined) { if (required && !partial) throw new HttpError(400, `กรุณากรอก ${k}`); return; }
    const v = String(b[k]).trim();
    if (required && !v) throw new HttpError(400, `กรุณากรอก ${k}`);
    out[k] = v.slice(0, max);
  };
  str('name', 80, true);
  str('code', 2, true);
  str('category', 40, true);
  str('description', 300, false);
  if (out.code) { out.code = out.code.toUpperCase(); if (!/^[A-Z]{1,2}$/.test(out.code)) throw new HttpError(400, 'รหัสคิวต้องเป็นตัวอักษรอังกฤษ 1-2 ตัว'); }
  for (const k of ['open_time', 'close_time']) {
    if (b[k] !== undefined) { if (!isHHMM(b[k])) throw new HttpError(400, `${k} ต้องเป็นรูปแบบ HH:MM`); out[k] = b[k]; }
  }
  for (const k of ['prep_min', 'prep_max']) if (b[k] !== undefined) out[k] = requireInt(b[k], k);
  if (b.is_open !== undefined) out.is_open = b.is_open ? 1 : 0;
  if (b.image_url !== undefined) out.image_url = b.image_url ? String(b.image_url) : null;
  return out;
}

r.get('/shops', (_req, res) => {
  const shops = db.prepare('SELECT * FROM shops ORDER BY code').all();
  res.json(shops.map((s) => ({
    ...serializeShop(s),
    menu_count: db.prepare('SELECT COUNT(*) AS n FROM menu_items WHERE shop_id = ?').get(s.id).n,
    owners: db.prepare(`SELECT id, username, name FROM users WHERE shop_id = ? AND role = 'vendor'`).all(s.id),
  })));
});

r.post('/shops', (req, res) => {
  const v = validateShop(req.body || {}, false);
  if (db.prepare('SELECT 1 FROM shops WHERE code = ?').get(v.code)) throw new HttpError(409, `รหัสคิว ${v.code} ถูกใช้แล้ว`);
  const keys = Object.keys(v);
  const info = db.prepare(`INSERT INTO shops (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`).run(...keys.map((k) => v[k]));
  res.status(201).json(serializeShop(db.prepare('SELECT * FROM shops WHERE id = ?').get(info.lastInsertRowid)));
});

r.patch('/shops/:id', (req, res) => {
  const id = requireInt(req.params.id, 'id');
  if (!db.prepare('SELECT 1 FROM shops WHERE id = ?').get(id)) throw new HttpError(404, 'ไม่พบร้านนี้');
  const v = validateShop(req.body || {}, true);
  if (v.code && db.prepare('SELECT 1 FROM shops WHERE code = ? AND id != ?').get(v.code, id)) throw new HttpError(409, `รหัสคิว ${v.code} ถูกใช้แล้ว`);
  const keys = Object.keys(v);
  if (keys.length) db.prepare(`UPDATE shops SET ${keys.map((k) => `${k} = ?`).join(', ')} WHERE id = ?`).run(...keys.map((k) => v[k]), id);
  res.json(serializeShop(db.prepare('SELECT * FROM shops WHERE id = ?').get(id)));
});

r.delete('/shops/:id', (req, res) => {
  const id = requireInt(req.params.id, 'id');
  if (db.prepare('SELECT 1 FROM orders WHERE shop_id = ? LIMIT 1').get(id)) {
    throw new HttpError(409, 'ร้านนี้มีประวัติออเดอร์แล้ว ลบไม่ได้ — ให้ปิดร้านแทน');
  }
  const info = db.prepare('DELETE FROM shops WHERE id = ?').run(id);
  if (!info.changes) throw new HttpError(404, 'ไม่พบร้านนี้');
  res.json({ ok: true });
});

// ---------- ผู้ใช้ ----------
r.get('/users', (req, res) => {
  const role = String(req.query.role || '');
  const q = String(req.query.q || '').trim();
  const where = [];
  const params = [];
  if (['student', 'vendor', 'admin'].includes(role)) { where.push('role = ?'); params.push(role); }
  if (q) { where.push('(username LIKE ? OR name LIKE ?)'); params.push(`%${q}%`, `%${q}%`); }
  const rows = db.prepare(`SELECT * FROM users ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY role, username LIMIT 500`).all(...params);
  res.json(rows.map(publicUser));
});

function checkShopForRole(role, shopId) {
  if (role !== 'vendor') return null;
  const id = requireInt(shopId, 'shop_id');
  if (!db.prepare('SELECT 1 FROM shops WHERE id = ?').get(id)) throw new HttpError(400, 'กรุณาเลือกร้านของบัญชีร้านค้า');
  return id;
}

r.post('/users', (req, res) => {
  const { username, name, password, role = 'student', shop_id, faculty } = req.body || {};
  if (!username || !name || !password) throw new HttpError(400, 'กรุณากรอกชื่อผู้ใช้ ชื่อ และรหัสผ่าน');
  if (!['student', 'vendor', 'admin'].includes(role)) throw new HttpError(400, 'role ไม่ถูกต้อง');
  if (String(password).length < 4) throw new HttpError(400, 'รหัสผ่านต้องมีอย่างน้อย 4 ตัวอักษร');
  if (db.prepare('SELECT 1 FROM users WHERE username = ?').get(String(username).trim())) throw new HttpError(409, 'ชื่อผู้ใช้นี้มีอยู่แล้ว');
  const info = db.prepare(
    'INSERT INTO users (username, name, password_hash, role, shop_id, faculty) VALUES (?, ?, ?, ?, ?, ?)'
  ).run(String(username).trim(), String(name).trim(), bcrypt.hashSync(String(password), 10), role,
    checkShopForRole(role, shop_id), faculty ? String(faculty) : 'SIET - KMITL');
  res.status(201).json(publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid)));
});

r.patch('/users/:id', (req, res) => {
  const id = requireInt(req.params.id, 'id');
  const u = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  if (!u) throw new HttpError(404, 'ไม่พบผู้ใช้นี้');
  const b = req.body || {};
  const role = b.role ?? u.role;
  if (!['student', 'vendor', 'admin'].includes(role)) throw new HttpError(400, 'role ไม่ถูกต้อง');
  if (id === req.user.id && (role !== 'admin' || b.is_active === false)) throw new HttpError(400, 'ไม่สามารถลดสิทธิ์หรือระงับบัญชีตัวเองได้');
  const next = {
    name: b.name !== undefined ? String(b.name).trim() : u.name,
    role,
    shop_id: role === 'vendor' ? checkShopForRole(role, b.shop_id ?? u.shop_id) : null,
    faculty: b.faculty !== undefined ? String(b.faculty) : u.faculty,
    is_active: b.is_active !== undefined ? (b.is_active ? 1 : 0) : u.is_active,
    password_hash: b.password ? bcrypt.hashSync(String(b.password), 10) : u.password_hash,
  };
  if (!next.name) throw new HttpError(400, 'กรุณากรอกชื่อ');
  db.prepare('UPDATE users SET name=?, role=?, shop_id=?, faculty=?, is_active=?, password_hash=? WHERE id=?')
    .run(next.name, next.role, next.shop_id, next.faculty, next.is_active, next.password_hash, id);
  res.json(publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(id)));
});

// ---------- ออเดอร์ทั้งหมด ----------
r.get('/orders', (req, res) => {
  const where = [];
  const params = [];
  if (req.query.shop_id) { where.push('shop_id = ?'); params.push(requireInt(req.query.shop_id, 'shop_id')); }
  if (req.query.status) { where.push('status = ?'); params.push(String(req.query.status)); }
  if (req.query.date) { where.push('order_date = ?'); params.push(String(req.query.date)); }
  const rows = db.prepare(`SELECT * FROM orders ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY id DESC LIMIT 200`).all(...params);
  res.json(rows.map(serializeOrder));
});

export default r;
