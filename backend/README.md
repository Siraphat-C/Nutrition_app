# My Nutrition Secretary API (backend)

FastAPI server ของแอปวิเคราะห์โภชนาการอาหารจากรูปภาพ
แอป Flutter เรียก API นี้อย่างเดียว ไม่ต่อ Supabase โดยตรง

## ติดตั้ง

ต้องใช้ Python 3.10 ขึ้นไป

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate    macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

ถ้าเครื่องมีการ์ดจอ NVIDIA และต้องการใช้ GPU บน Windows ให้ติดตั้ง torch แบบ CUDA แยก:
```bash
pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
```

## ตั้งค่า

1. คัดลอก `.env.example` เป็น `.env` แล้วใส่ค่าให้ครบ
2. สร้างตารางใน Supabase: เปิด SQL Editor แล้วรัน `supabase/schema.sql` (รันบนฐานข้อมูลว่าง)
3. สมัครบัญชีผ่าน `/api/register` แล้วตั้งเป็นแอดมินใน SQL Editor:
   ```sql
   update public.users set role_id = 1 where email = 'admin@example.com';
   ```

## รัน

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
ดูและทดลองยิง API ได้ที่ http://localhost:8000/docs

ทดสอบส่วนคำนวณ: `pytest`

## API

ทุก endpoint ที่มี 🔒 ต้องส่ง header `Authorization: Bearer <access_token>` (ได้จาก `data.access_token` ของ `/api/login`)
ใน `/docs` API ถูกแบ่งเป็นหมวด: บัญชีผู้ใช้, ข้อมูลส่วนตัว, อาหาร, แอดมิน

### รูปแบบผลลัพธ์

ทุก API ที่สำเร็จตอบรูปแบบเดียวกัน
```json
{ "success": true, "message": "ข้อความภาษาไทย", "data": { ... } }
```
API ที่เป็นรายการ (`GET /api/foods`, `GET /api/admin/users`) มี `total`, `limit`, `offset` เพิ่ม
(`total` เป็น `null` ถ้าขอหน้าที่เกินจำนวนข้อมูล)

ถ้าไม่สำเร็จจะได้ `{ "detail": "ข้อความภาษาไทย" }` พร้อมรหัส

| รหัส | ความหมาย |
|---|---|
| 400 | ส่งข้อมูลไม่ครบหรือทำไม่ได้ (เช่น แอดมินลบตัวเอง) |
| 401 | ยังไม่ล็อกอิน / token หมดอายุหรือถูกยกเลิก |
| 403 | ไม่มีสิทธิ์ (ไม่ใช่แอดมิน) |
| 404 | ไม่พบข้อมูล |
| 409 | ข้อมูลซ้ำ (อีเมล, username, ชื่อเมนู) หรือลบไม่ได้เพราะถูกใช้อยู่ |
| 413 | ไฟล์รูปใหญ่เกิน |
| 422 | ข้อมูลผิดรูปแบบหรือเกินช่วงที่กำหนด |


| Method | Path | สิทธิ์ | ใช้ทำอะไร |
|---|---|---|---|
| POST | `/api/register` | - | สมัครสมาชิก `{username, email, password}` (username ไทย/อังกฤษ 3–50 ตัว เว้นวรรคได้ ห้ามซ้ำ; รหัสผ่าน 8–72 ตัว, ภาษาไทยไม่เกิน 24 ตัว) |
| POST | `/api/login` | - | เข้าสู่ระบบ `{email, password}` ได้ `data.access_token` |
| GET | `/api/me` | 🔒 | ข้อมูลบัญชี + โปรไฟล์ |
| GET | `/api/profile` | 🔒 | ข้อมูลส่วนตัว + แคลอรี่ที่ควรได้รับต่อวัน + `bmi`, `allowed_goals` (เป้าหมายที่เลือกได้ตาม BMI), `expected_kg_per_week`/`expected_kg_per_month` |
| PUT | `/api/profile` | 🔒 | แก้ข้อมูลส่วนตัว (ส่งเฉพาะฟิลด์ที่แก้) ระบบคำนวณเป้าหมายให้อัตโนมัติ เลือกเป้าหมายที่ BMI ไม่อนุญาตได้ `422` ตั้งน้ำหนักเป้าหมายด้วย `target_weight` + `target_weeks` (เปลี่ยนได้ไม่เกิน 1 กก./สัปดาห์, ลดไม่ต่ำกว่า BMI 18.5, เพิ่มไม่ถึง BMI 23) |
| POST | `/api/profile/preview` | 🔒 | คำนวณเป้าหมายให้ดูก่อน ยังไม่บันทึก |
| PUT | `/api/account` | 🔒 | แก้ username / เปลี่ยนรหัสผ่าน |
| POST | `/api/logout` | 🔒 | ออกจากระบบ (token เดิมใช้ไม่ได้ทุกเครื่อง) |
| POST | `/api/analyze` | 🔒 | ส่งรูป (multipart field `file`, ไม่เกิน 10 MB) วิเคราะห์ชื่อเมนู |
| POST | `/api/logs` | 🔒 | บันทึกมื้ออาหาร `{food_id, meal_type, weight, is_manual_weight}` (weight = กรัม, ค่าเริ่มต้น 300) ระบบคำนวณ `total_calories` ให้ |
| GET | `/api/logs/today` | 🔒 | มื้อที่กินวันนี้ (เวลาไทย) |
| GET | `/api/logs?start=YYYY-MM-DD&end=YYYY-MM-DD` | 🔒 | มื้อย้อนหลัง ไม่เกิน 92 วันต่อครั้ง |
| DELETE | `/api/logs/{log_id}` | 🔒 | ลบมื้อที่บันทึกผิด (ลบได้เฉพาะของตัวเอง) |
| GET | `/api/dashboard/alerts` | 🔒 | การ์ดเตือนสุขภาพ (`danger`, `warning`, `info`, `good`) + 7 วันล่าสุด `{calories (สุทธิ), eaten, burned}` |
| GET | `/api/dashboard/summary?month=YYYY-MM` | 🔒 | สรุปรายเดือน: รวม, เฉลี่ย, วันเกิน/พอดี/ขาดเป้า, เมนูยอดนิยม, สัดส่วนตามมื้อ, รายวัน |
| POST | `/api/weight` | 🔒 | บันทึกน้ำหนักวันนี้ `{weight}` และคำนวณแคลอรี่ต่อวันใหม่ |
| GET | `/api/weight/history?days=90` | 🔒 | น้ำหนักย้อนหลัง (ใช้วาดกราฟ) |
| GET | `/api/exercise/activities` | 🔒 | กิจกรรมที่เลือกได้ `{key, name_th, met, compendium_code}` |
| POST | `/api/exercise` | 🔒 | บันทึกการออกกำลังกาย `{activity, minutes}` (1–600 นาที) ใช้น้ำหนักจากข้อมูลส่วนตัว คำนวณ `calories_burned` ให้ |
| GET | `/api/exercise/today` | 🔒 | การออกกำลังกายวันนี้ `{items, total_burned}` |
| DELETE | `/api/exercise/{exercise_log_id}` | 🔒 | ลบรายการออกกำลังกาย (ลบได้เฉพาะของตัวเอง) |
| GET | `/api/foods` | 🔒 | รายการเมนู ค้นหาชื่อคลาสหรือชื่อไทยด้วย `?q=` แบ่งหน้าด้วย `?limit=20&offset=0` มี `in_model` บอกว่าโมเดลยังทายเมนูนี้ได้ |
| GET | `/api/foods/{food_id}` | 🔒 | ดูเมนูเดียว |
| POST | `/api/admin/login` | - | เข้าสู่ระบบหน้าจัดการ (บัญชีที่ไม่ใช่แอดมินได้ `403`) |
| GET | `/api/admin/dashboard` | 🔒 admin | ข้อมูลแอดมิน + จำนวนผู้ใช้ แอดมิน และเมนูทั้งหมด |
| GET | `/api/admin/users` | 🔒 admin | รายการบัญชี ค้นหา username/อีเมลด้วย `?q=` กรองสิทธิ์ด้วย `?role_id=1` |
| GET | `/api/admin/users/{user_id}` | 🔒 admin | ดูบัญชีเดียว + โปรไฟล์ |
| POST | `/api/admin/users` | 🔒 admin | เพิ่มบัญชี `{username, email, password, role_id}` |
| PUT | `/api/admin/users/{user_id}` | 🔒 admin | แก้ไขบัญชี `{username, email, role_id, new_password}` (ส่งเฉพาะที่แก้) |
| DELETE | `/api/admin/users/{user_id}` | 🔒 admin | ลบบัญชี (โปรไฟล์และประวัติการกินถูกลบตาม) |
| POST | `/api/admin/foods` | 🔒 admin | เพิ่มเมนู `{food_name, food_name_th, calories_per_100g}` (0–900 kcal ต่อ 100 กรัม) |
| POST | `/api/admin/foods/sync` | 🔒 admin | สร้างแถวให้คลาสของโมเดลที่ยังไม่มีใน `foods` (เปิดเซิร์ฟเวอร์ทำให้อัตโนมัติอยู่แล้ว) |
| PUT | `/api/admin/foods/{food_id}` | 🔒 admin | แก้ไขเมนู `{food_name, food_name_th, calories_per_100g}` (ส่งเฉพาะที่แก้) |
| DELETE | `/api/admin/foods/{food_id}` | 🔒 admin | ลบเมนู (ถ้ามีผู้ใช้บันทึกเมนูนี้ไว้แล้วได้ `409`) |

### ข้อมูลส่วนตัว (`PUT /api/profile`)

```json
{
  "gender": "female",
  "birth_date": "2001-05-20",
  "weight": 60,
  "height": 165,
  "activity_level": 2,
  "goal": "lose"
}
```

| ฟิลด์ | ค่าที่รับ |
|---|---|
| `gender` | `male`, `female` |
| `birth_date` | `YYYY-MM-DD` อายุ 13–100 ปี |
| `weight` | กิโลกรัม (20–300) |
| `height` | เซนติเมตร (100–250) |
| `activity_level` | กิจกรรมในชีวิตประจำวัน ไม่รวมการออกกำลังกาย (นับจาก `/api/exercise` แทน เพื่อไม่ให้นับซ้ำ): 1 นั่งเป็นหลัก, 2 ยืนหรือเดินบ้าง, 3 ยืนหรือเดินเกือบทั้งวัน, 4 งานใช้แรง, 5 งานใช้แรงหนัก |
| `goal` | `lose`, `maintain`, `gain` |

แต่ละหน้าจอ onboarding ส่งเฉพาะฟิลด์ของหน้านั้นได้
เมื่อกรอกครบทั้ง 6 ฟิลด์ (`is_complete: true`) ระบบจะเติม `daily_calories` (kcal ต่อวัน) ให้

### การคำนวณเป้าหมาย (`nutrition.py`)

- BMR (Mifflin-St Jeor): ชาย `10w + 6.25h − 5age + 5`, หญิง `10w + 6.25h − 5age − 161`
- TDEE = BMR × ตัวคูณกิจกรรม (1.2 / 1.375 / 1.55 / 1.725 / 1.9)
- เป้าหมาย: ลด −500 kcal, คงที่ 0, เพิ่ม +300 kcal (ขั้นต่ำ หญิง 1200 / ชาย 1500 kcal)

### เปลี่ยนรหัสผ่าน (`PUT /api/account`)

```json
{ "current_password": "old-pass", "new_password": "new-pass-123" }
```

เมื่อเปลี่ยนรหัสผ่าน token เก่าทุกเครื่องจะใช้ไม่ได้ และ API จะส่ง `data.access_token` ใหม่กลับมา
แอปต้องเก็บ token ใหม่นี้แทนตัวเดิม

### ออกจากระบบ (`POST /api/logout`)

ไม่ต้องส่ง body ส่งแค่ header `Authorization`
หลังเรียกสำเร็จ token ของผู้ใช้นี้ทุกเครื่องจะใช้ไม่ได้ (ได้ `401`) แอปต้องลบ token ที่เก็บไว้ แล้วกลับไปหน้าเข้าสู่ระบบ

## อัปเดตฐานข้อมูลที่สร้างไว้แล้ว

ถ้าสร้างตารางด้วย `schema.sql` เวอร์ชันก่อนหน้า ให้รันไฟล์ใน `supabase/migrations/` ใน SQL Editor ตามลำดับ (รันซ้ำได้ ไม่เสียหาย)

- `002_add_token_version.sql` เพิ่มระบบออกจากระบบ
- `003_calories_only.sql` ตัดโปรตีน คาร์บ ไขมัน ออก เหลือแค่แคลอรี่
- `004_meals_and_weight.sql` บันทึกมื้อลง `saved_menu` (เพิ่ม `meal_type`) และเพิ่มตาราง `weight_logs`
- `005_exercise_logs.sql` เพิ่มตาราง `exercise_logs` (บันทึกการออกกำลังกาย)
- `006_food_name_th.sql` เพิ่มชื่อไทย `foods.food_name_th` ใส่ชื่อไทยให้ 12 เมนูเดิม และให้แคลอรี่ว่างได้ (เมนูใหม่จากโมเดลที่แอดมินยังไม่เติม)
- `007_target_weight.sql` เพิ่มน้ำหนักเป้าหมาย `target_weight` และวันครบกำหนด `target_date` ใน `user_profiles`
- `008_target_progress.sql` เพิ่มน้ำหนักตอนเริ่มตั้งเป้า `target_start_weight` และวันที่ตั้ง `target_set_at` (ใช้แสดงว่าลด/เพิ่มไปแล้วเท่าไร)

รัน migration ตอน backend เปิดอยู่ได้ ระบบจะเห็นคอลัมน์ใหม่เองภายใน 30 วินาที ไม่ต้องรีสตาร์ต

### เพิ่มเมนูใหม่

1. เทรนโมเดลใหม่ แล้วเอา `best.pt` มาแทน `models/yolo-cls.pt`
2. รีสตาร์ต backend: ระบบเพิ่มคลาสใหม่ลงตาราง `foods` ให้เอง
3. เข้าหน้าแอดมิน → เมนูอาหาร แล้วเติมชื่อไทยกับแคลอรี่ต่อ 100 กรัม (เมนูที่ยังไม่ได้เติมจะบันทึกมื้อไม่ได้)

### ข้อจำกัดของแอดมิน

- แอดมินลดสิทธิ์ตัวเองหรือลบบัญชีตัวเองไม่ได้ (กันไม่ให้ไม่มีใครเข้าหน้าจัดการได้)
- แอดมินรีเซ็ตรหัสผ่านให้ใคร คนนั้นจะถูกออกจากระบบทุกเครื่อง
- เปลี่ยนสิทธิ์ (`role_id`) มีผลทันทีกับ token ที่ใช้อยู่

## ความปลอดภัย

- `SUPABASE_KEY` เป็น service_role key ซึ่งข้ามระบบสิทธิ์ทั้งหมดของฐานข้อมูล ใช้บนเซิร์ฟเวอร์เท่านั้น
- ทุกตารางเปิด RLS ไว้โดยไม่มี policy ถ้าใครได้ anon key ไปก็อ่านข้อมูลไม่ได้
- ทุก endpoint ต้องเช็กสิทธิ์ผ่าน `get_current_user` หรือ `require_admin` เสมอ

## เกณฑ์การแจ้งเตือน (`dashboard.py`)

| เกณฑ์ | ค่า | ที่มา |
|---|---|---|
| ลดน้ำหนักเร็วเกินไป | เกิน 1 กก./สัปดาห์ | Nutrition ai+ สำนักโภชนาการ กรมอนามัย; CDC แนะนำ 0.5–1 กก. (1–2 ปอนด์)/สัปดาห์ |
| กินน้อยเกินไป | เฉลี่ย 7 วัน (แคลอรี่ที่กินจริง) ต่ำกว่า BMR หรือ 1,200 (หญิง) / 1,500 (ชาย) kcal | กรมอนามัย (BMR); 2013 AHA/ACC/TOS Obesity Guideline (1,200–1,500 หญิง, 1,500–1,800 ชาย) |
| แคลอรี่ ↔ น้ำหนัก | 7,700 kcal = 1 กก. | กรมอนามัย |
| แคลอรี่สุทธิ | กิน − เผาผลาญจากการออกกำลังกาย ใช้เทียบกับเป้า | ทีมกำหนดตามคำแนะนำอาจารย์ |
| กินเกินเป้า | เฉลี่ยเกินเป้า 10% และเกินอย่างน้อย 3 วัน | ทีมกำหนด (รออาจารย์ยืนยัน) |
| น้ำหนักขึ้นเร็ว | เกิน 0.5 กก./สัปดาห์ เมื่อเป้าหมายเป็นลด/คงน้ำหนัก | ทีมกำหนด (รออาจารย์ยืนยัน) |
| วันที่ "พอดี" | อยู่ในช่วงเป้า ±10% | ทีมกำหนด |

## เป้าหมายตาม BMI และค่าที่เหมาะสม (`nutrition.py`)

| ค่า | เกณฑ์ | ที่มา |
|---|---|---|
| ผอม | BMI < 18.5 เลือกได้แค่คงน้ำหนัก/เพิ่มน้ำหนัก | WHO Expert Consultation, Lancet 2004;363:157-63 |
| น้ำหนักเกิน (เกณฑ์เอเชีย) | BMI ≥ 23 เลือกได้แค่ลดน้ำหนัก | WHO Expert Consultation, Lancet 2004 |
| ลดน้ำหนัก | −500 kcal/วัน ≈ −0.45 กก./สัปดาห์ ≈ −1.9 กก./เดือน | 2013 AHA/ACC/TOS Obesity Guideline (ลด 500–750 kcal/วัน) |
| เพิ่มน้ำหนัก | +300 kcal/วัน ≈ +0.27 กก./สัปดาห์ | ทีมกำหนด |

## แคลอรี่จากการออกกำลังกาย (`exercise.py`)

`kcal = MET × น้ำหนักตัว (กก.) × ชั่วโมง` ค่า MET ของ 20 กิจกรรมมาจาก 2024 Adult Compendium of Physical Activities (Herrmann SD, et al. J Sport Health Sci 2024;13(1):6-12, https://pacompendium.com) เช่น เดิน 3.8, วิ่ง ~10 กม./ชม. 9.3, ปั่นจักรยานปานกลาง 8.0, ว่ายน้ำสบายๆ 6.0, แบดมินตัน 5.5

ต้องบันทึกอาหารอย่างน้อย 3 วันใน 7 วัน ระบบจึงจะเตือนเรื่องการกิน และน้ำหนักต้องมีอย่างน้อย 2 จุดห่างกัน 6 วันขึ้นไป
