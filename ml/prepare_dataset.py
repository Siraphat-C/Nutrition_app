"""
เตรียม dataset สำหรับเทรน YOLO classification

1. รวมรูปจากหลายแหล่ง
   --source       dataset แบบ classification (โฟลเดอร์ย่อยชื่อเมนู เช่น Roboflow "folder")
   --source-class dataset ที่ทั้งชุดเป็นเมนูเดียว (เช่น Roboflow ".yolov11" ที่มี train/images)
2. ตัดรูปซ้ำ 2 ชั้น
   - ชื่อไฟล์ต้นฉบับเดียวกันในแหล่งเดียวกัน (Roboflow สร้างหลายเวอร์ชันจากรูปเดียว เช่น หมุนรูป)
   - หน้าตาภาพเหมือนกัน (dHash) แม้ถูกย่อ บีบอัด หมุน 90/180/270 องศา หรือกลับซ้ายขวา
   รูปจากแหล่งที่ใส่ก่อนจะถูกเก็บไว้ (ใส่แหล่งที่ความละเอียดสูงกว่าไว้ก่อน)
3. แบ่งใหม่เป็น train / val / test (80 / 10 / 10) ต่อเมนู โดยไม่มีรูปซ้ำข้ามชุด
4. เขียนรายงานจำนวนรูปต่อเมนูไว้ที่ <output>/report.txt

ตัวอย่าง (รันในโฟลเดอร์ C:\\nutrition-backend):
    python ml/prepare_dataset.py ^
        --source-class "C:\\...\\Pork-Fried-Rice.v1i.yolov11=khao_pad_moo" ^
        --source "C:\\...\\Thai-Food-Classify.v1i.folder" ^
        --output "C:\\...\\thai_food_v2"

ตัวเลือกอื่น
    --map ชื่อเดิม=ชื่อใหม่   เปลี่ยนชื่อโฟลเดอร์เมนูของ --source ให้ตรงกับของเรา
    --only ชื่อเมนู          เอาเฉพาะเมนูที่ระบุ (ใส่ได้หลายครั้ง)
"""

import argparse
import random
import shutil
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
SPLITS = {"train": 0.8, "val": 0.1, "test": 0.1}
DUPLICATE_DISTANCE = 5  # dHash ต่างกันไม่เกินกี่บิต (จาก 64) ถึงจะถือว่าเป็นรูปเดียวกัน
SKIP_FOLDERS = {"runs", "labels"}  # ผลการเทรนเก่า และไฟล์ label ของ detection


def _dhash_of(gray: Image.Image, size: int = 8) -> int:
    small = gray.resize((size + 1, size), Image.Resampling.LANCZOS)
    pixels = small.tobytes()  # ค่าความสว่าง 0-255 ทีละพิกเซล
    value = 0
    for row in range(size):
        for col in range(size):
            left = pixels[row * (size + 1) + col]
            right = pixels[row * (size + 1) + col + 1]
            value = (value << 1) | (left > right)
    return value


def image_hashes(path: Path) -> list[int] | None:
    """dHash ของภาพในทุกทิศ (หมุน 0/90/180/270 และกลับซ้ายขวา) ใช้จับรูปซ้ำที่ถูกหมุน"""
    try:
        with Image.open(path) as img:
            gray = ImageOps.exif_transpose(img).convert("L")
    except (UnidentifiedImageError, OSError):
        return None
    hashes = []
    for flipped in (gray, ImageOps.mirror(gray)):
        for angle in (0, 90, 180, 270):
            hashes.append(_dhash_of(flipped.rotate(angle, expand=True)))
    return hashes


def original_name(path: Path) -> str:
    """ชื่อไฟล์ก่อน Roboflow ต่อท้าย .rf.<hash> (รูปที่มาจากต้นฉบับเดียวกันจะได้ชื่อเดียวกัน)"""
    return path.name.split(".rf.")[0]


def iter_images(root: Path):
    for path in sorted(root.rglob("*")):
        if path.suffix.lower() not in IMAGE_EXTENSIONS or not path.is_file():
            continue
        if SKIP_FOLDERS & set(path.relative_to(root).parts):
            continue
        yield path


def remove_duplicates(items: list[tuple[str, Path]]) -> tuple[list[Path], int, int]:
    """items = [(ชื่อแหล่ง, path)] เรียงตามลำดับความสำคัญ
    คืน (รูปที่ไม่ซ้ำ, จำนวนรูปซ้ำที่ตัดออก, จำนวนไฟล์ที่เปิดไม่ได้)"""
    seen_names: set[tuple[str, str]] = set()
    kept: list[tuple[list[int], Path]] = []
    duplicates = broken = 0
    for source_name, path in items:
        key = (source_name, original_name(path))
        if key in seen_names:
            duplicates += 1
            continue
        hashes = image_hashes(path)
        if hashes is None:
            broken += 1
            continue
        h = hashes[0]
        if any(bin(h ^ other).count("1") <= DUPLICATE_DISTANCE for other_hashes, _ in kept for other in other_hashes):
            duplicates += 1
            seen_names.add(key)
            continue
        seen_names.add(key)
        kept.append((hashes, path))
    return [p for _, p in kept], duplicates, broken


def split_paths(paths: list[Path], rng: random.Random) -> dict[str, list[Path]]:
    paths = paths[:]
    rng.shuffle(paths)
    n = len(paths)
    n_val = max(1, round(n * SPLITS["val"]))
    n_test = max(1, round(n * SPLITS["test"]))
    return {
        "val": paths[:n_val],
        "test": paths[n_val:n_val + n_test],
        "train": paths[n_val + n_test:],
    }


def parse_pair(text: str, option: str) -> tuple[str, str]:
    # แยกที่ = ตัวสุดท้าย (path บน Windows มี : แต่ไม่มี =)
    if "=" not in text:
        raise SystemExit(f"{option} ต้องอยู่ในรูป ค่าซ้าย=ค่าขวา: {text}")
    left, right = text.rsplit("=", 1)
    return left.strip(), right.strip()


def main():
    parser = argparse.ArgumentParser(description="รวม ตัดรูปซ้ำ และแบ่ง dataset ใหม่")
    parser.add_argument("--source", action="append", default=[],
                        help="dataset แบบ classification (โฟลเดอร์ย่อยชื่อเมนู)")
    parser.add_argument("--source-class", action="append", default=[],
                        help='dataset ที่ทั้งชุดเป็นเมนูเดียว: "PATH=ชื่อเมนู"')
    parser.add_argument("--output", required=True, help="โฟลเดอร์ปลายทาง (ต้องยังไม่มี หรือว่าง)")
    parser.add_argument("--map", action="append", default=[], help="เปลี่ยนชื่อเมนูของ --source: ชื่อเดิม=ชื่อใหม่")
    parser.add_argument("--only", action="append", default=[], help="เอาเฉพาะเมนูนี้ (ใส่ได้หลายครั้ง)")
    parser.add_argument("--min-images", type=int, default=50, help="เมนูที่มีรูปน้อยกว่านี้จะไม่ถูกนำไปใช้")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    if not args.source and not args.source_class:
        raise SystemExit("ต้องใส่ --source หรือ --source-class อย่างน้อย 1 ครั้ง")

    output = Path(args.output)
    if output.exists() and any(output.iterdir()):
        raise SystemExit(f"โฟลเดอร์ {output} มีไฟล์อยู่แล้ว ให้ลบหรือเลือกชื่อใหม่")

    name_map = dict(parse_pair(item, "--map") for item in args.map)
    # รูปของแต่ละเมนู เรียงตามลำดับแหล่งที่ใส่ใน command line
    all_images: dict[str, list[tuple[str, Path]]] = defaultdict(list)

    for item in args.source_class:
        path_text, class_name = parse_pair(item, "--source-class")
        root = Path(path_text)
        if not root.is_dir():
            raise SystemExit(f"ไม่พบโฟลเดอร์ {root}")
        for path in iter_images(root):
            all_images[class_name].append((str(root), path))

    for source in args.source:
        root = Path(source)
        if not root.is_dir():
            raise SystemExit(f"ไม่พบโฟลเดอร์ {root}")
        for path in iter_images(root):
            class_name = name_map.get(path.parent.name, path.parent.name)
            all_images[class_name].append((str(root), path))

    if args.only:
        all_images = {k: v for k, v in all_images.items() if k in set(args.only)}
    if not all_images:
        raise SystemExit("ไม่พบรูปภาพ ตรวจสอบ --source / --source-class / --only อีกครั้ง")

    rng = random.Random(args.seed)
    lines = [f"{'menu':28} {'found':>6} {'dup':>6} {'bad':>5} {'train':>6} {'val':>5} {'test':>5}"]
    totals = defaultdict(int)
    skipped = []

    for class_name in sorted(all_images):
        items = all_images[class_name]
        print(f"กำลังตรวจรูปซ้ำ: {class_name} ({len(items)} ไฟล์)", flush=True)
        unique, duplicates, broken = remove_duplicates(items)
        if len(unique) < args.min_images:
            skipped.append(f"{class_name} ({len(unique)} รูป)")
            continue
        parts = split_paths(unique, rng)
        for split, paths in parts.items():
            target = output / split / class_name
            target.mkdir(parents=True, exist_ok=True)
            for i, path in enumerate(paths):
                shutil.copy2(path, target / f"{class_name}_{i:04d}{path.suffix.lower()}")
            totals[split] += len(paths)
        totals["found"] += len(items)
        totals["duplicates"] += duplicates
        totals["broken"] += broken
        lines.append(
            f"{class_name:28} {len(items):>6} {duplicates:>6} {broken:>5} "
            f"{len(parts['train']):>6} {len(parts['val']):>5} {len(parts['test']):>5}"
        )

    lines.append(
        f"{'TOTAL':28} {totals['found']:>6} {totals['duplicates']:>6} {totals['broken']:>5} "
        f"{totals['train']:>6} {totals['val']:>5} {totals['test']:>5}"
    )
    if skipped:
        lines.append(f"\nไม่นำไปใช้ (รูปน้อยกว่า {args.min_images}): " + ", ".join(skipped))

    report = "\n".join(lines)
    output.mkdir(parents=True, exist_ok=True)
    (output / "report.txt").write_text(report, encoding="utf-8")
    print("\n" + report)
    print(f"\nเสร็จแล้ว: {output}")


if __name__ == "__main__":
    main()
