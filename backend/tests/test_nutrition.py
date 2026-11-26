from datetime import date

import pytest

from nutrition import calculate_age, calculate_daily_requirement

TODAY = date(2026, 11, 17)


def test_age_before_and_after_birthday():
    assert calculate_age(date(2001, 11, 17), TODAY) == 25
    assert calculate_age(date(2001, 11, 18), TODAY) == 24


def test_female_lose():
    # BMR = 600 + 1031.25 - 125 - 161 = 1345.25
    # TDEE = 1345.25 * 1.375 = 1849.72, minus 500 = 1349.72
    r = calculate_daily_requirement("female", date(2001, 1, 1), 60, 165, 2, "lose", TODAY)
    assert r.bmr == 1345.25
    assert r.tdee == 1849.72
    assert r.daily_calories == 1349.72


def test_male_maintain():
    # BMR = 700 + 1093.75 - 150 + 5 = 1648.75, TDEE = 2555.56
    r = calculate_daily_requirement("male", date(1996, 1, 1), 70, 175, 3, "maintain", TODAY)
    assert r.bmr == 1648.75
    assert r.daily_calories == 2555.56


def test_gain_adds_300():
    r = calculate_daily_requirement("male", date(1996, 1, 1), 70, 175, 3, "gain", TODAY)
    assert r.daily_calories == 2855.56


def test_minimum_calories_floor():
    r = calculate_daily_requirement("female", date(1960, 1, 1), 40, 145, 1, "lose", TODAY)
    assert r.daily_calories == 1200


@pytest.mark.parametrize(
    "gender, level, goal",
    [("other", 1, "lose"), ("male", 6, "lose"), ("male", 1, "bulk")],
)
def test_invalid_input(gender, level, goal):
    with pytest.raises(ValueError):
        calculate_daily_requirement(gender, date(2000, 1, 1), 60, 170, level, goal, TODAY)


def test_bmi_and_allowed_goals():
    from nutrition import allowed_goals, calculate_bmi
    # ตัวอย่างอาจารย์: สูง 160 หนัก 120 -> BMI 46.9 เลือกเพิ่มน้ำหนักไม่ได้
    assert calculate_bmi(120, 160) == 46.87
    assert allowed_goals(120, 160) == ["lose"]
    assert allowed_goals(45, 170) == ["maintain", "gain"]          # BMI 15.6
    assert allowed_goals(60, 170) == ["lose", "maintain", "gain"]  # BMI 20.8
    assert allowed_goals(66.47, 170) == ["lose"]                   # BMI 23.0 พอดีเกณฑ์


def test_expected_change_per_week():
    from nutrition import expected_change_per_week
    assert expected_change_per_week(1500, 2000) == -0.45   # ลด 500 kcal/วัน
    assert expected_change_per_week(2000, 2000) == 0
    assert expected_change_per_week(2300, 2000) == 0.27    # เพิ่ม 300 kcal/วัน


def test_expected_change_uses_calorie_floor():
    """เป้าถูกปัดขึ้นเป็นขั้นต่ำ: ส่วนที่ลดได้จริงน้อยกว่า 500 (ชาย 20 ปี 60 กก. 145 ซม. นั่งเป็นหลัก)"""
    from nutrition import expected_change_per_week
    r = calculate_daily_requirement("male", date(2006, 1, 17), 60, 145, 1, "lose", TODAY)
    assert r.daily_calories == 1500                     # TDEE 1,693.5 - 500 = 1,193.5 ต่ำกว่าขั้นต่ำ
    assert expected_change_per_week(r.daily_calories, r.tdee) == -0.18
