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
    assert r.daily_protein == 67.49
    assert r.daily_carbohydrate == 168.71
    assert r.daily_fat == 44.99


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
