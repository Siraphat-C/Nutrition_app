import io
import logging
import os
import threading
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Literal
from zoneinfo import ZoneInfo

import bcrypt
import jwt
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, HTTPException, Path as PathParam, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from PIL import Image, UnidentifiedImageError
from postgrest.exceptions import APIError
from pydantic import BaseModel, EmailStr, Field, field_validator
from supabase import Client, create_client
from ultralytics import YOLO

from nutrition import calculate_daily_requirement
from validation import (
    INT4_MAX,
    MAX_IMAGE_PIXELS,
    check_birth_date,
    check_email_length,
    check_password_bytes,
    round_2,
)

load_dotenv()

# ==========================================
# 0. ตั้งค่าระบบ (อ่านจากไฟล์ .env)
# ==========================================
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")  # ต้องเป็น service_role / secret key (ใช้บนเซิร์ฟเวอร์เท่านั้น)
SECRET_KEY = os.getenv("SECRET_KEY")      # ใช้เซ็น JWT ควรยาวอย่างน้อย 32 ตัวอักษร

missing = [name for name, value in {
    "SUPABASE_URL": SUPABASE_URL,
    "SUPABASE_KEY": SUPABASE_KEY,
    "SECRET_KEY": SECRET_KEY,
}.items() if not value]
if missing:
    raise RuntimeError(f"ไม่พบค่า {', '.join(missing)} ในไฟล์ .env")

logger = logging.getLogger("nutrition_api")

if len(SECRET_KEY) < 32:
    logger.warning(
        "SECRET_KEY สั้นกว่า 32 ตัวอักษร ควรสร้างใหม่ด้วย: "
        "python -c \"import secrets; print(secrets.token_urlsafe(48))\""
    )

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
LOCAL_TZ = ZoneInfo("Asia/Bangkok")
MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB

# CORS: แอปมือถือไม่ติด CORS อยู่แล้ว ตั้งไว้สำหรับหน้าเว็บ (เช่น Flutter web)
# ระบุโดเมนใน .env ได้ เช่น CORS_ORIGINS=http://localhost:3000,https://example.com
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

app = FastAPI(title="My Nutrition Secretary API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,  # ใช้ Bearer token ใน header ไม่ใช้ cookie
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# 1. เชื่อมต่อ Supabase และโหลดโมเดล YOLO
# ==========================================
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

model = YOLO(str(Path(__file__).parent / "models" / "yolo-cls.pt"))
# โมเดลตัวเดียวถูกใช้ร่วมกันทุกคำขอ และ YOLO ไม่รองรับการทำงานพร้อมกันหลายเธรด
# จึงล็อกให้ประมวลผลทีละรูป
model_lock = threading.Lock()

bearer_scheme = HTTPBearer()


# ข้อผิดพลาดจากฐานข้อมูลที่เกิดจากข้อมูลที่ส่งมา ให้ตอบเป็น 4xx แทน 500
DB_ERROR_RESPONSES = {
    "23505": (409, "ข้อมูลซ้ำกับที่มีอยู่แล้ว"),
    "23503": (409, "ข้อมูลนี้ถูกอ้างอิงอยู่ หรืออ้างอิงข้อมูลที่ไม่มีอยู่"),
    "23514": (422, "ข้อมูลไม่อยู่ในช่วงที่กำหนด"),
    "22001": (422, "ข้อความยาวเกินกำหนด"),
    "22003": (422, "ตัวเลขเกินช่วงที่กำหนด"),
    "22P02": (422, "รูปแบบข้อมูลไม่ถูกต้อง"),
}


@app.exception_handler(APIError)
def handle_database_error(request: Request, error: APIError):
    code = getattr(error, "code", None)
    if code in DB_ERROR_RESPONSES:
        status_code, detail = DB_ERROR_RESPONSES[code]
        return JSONResponse(status_code=status_code, content={"detail": detail})
    logger.exception("Database error on %s %s", request.method, request.url.path)
    return JSONResponse(status_code=500, content={"detail": "เกิดข้อผิดพลาดในระบบ"})


# ==========================================
# 2. ฟังก์ชันช่วยเหลือ (รหัสผ่าน & JWT)
# ==========================================
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))


def create_access_token(user: dict) -> str:
    """สร้าง JWT โดยฝัง user_id, role_id และ token_version
    (token_version เพิ่มขึ้นเมื่อออกจากระบบหรือเปลี่ยนรหัสผ่าน ทำให้ token เก่าใช้ไม่ได้)"""
    to_encode = {
        "user_id": user["user_id"],
        "role_id": user["role_id"],
        "ver": user["token_version"],
    }
    to_encode["exp"] = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)) -> dict:
    """ตรวจ token แล้วดึง role ล่าสุดจากฐานข้อมูล
    (ถ้าบัญชีถูกลบหรือถูกเปลี่ยนสิทธิ์ token เดิมจะใช้ตามสิทธิ์ใหม่ทันที)"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token ไม่ถูกต้องหรือหมดอายุ กรุณาล็อกอินใหม่",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        raise credentials_exception

    user_id = payload.get("user_id")
    if user_id is None:
        raise credentials_exception

    result = supabase.table("users").select("user_id, role_id, username, email, token_version") \
        .eq("user_id", user_id).execute()
    if not result.data:
        raise credentials_exception

    user = result.data[0]
    # token ที่ออกก่อนการออกจากระบบ / เปลี่ยนรหัสผ่านครั้งล่าสุด จะใช้ไม่ได้
    if payload.get("ver") != user["token_version"]:
        raise credentials_exception
    return user


def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    if current_user["role_id"] != 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="ปฏิเสธการเข้าถึง: เฉพาะผู้ดูแลระบบ (Admin) เท่านั้น",
        )
    return current_user


def public_user(user: dict) -> dict:
    """ข้อมูลผู้ใช้ที่ส่งกลับให้แอปได้ (ไม่รวม token_version)"""
    return {k: v for k, v in user.items() if k != "token_version"}


def bump_token_version(user: dict, extra_changes: dict | None = None) -> dict:
    """เพิ่ม token_version (ทำให้ token เก่าใช้ไม่ได้) พร้อมบันทึกค่าอื่นในคำสั่งเดียว
    ใช้เงื่อนไข token_version เดิม กันกรณีสองคำขอแก้พร้อมกัน"""
    changes = {**(extra_changes or {}), "token_version": user["token_version"] + 1}
    result = supabase.table("users").update(changes) \
        .eq("user_id", user["user_id"]) \
        .eq("token_version", user["token_version"]) \
        .execute()
    if not result.data:
        raise HTTPException(status_code=409, detail="บัญชีถูกแก้ไขจากที่อื่นพร้อมกัน กรุณาลองใหม่")
    return result.data[0]


def is_unique_violation(error: APIError) -> bool:
    return getattr(error, "code", None) == "23505"


def is_foreign_key_violation(error: APIError) -> bool:
    return getattr(error, "code", None) == "23503"


# ==========================================
# 3. โครงสร้างข้อมูลที่รับเข้าจากแอป (Schemas)
# ==========================================
def today_local() -> date:
    return datetime.now(LOCAL_TZ).date()


class UserRegister(BaseModel):
    username: str = Field(min_length=3, max_length=50, pattern=r"^[A-Za-z0-9_.]+$")
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)

    _email_length = field_validator("email")(check_email_length)
    _password_bytes = field_validator("password")(check_password_bytes)


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(max_length=128)


def _check_birth_date(value: date | None) -> date | None:
    return None if value is None else check_birth_date(value, today_local())


class ProfileUpdate(BaseModel):
    """ส่งเฉพาะฟิลด์ที่ต้องการแก้ (แต่ละหน้าจอ onboarding ส่งเฉพาะของหน้านั้นได้)"""
    gender: Literal["male", "female"] | None = None
    birth_date: date | None = None
    weight: float | None = Field(default=None, ge=20, le=300)       # kg
    height: float | None = Field(default=None, ge=100, le=250)      # cm
    activity_level: int | None = Field(default=None, ge=1, le=5)
    goal: Literal["lose", "maintain", "gain"] | None = None

    _birth_date = field_validator("birth_date")(_check_birth_date)
    # ปัดทศนิยม 2 ตำแหน่งก่อนตรวจช่วง ให้ตรงกับคอลัมน์ numeric(5, 2)
    _round = field_validator("weight", "height", mode="before")(round_2)


class RequirementPreview(BaseModel):
    gender: Literal["male", "female"]
    birth_date: date
    weight: float = Field(ge=20, le=300)
    height: float = Field(ge=100, le=250)
    activity_level: int = Field(ge=1, le=5)
    goal: Literal["lose", "maintain", "gain"]

    _birth_date = field_validator("birth_date")(_check_birth_date)
    _round = field_validator("weight", "height", mode="before")(round_2)


class AccountUpdate(BaseModel):
    username: str | None = Field(default=None, min_length=3, max_length=50, pattern=r"^[A-Za-z0-9_.]+$")
    current_password: str | None = Field(default=None, max_length=128)
    new_password: str | None = Field(default=None, min_length=8, max_length=72)

    @field_validator("new_password")
    @classmethod
    def _password_bytes(cls, value: str | None) -> str | None:
        return None if value is None else check_password_bytes(value)


class FoodLogRequest(BaseModel):
    food_id: int = Field(gt=0, le=INT4_MAX)
    meal_type: Literal["breakfast", "lunch", "dinner", "snack"]


class FoodRequest(BaseModel):
    food_name: str = Field(min_length=1, max_length=100)
    # ค่าต่อ 100 กรัม: พลังงานไม่เกิน 900 kcal (ไขมันล้วน), สารอาหารแต่ละตัวไม่เกิน 100 กรัม
    calories_per_100g: float = Field(ge=0, le=900)
    protein_per_100g: float = Field(default=0, ge=0, le=100)
    carbohydrate_per_100g: float = Field(default=0, ge=0, le=100)
    fat_per_100g: float = Field(default=0, ge=0, le=100)

    _round = field_validator(
        "calories_per_100g", "protein_per_100g", "carbohydrate_per_100g", "fat_per_100g",
        mode="before",
    )(round_2)


# ==========================================
# API 1: สมัครสมาชิก (Register)
# ==========================================
@app.post("/api/register", status_code=status.HTTP_201_CREATED)
def register(user: UserRegister):
    email = user.email.lower()

    if supabase.table("users").select("user_id").eq("email", email).execute().data:
        raise HTTPException(status_code=400, detail="อีเมลนี้ถูกใช้งานแล้ว")
    if supabase.table("users").select("user_id").eq("username", user.username).execute().data:
        raise HTTPException(status_code=400, detail="ชื่อผู้ใช้นี้ถูกใช้งานแล้ว")

    new_user = {
        "username": user.username,
        "email": email,
        "password_hash": hash_password(user.password),
        "role_id": 2,  # 2 = ผู้ใช้ทั่วไป
    }
    try:
        response = supabase.table("users").insert(new_user).execute()
    except APIError as e:
        # กันกรณีสมัครพร้อมกันสองเครื่องด้วยอีเมล/ชื่อเดียวกัน
        if is_unique_violation(e):
            raise HTTPException(status_code=400, detail="อีเมลหรือชื่อผู้ใช้นี้ถูกใช้งานแล้ว")
        raise

    user_id = response.data[0]["user_id"]
    supabase.table("user_profiles").insert({"user_id": user_id}).execute()

    return {"success": True, "message": "สมัครสมาชิกสำเร็จ", "user_id": user_id}


# ==========================================
# API 2: เข้าสู่ระบบ (Login & ออก JWT Token)
# ==========================================
@app.post("/api/login")
def login(user: UserLogin):
    response = supabase.table("users").select("*").eq("email", user.email.lower()).execute()
    if not response.data or not verify_password(user.password, response.data[0]["password_hash"]):
        raise HTTPException(status_code=401, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")

    db_user = response.data[0]
    access_token = create_access_token(db_user)
    return {
        "success": True,
        "access_token": access_token,
        "token_type": "bearer",
        "role_id": db_user["role_id"],
        "username": db_user["username"],
    }


# ==========================================
# API 3: ข้อมูลผู้ใช้ปัจจุบัน / Admin
# ==========================================
@app.get("/api/me")
def read_users_me(current_user: dict = Depends(get_current_user)):
    return {
        "message": "ยืนยันตัวตนสำเร็จ",
        "your_info": public_user(current_user),
        "profile": get_or_create_profile(current_user["user_id"]),
    }


@app.get("/api/admin/dashboard")
def admin_only_route(admin_user: dict = Depends(require_admin)):
    return {"message": "ยินดีต้อนรับผู้ดูแลระบบ (Admin)", "admin_info": public_user(admin_user)}


# ==========================================
# API 4: ข้อมูลส่วนตัว & เป้าหมายโภชนาการ
# ==========================================
PROFILE_INPUT_FIELDS = ("gender", "birth_date", "weight", "height", "activity_level", "goal")


def get_or_create_profile(user_id: int) -> dict:
    result = supabase.table("user_profiles").select("*").eq("user_id", user_id).execute()
    if result.data:
        return result.data[0]
    try:
        return supabase.table("user_profiles").insert({"user_id": user_id}).execute().data[0]
    except APIError as e:
        # มีคำขออื่นสร้างโปรไฟล์ไปพร้อมกันแล้ว
        if not is_unique_violation(e):
            raise
        return supabase.table("user_profiles").select("*").eq("user_id", user_id).execute().data[0]


@app.get("/api/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    profile = get_or_create_profile(current_user["user_id"])
    profile["is_complete"] = all(profile.get(f) is not None for f in PROFILE_INPUT_FIELDS)
    return profile


@app.put("/api/profile")
def update_profile(update: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    current = get_or_create_profile(user_id)

    changes = update.model_dump(mode="json", exclude_none=True)
    merged = {**{f: current.get(f) for f in PROFILE_INPUT_FIELDS}, **changes}

    if all(merged[f] is not None for f in PROFILE_INPUT_FIELDS):
        requirement = calculate_daily_requirement(
            gender=merged["gender"],
            birth_date=date.fromisoformat(str(merged["birth_date"])),
            weight=float(merged["weight"]),
            height=float(merged["height"]),
            activity_level=int(merged["activity_level"]),
            goal=merged["goal"],
            today=today_local(),
        )
        changes.update({
            "daily_calories": requirement.daily_calories,
            "daily_protein": requirement.daily_protein,
            "daily_carbohydrate": requirement.daily_carbohydrate,
            "daily_fat": requirement.daily_fat,
            "calculated_at": datetime.now(timezone.utc).isoformat(),
        })

    if not changes:
        raise HTTPException(status_code=400, detail="ไม่มีข้อมูลที่ต้องการแก้ไข")

    result = supabase.table("user_profiles").update(changes).eq("user_id", user_id).execute()
    profile = result.data[0]
    profile["is_complete"] = all(profile.get(f) is not None for f in PROFILE_INPUT_FIELDS)
    return profile


@app.post("/api/profile/preview")
def preview_requirement(data: RequirementPreview, current_user: dict = Depends(get_current_user)):
    """คำนวณเป้าหมายให้ดูก่อน ยังไม่บันทึก"""
    requirement = calculate_daily_requirement(
        **data.model_dump(), today=today_local()
    )
    return requirement.__dict__


# ==========================================
# API 5: แก้ไขบัญชีผู้ใช้ (username / รหัสผ่าน)
# ==========================================
@app.put("/api/account")
def update_account(update: AccountUpdate, current_user: dict = Depends(get_current_user)):
    changes = {}

    if update.username is not None and update.username != current_user["username"]:
        changes["username"] = update.username

    if update.new_password is not None:
        if not update.current_password:
            raise HTTPException(status_code=400, detail="กรุณากรอกรหัสผ่านปัจจุบัน")
        db_user = supabase.table("users").select("password_hash") \
            .eq("user_id", current_user["user_id"]).execute().data[0]
        if not verify_password(update.current_password, db_user["password_hash"]):
            raise HTTPException(status_code=400, detail="รหัสผ่านปัจจุบันไม่ถูกต้อง")
        changes["password_hash"] = hash_password(update.new_password)

    if not changes:
        raise HTTPException(status_code=400, detail="ไม่มีข้อมูลที่ต้องการแก้ไข")

    try:
        if "password_hash" in changes:
            # เปลี่ยนรหัสผ่าน: ให้ token เก่าทุกเครื่องใช้ไม่ได้ (เครื่องอื่นต้องล็อกอินใหม่)
            updated_user = bump_token_version(current_user, changes)
        else:
            supabase.table("users").update(changes).eq("user_id", current_user["user_id"]).execute()
            updated_user = {**current_user, **changes}
    except APIError as e:
        if is_unique_violation(e):
            raise HTTPException(status_code=400, detail="ชื่อผู้ใช้นี้ถูกใช้งานแล้ว")
        raise

    response = {
        "success": True,
        "message": "แก้ไขบัญชีสำเร็จ",
        "username": updated_user["username"],
    }
    if "password_hash" in changes:
        # ส่ง token ใหม่กลับไป เครื่องที่กำลังใช้งานจะได้ไม่ต้องล็อกอินใหม่
        response["access_token"] = create_access_token(updated_user)
        response["token_type"] = "bearer"
    return response


# ==========================================
# API 5.1: ออกจากระบบ (Logout)
# ==========================================
@app.post("/api/logout")
def logout(current_user: dict = Depends(get_current_user)):
    """ทำให้ token ทั้งหมดของผู้ใช้นี้ใช้ไม่ได้ (ออกจากระบบทุกเครื่อง)
    แอปต้องลบ token ที่เก็บไว้ในเครื่องด้วย"""
    bump_token_version(current_user)
    return {"success": True, "message": "ออกจากระบบสำเร็จ"}


# ==========================================
# API 6: วิเคราะห์ภาพอาหาร
# ==========================================
@app.post("/api/analyze")
def analyze_food(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(status_code=400, detail="กรุณาอัปโหลดไฟล์รูปภาพ")

    image_bytes = file.file.read(MAX_IMAGE_BYTES + 1)
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="ไฟล์รูปภาพต้องมีขนาดไม่เกิน 10 MB")

    try:
        image = Image.open(io.BytesIO(image_bytes))
        # เช็กขนาดก่อนแปลงรูป (ไฟล์เล็กแต่ภาพใหญ่มากจะกินหน่วยความจำหลาย GB)
        if image.width * image.height > MAX_IMAGE_PIXELS:
            raise HTTPException(status_code=413, detail="ภาพมีความละเอียดสูงเกินไป")
        image = image.convert("RGB")
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(status_code=400, detail="ไม่สามารถอ่านไฟล์รูปภาพได้")

    with model_lock:
        results = model(image, verbose=False)
    predicted_class_id = results[0].probs.top1
    confidence_score = float(results[0].probs.top1conf)
    predicted_class_name = model.names[predicted_class_id]

    response = supabase.table("foods").select("*").eq("food_name", predicted_class_name).execute()
    food = response.data[0] if response.data else None

    return {
        "success": True,
        "food_name": predicted_class_name,
        "confidence": round(confidence_score, 4),
        "food_id": food["food_id"] if food else None,
        "nutrition": food,  # ค่าต่อ 100 กรัม หรือ null ถ้ายังไม่มีเมนูนี้ในฐานข้อมูล
        "message": None if food else "ไม่พบข้อมูลโภชนาการเมนูนี้ในฐานข้อมูล",
    }


# ==========================================
# API 7: บันทึกประวัติการกิน (Food Logs)
# ชั่วคราว: จะเปลี่ยนไปใช้ตาราง saved_menu ตามรายงานในสัปดาห์ที่ 5
# ==========================================
@app.post("/api/logs", status_code=status.HTTP_201_CREATED)
def create_food_log(log: FoodLogRequest, current_user: dict = Depends(get_current_user)):
    if not supabase.table("foods").select("food_id").eq("food_id", log.food_id).execute().data:
        raise HTTPException(status_code=404, detail="ไม่พบเมนูอาหารนี้")

    data = {
        "user_id": current_user["user_id"],
        "food_id": log.food_id,
        "meal_type": log.meal_type,
    }
    result = supabase.table("food_logs").insert(data).execute()
    return {"message": "บันทึกมื้ออาหารสำเร็จ", "data": result.data}


@app.get("/api/logs/today")
def get_today_logs(current_user: dict = Depends(get_current_user)):
    # ช่วงเวลา 00:00 - 24:00 ของวันนี้ตามเวลาประเทศไทย ไม่ขึ้นกับ timezone ของเครื่องเซิร์ฟเวอร์
    start = datetime.now(LOCAL_TZ).replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=1)
    # ส่งเป็นเวลา UTC (ลงท้าย Z) เลี่ยงปัญหาเครื่องหมาย + ใน URL
    start = start.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    end = end.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    result = supabase.table("food_logs") \
        .select("log_id, meal_type, logged_at, foods(food_name, calories_per_100g)") \
        .eq("user_id", current_user["user_id"]) \
        .gte("logged_at", start) \
        .lt("logged_at", end) \
        .order("logged_at") \
        .execute()

    return {"message": "ดึงข้อมูลสำเร็จ", "data": result.data}


# ==========================================
# API 8: จัดการฐานข้อมูลอาหาร (Admin เท่านั้น)
# ==========================================
@app.post("/api/admin/foods", status_code=status.HTTP_201_CREATED)
def add_food(food: FoodRequest, admin_user: dict = Depends(require_admin)):
    try:
        result = supabase.table("foods").insert(food.model_dump()).execute()
    except APIError as e:
        if is_unique_violation(e):
            raise HTTPException(status_code=409, detail="มีเมนูชื่อนี้อยู่แล้ว")
        raise
    return {"message": "เพิ่มเมนูอาหารสำเร็จ", "data": result.data}


@app.delete("/api/admin/foods/{target_food_id}")
def delete_food(target_food_id: int = PathParam(gt=0, le=INT4_MAX), admin_user: dict = Depends(require_admin)):
    try:
        result = supabase.table("foods").delete().eq("food_id", target_food_id).execute()
    except APIError as e:
        if is_foreign_key_violation(e):
            raise HTTPException(status_code=409, detail="ลบไม่ได้: มีผู้ใช้บันทึกเมนูนี้ไว้แล้ว")
        raise

    if not result.data:
        raise HTTPException(status_code=404, detail=f"ไม่พบเมนูอาหารรหัส {target_food_id}")
    return {"message": f"ลบเมนูอาหารรหัส {target_food_id} สำเร็จเรียบร้อย"}
