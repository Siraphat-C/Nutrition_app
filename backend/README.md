# My Nutrition Secretary API (backend)

FastAPI server ของแอปวิเคราะห์โภชนาการอาหารจากรูปภาพ
แอป Flutter ใช้ Supabase Auth สำหรับสมัครสมาชิก/เข้าสู่ระบบ ส่วน API นี้ยังใช้ระบบบัญชีของตัวเองผ่านตาราง `public.users`

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

ทุก endpoint ที่มี 🔒 ต้องส่ง header `Authorization: Bearer <access_token>` (ได้จาก `/api/login`)

| Method | Path | สิทธิ์ | ใช้ทำอะไร |
|---|---|---|---|
| POST | `/api/register` | - | สมัครสมาชิก `{username, email, password}` (รหัสผ่าน 8–72 ตัว, ภาษาไทยไม่เกิน 24 ตัว) |
| POST | `/api/login` | - | เข้าสู่ระบบ `{email, password}` ได้ `access_token` |
| GET | `/api/me` | 🔒 | ข้อมูลบัญชี + โปรไฟล์ |
| GET | `/api/profile` | 🔒 | ข้อมูลส่วนตัว + แคลอรี่ที่ควรได้รับต่อวัน |
| PUT | `/api/profile` | 🔒 | แก้ข้อมูลส่วนตัว (ส่งเฉพาะฟิลด์ที่แก้) ระบบคำนวณเป้าหมายให้อัตโนมัติ |
| POST | `/api/profile/preview` | 🔒 | คำนวณเป้าหมายให้ดูก่อน ยังไม่บันทึก |
| PUT | `/api/account` | 🔒 | แก้ username / เปลี่ยนรหัสผ่าน |
| POST | `/api/logout` | 🔒 | ออกจากระบบ (token เดิมใช้ไม่ได้ทุกเครื่อง) |
| POST | `/api/analyze` | 🔒 | ส่งรูป (multipart field `file`, ไม่เกิน 10 MB) วิเคราะห์ชื่อเมนู |
| POST | `/api/logs` | 🔒 | บันทึกมื้ออาหาร `{food_id, meal_type}` |
| GET | `/api/logs/today` | 🔒 | ประวัติการกินวันนี้ (เวลาไทย) |
| GET | `/api/admin/dashboard` | 🔒 admin | ทดสอบสิทธิ์แอดมิน |
| POST | `/api/admin/foods` | 🔒 admin | เพิ่มเมนู `{food_name, calories_per_100g}` (0–900 kcal ต่อ 100 กรัม) |
| DELETE | `/api/admin/foods/{food_id}` | 🔒 admin | ลบเมนู |

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
| `activity_level` | 1 ไม่ออกกำลังกาย, 2 เบา 1–3 วัน/สัปดาห์, 3 ปานกลาง 3–5 วัน, 4 หนัก 6–7 วัน, 5 หนักมาก/งานใช้แรง |
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

เมื่อเปลี่ยนรหัสผ่าน token เก่าทุกเครื่องจะใช้ไม่ได้ และ API จะส่ง `access_token` ใหม่กลับมา
แอปต้องเก็บ token ใหม่นี้แทนตัวเดิม

### ออกจากระบบ (`POST /api/logout`)

ไม่ต้องส่ง body ส่งแค่ header `Authorization`
หลังเรียกสำเร็จ token ของผู้ใช้นี้ทุกเครื่องจะใช้ไม่ได้ (ได้ `401`) แอปต้องลบ token ที่เก็บไว้ แล้วกลับไปหน้าเข้าสู่ระบบ

## อัปเดตฐานข้อมูลที่สร้างไว้แล้ว

ถ้าสร้างตารางด้วย `schema.sql` เวอร์ชันก่อนหน้า ให้รันไฟล์ใน `supabase/migrations/` ใน SQL Editor ตามลำดับ (รันซ้ำได้ ไม่เสียหาย)

- `002_add_token_version.sql` เพิ่มระบบออกจากระบบ
- `003_calories_only.sql` ตัดโปรตีน คาร์บ ไขมัน ออก เหลือแค่แคลอรี่

## ความปลอดภัย

- `SUPABASE_KEY` เป็น service_role key ซึ่งข้ามระบบสิทธิ์ทั้งหมดของฐานข้อมูล ใช้บนเซิร์ฟเวอร์เท่านั้น
- ทุกตารางเปิด RLS ไว้โดยไม่มี policy ถ้าใครได้ anon key ไปก็อ่านข้อมูลไม่ได้
- ทุก endpoint ต้องเช็กสิทธิ์ผ่าน `get_current_user` หรือ `require_admin` เสมอ
