from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from dashboard import (
    Meal,
    build_alerts,
    classify_day,
    month_summary,
    totals_by_day,
    weight_rate_per_week,
)

TZ = ZoneInfo("Asia/Bangkok")
TODAY = date(2026, 11, 19)


def at(d: date, hour: int = 12) -> datetime:
    return datetime(d.year, d.month, d.day, hour, tzinfo=TZ)


def meal(d: date, kcal: float, name: str = "khao_man_kai", meal_type: str = "lunch", hour: int = 12) -> Meal:
    return Meal(eaten_at=at(d, hour), meal_type=meal_type, food_name=name, calories=kcal)


def codes(result: dict) -> list[str]:
    return [a["code"] for a in result["alerts"]]


def test_totals_use_bangkok_day():
    # 23:30 UTC ของวันที่ 18 = 06:30 วันที่ 19 เวลาไทย
    utc_late = datetime(2026, 11, 18, 23, 30, tzinfo=ZoneInfo("UTC"))
    totals = totals_by_day([Meal(utc_late, "breakfast", "x", 400)], TZ)
    assert totals == {TODAY: 400}


def test_classify_day_band():
    assert classify_day(1650, 1650) == "on_target"
    assert classify_day(1810, 1650) == "on_target"   # +9.7%
    assert classify_day(1830, 1650) == "over"
    assert classify_day(1480, 1650) == "under"


def test_month_summary_counts_and_rankings():
    meals = [
        meal(date(2026, 11, 1), 2000, "khao_man_kai"),
        meal(date(2026, 11, 2), 1650, "khao_moo_daeng"),
        meal(date(2026, 11, 3), 900, "khao_man_kai", "breakfast"),
        meal(date(2026, 11, 19), 500, "khao_kha_moo", "dinner"),  # วันนี้ ไม่นับเกิน/ขาด
        meal(date(2026, 10, 31), 3000, "khao_pad_moo"),           # คนละเดือน
    ]
    s = month_summary(meals, 1650, 2026, 11, TODAY, TZ)
    assert s["days_logged"] == 4
    assert s["total_calories"] == 5050
    assert (s["days_over"], s["days_on_target"], s["days_under"]) == (1, 1, 1)
    assert s["most_frequent"][0] == {"food_name": "khao_man_kai", "times": 2, "calories": 2900}
    assert s["most_calories"][0]["food_name"] == "khao_man_kai"
    assert len(s["daily"]) == 19                       # 1-19 พ.ย. (ยังไม่ถึงวันที่ 20)
    assert abs(sum(s["by_meal"].values()) - 1) < 0.001


def test_month_summary_empty_month():
    s = month_summary([], 1650, 2026, 12, TODAY, TZ)
    assert s["days_logged"] == 0
    assert s["average_per_day"] == 0
    assert s["daily"] == []                           # เดือนในอนาคต


def test_alert_over_goal_with_projection():
    meals = [meal(TODAY - timedelta(days=i), 2000) for i in range(1, 8)]
    r = build_alerts(meals, [], 1650, 1600, "male", "lose", TODAY, TZ)
    assert codes(r) == ["intake_over_goal"]
    assert "0.3 กก./สัปดาห์" in r["alerts"][0]["detail"]   # 350*7/7700 = 0.32
    assert len(r["last7"]) == 7 and r["last7"][-1]["date"] == TODAY.isoformat()


def test_alert_intake_too_low_is_danger():
    meals = [meal(TODAY - timedelta(days=i), 900) for i in range(1, 5)]
    r = build_alerts(meals, [], 1650, 1400, "female", "lose", TODAY, TZ)
    assert r["alerts"][0]["level"] == "danger"
    assert r["alerts"][0]["code"] == "intake_too_low"


def test_alert_needs_three_days():
    meals = [meal(TODAY - timedelta(days=1), 900)]
    r = build_alerts(meals, [], 1650, 1400, "female", "lose", TODAY, TZ)
    assert codes(r) == ["need_more_logs"]


def test_alert_today_over_goal():
    r = build_alerts([meal(TODAY, 1900)], [], 1650, 1400, "female", "maintain", TODAY, TZ)
    assert "today_over_goal" in codes(r)


def test_weight_loss_too_fast_and_ordering():
    weights = [(at(TODAY - timedelta(days=14)), 70.0), (at(TODAY), 67.0)]  # -1.5 กก./สัปดาห์
    meals = [meal(TODAY - timedelta(days=i), 1650) for i in range(1, 8)]
    r = build_alerts(meals, weights, 1650, 1500, "male", "lose", TODAY, TZ)
    assert r["alerts"][0]["code"] == "weight_loss_too_fast"
    assert r["alerts"][-1]["level"] == "good"


def test_weight_gain_fast_only_when_not_gaining():
    weights = [(at(TODAY - timedelta(days=7)), 60.0), (at(TODAY), 61.0)]
    assert "weight_gain_fast" in codes(build_alerts([], weights, 1650, 1400, "female", "maintain", TODAY, TZ))
    assert "weight_gain_fast" not in codes(build_alerts([], weights, 1650, 1400, "female", "gain", TODAY, TZ))


def test_weight_rate_needs_span():
    close = [(at(TODAY - timedelta(days=2)), 60.0), (at(TODAY), 59.0)]
    assert weight_rate_per_week(close, TODAY, TZ) is None
    old = [(at(TODAY - timedelta(days=60)), 70.0), (at(TODAY), 60.0)]
    assert weight_rate_per_week(old, TODAY, TZ) is None   # จุดเก่าเกิน 4 สัปดาห์


def test_no_goal_asks_for_profile():
    assert codes(build_alerts([], [], None, None, None, None, TODAY, TZ)) == ["need_profile"]
