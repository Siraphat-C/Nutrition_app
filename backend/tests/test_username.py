import re

from validation import SEARCH_PATTERN, USERNAME_PATTERN, clean_username


def ok(name: str) -> bool:
    return re.fullmatch(USERNAME_PATTERN, clean_username(name)) is not None


def test_thai_and_english_names():
    assert ok("ถิรวัฒน์")
    assert ok("ถิรวัฒน์ วงค์ทอง")
    assert ok("somchai_99")
    assert ok("Nong.Mint")


def test_spaces_are_cleaned():
    assert clean_username("  ถิรวัฒน์   วงค์ทอง ") == "ถิรวัฒน์ วงค์ทอง"


def test_rejects_symbols():
    assert not ok("a,b")
    assert not ok("name(1)")
    assert not ok("hi!")
    assert not ok("😀😀😀")


def test_search_accepts_thai_marks():
    # สระบน-ล่างและวรรณยุกต์ (เช่น ิ ์ ้) ไม่ใช่ตัวอักษรตาม \w จึงต้องรองรับแยก
    assert re.fullmatch(SEARCH_PATTERN, "ถิรวัฒน์")
    assert re.fullmatch(SEARCH_PATTERN, "test@gmail.com")
    assert not re.fullmatch(SEARCH_PATTERN, "a b")
    assert not re.fullmatch(SEARCH_PATTERN, "a,b")
