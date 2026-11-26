from food_sync import display_name, missing_classes, model_class_names
from dashboard import Meal, month_summary
from datetime import date, datetime, timezone


def test_model_class_names_keeps_class_order_and_drops_duplicates():
    assert model_class_names({0: "khao_man_kai", 1: " khao_na_ped ", 2: "khao_man_kai", 3: ""}) == [
        "khao_man_kai", "khao_na_ped"]


def test_missing_classes_only_returns_new_menus():
    assert missing_classes(["khao_man_kai", "khao_pad_kai"], ["khao_man_kai", "old_menu"]) == ["khao_pad_kai"]
    assert missing_classes(["khao_man_kai"], ["khao_man_kai"]) == []


def test_display_name_prefers_thai():
    assert display_name({"food_name": "khao_man_kai", "food_name_th": "ข้าวมันไก่"}) == "ข้าวมันไก่"
    assert display_name({"food_name": "khao_pad_kai", "food_name_th": None}) == "khao_pad_kai"
    assert display_name({"food_name": "khao_pad_kai", "food_name_th": "  "}) == "khao_pad_kai"
    assert display_name(None) == "unknown"


def test_month_top_foods_carry_thai_name():
    t = datetime(2026, 11, 10, 5, tzinfo=timezone.utc)
    meals = [Meal(t, "lunch", "khao_man_kai", 600, "ข้าวมันไก่")]
    s = month_summary(meals, 2000, 2026, 11, date(2026, 11, 26), timezone.utc)
    assert s["most_frequent"][0]["food_name_th"] == "ข้าวมันไก่"
