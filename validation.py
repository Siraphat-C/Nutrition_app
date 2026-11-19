"""
ตัวช่วยตรวจข้อมูลที่รับจากแอป ให้ตรงกับข้อจำกัดของฐานข้อมูล
(ถ้าค่าผ่าน Pydantic แต่ไม่ผ่านฐานข้อมูล ผู้ใช้จะได้ 500 แทน 422)
"""

import re
from datetime import date

from nutrition import calculate_age

INT4_MAX = 2_147_483_647      # ค่าสูงสุดของคอลัมน์ integer ใน Postgres
EMAIL_MAX_LENGTH = 100        # users.email varchar(100)
BCRYPT_MAX_BYTES = 72         # bcrypt ใช้รหัสผ่านได้ไม่เกิน 72 ไบต์ (ภาษาไทย 1 ตัว = 3 ไบต์)
MIN_AGE = 13                  # สูตร Mifflin-St Jeor ใช้กับวัยรุ่นและผู้ใหญ่
MAX_AGE = 100
MAX_IMAGE_PIXELS = 40_000_000  # ประมาณ 40 ล้านพิกเซล (รูปจากมือถือทั่วไป 12-50 MP)

# ชื่อผู้ใช้: ไทย อังกฤษ ตัวเลข _ . เว้นวรรคได้ทีละ 1 ช่องระหว่างคำ (users.username varchar(50))
USERNAME_MIN_LENGTH = 3
USERNAME_MAX_LENGTH = 50
_NAME_PART = r"[A-Za-z0-9_.\u0E00-\u0E7F]+"
USERNAME_PATTERN = rf"^{_NAME_PART}( {_NAME_PART})*$"
# คำค้นหา: ไม่มีเว้นวรรค จุลภาค วงเล็บ (กันอักขระพิเศษของตัวกรอง PostgREST)
SEARCH_PATTERN = r"^[\w@.\-\u0E00-\u0E7F]+$"


def check_birth_date(birth_date: date, today: date) -> date:
    age = calculate_age(birth_date, today)
    if not MIN_AGE <= age <= MAX_AGE:
        raise ValueError(f"อายุต้องอยู่ระหว่าง {MIN_AGE}-{MAX_AGE} ปี")
    return birth_date


def check_password_bytes(password: str) -> str:
    if len(password.encode("utf-8")) > BCRYPT_MAX_BYTES:
        raise ValueError(
            f"รหัสผ่านยาวเกินไป (ไม่เกิน {BCRYPT_MAX_BYTES} ไบต์ "
            "ภาษาอังกฤษประมาณ 72 ตัว หรือภาษาไทยประมาณ 24 ตัว)"
        )
    return password


def check_email_length(email: str) -> str:
    if len(email) > EMAIL_MAX_LENGTH:
        raise ValueError(f"อีเมลต้องยาวไม่เกิน {EMAIL_MAX_LENGTH} ตัวอักษร")
    return email


def round_2(value):
    """ปัดทศนิยม 2 ตำแหน่งก่อนตรวจขอบเขต ให้ตรงกับคอลัมน์ numeric(x, 2)
    ค่าที่ไม่ใช่ตัวเลข ปล่อยให้ Pydantic ตรวจและแจ้ง 422 เอง"""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return round(value, 2)
    return value


def clean_username(value):
    """ตัดเว้นวรรคหัวท้าย และรวมเว้นวรรคซ้อนให้เหลือช่องเดียว"""
    if isinstance(value, str):
        return re.sub(r"\s+", " ", value).strip()
    return value
