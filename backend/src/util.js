import jwt from 'jsonwebtoken';
import { db } from './db.js';

export const JWT_SECRET = process.env.JWT_SECRET || 'foodcourt-siet-dev-secret';
export const TZ = 'Asia/Bangkok';

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// ---------- เวลา (ยึดเวลาไทยเสมอ ไม่ขึ้นกับเครื่อง server) ----------
const dateFmt = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' });
const timeFmt = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

export const localDate = (d = new Date()) => dateFmt.format(d);           // 2026-10-19
export const localTime = (d = new Date()) => timeFmt.format(d);           // 11:45
export const toMinutes = (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; };
export const fromMinutes = (min) => `${String(Math.floor(min / 60)).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;
export const isHHMM = (s) => typeof s === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(s);

/** ISO (UTC) ของเวลาเที่ยงคืนวันที่ 1 ของเดือนปัจจุบันตามเวลาไทย */
export function startOfMonthIso(d = new Date()) {
  const [y, m] = localDate(d).split('-');
  return new Date(`${y}-${m}-01T00:00:00+07:00`).toISOString();
}
export function startOfDayIso(dateStr = localDate()) {
  return new Date(`${dateStr}T00:00:00+07:00`).toISOString();
}

// ---------- auth ----------
export function signToken(user) {
  return jwt.sign({ sub: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
}

export function auth(...roles) {
  return (req, _res, next) => {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new HttpError(401, 'กรุณาเข้าสู่ระบบ');
    let payload;
    try {
      payload = jwt.verify(token, JWT_SECRET);
    } catch {
      throw new HttpError(401, 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.sub);
    if (!user || !user.is_active) throw new HttpError(401, 'บัญชีนี้ถูกระงับหรือไม่มีอยู่');
    if (roles.length && !roles.includes(user.role)) throw new HttpError(403, 'ไม่มีสิทธิ์เข้าถึง');
    req.user = user;
    next();
  };
}

export function publicUser(u) {
  if (!u) return null;
  const shop = u.shop_id ? db.prepare('SELECT id, name FROM shops WHERE id = ?').get(u.shop_id) : null;
  return {
    id: u.id, username: u.username, name: u.name, role: u.role, email: u.email ?? null,
    faculty: u.faculty, is_active: !!u.is_active, shop, created_at: u.created_at,
  };
}

// ---------- ร้าน / เมนู ----------
export const ACTIVE_STATUSES = ['pending', 'accepted', 'cooking'];
export const STATUS_LABEL = {
  pending: 'รอร้านรับออเดอร์',
  accepted: 'ร้านรับออเดอร์แล้ว',
  cooking: 'กำลังทำอาหาร',
  ready: 'พร้อมรับอาหาร',
  completed: 'รับอาหารแล้ว',
  cancelled: 'ยกเลิก',
};

export function shopQueueCount(shopId) {
  return db.prepare(
    `SELECT COUNT(*) AS n FROM orders WHERE shop_id = ? AND order_date = ? AND status IN ('pending','accepted','cooking')`
  ).get(shopId, localDate()).n;
}

/** ร้านเปิดอยู่จริงหรือไม่ = สวิตช์เปิดร้าน + อยู่ในเวลาทำการ */
export function isShopOpenNow(shop, now = new Date()) {
  if (!shop.is_open) return false;
  const t = toMinutes(localTime(now));
  return t >= toMinutes(shop.open_time) && t < toMinutes(shop.close_time);
}

export function serializeShop(s) {
  return {
    id: s.id, code: s.code, name: s.name, description: s.description, category: s.category,
    open_time: s.open_time, close_time: s.close_time, prep_min: s.prep_min, prep_max: s.prep_max,
    is_open: !!s.is_open, open_now: isShopOpenNow(s), image_url: s.image_url,
    queue_count: shopQueueCount(s.id),
  };
}

export function serializeMenuItem(m) {
  return {
    id: m.id, shop_id: m.shop_id, name: m.name, description: m.description, price: m.price,
    is_available: !!m.is_available, image_url: m.image_url, sort_order: m.sort_order,
  };
}

/** ช่วงเวลารับอาหาร: ทุก 15 นาที เริ่มหลังเวลาเตรียมขั้นต่ำ ไม่เกินเวลาปิดร้าน (สูงสุด 9 ช่อง) */
export function pickupSlots(shop, now = new Date()) {
  if (!shop.is_open) return [];
  const open = toMinutes(shop.open_time);
  const close = toMinutes(shop.close_time);
  const earliest = Math.max(toMinutes(localTime(now)) + shop.prep_min, open);
  let t = Math.ceil(earliest / 15) * 15;
  const slots = [];
  while (t <= close && slots.length < 9) {
    slots.push(fromMinutes(t));
    t += 15;
  }
  return slots;
}

// ---------- ออเดอร์ ----------
export function serializeOrder(o) {
  const items = db.prepare('SELECT menu_item_id, name, price, qty FROM order_items WHERE order_id = ? ORDER BY id').all(o.id);
  const shop = db.prepare('SELECT id, name, code FROM shops WHERE id = ?').get(o.shop_id);
  const user = db.prepare('SELECT id, name, username FROM users WHERE id = ?').get(o.user_id);
  let queueAhead = 0;
  if (ACTIVE_STATUSES.includes(o.status)) {
    queueAhead = db.prepare(
      `SELECT COUNT(*) AS n FROM orders WHERE shop_id = ? AND order_date = ? AND id < ? AND status IN ('pending','accepted','cooking')`
    ).get(o.shop_id, o.order_date, o.id).n;
  }
  return {
    id: o.id, queue_no: o.queue_no, status: o.status, status_label: STATUS_LABEL[o.status],
    shop, user, items, item_count: items.reduce((s, i) => s + i.qty, 0),
    pickup_time: o.pickup_time, note: o.note, total: o.total, cancel_reason: o.cancel_reason,
    queue_ahead: queueAhead,
    created_at: o.created_at, accepted_at: o.accepted_at, cooking_at: o.cooking_at,
    ready_at: o.ready_at, completed_at: o.completed_at, cancelled_at: o.cancelled_at,
  };
}

/** การเปลี่ยนสถานะที่อนุญาต (ฝั่งร้าน) */
export const NEXT_STATUS = {
  pending: ['accepted', 'cancelled'],
  accepted: ['cooking', 'cancelled'],
  cooking: ['ready'],
  ready: ['completed'],
  completed: [],
  cancelled: [],
};

export function pick(obj, keys) {
  const out = {};
  for (const k of keys) if (obj[k] !== undefined) out[k] = obj[k];
  return out;
}

export function requireInt(v, name) {
  const n = Number(v);
  if (!Number.isInteger(n)) throw new HttpError(400, `${name} ไม่ถูกต้อง`);
  return n;
}
