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


def test_target_weight_range_uses_bmi_limits():
    from nutrition import target_weight_range
    assert target_weight_range(160) == (47.4, 58.8)   # BMI 18.5 ถึงต่ำกว่า 23


def test_check_target_rules():
    from nutrition import check_target
    assert check_target(120, 160, "lose", 115, 5) is None
    assert "อย่างน้อย 5 สัปดาห์" in check_target(120, 160, "lose", 115, 4)        # เกิน 1 กก./สัปดาห์
    assert "ต้องน้อยกว่าตอนนี้" in check_target(120, 160, "lose", 125, 10)
    assert "ต่ำสุด 50.4" in check_target(60, 165, "lose", 45, 30)                  # BMI ต่ำกว่า 18.5
    assert check_target(60, 170, "gain", 65, 5) is None
    assert "สูงสุด 66.4" in check_target(60, 170, "gain", 66.5, 10)               # BMI 23 ขึ้นไป
    assert check_target(60, 170, "maintain", 60, 5) is not None


def test_daily_calories_from_target():
    # ลด 5 กก. ใน 70 วัน = วันละ 5 * 7,700 / 70 = 550 kcal
    r = calculate_daily_requirement("male", date(2000, 1, 1), 80, 175, 1, "lose", TODAY,
                                    target_weight=75, target_days=70)
    assert r.daily_calories == round(r.tdee - 550, 2)
    # เพิ่ม 5 กก. ใน 70 วัน = วันละ +550 kcal
    g = calculate_daily_requirement("male", date(2000, 1, 1), 60, 170, 1, "gain", TODAY,
                                    target_weight=65, target_days=70)
    assert g.daily_calories == round(g.tdee + 550, 2)


def test_expired_or_wrong_direction_target_falls_back():
    base = calculate_daily_requirement("male", date(2000, 1, 1), 80, 175, 1, "lose", TODAY)
    for days, target in [(0, 75), (-3, 75), (30, 85)]:
        r = calculate_daily_requirement("male", date(2000, 1, 1), 80, 175, 1, "lose", TODAY,
                                        target_weight=target, target_days=days)
        assert r.daily_calories == base.daily_calories   # ใช้ -500 ตามเดิม


def test_target_still_respects_calorie_floor():
    r = calculate_daily_requirement("female", date(2000, 1, 1), 55, 160, 1, "lose", TODAY,
                                    target_weight=50, target_days=35)
    assert r.daily_calories == 1200


def test_target_progress_lose():
    from nutrition import target_progress
    p = target_progress(90, 82, 60, date(2026, 11, 1), date(2027, 2, 22), date(2026, 11, 26))
    assert (p["done_kg"], p["remaining_kg"], p["percent"], p["reached"]) == (8, 22, 27, False)
    assert p["behind_kg"] < 0          # ลดได้เร็วกว่าแผน


def test_target_progress_gain_and_wrong_direction():
    from nutrition import target_progress
    g = target_progress(60, 61, 65, date(2026, 11, 1), date(2026, 12, 31), date(2026, 11, 26))
    assert (g["done_kg"], g["percent"]) == (1, 20)
    assert g["behind_kg"] > 0          # เพิ่มช้ากว่าแผน
    w = target_progress(90, 92, 60, date(2026, 11, 1), date(2027, 2, 22), date(2026, 11, 26))
    assert (w["done_kg"], w["percent"], w["remaining_kg"]) == (-2, 0, 32)   # จะลดแต่น้ำหนักขึ้น


def test_target_progress_reached():
    from nutrition import target_progress
    p = target_progress(90, 59.5, 60, date(2026, 11, 1), date(2027, 2, 22), date(2027, 1, 1))
    assert p["reached"] and p["percent"] == 100 and p["remaining_kg"] == 0


def test_target_adjustment_is_capped_near_deadline():
    # เพิ่ม 5 กก. เหลือ 2 วัน: ไม่ให้กินเพิ่มเกินวันละ 1,100 kcal (1 กก./สัปดาห์)
    r = calculate_daily_requirement("male", date(2000, 1, 1), 60, 170, 1, "gain", TODAY,
                                    target_weight=65, target_days=2)
    assert r.daily_calories == round(r.tdee + 1100, 2)
