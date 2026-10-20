import { Router } from 'express';
import { db } from '../db.js';
import { HttpError, auth, serializeShop, serializeMenuItem, pickupSlots, requireInt } from '../util.js';

const r = Router();

r.get('/categories', (_req, res) => {
  const rows = db.prepare('SELECT DISTINCT category FROM shops ORDER BY category').all();
  res.json(rows.map((x) => x.category));
});

// GET /shops?q=ข้าว&category=เส้น  (ค้นหาทั้งชื่อร้านและชื่อเมนู)
r.get('/shops', (req, res) => {
  const q = String(req.query.q || '').trim();
  const category = String(req.query.category || '').trim();
  const where = [];
  const params = [];
  if (category) { where.push('s.category = ?'); params.push(category); }
  if (q) {
    where.push(`(s.name LIKE ? OR s.description LIKE ? OR EXISTS (SELECT 1 FROM menu_items m WHERE m.shop_id = s.id AND m.name LIKE ?))`);
    params.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }
  const rows = db.prepare(
    `SELECT s.* FROM shops s ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY s.is_open DESC, s.code`
  ).all(...params);
  res.json(rows.map(serializeShop));
});

r.get('/shops/:id', (req, res) => {
  const id = requireInt(req.params.id, 'id');
  const shop = db.prepare('SELECT * FROM shops WHERE id = ?').get(id);
  if (!shop) throw new HttpError(404, 'ไม่พบร้านนี้');
  const menu = db.prepare('SELECT * FROM menu_items WHERE shop_id = ? ORDER BY sort_order, id').all(id);
  res.json({ ...serializeShop(shop), menu: menu.map(serializeMenuItem), pickup_slots: pickupSlots(shop) });
});

r.get('/shops/:id/slots', (req, res) => {
  const shop = db.prepare('SELECT * FROM shops WHERE id = ?').get(requireInt(req.params.id, 'id'));
  if (!shop) throw new HttpError(404, 'ไม่พบร้านนี้');
  res.json(pickupSlots(shop));
});

// ---------- เมนูโปรด ----------
r.get('/favorites', auth(), (req, res) => {
  const rows = db.prepare(
    `SELECT m.*, s.name AS shop_name FROM favorites f
     JOIN menu_items m ON m.id = f.menu_item_id JOIN shops s ON s.id = m.shop_id
     WHERE f.user_id = ? ORDER BY f.created_at DESC`
  ).all(req.user.id);
  res.json(rows.map((m) => ({ ...serializeMenuItem(m), shop_name: m.shop_name })));
});

r.put('/favorites/:menuItemId', auth(), (req, res) => {
  const id = requireInt(req.params.menuItemId, 'menuItemId');
  if (!db.prepare('SELECT 1 FROM menu_items WHERE id = ?').get(id)) throw new HttpError(404, 'ไม่พบเมนูนี้');
  db.prepare('INSERT OR IGNORE INTO favorites (user_id, menu_item_id) VALUES (?, ?)').run(req.user.id, id);
  res.json({ ok: true });
});

r.delete('/favorites/:menuItemId', auth(), (req, res) => {
  db.prepare('DELETE FROM favorites WHERE user_id = ? AND menu_item_id = ?').run(req.user.id, requireInt(req.params.menuItemId, 'menuItemId'));
  res.json({ ok: true });
});

export default r;
