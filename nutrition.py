"""
ระบบคำนวณแคลอรี่ที่ควรได้รับต่อวัน (Daily Requirement)

1. BMR - Mifflin-St Jeor
     ชาย  = 10*น้ำหนัก(kg) + 6.25*ส่วนสูง(cm) - 5*อายุ + 5
     หญิง = 10*น้ำหนัก(kg) + 6.25*ส่วนสูง(cm) - 5*อายุ - 161
2. TDEE = BMR * ตัวคูณระดับกิจกรรม (ACTIVITY_FACTORS)
3. ปรับตามเป้าหมาย (GOAL_ADJUSTMENTS) และไม่ต่ำกว่าขั้นต่ำ (MIN_CALORIES)
4. เป้าหมายที่เลือกได้ตาม BMI (allowed_goals)

ที่มาของค่า
- ลด 500 kcal/วัน และขั้นต่ำ 1,200 (หญิง) / 1,500 (ชาย) kcal/วัน:
  2013 AHA/ACC/TOS Guideline for the Management of Overweight and Obesity in Adults
  (Jensen MD, et al. Circulation 2014;129(25 Suppl 2):S102-S138, Table 4 ข้อ 3b)
- เกณฑ์ BMI สำหรับคนเอเชีย (ผอม < 18.5, เริ่มเสี่ยง >= 23):
  WHO Expert Consultation. Lancet 2004;363:157-63
- เพิ่ม 300 kcal/วัน: ทีมกำหนด
"""

from dataclasses import dataclass
from datetime import date

# ระดับกิจกรรมนับเฉพาะชีวิตประจำวัน (งาน การเดินทาง) ไม่รวมการออกกำลังกาย
# การออกกำลังกายนับจาก exercise_logs แล้วไปหักจากแคลอรี่ที่กิน (ดู dashboard.py)
# ถ้าตัวคูณรวมการออกกำลังกายด้วย จะนับซ้ำสองครั้ง
ACTIVITY_FACTORS = {
    1: 1.2,    # นั่งเป็นหลัก
    2: 1.375,  # ยืนหรือเดินบ้าง
    3: 1.55,   # ยืนหรือเดินเกือบทั้งวัน
    4: 1.725,  # งานใช้แรง
    5: 1.9,    # งานใช้แรงหนัก
}

GOAL_ADJUSTMENTS = {
    "lose": -500,
    "maintain": 0,
    "gain": 300,
}

MIN_CALORIES = {
    "male": 1500,
    "female": 1200,
}

KCAL_PER_KG = 7700          # พลังงาน 7,700 kcal = น้ำหนักตัว 1 กก. (กรมอนามัย)
BMI_UNDERWEIGHT = 18.5      # ต่ำกว่านี้ = ผอม: ห้ามเลือกลดน้ำหนัก
BMI_OVERWEIGHT_ASIA = 23.0  # ตั้งแต่นี้ = น้ำหนักเกิน (เกณฑ์เอเชีย): ห้ามเลือกเพิ่มน้ำหนัก


def calculate_bmi(weight: float, height: float) -> float:
    """BMI = น้ำหนัก (กก.) / ส่วนสูง (ม.) ยกกำลังสอง"""
    meters = height / 100
    return round(weight / (meters * meters), 2)


def allowed_goals(weight: float, height: float) -> list[str]:
    """เป้าหมายที่เลือกได้ตาม BMI
    ผอม (< 18.5) เลือกได้แค่ คงน้ำหนัก/เพิ่ม; น้ำหนักเกิน (>= 23) เลือกได้แค่ ลดน้ำหนัก"""
    bmi = calculate_bmi(weight, height)
    if bmi < BMI_UNDERWEIGHT:
        return ["maintain", "gain"]
    if bmi >= BMI_OVERWEIGHT_ASIA:
        return ["lose"]
    return ["lose", "maintain", "gain"]


def expected_change_per_week(daily_calories: float, tdee: float) -> float:
    """น้ำหนักที่คาดว่าจะเปลี่ยนต่อสัปดาห์ (กก.) ถ้ากินตามเป้า
    คิดจากส่วนต่างจริงระหว่างเป้ากับ TDEE (ไม่ใช่ -500 ตายตัว)
    เพราะถ้าเป้าถูกปัดขึ้นเป็นแคลอรี่ขั้นต่ำ ส่วนที่ลดได้จริงจะน้อยกว่า 500
    เช่น TDEE 1,694 เป้า 1,500 (ขั้นต่ำ) = ลด 194 kcal/วัน = -0.18 กก./สัปดาห์"""
    return round((daily_calories - tdee) * 7 / KCAL_PER_KG, 2)


@dataclass
class DailyRequirement:
    bmr: float
    tdee: float
    daily_calories: float


def calculate_age(birth_date: date, today: date | None = None) -> int:
    today = today or date.today()
    had_birthday = (today.month, today.day) >= (birth_date.month, birth_date.day)
    return today.year - birth_date.year - (0 if had_birthday else 1)


def calculate_daily_requirement(
    gender: str,
    birth_date: date,
    weight: float,
    height: float,
    activity_level: int,
    goal: str,
    today: date | None = None,
) -> DailyRequirement:
    if gender not in MIN_CALORIES:
        raise ValueError("gender must be 'male' or 'female'")
    if activity_level not in ACTIVITY_FACTORS:
        raise ValueError("activity_level must be 1-5")
    if goal not in GOAL_ADJUSTMENTS:
        raise ValueError("goal must be 'lose', 'maintain' or 'gain'")

    age = calculate_age(birth_date, today)
    gender_constant = 5 if gender == "male" else -161
    bmr = 10 * weight + 6.25 * height - 5 * age + gender_constant
    tdee = bmr * ACTIVITY_FACTORS[activity_level]
    calories = max(tdee + GOAL_ADJUSTMENTS[goal], MIN_CALORIES[gender])

    return DailyRequirement(
        bmr=round(bmr, 2),
        tdee=round(tdee, 2),
        daily_calories=round(calories, 2),
    )
