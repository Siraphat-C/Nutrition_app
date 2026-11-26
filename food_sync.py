"""
ซิงก์เมนูในตาราง foods กับชื่อคลาสของโมเดล YOLO

- ชื่อคลาสของโมเดล = food_name ในตาราง foods (ต้องตรงกันทุกตัวอักษร)
- เทรนโมเดลใหม่แล้วมีคลาสเพิ่ม: ตอนเปิดเซิร์ฟเวอร์จะสร้างแถวให้เมนูที่ยังไม่มี
  (ยังไม่มีชื่อไทยและแคลอรี่) แล้วแอดมินเข้าไปเติมในหน้าแอดมิน
- ไม่ลบเมนูที่โมเดลไม่รู้จักแล้ว เพราะอาจมีผู้ใช้บันทึกเมนูนั้นไว้
"""

from collections.abc import Iterable


def model_class_names(names: dict[int, str] | Iterable[str]) -> list[str]:
    """ชื่อคลาสจาก model.names (dict {id: name}) เรียงตามรหัสคลาส ไม่ซ้ำ"""
    values = names.values() if isinstance(names, dict) else names
    seen: dict[str, None] = {}
    for name in values:
        cleaned = str(name).strip()
        if cleaned:
            seen.setdefault(cleaned, None)
    return list(seen)


def missing_classes(class_names: Iterable[str], existing_food_names: Iterable[str]) -> list[str]:
    """คลาสของโมเดลที่ยังไม่มีแถวในตาราง foods"""
    existing = set(existing_food_names)
    return [name for name in class_names if name not in existing]


def display_name(food: dict | None) -> str:
    """ชื่อสำหรับแสดงผล: ชื่อไทยถ้ามี ไม่อย่างนั้นใช้ชื่อคลาส"""
    if not food:
        return "unknown"
    return (food.get("food_name_th") or "").strip() or food.get("food_name") or "unknown"
