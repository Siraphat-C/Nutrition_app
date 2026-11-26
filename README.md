# Nutrition App (full-app)

branch นี้มีครบทั้งแอปและ backend ในที่เดียว

```
/            แอป Flutter (UI v2)
backend/     FastAPI + โมเดล YOLO (ตรงกับ branch backend-dev)
```

## 1. รัน backend

```sh
cd backend
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

สร้างไฟล์ `backend/.env` (ขอค่าจากทีม backend ทางแชทส่วนตัว ห้ามขึ้น git)

```
SUPABASE_URL=...
SUPABASE_KEY=...
SECRET_KEY=...
```

```sh
uvicorn main:app --reload --host 0.0.0.0
```

เช็กว่าถูกตัว: เปิด `http://localhost:8000/docs` ต้องเห็นหมวด **แอดมิน** และ `/api/dashboard/alerts`

## 2. รันแอป (เปิดอีก Terminal ที่โฟลเดอร์บนสุด)

```sh
flutter pub get
flutter run -d chrome                                   # เว็บ เครื่องเดียวกับ backend
flutter run -d <device> --dart-define=API_BASE=http://<IP คอม>:8000   # LDPlayer / มือถือ
```

| รันบน | API_BASE |
|---|---|
| Chrome เครื่องเดียวกับ backend | ไม่ต้องใส่ (`http://localhost:8000`) |
| Android Studio emulator | ไม่ต้องใส่ (`http://10.0.2.2:8000`) |
| LDPlayer / มือถือจริง | `http://<IP จาก ipconfig>:8000` |

### LDPlayer

1. LDPlayer → Settings → Other settings → ADB debugging → Open local connection แล้วเปิด LDPlayer ใหม่
2. `"C:\LDPlayer\LDPlayer9\adb.exe" connect 127.0.0.1:5555`
3. `flutter run -d 127.0.0.1:5555 --dart-define=API_BASE=http://<IP>:8000`

ไม่มีกล้องใน LDPlayer: ลากรูปอาหารใส่หน้าต่าง LDPlayer แล้วกด "เลือกจากคลัง"

## ปัญหาที่เจอบ่อย

| อาการ | แก้ |
|---|---|
| `NoSuchMethodError ... access_token` / "เซิร์ฟเวอร์ตอบผิดรูปแบบ" | รัน backend ผิดตัว ต้องรันใน `backend/` ของ branch นี้ |
| "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (10.0.2.2)" | ใส่ `--dart-define=API_BASE=...` |
| build Android พังที่ `mergeDebugJavaResource` | Windows ภาษาไทย (ปี พ.ศ.) แก้แล้วใน `android/gradle.properties` |
