import { Router } from 'express';
import { db } from '../db.js';
import { HttpError, auth, isShopOpenNow, pickupSlots, shopQueueCount, localTime, toMinutes } from '../util.js';

// ผู้ช่วยแนะนำเมนู: ใช้ Gemini ถ้ามี GEMINI_API_KEY ไม่งั้นใช้ตัวแนะนำแบบกฎ
const r = Router();
r.use(auth('student', 'admin'));

// โมเดลหลัก แล้วค่อยลองโมเดลสำรอง (lite เร็วกว่า) ถ้าตัวหลักล่ม/คนใช้เยอะ (503)
const GEMINI_MODELS = [
  process.env.GEMINI_MODEL || 'gemini-3.5-flash',
  process.env.GEMINI_FALLBACK_MODEL || 'gemini-3.5-flash-lite',
];
const MAX_PICKS = 3;

// จำกัด 10 ข้อความ/นาที/คน กัน key โดนใช้เกินโควตา
const hits = new Map();
function rateLimit(userId) {
  const now = Date.now();
  const recent = (hits.get(userId) || []).filter((t) => now - t < 60_000);
  if (recent.length >= 10) throw new HttpError(429, 'ถามถี่เกินไป รอสักครู่แล้วลองใหม่นะ');
  recent.push(now);
  hits.set(userId, recent);
}

/** ข้อมูลจริงที่ให้ AI ใช้ตัดสินใจ: เฉพาะร้านที่เปิดอยู่และเมนูที่ยังมีขาย */
function buildContext() {
  const shops = db.prepare('SELECT * FROM shops ORDER BY code').all().filter((s) => isShopOpenNow(s));
  return shops.map((s) => ({
    shop_id: s.id,
    shop_name: s.name,
    category: s.category,
    queue_now: shopQueueCount(s.id),
    wait_minutes: `${s.prep_min}-${s.prep_max}`,
    earliest_pickup: pickupSlots(s)[0] || null,
    closes_at: s.close_time,
    menu: db.prepare('SELECT id, name, description, price FROM menu_items WHERE shop_id = ? AND is_available = 1 ORDER BY sort_order, id')
      .all(s.id).map((m) => ({ menu_item_id: m.id, name: m.name, description: m.description, price: m.price })),
  })).filter((s) => s.menu.length && s.earliest_pickup);
}

function itemIndex(context) {
  const idx = new Map();
  for (const s of context) for (const m of s.menu) idx.set(m.menu_item_id, { ...m, shop_id: s.shop_id, shop_name: s.shop_name, earliest_pickup: s.earliest_pickup, queue_now: s.queue_now });
  return idx;
}

// ---------------- Gemini ----------------
async function askGemini(messages, context) {
  let lastErr;
  for (const model of GEMINI_MODELS) {
    try {
      return await askGeminiModel(model, messages, context);
    } catch (err) {
      lastErr = err;
      console.error(`[ai] ${model} failed: ${err.message.slice(0, 120)}`);
    }
  }
  throw lastErr;
}

async function askGeminiModel(model, messages, context) {
  const system = `คุณคือ "ผู้ช่วยแนะนำเมนู" ของศูนย์อาหาร FoodCourt SIET (KMITL) ตอบเป็นภาษาไทย สั้น เป็นกันเอง
เวลาตอนนี้ ${localTime()} น.
กติกา:
- แนะนำได้เฉพาะเมนูในข้อมูลด้านล่างเท่านั้น (ร้านที่เปิดอยู่และเมนูที่ยังมีขาย) ห้ามแต่งเมนูหรือราคาเอง
- เคารพงบ เวลาที่ต้องได้รับอาหาร (เทียบกับ earliest_pickup) และข้อจำกัดอาหาร เช่น ไม่เผ็ด ไม่กินหมู
- ถ้าเลือกได้ ให้ร้านที่คิวน้อยก่อน
- เลือกไม่เกิน ${MAX_PICKS} เมนู ใส่ menu_item_id ให้ตรงกับข้อมูล และเหตุผลสั้นๆ ต่อเมนู
- ถ้าไม่มีเมนูที่ตรงเงื่อนไข ให้บอกตรงๆ และเสนอทางเลือกที่ใกล้เคียงที่สุด
- ถ้าผู้ใช้คุยเรื่องอื่นที่ไม่เกี่ยวกับอาหารในศูนย์อาหาร ให้ชวนกลับมาเรื่องเลือกเมนูอย่างสุภาพ และ picks เป็น []
ข้อมูลร้านและเมนู (JSON):
${JSON.stringify(context)}`;

  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': process.env.GEMINI_API_KEY },
    signal: AbortSignal.timeout(15_000),
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: messages.map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.text }] })),
      generationConfig: {
        temperature: 0.4,
        responseMimeType: 'application/json',
        responseSchema: {
          type: 'OBJECT',
          properties: {
            reply: { type: 'STRING' },
            picks: { type: 'ARRAY', items: { type: 'OBJECT', properties: { menu_item_id: { type: 'INTEGER' }, reason: { type: 'STRING' } }, required: ['menu_item_id', 'reason'] } },
          },
          required: ['reply', 'picks'],
        },
      },
    }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Gemini ${res.status}: ${body.slice(0, 300)}`);
  }
  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.map((p) => p.text || '').join('') || '';
  const parsed = JSON.parse(text);
  return { reply: String(parsed.reply || ''), picks: Array.isArray(parsed.picks) ? parsed.picks : [] };
}

// ---------------- ตัวแนะนำแบบกฎ (ใช้เมื่อไม่มี key หรือ Gemini ล่ม) ----------------
const SPICY = /เผ็ด|ต้มยำ|กะเพรา|พริก|แกง|ยำ/;
const PORK = /หมู|ขาหมู/;

function askRules(messages, context) {
  const text = messages.filter((m) => m.role === 'user').map((m) => m.text).join(' ');
  const budget = Number((text.match(/(?:งบ|ไม่เกิน|ราคา)\s*(\d+)/) || text.match(/(\d+)\s*(?:บาท|฿)/) || [])[1]) || null;
  const t = text.match(/(\d{1,2})[:.](\d{2})/);
  const deadline = t ? Number(t[1]) * 60 + Number(t[2]) : null;
  const noSpicy = /ไม่เผ็ด|ไม่ทานเผ็ด|ไม่กินเผ็ด/.test(text);
  const noPork = /ไม่กินหมู|ไม่ทานหมู|ไม่เอาหมู/.test(text);
  const category = /เส้น|ก๋วยเตี๋ยว|บะหมี่|ผัดไทย/.test(text) ? 'เส้น'
    : /เครื่องดื่ม|น้ำ(?!ซุป|ใส|จิ้ม)|ชา|กาแฟ|ปั่น/.test(text) ? 'เครื่องดื่ม'
      : /ข้าว/.test(text) ? 'อาหารจานเดียว' : null;

  let items = [...itemIndex(context).values()].filter((m) => {
    const shop = context.find((s) => s.shop_id === m.shop_id);
    if (budget && m.price > budget) return false;
    if (deadline && toMinutes(m.earliest_pickup) > deadline) return false;
    if (noSpicy && SPICY.test(m.name + m.description)) return false;
    if (noPork && PORK.test(m.name + m.description)) return false;
    if (category && shop.category !== category) return false;
    if (!category && shop.category === 'เครื่องดื่ม') return false; // ถามหาอาหารก็ไม่ควรได้น้ำเปล่า
    return true;
  });
  items.sort((a, b) => a.queue_now - b.queue_now || a.price - b.price);
  // กระจายร้าน: ร้านละไม่เกิน 1 เมนูก่อน
  const seen = new Set();
  items = [...items.filter((m) => !seen.has(m.shop_id) && seen.add(m.shop_id)), ...items].filter((m, i, a) => a.indexOf(m) === i);
  const picks = items.slice(0, MAX_PICKS);

  const conds = [
    noSpicy && 'ไม่เผ็ด', noPork && 'ไม่มีหมู', category && `หมวด${category}`,
    budget && `ไม่เกิน ${budget} บาท`, deadline && `ทำทันก่อน ${t[1]}.${t[2]}`,
  ].filter(Boolean);
  if (!context.length) return { reply: 'ตอนนี้ยังไม่มีร้านที่เปิดรับออเดอร์เลย ลองใหม่ช่วงเวลาทำการนะ', picks: [] };
  if (!picks.length) {
    return { reply: `ยังไม่เจอเมนูที่${conds.length ? conds.join(' ') : 'ตรงเงื่อนไข'}เลย ลองเพิ่มงบหรือขยายเวลารับอาหารดูไหม`, picks: [] };
  }
  return {
    reply: `ได้เลย! เลือกจากร้านที่เปิดอยู่${conds.length ? ' ' + conds.join(' ') : ''} มี ${picks.length} เมนูดังนี้`,
    picks: picks.map((m) => ({
      menu_item_id: m.menu_item_id,
      reason: `คิวตอนนี้ ${m.queue_now} · รับได้ตั้งแต่ ${m.earliest_pickup} น.`,
    })),
  };
}

// POST /ai/chat { messages: [{ role: 'user'|'assistant', text }] }
r.post('/chat', async (req, res) => {
  const raw = Array.isArray(req.body?.messages) ? req.body.messages : [];
  const messages = raw.slice(-10)
    .filter((m) => m && typeof m.text === 'string' && m.text.trim())
    .map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', text: m.text.trim().slice(0, 500) }));
  if (!messages.length || messages.at(-1).role !== 'user') throw new HttpError(400, 'กรุณาพิมพ์ข้อความ');
  rateLimit(req.user.id);

  const context = buildContext();
  let result;
  let source = 'rules';
  if (process.env.GEMINI_API_KEY) {
    try {
      result = await askGemini(messages, context);
      source = 'gemini';
    } catch (err) {
      console.error('[ai] Gemini failed, falling back to rules:', err.message);
    }
  }
  result ??= askRules(messages, context);

  // ตรวจทุกเมนูที่ AI เลือกว่ามีอยู่จริงและยังสั่งได้
  const idx = itemIndex(context);
  const items = [];
  for (const p of result.picks) {
    const m = idx.get(Number(p.menu_item_id));
    if (m && !items.some((x) => x.menu_item_id === m.menu_item_id)) {
      items.push({
        menu_item_id: m.menu_item_id, name: m.name, price: m.price, shop_id: m.shop_id, shop_name: m.shop_name,
        earliest_pickup: m.earliest_pickup, queue_now: m.queue_now, reason: String(p.reason || '').slice(0, 200),
      });
    }
    if (items.length >= MAX_PICKS) break;
  }
  res.json({ reply: result.reply, items, source });
});

export default r;
