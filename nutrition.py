"""
ระบบคำนวณแคลอรี่ที่ควรได้รับต่อวัน (Daily Requirement)

1. BMR - Mifflin-St Jeor
     ชาย  = 10*น้ำหนัก(kg) + 6.25*ส่วนสูง(cm) - 5*อายุ + 5
     หญิง = 10*น้ำหนัก(kg) + 6.25*ส่วนสูง(cm) - 5*อายุ - 161
2. TDEE = BMR * ตัวคูณระดับกิจกรรม (ACTIVITY_FACTORS)
3. ปรับตามเป้าหมาย และไม่ต่ำกว่าขั้นต่ำ (MIN_CALORIES)
   - ตั้งน้ำหนักเป้าหมาย + ระยะเวลา: ปรับวันละ (เป้า - ตอนนี้) * 7,700 / จำนวนวัน
   - ไม่ได้ตั้ง: ใช้ค่าคงที่ GOAL_ADJUSTMENTS (ลด 500 / เพิ่ม 300)
4. เป้าหมายที่เลือกได้ตาม BMI (allowed_goals)
5. น้ำหนักเป้าหมาย: ลดได้ไม่ต่ำกว่า BMI 18.5, เพิ่มได้ไม่เกิน BMI 23,
   เปลี่ยนได้ไม่เกิน 1 กก./สัปดาห์ (check_target)

ที่มาของค่า
- ลด 500 kcal/วัน และขั้นต่ำ 1,200 (หญิง) / 1,500 (ชาย) kcal/วัน:
  2013 AHA/ACC/TOS Guideline for the Management of Overweight and Obesity in Adults
  (Jensen MD, et al. Circulation 2014;129(25 Suppl 2):S102-S138, Table 4 ข้อ 3b)
- เกณฑ์ BMI สำหรับคนเอเชีย (ผอม < 18.5, เริ่มเสี่ยง >= 23):
  WHO Expert Consultation. Lancet 2004;363:157-63
- เพิ่ม 300 kcal/วัน: ทีมกำหนด
- ไขมัน 1 กก. = 7,700 kcal และไม่ควรลดเกิน 1 กก./สัปดาห์: กรมอนามัย กระทรวงสาธารณสุข
  (ใช้เพดานเดียวกันกับการเพิ่มน้ำหนัก)
"""

import math
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
MAX_KG_PER_WEEK = 1.0       # เปลี่ยนน้ำหนักได้ไม่เกิน 1 กก./สัปดาห์ (กรมอนามัย)
MAX_TARGET_WEEKS = 104      # ตั้งเป้าได้ไกลสุด 2 ปี
# ปรับแคลต่อวันได้ไม่เกินเพดาน 1 กก./สัปดาห์ (= 1,100 kcal/วัน) แม้ใกล้วันครบกำหนดแล้วยังห่างเป้า
MAX_DAILY_ADJUSTMENT = MAX_KG_PER_WEEK * KCAL_PER_KG / 7


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


def target_weight_range(height: float) -> tuple[float, float]:
    """น้ำหนักเป้าหมายที่ตั้งได้ (กก.): ต่ำสุด BMI 18.5, สูงสุดต่ำกว่า BMI 23"""
    m2 = (height / 100) ** 2
    lowest = math.ceil(BMI_UNDERWEIGHT * m2 * 10) / 10
    highest = math.floor((BMI_OVERWEIGHT_ASIA * m2 - 0.01) * 10) / 10
    return lowest, highest


def min_target_weeks(weight: float, target_weight: float) -> int:
    """จำนวนสัปดาห์น้อยสุดที่ไม่เกิน 1 กก./สัปดาห์"""
    return max(1, math.ceil(round(abs(target_weight - weight), 2) / MAX_KG_PER_WEEK))


def check_target(weight: float, height: float, goal: str, target_weight: float, weeks: int) -> str | None:
    """ตรวจน้ำหนักเป้าหมาย คืนข้อความภาษาไทยถ้าตั้งไม่ได้ (None = ตั้งได้)"""
    if goal == "maintain":
        return "เป้าหมายรักษาน้ำหนักไม่ต้องตั้งน้ำหนักเป้าหมาย"
    if not 1 <= weeks <= MAX_TARGET_WEEKS:
        return f"ระยะเวลาต้องอยู่ระหว่าง 1–{MAX_TARGET_WEEKS} สัปดาห์"
    lowest, highest = target_weight_range(height)
    if goal == "lose":
        if target_weight >= weight:
            return f"ลดน้ำหนัก: น้ำหนักเป้าหมายต้องน้อยกว่าตอนนี้ ({weight:g} กก.)"
        if target_weight < lowest:
            return f"น้ำหนักเป้าหมายต่ำสุด {lowest:g} กก. (BMI 18.5) ต่ำกว่านี้ผอมเกินไป"
    if goal == "gain":
        if target_weight <= weight:
            return f"เพิ่มน้ำหนัก: น้ำหนักเป้าหมายต้องมากกว่าตอนนี้ ({weight:g} กก.)"
        if target_weight > highest:
            return f"น้ำหนักเป้าหมายสูงสุด {highest:g} กก. (BMI ต่ำกว่า 23)"
    need = min_target_weeks(weight, target_weight)
    if weeks < need:
        return (f"เร็วเกินไป: เปลี่ยน {abs(target_weight - weight):g} กก. ต้องใช้อย่างน้อย {need} สัปดาห์ "
                f"(ไม่เกิน {MAX_KG_PER_WEEK:g} กก./สัปดาห์)")
    return None


def target_applies(goal: str, weight: float, target_weight: float | None, days_left: int | None) -> bool:
    """ใช้น้ำหนักเป้าหมายคำนวณได้ไหม (ยังไม่ถึงวันครบกำหนด และทิศทางยังตรงกับเป้าหมาย)"""
    if target_weight is None or days_left is None or days_left <= 0:
        return False
    if goal == "lose":
        return target_weight < weight
    if goal == "gain":
        return target_weight > weight
    return False


def target_progress(start_weight: float, current_weight: float, target_weight: float,
                    set_date: date, target_date: date, today: date) -> dict:
    """ความคืบหน้าสู่น้ำหนักเป้าหมาย
    - done_kg: เปลี่ยนไปแล้วกี่กิโล (ทางที่ถูก = บวก, ทางผิด เช่น ลดแต่น้ำหนักขึ้น = ลบ)
    - percent: 0-100 ของระยะทางทั้งหมด
    - behind_kg: ช้ากว่าแผนกี่กิโล เทียบกับเส้นตรงจากวันเริ่มถึงวันครบกำหนด (ติดลบ = เร็วกว่าแผน)"""
    total_kg = target_weight - start_weight
    direction = 1 if total_kg > 0 else -1          # +1 เพิ่มน้ำหนัก, -1 ลดน้ำหนัก
    done_kg = (current_weight - start_weight) * direction
    goal_kg = abs(total_kg)
    percent = 0.0 if goal_kg == 0 else max(0.0, min(100.0, done_kg / goal_kg * 100))
    total_days = max(1, (target_date - set_date).days)
    elapsed = max(0, min(total_days, (today - set_date).days))
    planned_kg = goal_kg * elapsed / total_days
    return {
        "start_weight": round(start_weight, 2),
        "done_kg": round(done_kg, 2),
        "remaining_kg": round(max(0.0, goal_kg - done_kg), 2),
        "percent": round(percent),
        "behind_kg": round(planned_kg - done_kg, 2),
        "reached": done_kg >= goal_kg,
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
    target_weight: float | None = None,
    target_days: int | None = None,
) -> DailyRequirement:
    """target_weight + target_days (จำนวนวันที่เหลือถึงวันเป้าหมาย) = คำนวณจากน้ำหนักเป้าหมาย
    ไม่ส่ง หรือเป้าหมายหมดอายุ/ไม่ตรงทิศทาง = ใช้ค่าคงที่ GOAL_ADJUSTMENTS"""
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
    if target_applies(goal, weight, target_weight, target_days):
        adjustment = (target_weight - weight) * KCAL_PER_KG / target_days
        adjustment = max(-MAX_DAILY_ADJUSTMENT, min(MAX_DAILY_ADJUSTMENT, adjustment))
    else:
        adjustment = GOAL_ADJUSTMENTS[goal]
    calories = max(tdee + adjustment, MIN_CALORIES[gender])

    return DailyRequirement(
        bmr=round(bmr, 2),
        tdee=round(tdee, 2),
        daily_calories=round(calories, 2),
    )
