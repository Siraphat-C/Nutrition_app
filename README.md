# Nutrition App (full-app)

branch นี้มีครบทั้งแอปและ backend ในที่เดียว

```
/            แอป Flutter (UI v2)
backend/     FastAPI + โมเดล YOLO (ตรงกับ branch backend-dev)
```

1. Install Flutter and the tooling for the target platform, then add Flutter's `bin` directory to `PATH`.
2. Clone this repository and open a terminal in the repository root.
3. By default, the app uses local accounts and stores account, profile, and meal data on the device. Run it with:

   ```powershell
   flutter run -d <device_id>
   ```

   Clearing the app's data or uninstalling it removes these local accounts and records. To use Supabase Auth instead, configure the asset:

   ```powershell
   New-Item -ItemType Directory -Force assets
   Copy-Item .env.example assets/app.env
   ```

   Set `SUPABASE_URL` to the project's URL from **Supabase Dashboard → Project Settings → API**, and set `SUPABASE_PUBLISHABLE_KEY` to the project's publishable key. Add `--dart-define=LOCAL_AUTH=false` to a `flutter run` or `flutter build` command to opt into Supabase. Do not use a secret or `service_role` key in Flutter. The config file is gitignored; its publishable key is still included in the local app build, so it is not a place for secrets.

   Signup creates an account in Supabase Auth (`auth.users`) and stores the display name as user metadata. Nutrition profile and meal data remain local to the device; this change does not expose the database tables to the publishable key.

4. Fetch the locked dependencies:

```sh
cd backend
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

5. List available targets and run the app:

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
