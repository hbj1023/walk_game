#!/usr/bin/env python3
"""Production account and support smoke test using a disposable user."""

from __future__ import annotations

import datetime as dt
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


BASE_URL = os.environ.get("WALKMASTER_API_BASE_URL", "https://walk-master.com").rstrip("/")
REPORT_DIR = Path(__file__).resolve().parents[1] / "reports" / "playtests"


def request(path: str, payload: dict[str, object], token: str = "") -> tuple[int, dict[str, object]]:
    headers = {"Content-Type": "application/json; charset=utf-8"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(BASE_URL + path, body, headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        try:
            result = json.load(error)
        except json.JSONDecodeError:
            result = {"error": error.read().decode("utf-8", errors="replace")}
        return error.code, result


def check(results: list[dict[str, object]], name: str, actual: int, expected: set[int], body: dict[str, object]) -> None:
    passed = actual in expected
    results.append(
        {
            "name": name,
            "passed": passed,
            "status": actual,
            "expected": sorted(expected),
            "response": body,
        }
    )
    print(f"{'PASS' if passed else 'FAIL'} {name}: HTTP {actual}")


def main() -> int:
    stamp = dt.datetime.now().strftime("%Y%m%d%H%M%S")
    email = f"dlr.release.smoke.{stamp}@example.com"
    password = f"DlrRelease!{stamp}"
    results: list[dict[str, object]] = []

    status, register = request(
        "/register",
        {"email": email, "password": password, "name": "한글테스트"},
    )
    check(results, "한국어 닉네임 회원가입", status, {201}, register)
    token = str(register.get("token", ""))

    status, duplicate = request(
        "/register",
        {"email": email, "password": password, "name": "중복테스트"},
    )
    check(results, "중복 이메일 차단", status, {409}, duplicate)

    status, wrong_password = request(
        "/login",
        {"email": email, "password": password + "-wrong"},
    )
    check(results, "잘못된 비밀번호 차단", status, {400, 401, 403}, wrong_password)

    status, invalid_reset = request(
        "/password-reset/request",
        {"email": "invalid-email"},
    )
    check(results, "잘못된 재설정 이메일 차단", status, {400}, invalid_reset)

    status, empty_report = request(
        "/api/support/bug-reports",
        {"screen": "release-smoke", "message": "   "},
        token,
    )
    check(results, "빈 버그 제보 차단", status, {400}, empty_report)

    status, report = request(
        "/api/support/bug-reports",
        {"screen": "release-smoke", "message": f"자동 배포 전 검증 {stamp}"},
        token,
    )
    check(results, "버그 제보 저장", status, {201}, report)

    status, wrong_delete = request(
        "/api/users/delete-account",
        {"email": email, "password": password + "-wrong"},
        token,
    )
    check(results, "잘못된 비밀번호 계정 삭제 차단", status, {403}, wrong_delete)

    status, deleted = request(
        "/api/users/delete-account",
        {"email": email, "password": password},
        token,
    )
    check(results, "계정 연관 데이터 포함 삭제", status, {200}, deleted)

    status, login_after_delete = request(
        "/login",
        {"email": email, "password": password},
    )
    check(results, "삭제 계정 로그인 차단", status, {400, 401, 403}, login_after_delete)

    report = {
        "base_url": BASE_URL,
        "email": email,
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "passed": all(bool(item["passed"]) for item in results),
        "results": results,
    }
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    output = REPORT_DIR / f"{dt.date.today().isoformat()}-release-account-smoke.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"REPORT {output}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
