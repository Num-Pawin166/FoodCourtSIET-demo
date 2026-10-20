# FoodCourt SIET

ระบบสั่งอาหารล่วงหน้าของศูนย์อาหาร SIET - KMITL ประกอบด้วย 3 ส่วน

| ส่วน | ผู้ใช้ | เทคโนโลยี | โฟลเดอร์ |
|---|---|---|---|
| แอปมือถือ | นักศึกษา | Flutter | [mobile/](mobile/) |
| แอปร้านค้า "FoodCourt ร้านค้า" | ร้านค้า | Flutter | [vendor/](vendor/) |
| เว็บหลังบ้าน | ร้านค้า, ผู้ดูแล | HTML/JS (ไม่ต้อง build) | [backend/public/](backend/public/) |
| REST API + ฐานข้อมูล | — | Node.js 22.5+ · Express 5 · SQLite (`node:sqlite`) · JWT | [backend/src/](backend/src/) |

## วิธีรัน

```bash
# 1) Backend (ต้องเปิดก่อน)
cd backend
npm install
npm start            # http://localhost:3000  (สร้าง DB + ข้อมูลตัวอย่างให้อัตโนมัติครั้งแรก)
npm run seed         # ล้างข้อมูลทั้งหมดแล้วใส่ข้อมูลตัวอย่างใหม่

# 2) แอปมือถือ
cd mobile
flutter pub get
flutter run          # Android emulator จะต่อ http://10.0.2.2:3000 ให้อัตโนมัติ
# มือถือจริง: ใช้ IP ของเครื่องคอมในวง Wi-Fi เดียวกัน
flutter run --dart-define=API_URL=http://192.168.1.10:3000/api
```

เว็บหลังบ้าน: เปิด http://localhost:3000 แล้วเข้าสู่ระบบด้วยบัญชีร้านค้าหรือแอดมิน

### รันบน Android (Android Studio / emulator)
ชื่อโฟลเดอร์ `Year 3, Term 1 work` มีจุลภาค ทำให้ build Android ไม่ผ่าน ต้องจำลองโฟลเดอร์เป็นไดรฟ์ก่อน (ทำใหม่ทุกครั้งที่รีสตาร์ทเครื่อง)
หรือเปลี่ยนชื่อโฟลเดอร์ให้ไม่มีจุลภาคแทนก็ได้
```
subst X: "D:\Year 3, Term 1 work\mobile app\FoodCourt SIET"
```
- **Android Studio**: File → Open → เลือก `X:\mobile` (แอปนักศึกษา) หรือ `X:\vendor` (แอปร้านค้า) → เลือก emulator ด้านบน → กด ▶ Run
- **Terminal**: `cd X:\vendor` แล้วรัน `flutter run`
- ทั้งสองแอปต่อ backend ที่ `http://10.0.2.2:3000` ให้อัตโนมัติ (ต้องรัน backend ก่อน)
- Login ด้วย Google บน Android ต้องสร้าง OAuth client แบบ Android เพิ่ม (ดูหัวข้อ Google ด้านล่าง)

### ตั้งค่า AI (Gemini)
คัดลอก `backend/.env.example` เป็น `backend/.env` แล้วใส่ `GEMINI_API_KEY` (สร้างได้ฟรีที่ https://aistudio.google.com/apikey)
ถ้าไม่ใส่ key หรือ Gemini ใช้งานไม่ได้ ผู้ช่วยจะใช้ตัวแนะนำแบบกฎ (กรองตามงบ เวลา ไม่เผ็ด ไม่กินหมู หมวดอาหาร) แทนอัตโนมัติ
**ห้าม commit ไฟล์ `.env`** (มีอยู่ใน `.gitignore` แล้ว)

### ตั้งค่า Login ด้วย Google (@kmitl.ac.th เท่านั้น)
1. ไปที่ https://console.cloud.google.com → สร้างโปรเจกต์
2. **Google Auth Platform → Branding**: ตั้งชื่อแอปและอีเมลติดต่อ, **Audience**: เลือก External (ระหว่างทดสอบต้องเพิ่มอีเมล @kmitl.ac.th ที่จะใช้ใน Test users)
3. **Clients → Create client → Web application**
   - Authorized JavaScript origins: `http://localhost:5000` (และ URL จริงตอน deploy)
   - คัดลอก Client ID ไปใส่ `GOOGLE_CLIENT_ID=` ใน `backend/.env`
4. (Android) **Create client → Android**: package `th.ac.kmitl.siet.foodcourt_siet` + SHA-1 จาก `cd mobile/android && gradlew signingReport`
   (แอป Android ใช้ Web Client ID จากข้อ 3 อยู่แล้ว ไม่ต้องใส่ Android client ID ที่ไหน แค่สร้างไว้ในโปรเจกต์เดียวกัน)
5. รันเว็บด้วยพอร์ตตายตัวให้ตรงกับข้อ 3: `flutter run -d chrome --web-port 5000`

ระบบตรวจ 2 ชั้น: หน้าเลือกบัญชีของ Google แสดงเฉพาะโดเมน kmitl.ac.th และ backend ตรวจ token ซ้ำว่า `hd = kmitl.ac.th` และอีเมลยืนยันแล้ว
ล็อกอินครั้งแรก ระบบจะสร้างบัญชีให้อัตโนมัติ (ชื่อผู้ใช้ = ส่วนหน้าของอีเมล เช่น `65010001`) ถ้ามีบัญชีรหัสนักศึกษาเดียวกันอยู่แล้ว ระบบจะผูกเข้ากับบัญชีเดิม
การสมัครด้วยรหัสผ่านถูกปิดไว้ แต่ยังล็อกอินด้วยรหัสผ่านได้สำหรับบัญชีร้านค้า แอดมิน และบัญชีทดลอง

### บัญชีทดลอง

| บทบาท | ชื่อผู้ใช้ | รหัสผ่าน | ใช้ที่ |
|---|---|---|---|
| นักศึกษา | `65010001` – `65010005`, `66010010` | `1234` | แอปมือถือ |
| ร้านค้า | `shopa` – `shope` (ร้าน A–E) | `1234` | เว็บหลังบ้าน |
| ผู้ดูแล | `admin` | `admin1234` | เว็บหลังบ้าน |

## ฟีเจอร์

**แอปนักศึกษา** (ตามดีไซน์ Figma)
- Login ด้วย Google (เฉพาะ @kmitl.ac.th) หรือด้วยรหัสผ่านสำหรับบัญชีทดลอง
- Home: ค้นหาร้านหรือเมนู, กรองตามหมวด, ดูสถานะร้านเปิด/ปิดและจำนวนคิว
- AI แนะนำอาหาร: แชทบอกงบ เวลา และสิ่งที่อยากกินหรือไม่กิน แล้ว Gemini จะเลือกจากเมนูจริงของร้านที่เปิดอยู่ (เน้นร้านคิวน้อย) กดการ์ดเมนูเพื่อไปที่ร้าน
- Menu: ข้อมูลร้าน (เวลาเปิด-ปิด, เวลารอ, คิวตอนนี้), เพิ่ม/ลดจำนวน, กดหัวใจเก็บเป็นเมนูโปรด
- ตะกร้า: เลือกช่วงเวลารับอาหาร (ทุก 15 นาที คำนวณจากเวลาเตรียมและเวลาปิดร้าน), หมายเหตุถึงร้าน
- คำสั่งซื้อ: เลขคิว (เช่น A-027), คิวก่อนหน้า, ไทม์ไลน์สถานะที่อัปเดตทุก 5 วินาที, ยกเลิกได้ถ้าร้านยังไม่รับออเดอร์
- ประวัติ: กด "สั่งอีกครั้ง" เพื่อใส่เมนูเดิมลงตะกร้า
- บัญชีของฉัน: จำนวนออเดอร์และยอดใช้จ่ายเดือนนี้, เมนูโปรด

**แอปร้านค้า** (`vendor/`, ล็อกอินด้วย `shopa` / `1234`)
- ออเดอร์: แยกตามสถานะ (ใหม่ / รับแล้ว / กำลังทำ / พร้อมรับ / ทั้งหมดวันนี้) มีปุ่มเปลี่ยนสถานะ แจ้งเตือนด้วยเสียงและการสั่นเมื่อมีออเดอร์ใหม่ สรุปยอดวันนี้ และสวิตช์เปิด/ปิดร้าน
- เมนู: เพิ่ม แก้ไข ลบ และสวิตช์มีขาย/หมด
- ร้านของฉัน: เวลาเปิด-ปิด เวลารอ คำอธิบายร้าน และออกจากระบบ

**หลังบ้านร้านค้า (เว็บ)**
- บอร์ดออเดอร์ 4 คอลัมน์ (ใหม่ → รับแล้ว → กำลังทำ → พร้อมรับ) มีเสียงแจ้งเตือนเมื่อมีออเดอร์ใหม่
- ปฏิเสธหรือยกเลิกออเดอร์พร้อมเหตุผล (ลูกค้าเห็นเหตุผลในประวัติ)
- สรุปยอดวันนี้ และรายการออเดอร์ทั้งวัน
- จัดการเมนู: เพิ่ม, แก้ไข, ลบ, ตั้งว่า "หมด"
- ตั้งค่าร้าน: สวิตช์เปิด/ปิดร้าน, เวลาทำการ, เวลารอ

**หลังบ้านผู้ดูแล**
- ภาพรวม: ยอดขายวันนี้และย้อนหลัง 14 วัน, กราฟรายวัน, ยอดแยกตามร้าน, เมนูขายดี
- จัดการร้านค้า: รหัสคิว, หมวด, เวลาทำการ
- จัดการผู้ใช้: เพิ่มบัญชี, ผูกบัญชีร้านค้ากับร้าน, รีเซ็ตรหัสผ่าน, ระงับบัญชี
- ดูออเดอร์ทั้งหมด กรองตามร้าน สถานะ หรือวันที่

## สถานะออเดอร์

```
pending ──ร้านรับ──▶ accepted ──เริ่มทำ──▶ cooking ──เสร็จ──▶ ready ──ลูกค้ารับ──▶ completed
   │                    │
   └──── cancelled ◀────┘   (ลูกค้ายกเลิกได้เฉพาะตอน pending, ร้านยกเลิกได้ถึง accepted)
```

เลขคิวรีเซ็ตทุกวันแยกตามร้าน: `{รหัสร้าน}-{ลำดับ 3 หลัก}` เช่น A-001
เวลาทั้งหมดคำนวณตามเวลาไทย (Asia/Bangkok)

## ฐานข้อมูล (SQLite: `backend/data/foodcourt.db`)

| ตาราง | คอลัมน์หลัก |
|---|---|
| `shops` | code (ตัวอักษรนำหน้าคิว), name, category, open_time, close_time, prep_min/max, is_open |
| `users` | username, name, password_hash (bcrypt), role (`student`/`vendor`/`admin`), shop_id |
| `menu_items` | shop_id, name, description, price, is_available, sort_order |
| `orders` | queue_no, order_date, user_id, shop_id, status, pickup_time, note, total, เวลาของแต่ละสถานะ |
| `order_items` | order_id, menu_item_id, name และ price ณ ตอนสั่ง, qty |
| `favorites` | user_id, menu_item_id |

## API (`/api`)

ทุก endpoint ที่ต้องล็อกอินใช้ header `Authorization: Bearer <token>`

| Method | Path | สิทธิ์ | คำอธิบาย |
|---|---|---|---|
| POST | `/auth/login` | — | เข้าสู่ระบบ → `{ token, user }` |
| GET | `/auth/config` | — | `{ google_client_id, allowed_domain }` สำหรับตั้งค่าปุ่ม Google |
| POST | `/auth/google` | — | `{ id_token }` → `{ token, user }` (เฉพาะ @kmitl.ac.th) |
| POST | `/auth/register` | — | ปิดไว้ (เปิดได้ด้วย `ALLOW_PASSWORD_REGISTER=true`) |
| GET | `/auth/me`, `/auth/me/stats` | ทุกคน | ข้อมูลผู้ใช้ / สถิติเดือนนี้ |
| GET | `/categories` | — | หมวดหมู่ร้าน |
| GET | `/shops?q=&category=` | — | รายชื่อร้าน (ค้นหาทั้งชื่อร้านและชื่อเมนู) |
| GET | `/shops/:id` | — | ร้าน + เมนู + ช่วงเวลารับอาหาร |
| GET | `/shops/:id/slots` | — | ช่วงเวลารับอาหารที่ยังเลือกได้ |
| GET/PUT/DELETE | `/favorites[/:menuItemId]` | นักศึกษา | เมนูโปรด |
| POST | `/orders` | นักศึกษา | สร้างออเดอร์ (ราคาคำนวณที่ server) |
| GET | `/orders?scope=active\|history` | นักศึกษา | ออเดอร์ของฉัน |
| GET | `/orders/:id` | นักศึกษา | รายละเอียด + คิวก่อนหน้า |
| POST | `/orders/:id/cancel` | นักศึกษา | ยกเลิก (เฉพาะ pending) |
| GET/PATCH | `/vendor/shop` | ร้านค้า | ข้อมูลร้าน / เปิด-ปิดร้าน |
| GET | `/vendor/orders?scope=active\|today` | ร้านค้า | ออเดอร์ของร้าน |
| PATCH | `/vendor/orders/:id/status` | ร้านค้า | เปลี่ยนสถานะ `{ status, reason? }` |
| GET/POST/PATCH/DELETE | `/vendor/menu[/:id]` | ร้านค้า | จัดการเมนู |
| GET | `/vendor/summary` | ร้านค้า | สรุปยอดวันนี้ |
| GET | `/admin/summary?days=14` | ผู้ดูแล | ภาพรวม |
| GET/POST/PATCH/DELETE | `/admin/shops[/:id]` | ผู้ดูแล | จัดการร้าน (ร้านที่มีประวัติออเดอร์จะลบไม่ได้) |
| GET/POST/PATCH | `/admin/users[/:id]` | ผู้ดูแล | จัดการผู้ใช้ |
| GET | `/admin/orders?shop_id=&status=&date=` | ผู้ดูแล | ออเดอร์ทั้งหมด |
| POST | `/ai/chat` | นักศึกษา | `{ messages: [{ role, text }] }` → `{ reply, items, source }` (`source` = `gemini` หรือ `rules`) จำกัด 10 ครั้ง/นาที/คน |

## สิ่งที่ยังไม่ได้ทำ (ต่อยอดได้)
- อัปโหลดรูปอาหารและรูปร้าน (ฐานข้อมูลมีคอลัมน์ `image_url` รอไว้แล้ว ตอนนี้แอปใช้ไอคอนแทน)
- Push notification เมื่ออาหารพร้อม (ตอนนี้แอปดึงสถานะใหม่ทุก 5 วินาที)
- ชำระเงินออนไลน์ เช่น PromptPay QR (ตอนนี้จ่ายที่ร้านตอนรับอาหาร)
- ก่อนใช้งานจริงต้องตั้งค่า `JWT_SECRET` เป็นค่าลับของตัวเอง

## วิธีรัน
- cd backend && npm install && npm start
- cd mobile && flutter run 