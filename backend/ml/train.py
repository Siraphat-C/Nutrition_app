"""
เทรนโมเดลจำแนกเมนูอาหาร (YOLO11 classification)

ใช้กับ dataset ที่ได้จาก ml/prepare_dataset.py (มีโฟลเดอร์ train / val / test)

วิธีใช้ (รันในโฟลเดอร์ C:\\nutrition-backend):
    python ml/train.py --data "C:\\Users\\...\\thai_food_clean"

ผลลัพธ์อยู่ที่ ml/runs/<name>/  (weights/best.pt คือโมเดลที่ดีที่สุด)
ถ้าผลดีกว่าเดิม ให้คัดลอก best.pt ไปทับ models/yolo-cls.pt (สำรองไฟล์เดิมไว้ก่อน)
"""

import argparse
from pathlib import Path

from ultralytics import YOLO

ML_DIR = Path(__file__).parent


def main():
    parser = argparse.ArgumentParser(description="เทรน YOLO11 classification")
    parser.add_argument("--data", required=True, help="โฟลเดอร์ dataset ที่มี train / val / test")
    parser.add_argument("--model", default="yolo11s-cls.pt", help="โมเดลตั้งต้น (ใช้ตัวตั้งต้น ไม่ใช่โมเดลเดิมที่เทรนแล้ว)")
    parser.add_argument("--epochs", type=int, default=60)
    parser.add_argument("--imgsz", type=int, default=224, help="รูปจาก Roboflow ถูกย่อเหลือ 224 ไว้แล้ว")
    parser.add_argument("--batch", type=int, default=32, help="ถ้าขึ้น CUDA out of memory ให้ลดเป็น 16")
    parser.add_argument("--name", default="thai-food")
    args = parser.parse_args()

    data = Path(args.data)
    for split in ("train", "val", "test"):
        if not (data / split).is_dir():
            raise SystemExit(f"ไม่พบโฟลเดอร์ {data / split} (ใช้ ml/prepare_dataset.py สร้าง dataset ก่อน)")

    model = YOLO(args.model)
    model.train(
        data=str(data),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=0,            # GPU ตัวแรก (GTX 1650)
        workers=2,           # Windows ใช้ค่าน้อยจะเสถียรกว่า
        patience=15,         # ผลไม่ดีขึ้น 15 รอบติด ให้หยุดเอง (กัน overfitting)
        dropout=0.2,         # ลด overfitting
        cos_lr=True,         # ลด learning rate แบบค่อยเป็นค่อยไป
        project=str(ML_DIR / "runs"),
        name=args.name,
        seed=42,
        plots=True,
    )

    # วัดผลกับชุด test ที่โมเดลไม่เคยเห็นตอนเทรน: ตัวเลขนี้คือที่ควรใส่ในรายงาน
    best = Path(model.trainer.save_dir) / "weights" / "best.pt"
    metrics = YOLO(str(best)).val(
        data=str(data), split="test", imgsz=args.imgsz, batch=args.batch, device=0,
        project=str(ML_DIR / "runs"), name=f"{args.name}-test",  # เก็บผลไว้ใน ml/runs ด้วย
    )
    print("\n" + "=" * 50)
    print(f"ผลกับชุด test: top1 = {metrics.top1:.2%}   top5 = {metrics.top5:.2%}")
    print(f"โมเดลที่ดีที่สุด: {best}")
    print("=" * 50)


if __name__ == "__main__":
    main()
