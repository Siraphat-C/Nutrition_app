"""ทดสอบ API ของ backend แบบรวดเร็ว (ต้องเปิด uvicorn ไว้ก่อน)

วิธีรัน:
    python scripts/api_smoke_test.py
    python scripts/api_smoke_test.py --base http://localhost:8000

อีเมลและรหัสผ่านแอดมินอ่านจาก environment variable ADMIN_EMAIL และ
ADMIN_PASSWORD ถ้าไม่ได้ตั้งไว้ สคริปต์จะถามตอนรัน (รหัสผ่านไม่แสดงบนจอ)

สคริปต์จะสร้างผู้ใช้และเมนูอาหารชั่วคราวเพื่อทดสอบ แล้วลบทิ้งตอนจบเสมอ
แม้จะมีข้อที่ไม่ผ่านก็ตาม
"""

import argparse
import getpass
import os
import sys
import time

import httpx

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


class Runner:
    def __init__(self, base: str):
        self.client = httpx.Client(base_url=base, timeout=30)
        self.results: list[tuple[str, int, int, str]] = []

    def call(self, name, method, path, expect, token=None, json=None, params=None):
        headers = {"Authorization": f"Bearer {token}"} if token else {}
        r = self.client.request(method, path, headers=headers, json=json, params=params)
        try:
            body = r.json()
        except ValueError:
            body = {}
        msg = body.get("message") or body.get("detail") or ""
        if not isinstance(msg, str):
            msg = str(msg)[:80]
        self.results.append((name, r.status_code, expect, msg))
        mark = "PASS" if r.status_code == expect else "FAIL"
        print(f"[{mark}] {name}: {r.status_code} (ต้องได้ {expect}) {msg}")
        return body

    def summary(self) -> bool:
        failed = [x for x in self.results if x[1] != x[2]]
        print()
        print(f"ผ่าน {len(self.results) - len(failed)}/{len(self.results)} ข้อ")
        for name, got, expect, msg in failed:
            print(f"  ไม่ผ่าน: {name} ได้ {got} ต้องได้ {expect} {msg}")
        return not failed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://localhost:8000")
    args = parser.parse_args()

    email = os.getenv("ADMIN_EMAIL") or input("อีเมลแอดมิน: ").strip()
    password = os.getenv("ADMIN_PASSWORD") or getpass.getpass("รหัสผ่านแอดมิน: ")

    t = Runner(args.base)
    sfx = str(int(time.time()))[-6:]
    new_email = f"qa{sfx}@test.com"
    user_id = None
    food_id = None

    try:
        # 1. ล็อกอินแอดมิน
        login = t.call("1 ล็อกอินแอดมิน", "POST", "/api/admin/login", 200,
                       json={"email": email, "password": password})
        token = (login.get("data") or {}).get("access_token")
        if not token:
            print("ล็อกอินไม่ได้ หยุดทดสอบ")
            return 1
        me = t.call("1b /api/me", "GET", "/api/me", 200, token=token)
        admin_id = (me.get("data") or {}).get("user_id")
        t.call("1c ไม่มี token เข้าแดชบอร์ด", "GET", "/api/admin/dashboard", 401)

        # 2-3. แดชบอร์ดและรายชื่อผู้ใช้
        t.call("2 แดชบอร์ดแอดมิน", "GET", "/api/admin/dashboard", 200, token=token)
        t.call("3 รายชื่อผู้ใช้", "GET", "/api/admin/users", 200, token=token,
               params={"limit": 5})

        # 4. เพิ่มผู้ใช้
        created = t.call("4 เพิ่มผู้ใช้", "POST", "/api/admin/users", 201, token=token,
                         json={"username": f"qa{sfx}", "email": new_email,
                               "password": "qa-pass-1234", "role_id": 2})
        user_id = (created.get("data") or {}).get("user_id")
        t.call("4b อีเมลซ้ำ", "POST", "/api/admin/users", 409, token=token,
               json={"username": f"qb{sfx}", "email": new_email,
                     "password": "qa-pass-1234", "role_id": 2})
        user_login = t.call("4c ผู้ใช้ใหม่ล็อกอิน", "POST", "/api/login", 200,
                            json={"email": new_email, "password": "qa-pass-1234"})
        user_token = (user_login.get("data") or {}).get("access_token")
        t.call("4d user ธรรมดาเข้า API แอดมิน", "GET", "/api/admin/users", 403,
               token=user_token)

        # 5. แก้ผู้ใช้
        if user_id:
            t.call("5 แก้ผู้ใช้", "PUT", f"/api/admin/users/{user_id}", 200,
                   token=token, json={"username": f"qc{sfx}"})
        if admin_id:
            t.call("5b แอดมินลดสิทธิ์ตัวเอง", "PUT", f"/api/admin/users/{admin_id}",
                   400, token=token, json={"role_id": 2})

        # 6. ลบผู้ใช้
        if user_id:
            t.call("6 ลบผู้ใช้", "DELETE", f"/api/admin/users/{user_id}", 200,
                   token=token)
            t.call("6b ดูผู้ใช้ที่ลบแล้ว", "GET", f"/api/admin/users/{user_id}", 404,
                   token=token)
            user_id = None

        # 7. เมนูอาหาร
        food = t.call("7 เพิ่มเมนู", "POST", "/api/admin/foods", 201, token=token,
                      json={"food_name": f"qa_food_{sfx}", "calories_per_100g": 100})
        food_id = (food.get("data") or {}).get("food_id")
        if food_id:
            t.call("7b แก้เมนู", "PUT", f"/api/admin/foods/{food_id}", 200,
                   token=token, json={"calories_per_100g": 120})
            t.call("7c แคลอรี่เกิน 900", "PUT", f"/api/admin/foods/{food_id}", 422,
                   token=token, json={"calories_per_100g": 5000})
        t.call("7d ค้นหาเมนู", "GET", "/api/foods", 200, token=token,
               params={"q": "qa_food"})
        if food_id:
            t.call("7e ลบเมนู", "DELETE", f"/api/admin/foods/{food_id}", 200,
                   token=token)
            food_id = None
    finally:
        # ลบข้อมูลทดสอบที่ค้าง ถ้ามีข้อที่ล้มกลางทาง
        if "token" in locals() and token:
            if user_id:
                t.client.delete(f"/api/admin/users/{user_id}",
                                headers={"Authorization": f"Bearer {token}"})
            if food_id:
                t.client.delete(f"/api/admin/foods/{food_id}",
                                headers={"Authorization": f"Bearer {token}"})

    return 0 if t.summary() else 1


if __name__ == "__main__":
    sys.exit(main())
