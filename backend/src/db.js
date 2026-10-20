import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(__dirname, '..', 'data');
fs.mkdirSync(DATA_DIR, { recursive: true });

export const DB_PATH = process.env.DB_PATH || path.join(DATA_DIR, 'foodcourt.db');

export const db = new DatabaseSync(DB_PATH);
db.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;');

db.exec(`
CREATE TABLE IF NOT EXISTS shops (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT NOT NULL UNIQUE,             -- ตัวอักษรนำหน้าคิว เช่น A -> A-027
  name        TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category    TEXT NOT NULL DEFAULT 'อาหารจานเดียว',
  open_time   TEXT NOT NULL DEFAULT '07:30',
  close_time  TEXT NOT NULL DEFAULT '17:00',
  prep_min    INTEGER NOT NULL DEFAULT 5,
  prep_max    INTEGER NOT NULL DEFAULT 10,
  is_open     INTEGER NOT NULL DEFAULT 1,
  image_url   TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT NOT NULL UNIQUE,           -- รหัสนักศึกษา หรือชื่อผู้ใช้ของร้าน/แอดมิน
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('student','vendor','admin')),
  shop_id       INTEGER REFERENCES shops(id) ON DELETE SET NULL,
  faculty       TEXT NOT NULL DEFAULT 'SIET - KMITL',
  is_active     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS menu_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_id      INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  description  TEXT NOT NULL DEFAULT '',
  price        INTEGER NOT NULL CHECK (price >= 0),
  is_available INTEGER NOT NULL DEFAULT 1,
  image_url    TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS orders (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  queue_no      TEXT NOT NULL,
  order_date    TEXT NOT NULL,                  -- YYYY-MM-DD (เวลาไทย) ใช้รีเซ็ตเลขคิวรายวัน
  user_id       INTEGER NOT NULL REFERENCES users(id),
  shop_id       INTEGER NOT NULL REFERENCES shops(id),
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','accepted','cooking','ready','completed','cancelled')),
  pickup_time   TEXT NOT NULL,                  -- HH:MM
  note          TEXT NOT NULL DEFAULT '',
  total         INTEGER NOT NULL,
  cancel_reason TEXT,
  created_at    TEXT NOT NULL,
  accepted_at   TEXT,
  cooking_at    TEXT,
  ready_at      TEXT,
  completed_at  TEXT,
  cancelled_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_orders_shop_date ON orders(shop_id, order_date);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, created_at);

CREATE TABLE IF NOT EXISTS order_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id     INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  menu_item_id INTEGER REFERENCES menu_items(id) ON DELETE SET NULL,
  name         TEXT NOT NULL,                   -- เก็บชื่อ/ราคา ณ ตอนสั่ง
  price        INTEGER NOT NULL,
  qty          INTEGER NOT NULL CHECK (qty > 0)
);

CREATE TABLE IF NOT EXISTS favorites (
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (user_id, menu_item_id)
);
`);

// migration: อีเมลสำหรับล็อกอินด้วย Google (DB เก่าที่สร้างก่อนมีคอลัมน์นี้)
if (!db.prepare('PRAGMA table_info(users)').all().some((c) => c.name === 'email')) {
  db.exec('ALTER TABLE users ADD COLUMN email TEXT');
}
db.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL');

export function transaction(fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
}
