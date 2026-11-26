import io
import logging
import os
import threading
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Annotated, Literal
from zoneinfo import ZoneInfo

import bcrypt
import jwt
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, HTTPException, Path as PathParam, Query, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from PIL import Image, UnidentifiedImageError
from postgrest.exceptions import APIError
from pydantic import AfterValidator, BaseModel, BeforeValidator, EmailStr, Field
from supabase import Client, create_client
from ultralytics import YOLO

from dashboard import Meal, build_alerts, month_summary, local_day
from exercise import ACTIVITIES, MAX_MINUTES, MIN_MINUTES, activity_list, calories_burned
from food_sync import display_name, missing_classes, model_class_names
from nutrition import (
    KCAL_PER_KG,
    MAX_TARGET_WEEKS,
    allowed_goals,
    calculate_bmi,
    calculate_daily_requirement,
    check_target,
    expected_change_per_week,
    min_target_weeks,
    target_applies,
    target_progress,
    target_weight_range,
)
from validation import (
    INT4_MAX,
    MAX_IMAGE_PIXELS,
    SEARCH_PATTERN,
    USERNAME_MAX_LENGTH,
    USERNAME_MIN_LENGTH,
    USERNAME_PATTERN,
    check_birth_date,
    check_email_length,
    check_password_bytes,
    clean_username,
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

ADMIN_ROLE_ID = 1
USER_ROLE_ID = 2
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
LOCAL_TZ = ZoneInfo("Asia/Bangkok")
MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB

# CORS: แอปมือถือไม่ติด CORS อยู่แล้ว ตั้งไว้สำหรับหน้าเว็บ (เช่น Flutter web)
# ระบุโดเมนใน .env ได้ เช่น CORS_ORIGINS=http://localhost:3000,https://example.com
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

OPENAPI_TAGS = [
    {"name": "บัญชีผู้ใช้", "description": "สมัครสมาชิก เข้าสู่ระบบ แก้ไขบัญชี ออกจากระบบ"},
    {"name": "ข้อมูลส่วนตัว", "description": "ข้อมูลส่วนตัวและแคลอรี่ที่ควรได้รับต่อวัน"},
    {"name": "อาหาร", "description": "รายการอาหาร วิเคราะห์ภาพ และบันทึกการกิน"},
    {"name": "ออกกำลังกาย", "description": "บันทึกการออกกำลังกาย คำนวณแคลอรี่ที่เผาผลาญจากค่า MET"},
    {"name": "แอดมิน", "description": "จัดการบัญชีผู้ใช้และข้อมูลอาหาร (เฉพาะแอดมิน)"},
]

app = FastAPI(title="My Nutrition Secretary API", openapi_tags=OPENAPI_TAGS)

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


def has_column(table: str, column: str) -> bool:
    try:
        supabase.table(table).select(column).limit(1).execute()
        return True
    except APIError:
        return False


# ชื่อไทยของเมนูอยู่ในคอลัมน์ foods.food_name_th (migration 006)
# ถ้ายังไม่ได้รัน ระบบยังทำงานได้ แต่จะแสดงชื่อคลาสแทนชื่อไทย
HAS_FOOD_NAME_TH = has_column("foods", "food_name_th")
if not HAS_FOOD_NAME_TH:
    logger.warning("ยังไม่มีคอลัมน์ foods.food_name_th ให้รัน supabase/migrations/006_food_name_th.sql")
FOOD_FIELDS = "food_name, food_name_th, calories_per_100g" if HAS_FOOD_NAME_TH else "food_name, calories_per_100g"

class ColumnCheck:
    """เช็กว่ามีคอลัมน์แล้วหรือยัง ถ้ายังไม่มีจะเช็กใหม่ทุก 30 วินาที
    (รัน migration ตอนเซิร์ฟเวอร์เปิดอยู่ ก็ใช้ได้เลยโดยไม่ต้องรีสตาร์ต)"""

    RECHECK_SECONDS = 30

    def __init__(self, table: str, column: str, migration: str):
        self.table, self.column, self.migration = table, column, migration
        self._ready = False
        self._checked_at = 0.0
        self._check()
        if not self._ready:
            logger.warning("ยังไม่มีคอลัมน์ %s.%s ให้รัน supabase/migrations/%s", table, column, migration)

    def _check(self) -> None:
        self._checked_at = time.monotonic()
        self._ready = has_column(self.table, self.column)

    def __bool__(self) -> bool:
        if not self._ready and time.monotonic() - self._checked_at >= self.RECHECK_SECONDS:
            self._check()
        return self._ready


# น้ำหนักเป้าหมาย + วันครบกำหนด (migration 007) และน้ำหนักตอนเริ่มตั้งเป้า (migration 008)
HAS_TARGET_WEIGHT = ColumnCheck("user_profiles", "target_weight", "007_target_weight.sql")
HAS_TARGET_PROGRESS = ColumnCheck("user_profiles", "target_start_weight", "008_target_progress.sql")


def sync_foods_with_model() -> list[str]:
    """สร้างแถวใน foods ให้คลาสของโมเดลที่ยังไม่มี (ยังไม่มีชื่อไทยและแคลอรี่ ให้แอดมินเติม)"""
    existing = [r["food_name"] for r in supabase.table("foods").select("food_name").execute().data]
    added = missing_classes(model_class_names(model.names), existing)
    if added:
        supabase.table("foods").insert([{"food_name": name} for name in added]).execute()
    return added


try:
    _added = sync_foods_with_model()
    if _added:
        logger.warning("เพิ่มเมนูจากโมเดล %d เมนู (ยังไม่มีชื่อไทย/แคลอรี่): %s", len(_added), ", ".join(_added))
except APIError:
    logger.warning("ซิงก์เมนูจากโมเดลไม่ได้ ตรวจสอบว่ารัน supabase/migrations/006_food_name_th.sql แล้ว")

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
    if current_user["role_id"] != ADMIN_ROLE_ID:
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


def _check_birth_date(value: date) -> date:
    return check_birth_date(value, today_local())


# ชนิดข้อมูลที่ใช้ซ้ำหลายที่ กฎของแต่ละช่องอยู่ที่นี่ที่เดียว
Username = Annotated[
    str,
    BeforeValidator(clean_username),
    Field(min_length=USERNAME_MIN_LENGTH, max_length=USERNAME_MAX_LENGTH, pattern=USERNAME_PATTERN),
]
Email = Annotated[EmailStr, AfterValidator(check_email_length)]
NewPassword = Annotated[str, Field(min_length=8, max_length=72), AfterValidator(check_password_bytes)]
LoginPassword = Annotated[str, Field(max_length=128)]
RoleId = Literal[1, 2]  # 1 = แอดมิน, 2 = ผู้ใช้ทั่วไป
Gender = Literal["male", "female"]
Goal = Literal["lose", "maintain", "gain"]
BirthDate = Annotated[date, AfterValidator(_check_birth_date)]  # อายุ 13-100 ปี
# ปัดทศนิยม 2 ตำแหน่งก่อนตรวจช่วง ให้ตรงกับคอลัมน์ numeric(x, 2)
Weight = Annotated[float, BeforeValidator(round_2), Field(ge=20, le=300)]    # kg
Height = Annotated[float, BeforeValidator(round_2), Field(ge=100, le=250)]   # cm
ActivityLevel = Annotated[int, Field(ge=1, le=5)]
TargetWeeks = Annotated[int, Field(ge=1, le=MAX_TARGET_WEEKS)]  # จะถึงน้ำหนักเป้าหมายภายในกี่สัปดาห์
FoodName = Annotated[str, Field(min_length=1, max_length=100)]
FoodNameTh = Annotated[str, BeforeValidator(lambda v: v.strip() if isinstance(v, str) else v),
                       Field(min_length=1, max_length=100)]
Calories = Annotated[float, BeforeValidator(round_2), Field(ge=0, le=900)]  # kcal ต่อ 100 กรัม (ไขมันล้วน = 900)
DbId = Annotated[int, Field(gt=0, le=INT4_MAX)]
FoodWeight = Annotated[float, BeforeValidator(round_2), Field(gt=0, le=2000)]  # กรัม ต่อ 1 มื้อ
MealType = Literal["breakfast", "lunch", "dinner", "snack"]


class UserRegister(BaseModel):
    username: Username
    email: Email
    password: NewPassword


class UserLogin(BaseModel):
    email: EmailStr
    password: LoginPassword


class ProfileUpdate(BaseModel):
    """ส่งเฉพาะฟิลด์ที่ต้องการแก้ (แต่ละหน้าจอ onboarding ส่งเฉพาะของหน้านั้นได้)"""
    gender: Gender | None = None
    birth_date: BirthDate | None = None
    weight: Weight | None = None
    height: Height | None = None
    activity_level: ActivityLevel | None = None
    goal: Goal | None = None
    target_weight: Weight | None = None   # น้ำหนักเป้าหมาย (ส่งคู่กับ target_weeks)
    target_weeks: TargetWeeks | None = None
    clear_target: bool | None = None      # true = ยกเลิกน้ำหนักเป้าหมาย


class RequirementPreview(BaseModel):
    gender: Gender
    birth_date: BirthDate
    weight: Weight
    height: Height
    activity_level: ActivityLevel
    goal: Goal
    target_weight: Weight | None = None
    target_weeks: TargetWeeks | None = None
    keep_target: bool | None = None       # true = ใช้น้ำหนักเป้าหมายและวันครบกำหนดที่บันทึกไว้ (ผู้ใช้ไม่ได้แก้)


class AccountUpdate(BaseModel):
    username: Username | None = None
    current_password: LoginPassword | None = None
    new_password: NewPassword | None = None


class FoodLogRequest(BaseModel):
    food_id: DbId
    meal_type: MealType
    weight: FoodWeight = 300                      # กรัม
    is_manual_weight: bool = False                # true = ผู้ใช้แก้น้ำหนักเอง


class WeightLogRequest(BaseModel):
    weight: Weight


ActivityKey = Literal[tuple(ACTIVITIES)]


class ExerciseLogRequest(BaseModel):
    activity: ActivityKey                                              # คีย์จาก GET /api/exercise/activities
    minutes: Annotated[int, Field(ge=MIN_MINUTES, le=MAX_MINUTES)]     # ระยะเวลา (นาที)


class FoodRequest(BaseModel):
    food_name: FoodName
    food_name_th: FoodNameTh | None = None
    calories_per_100g: Calories


class FoodUpdate(BaseModel):
    """แก้ไขเมนู: ส่งเฉพาะฟิลด์ที่ต้องการแก้"""
    food_name: FoodName | None = None
    food_name_th: FoodNameTh | None = None
    calories_per_100g: Calories | None = None


class AdminUserCreate(UserRegister):
    role_id: RoleId = USER_ROLE_ID


class AdminUserUpdate(BaseModel):
    """แอดมินแก้ไขบัญชี: ส่งเฉพาะฟิลด์ที่ต้องการแก้"""
    username: Username | None = None
    email: Email | None = None
    role_id: RoleId | None = None
    new_password: NewPassword | None = None


# ค่าค้นหาในรายการ: ตัวอักษร (รวมภาษาไทย) ตัวเลข _ @ . - ไม่มีเว้นวรรค (กันอักขระพิเศษของตัวกรอง PostgREST)
SearchQuery = Query(default=None, max_length=100, pattern=SEARCH_PATTERN)
LimitQuery = Query(default=20, ge=1, le=100)
OffsetQuery = Query(default=0, ge=0, le=1_000_000)


# ==========================================
# รูปแบบผลลัพธ์: ทุก API ตอบ {success, message, data} เหมือนกัน
# (error ตอบ {detail} ตามมาตรฐาน FastAPI)
# ==========================================
def ok(message: str, data=None, **extra) -> dict:
    return {"success": True, "message": message, "data": data, **extra}


def fetch_page(query, limit: int, offset: int) -> dict:
    """ดึงข้อมูลทีละหน้า ถ้าขอหน้าที่เกินจำนวนข้อมูล ให้ได้รายการว่างแทน error"""
    try:
        result = query.range(offset, offset + limit - 1).execute()
    except APIError as e:
        if getattr(e, "code", None) != "PGRST103":  # Requested range not satisfiable
            raise
        return {"data": [], "total": None, "limit": limit, "offset": offset}
    return {"data": result.data, "total": result.count or 0, "limit": limit, "offset": offset}


# ==========================================
# API 1: สมัครสมาชิก (Register)
# ==========================================
def ensure_email_and_username_free(email: str | None, username: str | None, exclude_user_id: int | None = None):
    """เช็กว่าอีเมล/ชื่อผู้ใช้ยังไม่มีคนอื่นใช้ (exclude_user_id = ตัวเอง ตอนแก้ไขบัญชี)"""
    for column, value, message in (
        ("email", email, "อีเมลนี้ถูกใช้งานแล้ว"),
        ("username", username, "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"),
    ):
        if value is None:
            continue
        rows = supabase.table("users").select("user_id").eq(column, value).execute().data
        if any(row["user_id"] != exclude_user_id for row in rows):
            raise HTTPException(status_code=409, detail=message)


def create_user(username: str, email: str, password: str, role_id: int = USER_ROLE_ID) -> dict:
    """สร้างบัญชี + โปรไฟล์ว่าง ใช้ร่วมกันระหว่างสมัครสมาชิกและแอดมินเพิ่มบัญชี"""
    email = email.lower()
    ensure_email_and_username_free(email, username)

    new_user = {
        "username": username,
        "email": email,
        "password_hash": hash_password(password),
        "role_id": role_id,
    }
    try:
        response = supabase.table("users").insert(new_user).execute()
    except APIError as e:
        # กันกรณีสมัครพร้อมกันสองเครื่องด้วยอีเมล/ชื่อเดียวกัน
        if is_unique_violation(e):
            raise HTTPException(status_code=409, detail="อีเมลหรือชื่อผู้ใช้นี้ถูกใช้งานแล้ว")
        raise

    created = response.data[0]
    supabase.table("user_profiles").insert({"user_id": created["user_id"]}).execute()
    return created


@app.post("/api/register", tags=["บัญชีผู้ใช้"], status_code=status.HTTP_201_CREATED)
def register(user: UserRegister):
    created = create_user(user.username, user.email, user.password)
    return ok("สมัครสมาชิกสำเร็จ", {"user_id": created["user_id"]})


# ==========================================
# API 2: เข้าสู่ระบบ (Login & ออก JWT Token)
# ==========================================
def authenticate(email: str, password: str) -> dict:
    response = supabase.table("users").select("*").eq("email", email.lower()).execute()
    if not response.data or not verify_password(password, response.data[0]["password_hash"]):
        raise HTTPException(status_code=401, detail="อีเมลหรือรหัสผ่านไม่ถูกต้อง")
    return response.data[0]


def login_response(db_user: dict) -> dict:
    return ok("เข้าสู่ระบบสำเร็จ", {
        "access_token": create_access_token(db_user),
        "token_type": "bearer",
        "role_id": db_user["role_id"],
        "username": db_user["username"],
    })


@app.post("/api/login", tags=["บัญชีผู้ใช้"])
def login(user: UserLogin):
    return login_response(authenticate(user.email, user.password))


@app.post("/api/admin/login", tags=["แอดมิน"])
def admin_login(user: UserLogin):
    """เข้าสู่ระบบหน้าจัดการ: รับเฉพาะบัญชีแอดมิน"""
    db_user = authenticate(user.email, user.password)
    if db_user["role_id"] != ADMIN_ROLE_ID:
        raise HTTPException(status_code=403, detail="บัญชีนี้ไม่มีสิทธิ์ผู้ดูแลระบบ")
    return login_response(db_user)


# ==========================================
# API 3: ข้อมูลผู้ใช้ปัจจุบัน / Admin
# ==========================================
@app.get("/api/me", tags=["บัญชีผู้ใช้"])
def read_users_me(current_user: dict = Depends(get_current_user)):
    return ok("ยืนยันตัวตนสำเร็จ", {
        "user": public_user(current_user),
        "profile": with_completeness(get_or_create_profile(current_user["user_id"])),
    })


def count_rows(table: str, column: str, **filters) -> int:
    query = supabase.table(table).select(column, count="exact")
    for key, value in filters.items():
        query = query.eq(key, value)
    return query.limit(1).execute().count or 0


@app.get("/api/admin/dashboard", tags=["แอดมิน"])
def admin_only_route(admin_user: dict = Depends(require_admin)):
    return ok("ยินดีต้อนรับผู้ดูแลระบบ (Admin)", {
        "admin": public_user(admin_user),
        "stats": {
            "total_users": count_rows("users", "user_id"),
            "total_admins": count_rows("users", "user_id", role_id=ADMIN_ROLE_ID),
            "total_foods": count_rows("foods", "food_id"),
        },
    })


# ==========================================
# API 4: ข้อมูลส่วนตัว & เป้าหมายโภชนาการ
# ==========================================
PROFILE_INPUT_FIELDS = ("gender", "birth_date", "weight", "height", "activity_level", "goal")


GOAL_NAMES_TH = {"lose": "ลดน้ำหนัก", "maintain": "คงน้ำหนัก", "gain": "เพิ่มน้ำหนัก"}


def body_info(weight, height, requirement=None) -> dict:
    """BMI, เป้าหมายที่เลือกได้ และน้ำหนักที่คาดว่าจะเปลี่ยน (ให้แอปปิดปุ่มที่เลือกไม่ได้)
    requirement = ผลจาก calculate_daily_requirement (ไม่มี = ข้อมูลยังไม่ครบ ไม่คำนวณน้ำหนักที่จะเปลี่ยน)"""
    info = {"bmi": None, "allowed_goals": list(GOAL_NAMES_TH),
            "expected_kg_per_week": None, "expected_kg_per_month": None,
            "target_min_weight": None, "target_max_weight": None}
    if weight is not None and height is not None:
        info["bmi"] = calculate_bmi(float(weight), float(height))
        info["allowed_goals"] = allowed_goals(float(weight), float(height))
        info["target_min_weight"], info["target_max_weight"] = target_weight_range(float(height))
    if requirement is not None:
        per_week = expected_change_per_week(requirement.daily_calories, requirement.tdee)
        info["expected_kg_per_week"] = per_week
        # คิดรายเดือนจากค่าก่อนปัด จะได้ไม่คลาดจากการปัดรายสัปดาห์
        per_day = (requirement.daily_calories - requirement.tdee) / KCAL_PER_KG
        info["expected_kg_per_month"] = round(per_day * 30, 2)
    return info


def target_days_left(profile: dict, today: date) -> int | None:
    """จำนวนวันที่เหลือถึงวันเป้าหมาย (ไม่ได้ตั้งเป้า = None)"""
    if not profile.get("target_date"):
        return None
    return (date.fromisoformat(str(profile["target_date"])) - today).days


def requirement_of(profile: dict):
    """คำนวณเป้าแคลอรี่จากข้อมูลในโปรไฟล์ (ข้อมูลไม่ครบ = None)
    ถ้าตั้งน้ำหนักเป้าหมายไว้ คิดจากน้ำหนักที่ต้องเปลี่ยนหารด้วยจำนวนวันที่เหลือ"""
    if not all(profile.get(f) is not None for f in PROFILE_INPUT_FIELDS):
        return None
    today = today_local()
    target = profile.get("target_weight")
    return calculate_daily_requirement(
        gender=profile["gender"],
        birth_date=date.fromisoformat(str(profile["birth_date"])),
        weight=float(profile["weight"]),
        height=float(profile["height"]),
        activity_level=int(profile["activity_level"]),
        goal=profile["goal"],
        today=today,
        target_weight=None if target is None else float(target),
        target_days=target_days_left(profile, today),
    )


def check_target_or_422(weight, height, goal, target_weight, target_weeks) -> None:
    if target_weight is None and target_weeks is None:
        return
    if target_weight is None or target_weeks is None:
        raise HTTPException(status_code=422, detail="ตั้งน้ำหนักเป้าหมายต้องใส่ทั้งน้ำหนักและจำนวนสัปดาห์")
    if not HAS_TARGET_WEIGHT:
        raise HTTPException(status_code=503, detail="ยังตั้งน้ำหนักเป้าหมายไม่ได้ ให้รัน supabase/migrations/007_target_weight.sql")
    if weight is None or height is None or goal is None:
        raise HTTPException(status_code=422, detail="กรอกน้ำหนัก ส่วนสูง และเป้าหมายก่อนตั้งน้ำหนักเป้าหมาย")
    problem = check_target(float(weight), float(height), goal, float(target_weight), int(target_weeks))
    if problem:
        raise HTTPException(status_code=422, detail=problem)


def target_info(profile: dict) -> dict:
    """ข้อมูลน้ำหนักเป้าหมายสำหรับแอป: จำนวนวันที่เหลือ ยังใช้คำนวณอยู่ไหม และความคืบหน้า"""
    today = today_local()
    days = target_days_left(profile, today)
    weight = profile.get("weight")
    target = profile.get("target_weight")
    active = weight is not None and target_applies(
        profile.get("goal") or "", float(weight), None if target is None else float(target), days)
    progress = None
    start, set_at = profile.get("target_start_weight"), profile.get("target_set_at")
    if weight is not None and target is not None and start is not None and set_at and days is not None:
        progress = target_progress(
            float(start), float(weight), float(target),
            date.fromisoformat(str(set_at)), date.fromisoformat(str(profile["target_date"])), today)
    return {"target_days_left": days, "target_active": active, "target_progress": progress}


def check_goal_allowed(weight, height, goal) -> None:
    if weight is None or height is None or goal is None:
        return
    allowed = allowed_goals(float(weight), float(height))
    if goal not in allowed:
        bmi = calculate_bmi(float(weight), float(height))
        choices = " หรือ ".join(GOAL_NAMES_TH[g] for g in allowed)
        raise HTTPException(
            status_code=422,
            detail=f"BMI {bmi:.1f} เลือก{GOAL_NAMES_TH[goal]}ไม่ได้ กรุณาเลือก{choices}",
        )


def current_goal(profile: dict, requirement=None) -> float | None:
    """เป้าแคลต่อวันของวันนี้: คำนวณใหม่ทุกครั้ง (ตั้งน้ำหนักเป้าหมายไว้ ค่าจะเปลี่ยนตามจำนวนวันที่เหลือ
    และเลยวันครบกำหนดแล้วกลับไปใช้ค่าปกติ) ข้อมูลไม่ครบใช้ค่าที่บันทึกไว้"""
    requirement = requirement or requirement_of(profile)
    if requirement is not None:
        return requirement.daily_calories
    return float(profile["daily_calories"]) if profile.get("daily_calories") is not None else None


def with_completeness(profile: dict) -> dict:
    """เพิ่ม is_complete = กรอกข้อมูลส่วนตัวครบทั้ง 6 ช่องหรือยัง พร้อม BMI และเป้าหมายที่เลือกได้"""
    requirement = requirement_of(profile)
    return {
        **profile,
        "daily_calories": current_goal(profile, requirement),
        "is_complete": all(profile.get(f) is not None for f in PROFILE_INPUT_FIELDS),
        **body_info(profile.get("weight"), profile.get("height"), requirement),
        **target_info(profile),
    }


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


@app.get("/api/profile", tags=["ข้อมูลส่วนตัว"])
def get_profile(current_user: dict = Depends(get_current_user)):
    return ok("ดึงข้อมูลสำเร็จ", with_completeness(get_or_create_profile(current_user["user_id"])))


@app.put("/api/profile", tags=["ข้อมูลส่วนตัว"])
def update_profile(update: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    current = get_or_create_profile(user_id)

    changes = update.model_dump(mode="json", exclude_none=True)
    target_weeks = changes.pop("target_weeks", None)
    clear_target = changes.pop("clear_target", None) is True
    merged = {**{f: current.get(f) for f in PROFILE_INPUT_FIELDS}, **changes}
    # เช็กเฉพาะตอนเลือกเป้าหมายใหม่ (บันทึกน้ำหนักอย่างเดียวไม่ถูกบล็อก)
    if "goal" in changes:
        check_goal_allowed(merged["weight"], merged["height"], merged["goal"])
    check_target_or_422(merged["weight"], merged["height"], merged["goal"],
                        changes.get("target_weight"), target_weeks)
    if target_weeks is not None:
        changes["target_date"] = (today_local() + timedelta(days=7 * target_weeks)).isoformat()
        if HAS_TARGET_PROGRESS:
            # จำน้ำหนักตอนเริ่มตั้งเป้า ไว้คำนวณว่าลด/เพิ่มไปแล้วเท่าไร
            changes["target_start_weight"] = float(merged["weight"])
            changes["target_set_at"] = today_local().isoformat()
    elif HAS_TARGET_WEIGHT and current.get("target_weight") is not None and (
            clear_target or changes.get("goal", current.get("goal")) != current.get("goal")):
        # ยกเลิกเอง หรือเปลี่ยนเป้าหมาย (เช่น ลด -> รักษา) = ล้างน้ำหนักเป้าหมายเดิม
        changes["target_weight"] = None
        changes["target_date"] = None
        if HAS_TARGET_PROGRESS:
            changes["target_start_weight"] = None
            changes["target_set_at"] = None
    for f in ("target_weight", "target_date"):
        merged[f] = changes[f] if f in changes else current.get(f)

    if all(merged[f] is not None for f in PROFILE_INPUT_FIELDS):
        requirement = requirement_of(merged)
        changes.update({
            "daily_calories": requirement.daily_calories,
            "calculated_at": datetime.now(timezone.utc).isoformat(),
        })

    if not changes:
        raise HTTPException(status_code=400, detail="ไม่มีข้อมูลที่ต้องการแก้ไข")

    result = supabase.table("user_profiles").update(changes).eq("user_id", user_id).execute()
    if "weight" in changes and _as_float(changes["weight"]) != _as_float(current.get("weight")):
        supabase.table("weight_logs").insert({"user_id": user_id, "weight": changes["weight"]}).execute()
    return ok("บันทึกข้อมูลส่วนตัวสำเร็จ", with_completeness(result.data[0]))


def _as_float(value) -> float | None:
    return None if value is None else round(float(value), 2)


@app.post("/api/profile/preview", tags=["ข้อมูลส่วนตัว"])
def preview_requirement(data: RequirementPreview, current_user: dict = Depends(get_current_user)):
    """คำนวณเป้าหมายให้ดูก่อน ยังไม่บันทึก"""
    check_goal_allowed(data.weight, data.height, data.goal)
    check_target_or_422(data.weight, data.height, data.goal, data.target_weight, data.target_weeks)
    fields = data.model_dump(exclude={"target_weight", "target_weeks", "keep_target"})
    today = today_local()
    target, days, target_date = None, None, None
    if data.target_weight is not None and data.target_weeks is not None:
        target, days = data.target_weight, 7 * data.target_weeks
        target_date = today + timedelta(days=days)
    elif data.keep_target:
        # ไม่ได้แก้น้ำหนักเป้าหมาย: คิดจากค่าที่บันทึกไว้ วันครบกำหนดจะตรงกับตอนบันทึกจริง
        saved = get_or_create_profile(current_user["user_id"])
        if saved.get("target_weight") is not None and saved.get("target_date"):
            target = float(saved["target_weight"])
            target_date = date.fromisoformat(str(saved["target_date"]))
            days = (target_date - today).days
    requirement = calculate_daily_requirement(**fields, today=today, target_weight=target, target_days=days)
    extra = {}
    if target is not None and target_applies(data.goal, data.weight, target, days):
        extra = {"target_date": target_date.isoformat(),
                 "target_min_weeks": min_target_weeks(data.weight, target)}
    return ok("คำนวณสำเร็จ", {**requirement.__dict__, **body_info(data.weight, data.height, requirement), **extra})


# ==========================================
# API 5: แก้ไขบัญชีผู้ใช้ (username / รหัสผ่าน)
# ==========================================
@app.put("/api/account", tags=["บัญชีผู้ใช้"])
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
            raise HTTPException(status_code=409, detail="ชื่อผู้ใช้นี้ถูกใช้งานแล้ว")
        raise

    data = {"username": updated_user["username"]}
    if "password_hash" in changes:
        # ส่ง token ใหม่กลับไป เครื่องที่กำลังใช้งานจะได้ไม่ต้องล็อกอินใหม่
        data["access_token"] = create_access_token(updated_user)
        data["token_type"] = "bearer"
    return ok("แก้ไขบัญชีสำเร็จ", data)


# ==========================================
# API 5.1: ออกจากระบบ (Logout)
# ==========================================
@app.post("/api/logout", tags=["บัญชีผู้ใช้"])
def logout(current_user: dict = Depends(get_current_user)):
    """ทำให้ token ทั้งหมดของผู้ใช้นี้ใช้ไม่ได้ (ออกจากระบบทุกเครื่อง)
    แอปต้องลบ token ที่เก็บไว้ในเครื่องด้วย"""
    bump_token_version(current_user)
    return ok("ออกจากระบบสำเร็จ")


# ==========================================
# API 6: วิเคราะห์ภาพอาหาร
# ==========================================
@app.post("/api/analyze", tags=["อาหาร"])
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

    # 0 kcal = แอดมินยังไม่ได้ใส่ค่าจริง (ไม่มีจานข้าวไหน 0 kcal) ถือว่ายังไม่มีข้อมูล
    has_calories = bool(food) and float(food.get("calories_per_100g") or 0) > 0
    return ok(
        "วิเคราะห์สำเร็จ" if has_calories else "วิเคราะห์สำเร็จ แต่ไม่พบข้อมูลแคลอรี่ของเมนูนี้ในฐานข้อมูล",
        {
            "food_name": predicted_class_name,
            "food_name_th": (food or {}).get("food_name_th"),
            "confidence": round(confidence_score, 4),
            "food_id": food["food_id"] if food else None,
            "calories_per_100g": food["calories_per_100g"] if food else None,
        },
    )


# ==========================================
# API 7: บันทึกมื้ออาหาร (ตาราง saved_menu ตามรายงาน ตารางที่ 40)
# ==========================================
MEAL_SELECT = (
    "log_id:saved_menu_id, meal_type, logged_at:saved_at, estimated_weight, is_manual_weight, "
    f"total_calories, food_id, foods({FOOD_FIELDS})"
)
MAX_LOG_RANGE_DAYS = 92


def utc_bounds(first_day: date, last_day: date) -> tuple[str, str]:
    """00:00 ของวันแรก ถึง 24:00 ของวันสุดท้าย ตามเวลาไทย แปลงเป็น UTC (ลงท้าย Z เลี่ยงปัญหา + ใน URL)"""
    start = datetime.combine(first_day, datetime.min.time(), LOCAL_TZ)
    end = datetime.combine(last_day + timedelta(days=1), datetime.min.time(), LOCAL_TZ)
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    return start.astimezone(timezone.utc).strftime(fmt), end.astimezone(timezone.utc).strftime(fmt)


def fetch_meals(user_id: int, first_day: date, last_day: date) -> list[dict]:
    start, end = utc_bounds(first_day, last_day)
    return supabase.table("saved_menu").select(MEAL_SELECT) \
        .eq("user_id", user_id) \
        .gte("saved_at", start) \
        .lt("saved_at", end) \
        .order("saved_at") \
        .execute().data


def to_meals(rows: list[dict]) -> list[Meal]:
    return [
        Meal(
            eaten_at=datetime.fromisoformat(str(r["logged_at"]).replace("Z", "+00:00")),
            meal_type=r["meal_type"],
            food_name=(r.get("foods") or {}).get("food_name") or "unknown",
            food_name_th=display_name(r.get("foods")),
            calories=float(r["total_calories"] or 0),
        )
        for r in rows
    ]


@app.post("/api/logs", tags=["อาหาร"], status_code=status.HTTP_201_CREATED)
def create_food_log(log: FoodLogRequest, current_user: dict = Depends(get_current_user)):
    rows = supabase.table("foods").select("food_id, calories_per_100g").eq("food_id", log.food_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="ไม่พบเมนูอาหารนี้")

    if float(rows[0]["calories_per_100g"] or 0) <= 0:
        raise HTTPException(status_code=409, detail="เมนูนี้ยังไม่มีข้อมูลแคลอรี่ ให้แอดมินเติมก่อน")
    per_100g = float(rows[0]["calories_per_100g"])
    data = {
        "user_id": current_user["user_id"],
        "food_id": log.food_id,
        "meal_type": log.meal_type,
        "estimated_weight": log.weight,
        "is_manual_weight": log.is_manual_weight,
        "total_calories": round(per_100g * log.weight / 100, 2),
    }
    saved = supabase.table("saved_menu").insert(data).execute().data[0]
    result = supabase.table("saved_menu").select(MEAL_SELECT).eq("saved_menu_id", saved["saved_menu_id"]).execute()
    return ok("บันทึกมื้ออาหารสำเร็จ", result.data[0])


@app.get("/api/logs/today", tags=["อาหาร"])
def get_today_logs(current_user: dict = Depends(get_current_user)):
    today = today_local()
    return ok("ดึงข้อมูลสำเร็จ", fetch_meals(current_user["user_id"], today, today))


@app.get("/api/logs", tags=["อาหาร"])
def get_logs(
    start: date = Query(..., description="วันแรก (YYYY-MM-DD) ตามเวลาไทย"),
    end: date = Query(..., description="วันสุดท้าย (YYYY-MM-DD) ตามเวลาไทย"),
    current_user: dict = Depends(get_current_user),
):
    if end < start:
        raise HTTPException(status_code=422, detail="วันสุดท้ายต้องไม่อยู่ก่อนวันแรก")
    if (end - start).days + 1 > MAX_LOG_RANGE_DAYS:
        raise HTTPException(status_code=422, detail=f"ดึงได้ครั้งละไม่เกิน {MAX_LOG_RANGE_DAYS} วัน")
    return ok("ดึงข้อมูลสำเร็จ", fetch_meals(current_user["user_id"], start, end))


@app.delete("/api/logs/{log_id}", tags=["อาหาร"])
def delete_log(log_id: int = PathParam(gt=0, le=INT4_MAX), current_user: dict = Depends(get_current_user)):
    result = supabase.table("saved_menu").delete() \
        .eq("saved_menu_id", log_id) \
        .eq("user_id", current_user["user_id"]) \
        .execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="ไม่พบมื้ออาหารนี้")
    return ok("ลบมื้ออาหารสำเร็จ")


# ==========================================
# API 7.2: ออกกำลังกาย (แคลอรี่ที่เผาผลาญ = MET x น้ำหนัก x ชั่วโมง)
# ==========================================
EXERCISE_SELECT = "exercise_log_id, activity, met, duration_minutes, weight_kg, calories_burned, logged_at"


def fetch_exercises(user_id: int, first_day: date, last_day: date) -> list[dict]:
    start, end = utc_bounds(first_day, last_day)
    return supabase.table("exercise_logs").select(EXERCISE_SELECT) \
        .eq("user_id", user_id) \
        .gte("logged_at", start) \
        .lt("logged_at", end) \
        .order("logged_at") \
        .execute().data


def burned_by_day(rows: list[dict]) -> dict[date, float]:
    totals: dict[date, float] = {}
    for r in rows:
        day = local_day(datetime.fromisoformat(str(r["logged_at"]).replace("Z", "+00:00")), LOCAL_TZ)
        totals[day] = totals.get(day, 0.0) + float(r["calories_burned"] or 0)
    return totals


def with_activity_name(row: dict) -> dict:
    activity = ACTIVITIES.get(row["activity"])
    return {**row, "name_th": activity.name_th if activity else row["activity"]}


@app.get("/api/exercise/activities", tags=["ออกกำลังกาย"])
def list_activities(current_user: dict = Depends(get_current_user)):
    """กิจกรรมที่เลือกได้ พร้อมค่า MET (2024 Adult Compendium of Physical Activities)"""
    return ok("ดึงข้อมูลสำเร็จ", activity_list())


@app.post("/api/exercise", tags=["ออกกำลังกาย"], status_code=status.HTTP_201_CREATED)
def create_exercise_log(entry: ExerciseLogRequest, current_user: dict = Depends(get_current_user)):
    profile = get_or_create_profile(current_user["user_id"])
    if profile.get("weight") is None:
        raise HTTPException(status_code=400, detail="กรุณากรอกน้ำหนักตัวในข้อมูลส่วนตัวก่อน")
    weight = float(profile["weight"])
    activity = ACTIVITIES[entry.activity]
    data = {
        "user_id": current_user["user_id"],
        "activity": activity.key,
        "met": activity.met,
        "duration_minutes": entry.minutes,
        "weight_kg": weight,
        "calories_burned": calories_burned(activity.met, weight, entry.minutes),
    }
    saved = supabase.table("exercise_logs").insert(data).execute().data[0]
    return ok("บันทึกการออกกำลังกายสำเร็จ", with_activity_name(saved))


@app.get("/api/exercise/today", tags=["ออกกำลังกาย"])
def get_today_exercises(current_user: dict = Depends(get_current_user)):
    today = today_local()
    rows = [with_activity_name(r) for r in fetch_exercises(current_user["user_id"], today, today)]
    total = round(sum(float(r["calories_burned"] or 0) for r in rows), 2)
    return ok("ดึงข้อมูลสำเร็จ", {"items": rows, "total_burned": total})


@app.delete("/api/exercise/{exercise_log_id}", tags=["ออกกำลังกาย"])
def delete_exercise(
    exercise_log_id: int = PathParam(gt=0, le=INT4_MAX),
    current_user: dict = Depends(get_current_user),
):
    result = supabase.table("exercise_logs").delete() \
        .eq("exercise_log_id", exercise_log_id) \
        .eq("user_id", current_user["user_id"]) \
        .execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="ไม่พบรายการออกกำลังกายนี้")
    return ok("ลบรายการออกกำลังกายสำเร็จ")


# ==========================================
# API 7.1: Dashboard (สรุปรายเดือน, การแจ้งเตือน) และน้ำหนักย้อนหลัง
# ==========================================
def requirement_for(profile: dict):
    return requirement_of(profile)


def fetch_weights(user_id: int, since: date) -> list[dict]:
    start, _ = utc_bounds(since, since)
    return supabase.table("weight_logs").select("weight_log_id, weight, logged_at") \
        .eq("user_id", user_id) \
        .gte("logged_at", start) \
        .order("logged_at") \
        .execute().data


@app.get("/api/dashboard/summary", tags=["อาหาร"])
def dashboard_summary(
    month: str = Query(..., pattern=r"^\d{4}-(0[1-9]|1[0-2])$", description="เดือน YYYY-MM"),
    current_user: dict = Depends(get_current_user),
):
    year, mon = int(month[:4]), int(month[5:])
    first = date(year, mon, 1)
    last = (date(year + (mon == 12), mon % 12 + 1, 1) - timedelta(days=1))
    profile = get_or_create_profile(current_user["user_id"])
    goal = current_goal(profile)
    rows = fetch_meals(current_user["user_id"], first, last)
    try:
        burned = burned_by_day(fetch_exercises(current_user["user_id"], first, last))
    except APIError:
        burned = {}
    return ok("ดึงข้อมูลสำเร็จ",
              month_summary(to_meals(rows), goal, year, mon, today_local(), LOCAL_TZ, burned))


@app.get("/api/dashboard/alerts", tags=["อาหาร"])
def dashboard_alerts(current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    today = today_local()
    profile = get_or_create_profile(user_id)
    requirement = requirement_for(profile)
    goal = current_goal(profile, requirement)
    meals = to_meals(fetch_meals(user_id, today - timedelta(days=7), today))
    try:
        burned = burned_by_day(fetch_exercises(user_id, today - timedelta(days=7), today))
    except APIError:
        # ยังไม่ได้รัน migration 005 (ไม่มีตาราง exercise_logs) ก็ยังแสดงการแจ้งเตือนได้
        logger.warning("อ่าน exercise_logs ไม่ได้ ตรวจสอบว่ารัน supabase/migrations/005_exercise_logs.sql แล้ว")
        burned = {}
    weights = [
        (datetime.fromisoformat(str(w["logged_at"]).replace("Z", "+00:00")), float(w["weight"]))
        for w in fetch_weights(user_id, today - timedelta(days=28))
    ]
    data = build_alerts(
        meals, weights, goal,
        requirement.bmr if requirement else None,
        profile.get("gender"), profile.get("goal"), today, LOCAL_TZ, burned,
    )
    return ok("ดึงข้อมูลสำเร็จ", data)


@app.post("/api/weight", tags=["ข้อมูลส่วนตัว"], status_code=status.HTTP_201_CREATED)
def log_weight(entry: WeightLogRequest, current_user: dict = Depends(get_current_user)):
    """บันทึกน้ำหนักวันนี้ และอัปเดตน้ำหนักในข้อมูลส่วนตัว (คำนวณแคลอรี่ต่อวันใหม่)"""
    user_id = current_user["user_id"]
    before = get_or_create_profile(user_id)
    # update_profile บันทึก weight_logs ให้เมื่อน้ำหนักเปลี่ยน
    profile = update_profile(ProfileUpdate(weight=entry.weight), current_user)["data"]
    if _as_float(before.get("weight")) == _as_float(entry.weight):
        # น้ำหนักเท่าเดิม ก็ยังเก็บเป็นจุดใหม่ในกราฟ
        supabase.table("weight_logs").insert({"user_id": user_id, "weight": entry.weight}).execute()
    return ok("บันทึกน้ำหนักสำเร็จ", profile)


@app.get("/api/weight/history", tags=["ข้อมูลส่วนตัว"])
def weight_history(
    days: int = Query(default=90, ge=1, le=366),
    current_user: dict = Depends(get_current_user),
):
    since = today_local() - timedelta(days=days)
    return ok("ดึงข้อมูลสำเร็จ", fetch_weights(current_user["user_id"], since))


# ==========================================
# API 8: จัดการฐานข้อมูลอาหาร (Admin เท่านั้น)
# ==========================================
@app.post("/api/admin/foods", tags=["แอดมิน"], status_code=status.HTTP_201_CREATED)
def add_food(food: FoodRequest, admin_user: dict = Depends(require_admin)):
    try:
        data = food.model_dump(exclude_none=True)
        if not HAS_FOOD_NAME_TH:
            data.pop("food_name_th", None)
        result = supabase.table("foods").insert(data).execute()
    except APIError as e:
        if is_unique_violation(e):
            raise HTTPException(status_code=409, detail="มีเมนูชื่อนี้อยู่แล้ว")
        raise
    return ok("เพิ่มเมนูอาหารสำเร็จ", result.data[0])


@app.post("/api/admin/foods/sync", tags=["แอดมิน"])
def sync_foods(admin_user: dict = Depends(require_admin)):
    """ดึงชื่อคลาสจากโมเดล แล้วสร้างแถวให้เมนูที่ยังไม่มี (ตอนเปิดเซิร์ฟเวอร์ทำให้อัตโนมัติอยู่แล้ว)"""
    try:
        added = sync_foods_with_model()
    except APIError:
        raise HTTPException(status_code=503,
                            detail="ดึงเมนูจากโมเดลไม่ได้ ให้รัน supabase/migrations/006_food_name_th.sql")
    return ok(f"เพิ่มเมนูจากโมเดล {len(added)} เมนู" if added else "เมนูครบตามโมเดลแล้ว", {"added": added})


@app.delete("/api/admin/foods/{target_food_id}", tags=["แอดมิน"])
def delete_food(target_food_id: int = PathParam(gt=0, le=INT4_MAX), admin_user: dict = Depends(require_admin)):
    try:
        result = supabase.table("foods").delete().eq("food_id", target_food_id).execute()
    except APIError as e:
        if is_foreign_key_violation(e):
            raise HTTPException(status_code=409, detail="ลบไม่ได้: มีผู้ใช้บันทึกเมนูนี้ไว้แล้ว")
        raise

    if not result.data:
        raise HTTPException(status_code=404, detail=f"ไม่พบเมนูอาหารรหัส {target_food_id}")
    return ok(f"ลบเมนูอาหารรหัส {target_food_id} สำเร็จ")


@app.put("/api/admin/foods/{target_food_id}", tags=["แอดมิน"])
def update_food(
    update: FoodUpdate,
    target_food_id: int = PathParam(gt=0, le=INT4_MAX),
    admin_user: dict = Depends(require_admin),
):
    changes = update.model_dump(exclude_none=True)
    if not HAS_FOOD_NAME_TH:
        changes.pop("food_name_th", None)   # ยังไม่ได้รัน migration 006
    if not changes:
        raise HTTPException(status_code=400, detail="ไม่มีข้อมูลที่ต้องการแก้ไข")

    try:
        result = supabase.table("foods").update(changes).eq("food_id", target_food_id).execute()
    except APIError as e:
        if is_unique_violation(e):
            raise HTTPException(status_code=409, detail="มีเมนูชื่อนี้อยู่แล้ว")
        raise

    if not result.data:
        raise HTTPException(status_code=404, detail=f"ไม่พบเมนูอาหารรหัส {target_food_id}")
    return ok("แก้ไขเมนูอาหารสำเร็จ", result.data[0])


# ==========================================
# API 9: ดูรายการอาหาร (ผู้ใช้ที่ล็อกอินแล้วทุกคน)
# ==========================================
@app.get("/api/foods", tags=["อาหาร"])
def list_foods(
    q: str | None = SearchQuery,
    limit: int = LimitQuery,
    offset: int = OffsetQuery,
    current_user: dict = Depends(get_current_user),
):
    """ค้นหาจากชื่อเมนู (q) และแบ่งหน้าด้วย limit / offset"""
    query = supabase.table("foods").select("*", count="exact")
    if q:
        # ตัดอักขระที่ใช้แยกเงื่อนไขของ PostgREST ออก กันคำค้นทำให้ตัวกรองพัง
        term = "".join(ch for ch in q if ch not in ",()")
        if HAS_FOOD_NAME_TH:
            query = query.or_(f"food_name.ilike.%{term}%,food_name_th.ilike.%{term}%")
        else:
            query = query.ilike("food_name", f"%{term}%")
    page = fetch_page(query.order("food_name"), limit, offset)
    classes = set(model_class_names(model.names))
    page["data"] = [{**f, "in_model": f["food_name"] in classes} for f in page["data"]]
    return ok("ดึงข้อมูลสำเร็จ", **page)


@app.get("/api/foods/{target_food_id}", tags=["อาหาร"])
def get_food(target_food_id: int = PathParam(gt=0, le=INT4_MAX), current_user: dict = Depends(get_current_user)):
    result = supabase.table("foods").select("*").eq("food_id", target_food_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail=f"ไม่พบเมนูอาหารรหัส {target_food_id}")
    return ok("ดึงข้อมูลสำเร็จ", result.data[0])


# ==========================================
# API 10: จัดการบัญชีผู้ใช้ (Admin เท่านั้น)
# ==========================================
USER_LIST_COLUMNS = "user_id, username, email, role_id, created_at, updated_at"


def get_user_or_404(user_id: int) -> dict:
    result = supabase.table("users").select(USER_LIST_COLUMNS + ", token_version") \
        .eq("user_id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail=f"ไม่พบบัญชีผู้ใช้รหัส {user_id}")
    return result.data[0]


@app.get("/api/admin/users", tags=["แอดมิน"])
def list_users(
    q: str | None = SearchQuery,
    role_id: int | None = Query(default=None, ge=1, le=2),  # ค่าจาก URL เป็นข้อความ จึงใช้ int แทน Literal
    limit: int = LimitQuery,
    offset: int = OffsetQuery,
    admin_user: dict = Depends(require_admin),
):
    """ค้นหาจาก username หรืออีเมล (q), กรองตามสิทธิ์ (role_id) และแบ่งหน้าด้วย limit / offset"""
    query = supabase.table("users").select(USER_LIST_COLUMNS, count="exact")
    if q:
        query = query.or_(f"username.ilike.%{q}%,email.ilike.%{q}%")
    if role_id is not None:
        query = query.eq("role_id", role_id)
    return ok("ดึงข้อมูลสำเร็จ", **fetch_page(query.order("user_id"), limit, offset))


@app.get("/api/admin/users/{target_user_id}", tags=["แอดมิน"])
def get_user(target_user_id: int = PathParam(gt=0, le=INT4_MAX), admin_user: dict = Depends(require_admin)):
    user = public_user(get_user_or_404(target_user_id))
    user["profile"] = with_completeness(get_or_create_profile(target_user_id))
    return ok("ดึงข้อมูลสำเร็จ", user)


@app.post("/api/admin/users", tags=["แอดมิน"], status_code=status.HTTP_201_CREATED)
def admin_create_user(new_user: AdminUserCreate, admin_user: dict = Depends(require_admin)):
    created = create_user(new_user.username, new_user.email, new_user.password, role_id=new_user.role_id)
    return ok("เพิ่มบัญชีผู้ใช้สำเร็จ", public_user(get_user_or_404(created["user_id"])))


@app.put("/api/admin/users/{target_user_id}", tags=["แอดมิน"])
def admin_update_user(
    update: AdminUserUpdate,
    target_user_id: int = PathParam(gt=0, le=INT4_MAX),
    admin_user: dict = Depends(require_admin),
):
    target = get_user_or_404(target_user_id)

    # กันแอดมินลดสิทธิ์ตัวเอง (ถ้าเป็นแอดมินคนเดียว จะไม่มีใครเข้าหน้าจัดการได้อีก)
    if target_user_id == admin_user["user_id"] and update.role_id not in (None, ADMIN_ROLE_ID):
        raise HTTPException(status_code=400, detail="ไม่สามารถลดสิทธิ์บัญชีของตัวเองได้")

    changes = {}
    if update.username is not None and update.username != target["username"]:
        changes["username"] = update.username
    if update.email is not None and update.email.lower() != target["email"]:
        changes["email"] = update.email.lower()
    if update.role_id is not None and update.role_id != target["role_id"]:
        changes["role_id"] = update.role_id
    if update.new_password is not None:
        changes["password_hash"] = hash_password(update.new_password)

    if not changes:
        raise HTTPException(status_code=400, detail="ไม่มีข้อมูลที่ต้องการแก้ไข")

    ensure_email_and_username_free(changes.get("email"), changes.get("username"), exclude_user_id=target_user_id)

    try:
        if "password_hash" in changes:
            # รีเซ็ตรหัสผ่าน: บังคับให้ผู้ใช้คนนั้นออกจากระบบทุกเครื่อง
            updated = bump_token_version(target, changes)
        else:
            updated = supabase.table("users").update(changes).eq("user_id", target_user_id).execute().data[0]
    except APIError as e:
        if is_unique_violation(e):
            raise HTTPException(status_code=409, detail="อีเมลหรือชื่อผู้ใช้นี้ถูกใช้งานแล้ว")
        raise

    data = {k: updated[k] for k in ("user_id", "username", "email", "role_id", "created_at", "updated_at")}
    return ok("แก้ไขบัญชีผู้ใช้สำเร็จ", data)


@app.delete("/api/admin/users/{target_user_id}", tags=["แอดมิน"])
def admin_delete_user(target_user_id: int = PathParam(gt=0, le=INT4_MAX), admin_user: dict = Depends(require_admin)):
    if target_user_id == admin_user["user_id"]:
        raise HTTPException(status_code=400, detail="ไม่สามารถลบบัญชีของตัวเองได้")

    # โปรไฟล์และประวัติการกินของผู้ใช้จะถูกลบตามไปด้วย (on delete cascade)
    result = supabase.table("users").delete().eq("user_id", target_user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail=f"ไม่พบบัญชีผู้ใช้รหัส {target_user_id}")
    return ok(f"ลบบัญชีผู้ใช้รหัส {target_user_id} สำเร็จ")
