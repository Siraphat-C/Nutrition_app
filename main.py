from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from ultralytics import YOLO
from PIL import Image
import io
from supabase import create_client, Client
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone

import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="My Nutrition Secretary API")

# เปิดใช้งาน CORS (อนุญาตให้แอป Flutter หรือหน้าเว็บยิง API เข้ามาได้โดยไม่ติดบล็อก)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # อนุญาตทุกโดเมน (หรือจะระบุเฉพาะ IP ตอนขึ้นระบบจริงก็ได้)
    allow_credentials=True,
    allow_methods=["*"],  # อนุญาตทุก Method (GET, POST, PUT, DELETE)
    allow_headers=["*"],  # อนุญาตทุก Header
)

# 1. เชื่อมต่อ Supabase และโหลดโมเดล YOLO
# ... (โค้ดเดิมด้านล่าง) ...

# 1. เชื่อมต่อ Supabase และโหลดโมเดล YOLO
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

model = YOLO("models/yolo-cls.pt")

# 2. ตั้งค่าระบบความปลอดภัย (Password Hashing & JWT)
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = HTTPBearer()

# 3. โครงสร้างข้อมูลที่รับเข้าจากแอป (Schemas)
class UserRegister(BaseModel):
    username: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# 4. ฟังก์ชันช่วยเหลือ (เข้ารหัสผ่าน & สร้าง/ตรวจ JWT Token)
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# ฟังก์ชันตรวจสอบบัตรผ่าน (Middleware/Dependency)
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(oauth2_scheme)):
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token ไม่ถูกต้องหรือหมดอายุ กรุณาล็อกอินใหม่",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        role_id: int = payload.get("role_id")
        if user_id is None or role_id is None:
            raise credentials_exception
        return {"user_id": user_id, "role_id": role_id}
    except JWTError:
        raise credentials_exception

# ฟังก์ชันกั้นประตูเฉพาะ Admin (role_id == 1)
def require_admin(current_user: dict = Depends(get_current_user)):
    if current_user["role_id"] != 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="ปฏิเสธการเข้าถึง: เฉพาะผู้ดูแลระบบ (Admin) เท่านั้น"
        )
    return current_user

# ==========================================
# API 1: สมัครสมาชิก (Register)
# ==========================================
@app.post("/api/register")
def register(user: UserRegister):
    # เช็กว่าอีเมลหรือชื่อผู้ใช้ซ้ำไหม
    existing_email = supabase.table("users").select("user_id").eq("email", user.email).execute()
    if existing_email.data:
        raise HTTPException(status_code=400, detail="อีเมลนี้ถูกใช้งานแล้ว")

    existing_user = supabase.table("users").select("user_id").eq("username", user.username).execute()
    if existing_user.data:
        raise HTTPException(status_code=400, detail="ชื่อผู้ใช้นี้ถูกใช้งานแล้ว")

    # เข้ารหัสผ่านและบันทึกลงตาราง users (ค่าเริ่มต้น role_id = 2 คือ User ทั่วไป)
    hashed_pw = hash_password(user.password)
    new_user = {
        "username": user.username,
        "email": user.email,
        "password_hash": hashed_pw,
        "role_id": 2
    }
    response = supabase.table("users").insert(new_user).execute()
    return {
        "success": True,
        "message": "สมัครสมาชิกสำเร็จ",
        "user_id": response.data[0]["user_id"]
    }

# ==========================================
# API 2: เข้าสู่ระบบ (Login & ออก JWT Token)
# ==========================================
@app.post("/api/login")
def login(user: UserLogin):
    # ค้นหาผู้ใช้จากอีเมล
    response = supabase.table("users").select("*").eq("email", user.email).execute()
    if not response.data:
        raise HTTPException(status_code=401, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")

    db_user = response.data[0]

    # ตรวจสอบรหัสผ่านที่กรอกเทียบกับรหัสที่เข้ารหัสไว้ในฐานข้อมูล
    if not verify_password(user.password, db_user["password_hash"]):
        raise HTTPException(status_code=401, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")

    # สร้าง JWT Token โดยฝัง user_id และ role_id ไว้ข้างใน
    access_token = create_access_token(
        data={"user_id": db_user["user_id"], "role_id": db_user["role_id"]}
    )
    return {
        "success": True,
        "access_token": access_token,
        "token_type": "bearer",
        "role_id": db_user["role_id"],
        "username": db_user["username"]
    }

# ==========================================
# API 3: ตัวอย่างเส้นทางที่แยกสิทธิ์ (User vs Admin)
# ==========================================
@app.get("/api/me")
def read_users_me(current_user: dict = Depends(get_current_user)):
    return {"message": "ยืนยันตัวตนสำเร็จ", "your_info": current_user}

@app.get("/api/admin/dashboard")
def admin_only_route(admin_user: dict = Depends(require_admin)):
    return {"message": "ยินดีต้อนรับผู้ดูแลระบบ (Admin)", "admin_info": admin_user}

# ==========================================
# API 4: วิเคราะห์ภาพอาหาร (ของเดิม)
# ==========================================
@app.post("/api/analyze")
async def analyze_food(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        results = model(image)
        predicted_class_id = results[0].probs.top1
        confidence_score = float(results[0].probs.top1conf)
        predicted_class_name = model.names[predicted_class_id]

        nutrition_info = None
        response = supabase.table("Foods").select("*").eq("food_name", predicted_class_name).execute()

        if len(response.data) > 0:
            nutrition_info = response.data[0]
        else:
            nutrition_info = {"message": "ไม่พบข้อมูลโภชนาการเมนูนี้ในฐานข้อมูล"}

        return {
            "success": True,
            "food_name": predicted_class_name,
            "confidence": round(confidence_score, 4),
            "nutrition": nutrition_info
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

# ==========================================
# ส่วนที่ 4: ระบบบันทึกประวัติการกิน (Food Logs)
# ==========================================

# 1. สร้าง Model รับข้อมูลจากแอป Flutter
class FoodLogRequest(BaseModel):
    food_id: int
    meal_type: str  # เช่น 'breakfast', 'lunch', 'dinner', 'snack'

security = HTTPBearer()

# 2. API สำหรับบันทึกมื้ออาหาร
@app.post("/api/logs")
def create_food_log(log: FoodLogRequest, credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        # ถอดรหัส Token เพื่อดึง user_id ของคนที่กำลังใช้งาน
        SECRET_KEY = os.getenv("SECRET_KEY")
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("user_id") # ดึง user_id จาก token

        if not user_id:
            raise HTTPException(status_code=401, detail="Token ไม่สมบูรณ์ ไม่มี user_id")

        # บันทึกลงตาราง food_logs
        data = {
            "user_id": user_id,
            "food_id": log.food_id,
            "meal_type": log.meal_type
        }
        result = supabase.table("food_logs").insert(data).execute()
        return {"message": "บันทึกมื้ออาหารสำเร็จ", "data": result.data}
        
    except JWTError:
        raise HTTPException(status_code=401, detail="Token ไม่ถูกต้องหรือหมดอายุ โปรดล็อกอินใหม่")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. API สำหรับดึงประวัติการกินของ "วันนี้"
@app.get("/api/logs/today")
def get_today_logs(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        SECRET_KEY = os.getenv("SECRET_KEY")
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("user_id")

        # ดึงวันที่ปัจจุบัน (เอาแค่ ปี-เดือน-วัน)
        today = datetime.now(timezone.utc).astimezone().date().isoformat()
        
        # ดึงข้อมูลการกินของวันนี้ พร้อมดึงชื่อและแคลอรีจากตาราง Foods มาด้วย (Join table)
        result = supabase.table("food_logs") \
            .select("log_id, meal_type, logged_at, Foods(food_name, calories)") \
            .eq("user_id", user_id) \
            .gte("logged_at", f"{today}T00:00:00+07:00") \
            .execute()
            
        return {"message": "ดึงข้อมูลสำเร็จ", "data": result.data}
        
    except JWTError:
        raise HTTPException(status_code=401, detail="Token ไม่ถูกต้องหรือหมดอายุ")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# ส่วนที่ 5: ระบบจัดการฐานข้อมูลอาหาร (Admin)
# ==========================================

# Model รับข้อมูลเพิ่มอาหาร
class FoodRequest(BaseModel):
    food_name: str
    calories: str

# 1. API เพิ่มเมนูอาหารใหม่
@app.post("/api/admin/foods")
def add_food(food: FoodRequest, credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        # ยืนยันตัวตนว่าล็อกอินอยู่ (อนาคตสามารถเพิ่มโค้ดเช็ก role_id ว่าเป็น admin ได้ตรงนี้)
        SECRET_KEY = os.getenv("SECRET_KEY")
        jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])

        # บันทึกเมนูใหม่ลงตาราง Foods
        data = {
            "food_name": food.food_name,
            "calories": food.calories
        }
        result = supabase.table("Foods").insert(data).execute()
        return {"message": "เพิ่มเมนูอาหารสำเร็จ", "data": result.data}
        
    except JWTError:
        raise HTTPException(status_code=401, detail="Token ไม่ถูกต้องหรือหมดอายุ")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. API ลบเมนูอาหาร
@app.delete("/api/admin/foods/{target_food_id}")
def delete_food(target_food_id: int, credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        SECRET_KEY = os.getenv("SECRET_KEY")
        jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
        
        # ลบข้อมูลตาม food_id
        result = supabase.table("Foods").delete().eq("food_id", target_food_id).execute()
        return {"message": f"ลบเมนูอาหารรหัส {target_food_id} สำเร็จเรียบร้อย"}
        
    except JWTError:
        raise HTTPException(status_code=401, detail="Token ไม่ถูกต้องหรือหมดอายุ")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))