#!/usr/bin/env python3
"""Multi-day progression test mixing offline daily movement and active play walking."""

from __future__ import annotations

import datetime
import json
import random
import sys
import time
import urllib.request
from pathlib import Path

from live_progression_playtest import ApiError, BASE, Runner


PROFILES = [
    {"key": "low_guided", "strategy": "guided", "style": "공략형", "label": "저활동형 공략", "weekday": (3500, 1000), "weekend": (3000, 2000), "description": "앉아서 근무, 짧은 여가 걷기, 목표 세트 우선"},
    {"key": "low_free", "strategy": "scavenger", "style": "자유형", "label": "저활동형 자유", "weekday": (3500, 1000), "weekend": (3000, 2000), "description": "앉아서 근무, 짧은 여가 걷기, 가격과 즉시 성능으로 선택"},
    {"key": "normal_guided", "strategy": "guided", "style": "공략형", "label": "보통형 공략", "weekday": (5500, 2000), "weekend": (3000, 6000), "description": "일상 이동과 퇴근 후 약 25분 걷기, 목표 세트 우선"},
    {"key": "normal_free", "strategy": "scavenger", "style": "자유형", "label": "보통형 자유", "weekday": (5500, 2000), "weekend": (3000, 6000), "description": "일상 이동과 퇴근 후 약 25분 걷기, 가격과 즉시 성능으로 선택"},
    {"key": "active_guided", "strategy": "guided", "style": "공략형", "label": "활동형 공략", "weekday": (6500, 3500), "weekend": (4000, 8000), "description": "이동량이 많고 퇴근 후 40분 이상 걷기, 목표 세트 우선"},
    {"key": "active_free", "strategy": "scavenger", "style": "자유형", "label": "활동형 자유", "weekday": (6500, 3500), "weekend": (4000, 8000), "description": "이동량이 많고 퇴근 후 40분 이상 걷기, 가격과 즉시 성능으로 선택"},
]
SHOP_ID = "h36hx72gbskptte"
MAX_DAYS = 5


def register(profile, stamp):
    email = f"dlr.lifestyle2.{stamp}.{profile['key']}@example.com"
    password = f"DlrLife2!{stamp}-{profile['key']}"
    body = json.dumps({"email": email, "password": password, "name": profile["label"]}, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(BASE + "/register", body, {"Content-Type": "application/json; charset=utf-8"})
    with urllib.request.urlopen(request) as response:
        result = json.load(response)
    return {"role": profile["strategy"], "email": email, "password": password, "name": profile["label"], "user_id": result["user_id"], "character_id": result["character_id"]}


def sync(runner, sync_type, steps, captured_at):
    result = runner.api.post("/steps/sync", {
        "source_type": "sensor",
        "sync_type": sync_type,
        "step_count": steps,
        "distance_m": 0,
        "stride_m": 0.75,
        "captured_at": captured_at.isoformat(),
        "is_delta": True,
        "gps_distance_m": round(steps * 0.75) if sync_type != "offline" else 0,
        "abnormal_flag": False,
        "abnormal_reason": "",
    })
    runner.steps += steps
    runner.distance_m += round(steps * 0.75)
    return result


def highest_cleared(runner):
    return max([int(s.get("stage_no", 0)) for s in runner.stages() if s.get("is_cleared")], default=0)


def play_day(runner, profile, day, date):
    weekend = date.weekday() >= 5
    offline_steps, online_steps = profile["weekend" if weekend else "weekday"]
    offline = sync(runner, "offline", offline_steps, datetime.datetime.combine(date, datetime.time(17, 30), datetime.timezone.utc))
    realtime = sync(runner, "realtime", online_steps, datetime.datetime.combine(date, datetime.time(19, 0), datetime.timezone.utc))
    before = highest_cleared(runner)
    runner.prepare(before // 5 + 1)
    day_battles = []
    safety = 0
    farming = False
    while int(runner.main().get("attack_count_balance", 0)) > 0 and safety < 8:
        safety += 1
        stages = runner.stages()
        highest = highest_cleared(runner)
        if highest >= 15:
            break
        if farming:
            farm_no = highest
            if farm_no % 5 == 0:
                farm_no -= 1
            target = next((s for s in stages if int(s.get("stage_no", 0)) == farm_no), None)
        else:
            target = next((s for s in stages if int(s.get("stage_no", 0)) == highest + 1 and s.get("is_unlocked")), None)
        if target is None:
            break
        event_index = len(runner.events)
        try:
            success = runner.battle(target, ensure_attacks=False)
        except ApiError as exc:
            if "attack_count_balance is not enough" in str(exc):
                break
            runner.log("lifestyle_battle_error", stage=int(target.get("stage_no", 0)), error=str(exc))
            break
        battle_event = next((e for e in reversed(runner.events[event_index:]) if e["kind"] in ("battle_clear", "battle_fail", "battle_attack_error")), None)
        if battle_event:
            day_battles.append({k: battle_event.get(k) for k in ("kind", "stage", "hits", "final_hp", "monster_hp")})
        if not success:
            # After one progression failure, a real player farms the latest normal stage.
            farming = True
            if int(runner.main().get("attack_count_balance", 0)) < 5:
                break
    return {
        "day": day,
        "date": date.isoformat(),
        "weekend": weekend,
        "offline_steps": offline_steps,
        "online_steps": online_steps,
        "offline_generated": offline.get("offline_attack_count_earned", 0),
        "offline_stored": offline.get("offline_attack_count_stored", 0),
        "offline_lost": offline.get("offline_attack_count_lost", 0),
        "online_earned": realtime.get("attack_count_earned", 0),
        "attack_balance_after_sync": realtime.get("attack_count_balance", 0),
        "highest_before": before,
        "highest_after": highest_cleared(runner),
        "battles": day_battles,
        "end": {k: runner.main().get(k) for k in ("level", "coin_balance", "stat_exp", "attack_count_balance")},
    }


def write_report(results, path):
    lines = [
        "# 현실 생활 패턴 4계정 진행 테스트",
        "",
        f"- 공개 서버: {BASE}",
        "- 오프라인 걸음은 `sync_type=offline`, 여가 걷기는 `sync_type=realtime`로 실제 정산",
        "- 1보=0.75m, 여가 걷기 속도는 약 80m/분으로 환산",
        "- 최대 35일 또는 3장 보스 클리어까지 진행",
        "",
        "## 요약",
        "",
        "| 생활 유형 | 결과 | 소요일 | 총 걸음 | 오프라인 손실 | 최종 레벨 | 최종 골드 |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for result in results:
        lines.append(f"| {result['label']} | {result['highest_cleared']} 스테이지 | {result['days_played']}일 | {result['total_steps']:,} | {result['offline_lost']:,}회 | {result['final_main'].get('level')} | {result['final_main'].get('coin_balance')} |")
    for result in results:
        lines += ["", f"## {result['label']}", "", f"- 생활 패턴: {result['description']}", f"- 최종 스탯: `{json.dumps(result['final_stats'].get('final_stats', {}), ensure_ascii=False)}`", f"- 최종 장비: {', '.join(x['name'] for x in result['final_stats'].get('equipped_items', [])) or '없음'}", "", "| 일차 | 걸음(오프라인/온라인) | 공격 기회(저장/손실/+온라인) | 진행 | 전투 결과 |", "|---:|---:|---:|---:|---|"]
        for day in result["days"]:
            battles = ", ".join(f"{b.get('stage')} {'성공' if b.get('kind') == 'battle_clear' else '실패'} {b.get('hits')}타" for b in day["battles"]) or "전투 없음"
            lines.append(f"| {day['day']} | {day['offline_steps']:,}/{day['online_steps']:,} | {day['offline_stored']}/{day['offline_lost']}/+{day['online_earned']} | {day['highest_before']}→{day['highest_after']} | {battles} |")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    stamp = datetime.datetime.now().strftime("%H%M%S")
    start_date = datetime.date.today()
    results = []
    selected_role = sys.argv[1] if len(sys.argv) > 1 else ""
    selected_profiles = [p for p in PROFILES if not selected_role or p["key"] == selected_role]
    for index, profile in enumerate(selected_profiles):
        account = register(profile, stamp)
        runner = Runner(profile["strategy"], account, random.Random(20260722 + index))
        runner.api.login()
        days = []
        for day in range(1, MAX_DAYS + 1):
            entry = play_day(runner, profile, day, start_date + datetime.timedelta(days=day - 1))
            days.append(entry)
            print(profile["label"], day, entry["highest_after"], flush=True)
            if entry["highest_after"] >= 15:
                break
        final_main = runner.main()
        result = {
            "role": profile["key"], "style": profile["style"], "strategy": profile["strategy"], "label": profile["label"], "description": profile["description"],
            "account": {"email": account["email"], "character_id": account["character_id"]},
            "days_played": len(days), "highest_cleared": highest_cleared(runner), "total_steps": runner.steps,
            "offline_lost": sum(x["offline_lost"] for x in days), "final_main": final_main,
            "final_stats": runner.stats(), "days": days, "events": runner.events,
        }
        results.append(result)
        output = Path(f"reports/playtests/2026-07-22-lifestyle2-{profile['key']}.json")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        write_report(results, output.with_suffix(".md"))


if __name__ == "__main__":
    main()
