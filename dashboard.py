"""
สรุปการกินและการแจ้งเตือนสำหรับ Dashboard (คำนวณล้วน ไม่แตะฐานข้อมูล ทดสอบได้)

เกณฑ์และที่มา
- ลดน้ำหนักไม่ควรเกิน 1 กก./สัปดาห์ และไม่ควรกินต่ำกว่า BMR:
  เครื่องมือวางแผนลดน้ำหนัก Nutrition ai+ สำนักโภชนาการ กรมอนามัย
- 7,700 kcal = น้ำหนัก 1 กก.: ใช้ในเครื่องมือเดียวกัน
- ขั้นต่ำ 1,200 kcal (หญิง) / 1,500 kcal (ชาย): ใช้ค่าเดียวกับ nutrition.MIN_CALORIES
- ทีมกำหนดเอง (รออาจารย์ยืนยัน): กินเกินเป้าเกิน 10%, น้ำหนักขึ้นเกิน 0.5 กก./สัปดาห์,
  ช่วง "พอดี" = เป้า ±10%
"""

from __future__ import annotations

import calendar
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, tzinfo

from nutrition import MIN_CALORIES

KCAL_PER_KG = 7700
MAX_SAFE_LOSS_KG_PER_WEEK = 1.0
FAST_GAIN_KG_PER_WEEK = 0.5     # ทีมกำหนด
ON_TARGET_BAND = 0.10           # ทีมกำหนด: เป้า ±10% ถือว่าพอดี
MIN_DAYS_FOR_ANALYSIS = 3       # ต้องบันทึกอย่างน้อย 3 วันใน 7 วัน ถึงจะเตือนเรื่องการกิน
WEIGHT_WINDOW_DAYS = 28         # ใช้น้ำหนักย้อนหลังไม่เกิน 4 สัปดาห์
MIN_WEIGHT_SPAN_DAYS = 6        # จุดน้ำหนักต้องห่างกันอย่างน้อย 6 วัน ถึงจะคำนวณอัตราได้
MEAL_TYPES = ("breakfast", "lunch", "dinner", "snack")


@dataclass
class Meal:
    eaten_at: datetime          # มี timezone
    meal_type: str
    food_name: str
    calories: float


def local_day(moment: datetime, tz: tzinfo) -> date:
    return moment.astimezone(tz).date()


def totals_by_day(meals: list[Meal], tz: tzinfo) -> dict[date, float]:
    totals: dict[date, float] = defaultdict(float)
    for m in meals:
        totals[local_day(m.eaten_at, tz)] += m.calories
    return dict(totals)


def classify_day(calories: float, goal: float) -> str:
    """over / under / on_target เทียบกับเป้า ±10%"""
    if calories > goal * (1 + ON_TARGET_BAND):
        return "over"
    if calories < goal * (1 - ON_TARGET_BAND):
        return "under"
    return "on_target"


def _top_foods(meals: list[Meal], key: str, limit: int = 5) -> list[dict]:
    stats: dict[str, dict] = {}
    for m in meals:
        s = stats.setdefault(m.food_name, {"food_name": m.food_name, "times": 0, "calories": 0.0})
        s["times"] += 1
        s["calories"] += m.calories
    ranked = sorted(stats.values(), key=lambda s: (-s[key], s["food_name"]))
    return [{**s, "calories": round(s["calories"], 2)} for s in ranked[:limit]]


def month_summary(meals: list[Meal], goal: float | None, year: int, month: int,
                  today: date, tz: tzinfo) -> dict:
    """สรุปเดือน: รวม, เฉลี่ย, วันเกิน/ขาด/พอดี, เมนูยอดนิยม, สัดส่วนตามมื้อ, รายวัน"""
    last_day = calendar.monthrange(year, month)[1]
    first = date(year, month, 1)
    last = date(year, month, last_day)
    end = min(last, today)

    month_meals = [m for m in meals if first <= local_day(m.eaten_at, tz) <= last]
    per_day = totals_by_day(month_meals, tz)
    total = sum(per_day.values())
    days_logged = len(per_day)

    # วันนี้ยังไม่จบ จึงไม่นับเป็นวันเกิน/ขาด/พอดี
    finished = {d: c for d, c in per_day.items() if d < today}
    counts = {"over": 0, "under": 0, "on_target": 0}
    if goal:
        for c in finished.values():
            counts[classify_day(c, goal)] += 1

    by_meal_kcal = {t: 0.0 for t in MEAL_TYPES}
    for m in month_meals:
        by_meal_kcal[m.meal_type if m.meal_type in by_meal_kcal else "snack"] += m.calories
    by_meal = {t: round(v / total, 4) if total else 0.0 for t, v in by_meal_kcal.items()}

    daily = []
    if end >= first:
        d = first
        while d <= end:
            daily.append({"date": d.isoformat(), "calories": round(per_day.get(d, 0.0), 2)})
            d += timedelta(days=1)

    return {
        "month": f"{year:04d}-{month:02d}",
        "goal": goal,
        "days_logged": days_logged,
        "total_calories": round(total, 2),
        "average_per_day": round(total / days_logged, 2) if days_logged else 0.0,
        "days_over": counts["over"],
        "days_under": counts["under"],
        "days_on_target": counts["on_target"],
        "most_frequent": _top_foods(month_meals, "times"),
        "most_calories": _top_foods(month_meals, "calories"),
        "by_meal": by_meal,
        "daily": daily,
    }


def weight_rate_per_week(weights: list[tuple[datetime, float]], today: date, tz: tzinfo) -> float | None:
    """อัตราเปลี่ยนน้ำหนัก (กก./สัปดาห์) จากจุดแรกถึงจุดล่าสุดใน 4 สัปดาห์ (None = ข้อมูลไม่พอ)"""
    window_start = today - timedelta(days=WEIGHT_WINDOW_DAYS)
    points = sorted((w for w in weights if local_day(w[0], tz) >= window_start), key=lambda w: w[0])
    if len(points) < 2:
        return None
    (t0, kg0), (t1, kg1) = points[0], points[-1]
    span_days = (t1 - t0).total_seconds() / 86400
    if span_days < MIN_WEIGHT_SPAN_DAYS:
        return None
    return (kg1 - kg0) / span_days * 7


def build_alerts(meals: list[Meal], weights: list[tuple[datetime, float]], goal: float | None,
                 bmr: float | None, gender: str | None, goal_type: str | None,
                 today: date, tz: tzinfo) -> dict:
    """การ์ดเตือน + แคลอรี่ 7 วันล่าสุด (6 วันก่อน + วันนี้)"""
    per_day = totals_by_day(meals, tz)
    past_days = [today - timedelta(days=i) for i in range(6, 0, -1)]
    last7 = [{"date": d.isoformat(), "calories": round(per_day.get(d, 0.0), 2)} for d in past_days]
    today_total = per_day.get(today, 0.0)
    last7.append({"date": today.isoformat(), "calories": round(today_total, 2)})

    # วันที่บันทึกใน 7 วันก่อนหน้า (ไม่รวมวันนี้ที่ยังไม่จบ)
    window = [today - timedelta(days=i) for i in range(7, 0, -1)]
    logged = [per_day[d] for d in window if d in per_day]
    alerts: list[dict] = []

    if not goal:
        alerts.append(_alert("info", "need_profile", "กรอกข้อมูลร่างกายให้ครบ",
                             "ระบบจะคำนวณเป้าหมายแคลอรี่และเริ่มวิเคราะห์ให้"))
        return {"goal": goal, "alerts": alerts, "last7": last7}

    floor = max(bmr or 0, MIN_CALORIES.get(gender or "", 0))
    if len(logged) >= MIN_DAYS_FOR_ANALYSIS:
        avg = sum(logged) / len(logged)
        over_days = sum(1 for c in logged if classify_day(c, goal) == "over")
        on_days = sum(1 for c in logged if classify_day(c, goal) == "on_target")
        if floor and avg < floor:
            alerts.append(_alert(
                "danger", "intake_too_low",
                f"7 วันที่ผ่านมากินเฉลี่ยเพียง {avg:,.0f} kcal/วัน",
                f"ต่ำกว่าระดับที่ปลอดภัย ({floor:,.0f} kcal) อาจทำให้ระบบเผาผลาญลดลงและขาดสารอาหาร "
                "ถ้าบันทึกไม่ครบทุกมื้อ ตัวเลขนี้อาจต่ำกว่าความจริง",
            ))
        elif avg > goal * (1 + ON_TARGET_BAND) and over_days >= MIN_DAYS_FOR_ANALYSIS:
            excess = avg - goal
            kg_week = excess * 7 / KCAL_PER_KG
            alerts.append(_alert(
                "warning", "intake_over_goal",
                f"7 วันที่ผ่านมา กินเกินเป้า {over_days} วัน",
                f"เฉลี่ยเกินวันละ {excess:,.0f} kcal ถ้ากินแบบนี้ต่อ น้ำหนักอาจขึ้นประมาณ "
                f"{kg_week:.1f} กก./สัปดาห์",
            ))
        elif on_days >= 5:
            alerts.append(_alert("good", "on_track", f"กินตามเป้า {on_days} จาก {len(logged)} วัน",
                                 "ทำต่อแบบนี้ได้เลย"))
    else:
        alerts.append(_alert("info", "need_more_logs", "บันทึกอาหารให้ครบอย่างน้อย 3 วัน",
                             "ระบบจะเริ่มวิเคราะห์การกินย้อนหลังให้"))

    if today_total > goal:
        alerts.append(_alert("warning", "today_over_goal",
                             f"วันนี้กินเกินเป้าแล้ว {today_total - goal:,.0f} kcal",
                             "มื้อถัดไปเลือกเมนูเบาๆ หรือข้ามของว่าง"))

    rate = weight_rate_per_week(weights, today, tz)
    if rate is not None:
        if rate < -MAX_SAFE_LOSS_KG_PER_WEEK:
            alerts.append(_alert("danger", "weight_loss_too_fast",
                                 f"น้ำหนักลดเร็ว {abs(rate):.1f} กก./สัปดาห์",
                                 "ไม่ควรลดเกิน 1 กก./สัปดาห์ ลองเพิ่มพลังงานจากอาหารให้ใกล้เป้า"))
        elif rate > FAST_GAIN_KG_PER_WEEK and goal_type in ("lose", "maintain"):
            alerts.append(_alert("warning", "weight_gain_fast",
                                 f"น้ำหนักขึ้น {rate:.1f} กก./สัปดาห์",
                                 "สวนทางกับเป้าหมาย ลองดูว่ามื้อไหนกินเกินบ่อย"))
        elif goal_type == "lose" and -MAX_SAFE_LOSS_KG_PER_WEEK <= rate < 0:
            alerts.append(_alert("good", "weight_loss_safe",
                                 f"น้ำหนักลดลง {abs(rate):.1f} กก./สัปดาห์",
                                 "อยู่ในเกณฑ์ปลอดภัย (ไม่เกิน 1 กก./สัปดาห์)"))

    order = {"danger": 0, "warning": 1, "info": 2, "good": 3}
    alerts.sort(key=lambda a: order[a["level"]])
    return {"goal": goal, "alerts": alerts, "last7": last7}


def _alert(level: str, code: str, title: str, detail: str) -> dict:
    return {"level": level, "code": code, "title": title, "detail": detail}
