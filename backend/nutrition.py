"""
ระบบคำนวณแคลอรี่ที่ควรได้รับต่อวัน (Daily Requirement)

1. BMR - Mifflin-St Jeor
     ชาย  = 10*น้ำหนัก(kg) + 6.25*ส่วนสูง(cm) - 5*อายุ + 5
     หญิง = 10*น้ำหนัก(kg) + 6.25*ส่วนสูง(cm) - 5*อายุ - 161
2. TDEE = BMR * ตัวคูณระดับกิจกรรม (ACTIVITY_FACTORS)
3. ปรับตามเป้าหมาย (GOAL_ADJUSTMENTS) และไม่ต่ำกว่าขั้นต่ำ (MIN_CALORIES)
"""

from dataclasses import dataclass
from datetime import date

ACTIVITY_FACTORS = {
    1: 1.2,    # ไม่ออกกำลังกาย
    2: 1.375,  # ออกกำลังกายเบา 1-3 วัน/สัปดาห์
    3: 1.55,   # ออกกำลังกายปานกลาง 3-5 วัน/สัปดาห์
    4: 1.725,  # ออกกำลังกายหนัก 6-7 วัน/สัปดาห์
    5: 1.9,    # ออกกำลังกายหนักมาก / งานใช้แรง
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
