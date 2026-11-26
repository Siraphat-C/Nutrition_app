"""
แคลอรี่ที่เผาผลาญจากการออกกำลังกาย (คำนวณล้วน ไม่แตะฐานข้อมูล ทดสอบได้)

สูตร: kcal = MET x น้ำหนักตัว (กก.) x เวลา (ชั่วโมง)
  1 MET = พลังงานตอนนั่งพัก ประมาณ 1 kcal ต่อน้ำหนักตัว 1 กก. ต่อชั่วโมง

ค่า MET มาจาก 2024 Adult Compendium of Physical Activities
  Herrmann SD, et al. J Sport Health Sci. 2024;13(1):6-12. doi:10.1016/j.jshs.2023.10.010
  https://pacompendium.com/adult-compendium/
ตัวเลขในวงเล็บท้ายแต่ละรายการคือรหัสกิจกรรมใน Compendium
"""

from __future__ import annotations

from dataclasses import dataclass

MIN_MINUTES = 1
MAX_MINUTES = 600  # 10 ชั่วโมงต่อครั้ง


@dataclass(frozen=True)
class Activity:
    key: str
    name_th: str
    met: float
    compendium_code: str


ACTIVITIES: dict[str, Activity] = {a.key: a for a in [
    Activity("walk", "เดิน (ความเร็วปกติ)", 3.8, "17190"),
    Activity("walk_brisk", "เดินเร็ว", 4.8, "17200"),
    Activity("jogging", "วิ่งเหยาะ", 7.5, "12020"),
    Activity("running", "วิ่ง (ประมาณ 10 กม./ชม.)", 9.3, "12050"),
    Activity("cycling_leisure", "ปั่นจักรยาน (สบายๆ)", 4.0, "01010"),
    Activity("cycling", "ปั่นจักรยาน (ปานกลาง)", 8.0, "01030"),
    Activity("stationary_bike", "จักรยานอยู่กับที่", 6.8, "01200"),
    Activity("swimming", "ว่ายน้ำ (สบายๆ)", 6.0, "18310"),
    Activity("aerobic", "แอโรบิก", 7.3, "02000"),
    Activity("weight_training", "เวทเทรนนิ่ง", 3.5, "02054"),
    Activity("yoga", "โยคะ", 2.3, "02150"),
    Activity("jump_rope", "กระโดดเชือก", 11.0, "02068"),
    Activity("elliptical", "เครื่องเดินวงรี (Elliptical)", 5.0, "02048"),
    Activity("football", "ฟุตบอล", 7.0, "15610"),
    Activity("futsal", "ฟุตซอล", 7.8, "15195"),
    Activity("basketball", "บาสเกตบอล", 7.5, "15055"),
    Activity("badminton", "แบดมินตัน", 5.5, "15030"),
    Activity("volleyball", "วอลเลย์บอล", 3.0, "15720"),
    Activity("table_tennis", "ปิงปอง", 4.0, "15660"),
    Activity("muay_thai", "มวยไทย", 10.3, "15430"),
]}


def calories_burned(met: float, weight_kg: float, minutes: float) -> float:
    """kcal = MET x น้ำหนัก (กก.) x ชั่วโมง"""
    if met <= 0 or weight_kg <= 0 or minutes <= 0:
        raise ValueError("MET, น้ำหนัก และเวลาต้องมากกว่า 0")
    return round(met * weight_kg * minutes / 60, 2)


def activity_list() -> list[dict]:
    return [
        {"key": a.key, "name_th": a.name_th, "met": a.met, "compendium_code": a.compendium_code}
        for a in ACTIVITIES.values()
    ]
