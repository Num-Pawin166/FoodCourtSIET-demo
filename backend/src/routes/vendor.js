import { Router } from 'express';
import { db } from '../db.js';
import {
  HttpError, auth, serializeOrder, serializeShop, serializeMenuItem, NEXT_STATUS,
  localDate, isHHMM, requireInt,
} from '../util.js';

// หลังบ้านของ "ร้านค้า" — ทุก endpoint ผูกกับร้านของบัญชีที่ล็อกอิน
const r = Router();
r.use(auth('vendor'), (req, _res, next) => {
  if (!req.user.shop_id) throw new HttpError(403, 'บัญชีนี้ยังไม่ได้ผูกกับร้านค้า');
  req.shop = db.prepare('SELECT * FROM shops WHERE id = ?').get(req.user.shop_id);
  next();
});

// ---------- ข้อมูลร้าน ----------
r.get('/shop', (req, res) => res.json(serializeShop(req.shop)));

r.patch('/shop', (req, res) => {
  const b = req.body || {};
  const s = { ...req.shop };
  if (b.description !== undefined) s.description = String(b.description).slice(0, 300);
  if (b.is_open !== undefined) s.is_open = b.is_open ? 1 : 0;
  if (b.open_time !== undefined) { if (!isHHMM(b.open_time)) throw new HttpError(400, 'เวลาเปิดไม่ถูกต้อง'); s.open_time = b.open_time; }
  if (b.close_time !== undefined) { if (!isHHMM(b.close_time)) throw new HttpError(400, 'เวลาปิดไม่ถูกต้อง'); s.close_time = b.close_time; }
  if (b.prep_min !== undefined) s.prep_min = requireInt(b.prep_min, 'prep_min');
  if (b.prep_max !== undefined) s.prep_max = requireInt(b.prep_max, 'prep_max');
  if (s.open_time >= s.close_time) throw new HttpError(400, 'เวลาเปิดต้องก่อนเวลาปิด');
  if (s.prep_min < 0 || s.prep_max < s.prep_min) throw new HttpError(400, 'เวลารอไม่ถูกต้อง');
  db.prepare(
    `UPDATE shops SET description=?, is_open=?, open_time=?, close_time=?, prep_min=?, prep_max=? WHERE id=?`
  ).run(s.description, s.is_open, s.open_time, s.close_time, s.prep_min, s.prep_max, s.id);
  res.json(serializeShop(db.prepare('SELECT * FROM shops WHERE id = ?').get(s.id)));
});

// ---------- ออเดอร์ ----------
// GET /vendor/orders?scope=active|today
r.get('/orders', (req, res) => {
  const scope = req.query.scope === 'today' ? 'today' : 'active';
  const sql = scope === 'active'
    ? `SELECT * FROM orders WHERE shop_id = ? AND status IN ('pending','accepted','cooking','ready') ORDER BY id`
    : `SELECT * FROM orders WHERE shop_id = ? AND order_date = ? ORDER BY id DESC`;
  const rows = scope === 'active'
    ? db.prepare(sql).all(req.shop.id)
    : db.prepare(sql).all(req.shop.id, localDate());
  res.json(rows.map(serializeOrder));
});

// PATCH /vendor/orders/:id/status { status, reason? }
r.patch('/orders/:id/status', (req, res) => {
  const o = db.prepare('SELECT * FROM orders WHERE id = ? AND shop_id = ?').get(requireInt(req.params.id, 'id'), req.shop.id);
  if (!o) throw new HttpError(404, 'ไม่พบออเดอร์นี้');
  const { status, reason } = req.body || {};
  if (!NEXT_STATUS[o.status].includes(status)) throw new HttpError(409, `เปลี่ยนสถานะจาก ${o.status} เป็น ${status} ไม่ได้`);
  const now = new Date().toISOString();
  const col = { accepted: 'accepted_at', cooking: 'cooking_at', ready: 'ready_at', completed: 'completed_at', cancelled: 'cancelled_at' }[status];
  db.prepare(`UPDATE orders SET status = ?, ${col} = ?, cancel_reason = COALESCE(?, cancel_reason) WHERE id = ?`)
    .run(status, now, status === 'cancelled' ? String(reason || 'ร้านยกเลิกออเดอร์') : null, o.id);
  res.json(serializeOrder(db.prepare('SELECT * FROM orders WHERE id = ?').get(o.id)));
});

// ---------- เมนู ----------
r.get('/menu', (req, res) => {
  res.json(db.prepare('SELECT * FROM menu_items WHERE shop_id = ? ORDER BY sort_order, id').all(req.shop.id).map(serializeMenuItem));
});

function validateMenu(b, partial) {
  const out = {};
  if (b.name !== undefined || !partial) {
    if (!b.name || !String(b.name).trim()) throw new HttpError(400, 'กรุณากรอกชื่อเมนู');
    out.name = String(b.name).trim().slice(0, 80);
  }
  if (b.price !== undefined || !partial) {
    const p = Number(b.price);
    if (!Number.isInteger(p) || p < 0 || p > 10000) throw new HttpError(400, 'ราคาต้องเป็นจำนวนเต็ม 0-10000');
    out.price = p;
  }
  if (b.description !== undefined) out.description = String(b.description).slice(0, 200);
  if (b.is_available !== undefined) out.is_available = b.is_available ? 1 : 0;
  if (b.image_url !== undefined) out.image_url = b.image_url ? String(b.image_url) : null;
  if (b.sort_order !== undefined) out.sort_order = requireInt(b.sort_order, 'sort_order');
  return out;
}

r.post('/menu', (req, res) => {
  const v = validateMenu(req.body || {}, false);
  const info = db.prepare(
    `INSERT INTO menu_items (shop_id, name, description, price, is_available, image_url, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(req.shop.id, v.name, v.description ?? '', v.price, v.is_available ?? 1, v.image_url ?? null, v.sort_order ?? 0);
  res.status(201).json(serializeMenuItem(db.prepare('SELECT * FROM menu_items WHERE id = ?').get(info.lastInsertRowid)));
});

r.patch('/menu/:id', (req, res) => {
  const id = requireInt(req.params.id, 'id');
  if (!db.prepare('SELECT 1 FROM menu_items WHERE id = ? AND shop_id = ?').get(id, req.shop.id)) throw new HttpError(404, 'ไม่พบเมนูนี้');
  const v = validateMenu(req.body || {}, true);
  const keys = Object.keys(v);
  if (keys.length) db.prepare(`UPDATE menu_items SET ${keys.map((k) => `${k} = ?`).join(', ')} WHERE id = ?`).run(...keys.map((k) => v[k]), id);
  res.json(serializeMenuItem(db.prepare('SELECT * FROM menu_items WHERE id = ?').get(id)));
});

r.delete('/menu/:id', (req, res) => {
  const info = db.prepare('DELETE FROM menu_items WHERE id = ? AND shop_id = ?').run(requireInt(req.params.id, 'id'), req.shop.id);
  if (!info.changes) throw new HttpError(404, 'ไม่พบเมนูนี้');
  res.json({ ok: true });
});

// ---------- สรุปยอดวันนี้ ----------
r.get('/summary', (req, res) => {
  const today = localDate();
  const s = db.prepare(
    `SELECT COUNT(*) AS orders,
            COALESCE(SUM(CASE WHEN status != 'cancelled' THEN total END), 0) AS revenue,
            SUM(status = 'cancelled') AS cancelled,
            SUM(status IN ('pending','accepted','cooking')) AS in_progress
     FROM orders WHERE shop_id = ? AND order_date = ?`
  ).get(req.shop.id, today);
  const top = db.prepare(
    `SELECT oi.name, SUM(oi.qty) AS qty, SUM(oi.qty * oi.price) AS revenue
     FROM order_items oi JOIN orders o ON o.id = oi.order_id
     WHERE o.shop_id = ? AND o.order_date = ? AND o.status != 'cancelled'
     GROUP BY oi.name ORDER BY qty DESC LIMIT 5`
  ).all(req.shop.id, today);
  res.json({ date: today, orders: s.orders, revenue: s.revenue, cancelled: s.cancelled || 0, in_progress: s.in_progress || 0, top_items: top });
});

export default r;
