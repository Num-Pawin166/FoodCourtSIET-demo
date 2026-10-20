import { Router } from 'express';
import { db, transaction } from '../db.js';
import {
  HttpError, auth, serializeOrder, pickupSlots, isShopOpenNow, localDate, requireInt,
} from '../util.js';

const r = Router();
r.use(auth('student', 'admin'));

// สร้างออเดอร์: { shop_id, items: [{ menu_item_id, qty }], pickup_time: "11:45", note }
r.post('/', (req, res) => {
  const { shop_id, items, pickup_time, note = '' } = req.body || {};
  const shopId = requireInt(shop_id, 'shop_id');
  if (!Array.isArray(items) || items.length === 0) throw new HttpError(400, 'ตะกร้าว่าง');
  if (String(note).length > 200) throw new HttpError(400, 'หมายเหตุยาวเกิน 200 ตัวอักษร');

  const order = transaction(() => {
    const shop = db.prepare('SELECT * FROM shops WHERE id = ?').get(shopId);
    if (!shop) throw new HttpError(404, 'ไม่พบร้านนี้');
    if (!isShopOpenNow(shop)) throw new HttpError(409, 'ร้านปิดอยู่ ไม่สามารถสั่งได้ในขณะนี้');
    if (!pickupSlots(shop).includes(pickup_time)) throw new HttpError(409, 'เวลารับอาหารนี้ไม่ว่างแล้ว กรุณาเลือกใหม่');

    // รวมรายการซ้ำ และดึงราคาจากฐานข้อมูลเสมอ (ไม่เชื่อราคาจากแอป)
    const qtyById = new Map();
    for (const it of items) {
      const id = requireInt(it.menu_item_id, 'menu_item_id');
      const qty = requireInt(it.qty, 'qty');
      if (qty < 1 || qty > 20) throw new HttpError(400, 'จำนวนต่อเมนูต้องอยู่ระหว่าง 1-20');
      qtyById.set(id, (qtyById.get(id) || 0) + qty);
    }
    const lines = [];
    for (const [id, qty] of qtyById) {
      const m = db.prepare('SELECT * FROM menu_items WHERE id = ? AND shop_id = ?').get(id, shopId);
      if (!m) throw new HttpError(400, 'มีเมนูที่ไม่อยู่ในร้านนี้');
      if (!m.is_available) throw new HttpError(409, `"${m.name}" หมดแล้ว`);
      lines.push({ m, qty });
    }
    const total = lines.reduce((s, l) => s + l.m.price * l.qty, 0);

    const today = localDate();
    const seq = db.prepare('SELECT COUNT(*) AS n FROM orders WHERE shop_id = ? AND order_date = ?').get(shopId, today).n + 1;
    const queueNo = `${shop.code}-${String(seq).padStart(3, '0')}`;
    const info = db.prepare(
      `INSERT INTO orders (queue_no, order_date, user_id, shop_id, pickup_time, note, total, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(queueNo, today, req.user.id, shopId, pickup_time, String(note).trim(), total, new Date().toISOString());
    const ins = db.prepare('INSERT INTO order_items (order_id, menu_item_id, name, price, qty) VALUES (?, ?, ?, ?, ?)');
    for (const { m, qty } of lines) ins.run(info.lastInsertRowid, m.id, m.name, m.price, qty);
    return db.prepare('SELECT * FROM orders WHERE id = ?').get(info.lastInsertRowid);
  });

  res.status(201).json(serializeOrder(order));
});

// GET /orders?scope=active|history
r.get('/', (req, res) => {
  const scope = req.query.scope === 'history' ? 'history' : 'active';
  const statuses = scope === 'active'
    ? `('pending','accepted','cooking','ready')`
    : `('completed','cancelled')`;
  const rows = db.prepare(
    `SELECT * FROM orders WHERE user_id = ? AND status IN ${statuses} ORDER BY created_at DESC LIMIT 50`
  ).all(req.user.id);
  res.json(rows.map(serializeOrder));
});

function ownOrder(req) {
  const o = db.prepare('SELECT * FROM orders WHERE id = ?').get(requireInt(req.params.id, 'id'));
  if (!o || (o.user_id !== req.user.id && req.user.role !== 'admin')) throw new HttpError(404, 'ไม่พบออเดอร์นี้');
  return o;
}

r.get('/:id', (req, res) => res.json(serializeOrder(ownOrder(req))));

// ลูกค้ายกเลิกได้เฉพาะตอนร้านยังไม่รับออเดอร์
r.post('/:id/cancel', (req, res) => {
  const o = ownOrder(req);
  if (o.status !== 'pending') throw new HttpError(409, 'ร้านรับออเดอร์แล้ว ไม่สามารถยกเลิกได้');
  db.prepare(`UPDATE orders SET status = 'cancelled', cancel_reason = 'ลูกค้ายกเลิก', cancelled_at = ? WHERE id = ?`)
    .run(new Date().toISOString(), o.id);
  res.json(serializeOrder(db.prepare('SELECT * FROM orders WHERE id = ?').get(o.id)));
});

export default r;
