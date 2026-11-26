import pytest

from exercise import ACTIVITIES, MAX_MINUTES, activity_list, calories_burned


def test_calories_burned_formula():
    # 60 กก. วิ่ง (MET 9.3) 30 นาที = 9.3 x 60 x 0.5 = 279 kcal
    assert calories_burned(9.3, 60, 30) == 279.0
    # 70 กก. เดิน (MET 3.8) 1 ชั่วโมง = 266 kcal
    assert calories_burned(3.8, 70, 60) == 266.0


def test_calories_burned_rejects_zero():
    with pytest.raises(ValueError):
        calories_burned(5.0, 60, 0)


def test_activity_list_matches_compendium_values():
    items = {a["key"]: a for a in activity_list()}
    assert items["running"]["met"] == 9.3 and items["running"]["compendium_code"] == "12050"
    assert items["walk"]["met"] == 3.8
    assert len(items) == len(ACTIVITIES)
    assert all(0 < a.met <= 12 for a in ACTIVITIES.values())
    assert MAX_MINUTES == 600
