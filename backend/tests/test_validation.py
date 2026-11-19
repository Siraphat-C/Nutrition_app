from datetime import date

import pytest

from validation import (
    check_birth_date,
    check_email_length,
    check_password_bytes,
    round_2,
)

TODAY = date(2026, 11, 17)


def test_birth_date_age_limits():
    assert check_birth_date(date(2013, 11, 17), TODAY)          # 13 วันนี้พอดี
    assert check_birth_date(date(1926, 11, 18), TODAY)          # 99
    with pytest.raises(ValueError):
        check_birth_date(date(2013, 11, 18), TODAY)              # 12
    with pytest.raises(ValueError):
        check_birth_date(TODAY, TODAY)                           # เกิดวันนี้
    with pytest.raises(ValueError):
        check_birth_date(date(1900, 1, 1), TODAY)                # 126


def test_password_bytes():
    assert check_password_bytes("a" * 72)
    with pytest.raises(ValueError):
        check_password_bytes("a" * 73)
    assert check_password_bytes("ก" * 24)                        # 72 ไบต์
    with pytest.raises(ValueError):
        check_password_bytes("ก" * 25)                           # 75 ไบต์


def test_email_length():
    assert check_email_length("a" * 90 + "@test.com")             # 99
    with pytest.raises(ValueError):
        check_email_length("a" * 92 + "@test.com")                 # 101


def test_round_2():
    assert round_2(399.999) == 400.0
    assert round_2(0.001) == 0.0
    assert round_2(None) is None
