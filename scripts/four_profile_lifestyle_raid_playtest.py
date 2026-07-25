#!/usr/bin/env python3
"""Four fresh lifestyle profiles progressing to a real-time four-player raid."""

from __future__ import annotations

import datetime as dt
import json
import msvcrt
import os
import random
import time
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

from live_progression_playtest import ApiError, Runner, SHOP_ID
from three_profile_raid_playtest import (
    BASE,
    RobustApi,
    consumables,
    equip_best_complete_set,
    equip_strongest_weapon,
    equipment_family,
    ensure_healing_potions,
    healing_template,
    highest,
    play_battle,
    register,
    stages,
    sync,
    unwrap_items,
    use_healing_potion,
)


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports" / "playtests"
RUN_NAME = os.environ.get(
    "DLR_PLAYTEST_RUN_NAME",
    "2026-07-23-four-profile-lifestyle-third-run",
)
CHECKPOINT = REPORT_DIR / f"{RUN_NAME}-checkpoint.json"
LIVE_LOG = REPORT_DIR / f"{RUN_NAME}-live.log"
FINAL_JSON = REPORT_DIR / f"{RUN_NAME}-final.json"
FINAL_MD = REPORT_DIR / f"{RUN_NAME}-final.md"
MAX_DAYS = 180
OFFLINE_SYNC_CHUNK_STEPS = 500
OFFLINE_RETURN_DELAY_MINUTES = 30
TWO_PHASE_RAID = os.environ.get("DLR_PLAYTEST_TWO_PHASE_RAID", "") == "1"
MAX_TARGET_STAGE = 15 if TWO_PHASE_RAID else 13
FIRST_RAID_PHASE = "3-3 희귀 장비 17주기 측정"
FINAL_EPIC_RAID_PHASE = "3-5 에픽 장비 최종"
GOLD_MINE_FEATURE = "gold_mine_event"
LOCK_PATH = REPORT_DIR / "four-profile-lifestyle.lock"
_LOCK_HANDLE: Any = None

PROFILES = [
    {
        "key": "offline_returner",
        "label": "오프라인 복귀형",
        "role": "guided",
        "weekday": [("offline_farm", 6500, "18:00"), ("realtime_progress", 2000, "19:30")],
        "weekend": [("offline_farm", 4500, "14:00"), ("realtime_progress", 3500, "17:00")],
        "note": "보관함 복귀 때 10타 이하 안전 스테이지만 파밍하고 저녁에 다음 스테이지 도전",
    },
    {
        "key": "online_attacker",
        "label": "온라인 집중형",
        "role": "attacker",
        "weekday": [("offline_farm", 1200, "08:30"), ("realtime_progress", 7000, "19:00")],
        "weekend": [("realtime_progress", 9000, "16:00")],
        "note": "대부분 온라인 걷기, 공격력과 무기 우선",
    },
    {
        "key": "balanced_guided",
        "label": "균형 공략형",
        "role": "guided",
        "weekday": [("offline_farm", 4200, "18:00"), ("realtime_progress", 3500, "20:00")],
        "weekend": [("offline_farm", 2500, "13:00"), ("realtime_progress", 5500, "17:00")],
        "note": "공격과 생존을 함께 올리고 세트 장비를 우선",
    },
    {
        "key": "free_explorer",
        "label": "자유 탐색형",
        "role": "scavenger",
        "weekday": [("offline_farm", 5000, "18:30"), ("realtime_progress", 2500, "21:00")],
        "weekend": [("offline_farm", 3000, "14:00"), ("realtime_progress", 5000, "18:00")],
        "note": "효율을 모르는 상태로 민첩과 가성비 장비를 자유 선택",
    },
]


def emit(kind: str, **payload: Any) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    line = f"{dt.datetime.now().isoformat(timespec='seconds')} {kind}"
    if payload:
        line += " " + json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    with LIVE_LOG.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")
    print(line, flush=True)


def save(state: dict[str, Any]) -> None:
    CHECKPOINT.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def acquire_single_run_lock() -> None:
    global _LOCK_HANDLE
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    handle = LOCK_PATH.open("a+b")
    handle.seek(0, 2)
    if handle.tell() == 0:
        handle.write(b"0")
        handle.flush()
    handle.seek(0)
    try:
        msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError as exc:
        handle.close()
        raise RuntimeError("four-profile playtest is already running") from exc
    _LOCK_HANDLE = handle


def runner_for(entry: dict[str, Any], seed: int) -> Runner:
    runner = Runner(entry["profile"]["role"], entry["account"], random.Random(seed))
    runner.api = RobustApi(entry["account"]["email"], entry["account"]["password"])
    runner.api.login()
    runner.steps = int(entry.get("steps", 0))
    runner.distance_m = float(entry.get("distance_m", 0))
    return runner


def load_or_create() -> dict[str, Any]:
    if CHECKPOINT.exists():
        state = json.loads(CHECKPOINT.read_text(encoding="utf-8-sig"))
        current = {profile["key"]: profile for profile in PROFILES}
        for entry in state["profiles"]:
            entry["profile"] = current[entry["profile"]["key"]]
            entry.setdefault("clear_hits", {})
            entry.setdefault("clear_hit_max", dict(entry["clear_hits"]))
        return state
    stamp = dt.datetime.now().strftime("%m%d%H%M%S")
    state = {
        "created_at": dt.datetime.now().isoformat(),
        "day": 0,
        "profiles": [],
        "issues": [],
        "raid_attempts": [],
        "feature_checks": [],
    }
    for profile in PROFILES:
        account = register({"key": profile["key"], "label": profile["label"], "strategy": profile["role"]}, stamp)
        state["profiles"].append(
            {
                "profile": profile,
                "account": account,
                "steps": 0,
                "distance_m": 0,
                "days": [],
                "clear_hits": {},
                "clear_hit_max": {},
                "preparations": {},
                "mission_coin": 0,
                "mission_claims": [],
                "ticket_fragments_earned": 0,
                "notification_checks": [],
            }
        )
        emit("ACCOUNT_CREATED", profile=profile["label"], email=account["email"])
    save(state)
    return state


def normalize_slot(value: Any) -> str:
    slot = str(value or "")
    return "sword" if slot == "weapon" else slot


def pocketbase_user_missions(runner: Runner, date: dt.date) -> list[dict[str, Any]]:
    filter_text = f'user="{runner.account["user_id"]}" && mission_date~"{date.isoformat()}"'
    query = urllib.parse.urlencode({
        "filter": filter_text,
        "expand": "mission",
        "perPage": "100",
    })
    request = urllib.request.Request(
        f"{BASE}:8090/api/collections/user_missions/records?{query}",
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {runner.api.token}",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8-sig"))
    return list(payload.get("items", []))


def claim_completed_missions(runner: Runner, entry: dict[str, Any], day: int, date: dt.date) -> dict[str, Any]:
    before_coin = int(runner.main().get("coin_balance", 0) or 0)
    claimed: list[dict[str, Any]] = []
    for mission in pocketbase_user_missions(runner, date):
        if mission.get("status") != "completed":
            continue
        result = runner.api.post(f"/api/user-missions/{mission['id']}/claim", {})
        data = result.get("data", result)
        expanded = mission.get("expand", {}).get("mission", {})
        reward = int(data.get("reward_coin", expanded.get("reward_coin", 0)) or 0)
        claimed.append({
            "id": mission["id"],
            "title": expanded.get("title", ""),
            "reward_coin": reward,
        })
    after_coin = int(runner.main().get("coin_balance", 0) or 0)
    reward_total = sum(item["reward_coin"] for item in claimed)
    if after_coin - before_coin != reward_total:
        raise RuntimeError(
            f"mission coin mismatch: before={before_coin} after={after_coin} rewards={reward_total}"
        )
    entry["mission_coin"] = int(entry.get("mission_coin", 0)) + reward_total
    entry["mission_claims"].extend({"day": day, "date": date.isoformat(), **item} for item in claimed)
    emit(
        "MISSION_CLAIM",
        profile=entry["profile"]["label"],
        day=day,
        count=len(claimed),
        reward_coin=reward_total,
        coin_balance=after_coin,
    )
    return {"count": len(claimed), "reward_coin": reward_total, "coin_balance": after_coin}


def check_notifications(runner: Runner, entry: dict[str, Any], day: int) -> dict[str, Any]:
    count_result = runner.api.get("/api/notifications/unread-count")
    unread = int((count_result.get("data", count_result) or {}).get("unread_count", 0) or 0)
    list_result = runner.api.get("/api/notifications?unreadOnly=true&perPage=100")
    items = unwrap_items(list_result)
    if unread != len(items):
        raise RuntimeError(f"notification unread mismatch: count={unread} list={len(items)}")
    read_result = runner.api.post("/api/notifications/read-all", {})
    updated = int((read_result.get("data", read_result) or {}).get("updated_count", 0) or 0)
    remaining_result = runner.api.get("/api/notifications/unread-count")
    remaining = int((remaining_result.get("data", remaining_result) or {}).get("unread_count", 0) or 0)
    if remaining != 0:
        raise RuntimeError(f"notifications remained unread after read-all: {remaining}")
    check = {"day": day, "unread": unread, "listed": len(items), "updated": updated}
    entry["notification_checks"].append(check)
    emit("NOTIFICATION_CHECK", profile=entry["profile"]["label"], **check)
    return check


def setup_friendships(state: dict[str, Any], runners: list[Runner]) -> None:
    host = runners[0]
    for guest in runners[1:]:
        created = host.api.post("/api/friendships/request", {
            "requesterUserId": host.account["user_id"],
            "targetUserId": guest.account["user_id"],
        })
        created_data = created.get("data", created)
        friendship = created_data.get("friendship", created_data)
        friendship_id = friendship.get("id")
        incoming = unwrap_items(guest.api.get(f"/api/users/{guest.account['user_id']}/friend-requests"))
        if not friendship_id or not any(item.get("id") == friendship_id for item in incoming):
            raise RuntimeError(f"friend request did not appear for {guest.account['name']}")
        guest.api.post(f"/api/friendships/{friendship_id}/accept", {})
        friends = unwrap_items(host.api.get(f"/api/users/{host.account['user_id']}/friends"))
        if not any(
            guest.account["user_id"] in {
                item.get("user_low"),
                item.get("user_high"),
                item.get("friend_user_id"),
            }
            for item in friends
        ):
            raise RuntimeError(f"accepted friendship missing for {guest.account['name']}")
        state["feature_checks"].append({
            "feature": "friendship",
            "guest": guest.account["name"],
            "status": "accepted",
        })
        emit("FRIENDSHIP_CHECK", host=host.account["name"], guest=guest.account["name"])


def item_chapter(name: str) -> int:
    if "채석단" in name or "균열자" in name:
        return 3
    if any(value in name for value in ("모험가", "도적", "광전사", "창술사", "견습기사", "맹독")):
        return 2
    return 1


def inventory_snapshot(runner: Runner) -> list[str]:
    rows = []
    for owned in runner.inventory():
        template = runner.template(owned)
        rows.append(str(template.get("name", "")))
    return sorted(name for name in rows if name)


def preparation(entry: dict[str, Any], target: int, day: int) -> dict[str, Any]:
    key = str(target)
    record = entry["preparations"].get(key)
    if record is None:
        record = {
            "target_stage": target,
            "started_day": day,
            "completed_day": None,
            "farm_clears": 0,
            "farm_stages": {},
            "purchases": [],
            "stat_upgrades": [],
            "attempts": [],
        }
        entry["preparations"][key] = record
    return record


def record_stage_clear(entry: dict[str, Any], stage_no: int, hits: int) -> None:
    key = str(stage_no)
    previous_min = int(entry["clear_hits"].get(key, 999))
    previous_max = int(entry.setdefault("clear_hit_max", {}).get(key, 0))
    entry["clear_hits"][key] = min(previous_min, hits)
    entry["clear_hit_max"][key] = max(previous_max, hits)


def upgrade_stats(runner: Runner, entry: dict[str, Any], target: int, day: int) -> None:
    before_count = len(runner.events)
    runner.upgrade_stats()
    record = preparation(entry, target, day)
    for event in runner.events[before_count:]:
        if event.get("kind") == "stat_upgrade":
            record["stat_upgrades"].append({"day": day, "stat": event.get("stat"), "cost": event.get("cost")})


def equipment_score(role: str, template: dict[str, Any]) -> float:
    attack = float(template.get("base_attack", 0) or 0)
    defense = float(template.get("base_defense", 0) or 0)
    hp = float(template.get("base_hp", 0) or 0)
    agility = float(template.get("base_agility", 0) or 0)
    rarity = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}.get(str(template.get("rarity", "")), 0)
    if role == "attacker":
        return attack * 8 + agility + rarity * 25 + defense
    if role == "guided":
        return attack * 4 + defense * 4 + hp / 10 + agility * 2 + rarity * 30
    return (attack * 3 + defense * 2 + hp / 14 + agility * 5 + rarity * 18)


def equip_best_defensive_set(runner: Runner) -> None:
    grouped: dict[str, dict[str, tuple[float, dict[str, Any]]]] = {}
    for owned in runner.inventory():
        template = runner.template(owned)
        family = equipment_family(str(template.get("name", "")))
        slot = normalize_slot(template.get("equipment_slot"))
        if not family or slot not in {"sword", "helmet", "armor", "shoes"}:
            continue
        score = (
            float(template.get("base_defense", 0) or 0) * 100
            + float(template.get("base_hp", 0) or 0) * 2
            + float(template.get("base_attack", 0) or 0)
        )
        current = grouped.setdefault(family, {}).get(slot)
        if current is None or score > current[0]:
            grouped[family][slot] = (score, owned)
    complete = [
        (sum(value[0] for value in pieces.values()), family, pieces)
        for family, pieces in grouped.items()
        if {"sword", "helmet", "armor", "shoes"}.issubset(pieces)
    ]
    if not complete:
        return
    _, family, pieces = max(complete, key=lambda row: row[0])
    for slot in ("sword", "helmet", "armor", "shoes"):
        try:
            runner.api.post(
                f"/api/characters/{runner.character_id}/equip",
                {"ownedEquipmentId": pieces[slot][1]["id"]},
            )
        except ApiError as exc:
            if "equipment is already equipped" not in str(exc):
                raise
    emit("DEFENSIVE_SET_EQUIPPED", profile=runner.account.get("name"), family=family)


def buy_progression_item(runner: Runner, entry: dict[str, Any], target: int, day: int) -> bool:
    chapter = (target - 1) // 5 + 1
    coins = int(runner.main().get("coin_balance", 0) or 0)
    owned_templates = {
        owned.get("item_template") or runner.template(owned).get("id")
        for owned in runner.inventory()
    }
    candidates = []
    for shop_item in runner.shop_items():
        template = runner.template(shop_item)
        if template.get("item_type") != "equipment" or template.get("id") in owned_templates:
            continue
        name = str(template.get("name", ""))
        price = int(shop_item.get("price_coin", 0) or 0)
        if item_chapter(name) > chapter or not shop_item.get("is_purchase_unlocked", True) or not (0 < price <= coins):
            continue
        score = equipment_score(entry["profile"]["role"], template) - price / 40
        candidates.append((score, shop_item, template))
    if not candidates:
        return False
    _, shop_item, template = max(candidates, key=lambda row: row[0])
    if not runner.buy(shop_item):
        return False
    preparation(entry, target, day)["purchases"].append(
        {"day": day, "item": template.get("name"), "price": shop_item.get("price_coin"), "slot": normalize_slot(template.get("equipment_slot"))}
    )
    emit("PREP_PURCHASE", profile=entry["profile"]["label"], target=target, item=template.get("name"), price=shop_item.get("price_coin"))
    return True


def prepare_for_target(runner: Runner, entry: dict[str, Any], target: int, day: int) -> None:
    upgrade_stats(runner, entry, target, day)
    buy_progression_item(runner, entry, target, day)
    equip_best_complete_set(runner)
    equip_strongest_weapon(runner)
    desired = 3 if target % 5 == 0 else 2
    before = sum(
        int(item.get("quantity", 0) or 0)
        for item in consumables(runner)
        if int(healing_template(item).get("recover_hp", 0) or 0) > 0
    )
    ensure_healing_potions(runner, desired=desired)
    after = sum(
        int(item.get("quantity", 0) or 0)
        for item in consumables(runner)
        if int(healing_template(item).get("recover_hp", 0) or 0) > 0
    )
    if after > before:
        preparation(entry, target, day)["purchases"].append(
            {"day": day, "item": "회복약", "quantity": after - before, "purpose": "다음 스테이지 생존 준비"}
        )
        emit(
            "PREP_POTION",
            profile=entry["profile"]["label"],
            target=target,
            quantity=after - before,
            total=after,
        )
    if buy_progression_item(runner, entry, target, day):
        equip_best_complete_set(runner)
        equip_strongest_weapon(runner)
    if target == 10:
        equip_best_defensive_set(runner)


def safe_farm_stage(entry: dict[str, Any], runner: Runner) -> tuple[dict[str, Any] | None, int]:
    top = highest(runner)
    available = {int(stage.get("stage_no", 0)): stage for stage in stages(runner)}
    known = {int(key): int(value) for key, value in entry.get("clear_hit_max", {}).items()}
    for stage_no in range(top, 0, -1):
        if stage_no % 5 == 0 or known.get(stage_no, 999) > 10:
            continue
        if stage_no in available:
            return available[stage_no], known[stage_no]
    return None, 0


def affordable_farm_stage(entry: dict[str, Any], runner: Runner) -> tuple[dict[str, Any] | None, int]:
    top = highest(runner)
    balance = int(runner.main().get("attack_count_balance", 0) or 0)
    available = {int(stage.get("stage_no", 0)): stage for stage in stages(runner)}
    known = {int(key): int(value) for key, value in entry.get("clear_hit_max", {}).items()}
    for stage_no in range(top, 0, -1):
        expected = known.get(stage_no, 999)
        required = max(expected + 3, int(expected * 1.25 + 0.999))
        if stage_no % 5 == 0 or required > balance:
            continue
        if stage_no in available:
            return available[stage_no], expected
    return None, 0


def farm_once(runner: Runner, entry: dict[str, Any], target: int, day: int, strict_ten: bool) -> dict[str, Any] | None:
    if strict_ten:
        stage, expected = safe_farm_stage(entry, runner)
        if stage is None:
            emit("OFFLINE_FARM_SKIPPED", profile=entry["profile"]["label"], reason="10타 이하 클리어 기록 없음")
            return None
        balance = int(runner.main().get("attack_count_balance", 0) or 0)
        if balance < expected:
            emit("OFFLINE_FARM_SKIPPED", profile=entry["profile"]["label"], reason="예상 타수보다 공격 기회 부족", balance=balance, expected=expected)
            return None
    else:
        stage, _ = affordable_farm_stage(entry, runner)
        if stage is None:
            emit("FARM_SKIPPED", profile=entry["profile"]["label"], reason="보유 공격 기회 안에 끝낼 파밍 기록 없음")
            return None
    outcome = play_battle(runner, stage)
    if outcome.get("result") == "cleared":
        stage_no = int(stage.get("stage_no", 0))
        hits = int(outcome.get("hits", 0) or 0)
        record_stage_clear(entry, stage_no, hits)
        record = preparation(entry, target, day)
        record["farm_clears"] += 1
        record["farm_stages"][str(stage_no)] = int(record["farm_stages"].get(str(stage_no), 0)) + 1
    elif outcome.get("result") == "failed":
        stage_no = int(stage.get("stage_no", 0))
        entry["clear_hits"][str(stage_no)] = 999
        entry.setdefault("clear_hit_max", {})[str(stage_no)] = 999
        emit(
            "FARM_SAFETY_INVALIDATED",
            profile=entry["profile"]["label"],
            stage=stage_no,
            reason="현재 장비와 피해 편차에서 파밍 실패",
        )
    emit("SAFE_FARM" if strict_ten else "FARM", profile=entry["profile"]["label"], target=target, stage=stage.get("stage_no"), outcome=outcome.get("result"), hits=outcome.get("hits"))
    return outcome


def consume_full_offline_storage(
    runner: Runner,
    entry: dict[str, Any],
    target: int,
    day: int,
) -> list[dict[str, Any]]:
    """Model a player opening the app as soon as the full-storage alert arrives."""
    results: list[dict[str, Any]] = []
    emit(
        "OFFLINE_FULL_RETURN",
        profile=entry["profile"]["label"],
        day=day,
        balance=runner.main().get("attack_count_balance"),
    )
    for _ in range(20):
        before = int(runner.main().get("attack_count_balance", 0) or 0)
        if before <= 0:
            break
        outcome = farm_once(runner, entry, target, day, strict_ten=True)
        if outcome is None:
            break
        results.append(outcome)
        after = int(runner.main().get("attack_count_balance", 0) or 0)
        if after >= before:
            raise RuntimeError("offline full-return farming did not consume attack balance")
    emit(
        "OFFLINE_FULL_DRAINED",
        profile=entry["profile"]["label"],
        day=day,
        battles=len(results),
        remaining=runner.main().get("attack_count_balance"),
    )
    return results


def run_offline_session_with_returns(
    runner: Runner,
    entry: dict[str, Any],
    target: int,
    day: int,
    step_count: int,
    captured: dt.datetime,
) -> dict[str, Any]:
    """Split offline walking so every full-storage alert can trigger a return."""
    remaining_steps = step_count
    synced_steps = 0
    chunks: list[dict[str, Any]] = []
    returns: list[dict[str, Any]] = []
    current_time = captured
    was_full = int(runner.main().get("attack_count_balance", 0) or 0) >= 10

    while remaining_steps > 0:
        chunk_steps = min(OFFLINE_SYNC_CHUNK_STEPS, remaining_steps)
        chunk_time = current_time
        result = sync(runner, "offline", chunk_steps, chunk_time)
        current_time = chunk_time + dt.timedelta(minutes=5)
        remaining_steps -= chunk_steps
        synced_steps += chunk_steps
        chunk = {
            "steps": chunk_steps,
            "captured_at": chunk_time.isoformat(),
            "attack_balance": result.get("attack_count_balance"),
            "offline_earned": result.get("offline_attack_count_earned", 0),
            "offline_stored": result.get("offline_attack_count_stored", 0),
            "offline_lost": result.get("offline_attack_count_lost", 0),
        }
        chunks.append(chunk)

        entry["ticket_fragments_earned"] = int(entry.get("ticket_fragments_earned", 0)) + int(
            result.get("boss_ticket_fragment_earned", 0) or 0
        )
        storage_cap = int(result.get("offline_attack_count_cap", 10) or 10)
        balance = int(result.get("attack_count_balance", 0) or 0)
        is_full = balance >= storage_cap
        if not is_full:
            was_full = False
            continue
        if was_full:
            continue
        was_full = True

        return_time = chunk_time + dt.timedelta(minutes=OFFLINE_RETURN_DELAY_MINUTES)
        before = balance
        battles = consume_full_offline_storage(runner, entry, target, day)
        after = int(runner.main().get("attack_count_balance", 0) or 0)
        returns.append(
            {
                "alert_after_steps": synced_steps,
                "alerted_at": chunk_time.isoformat(),
                "returned_at": return_time.isoformat(),
                "balance_before": before,
                "balance_after": after,
                "battles": battles,
            }
        )
        current_time = max(current_time, return_time)
        was_full = after >= storage_cap

    return {
        "type": "offline_farm",
        "steps": step_count,
        "chunks": chunks,
        "full_storage_returns": returns,
        "full_storage_return_count": len(returns),
        "attack_balance": runner.main().get("attack_count_balance"),
        "offline_earned": sum(int(chunk["offline_earned"] or 0) for chunk in chunks),
        "offline_stored": sum(int(chunk["offline_stored"] or 0) for chunk in chunks),
        "offline_lost": sum(int(chunk["offline_lost"] or 0) for chunk in chunks),
    }


def test_gold_mine_event(
    state: dict[str, Any],
    runners: list[Runner],
) -> None:
    """Exercise unlock, milestone rewards, persistence, and the daily guard."""
    if any(
        check.get("feature") == GOLD_MINE_FEATURE
        for check in state.get("feature_checks", [])
    ):
        return

    targets = (100.0, 400.0, 500.0, 600.0)
    started: list[tuple[Runner, float, str, dict[str, Any]]] = []
    for runner, distance in zip(runners, targets):
        before = runner.api.get("/api/events/gold-mine/status").get("data", {})
        if not before.get("unlocked"):
            raise RuntimeError(
                f"gold mine was not unlocked for {runner.account['name']}"
            )
        if before.get("attempted_today"):
            state["feature_checks"].append(
                {
                    "feature": GOLD_MINE_FEATURE,
                    "profile": runner.account["name"],
                    "distance_m": distance,
                    "status": "already_attempted",
                    "before": before,
                }
            )
            continue
        payload = runner.api.post("/api/events/gold-mine/start", {})
        data = payload.get("data", payload)
        run = data.get("run", data)
        run_id = str(run.get("id") or "")
        if not run_id:
            raise RuntimeError(
                f"gold mine start did not return a run id for {runner.account['name']}"
            )
        started.append((runner, distance, run_id, before))
        emit(
            "GOLD_MINE_STARTED",
            profile=runner.account["name"],
            distance_m=distance,
            run_id=run_id,
        )

    if started:
        time.sleep(75)

    for runner, distance, run_id, before in started:
        result_payload = runner.api.post(
            "/api/events/gold-mine/finish",
            {
                "run_id": run_id,
                "distance_m": distance,
                "step_count": max(1, round(distance / 0.75)),
                "max_speed_kmh": 28.8,
            },
        )
        result = result_payload.get("data", result_payload)
        after = runner.api.get("/api/events/gold-mine/status").get("data", {})
        duplicate_rejected = False
        duplicate_error = ""
        try:
            runner.api.post("/api/events/gold-mine/start", {})
        except ApiError as exc:
            duplicate_rejected = True
            duplicate_error = str(exc)
        if not duplicate_rejected:
            raise RuntimeError(
                f"gold mine allowed a second daily entry for {runner.account['name']}"
            )
        state["feature_checks"].append(
            {
                "feature": GOLD_MINE_FEATURE,
                "profile": runner.account["name"],
                "distance_m": distance,
                "status": "verified",
                "before": before,
                "result": result,
                "after": after,
                "duplicate_start_rejected": duplicate_rejected,
                "duplicate_error": duplicate_error,
            }
        )
        emit(
            "GOLD_MINE_VERIFIED",
            profile=runner.account["name"],
            distance_m=distance,
            reward_coin=result.get("reward_coin"),
            reward_stat_exp=result.get("reward_stat_exp"),
            reward_fragments=result.get("reward_ticket_fragments"),
        )
    save(state)


def finish_current_normal_battle(runner: Runner, entry: dict[str, Any], day: int) -> bool:
    current = runner.api.get("/battle/normal/current")
    battle = current.get("battle")
    if not battle:
        return True
    stage_id = str(battle.get("stage") or battle.get("stage_id") or "")
    actual = next((stage for stage in stages(runner) if str(stage.get("id")) == stage_id), None)
    if actual is None:
        raise RuntimeError(f"current normal battle stage was not found: {stage_id}")
    stage_no = int(actual.get("stage_no", 0))
    was_progress_attempt = stage_no == highest(runner) + 1
    outcome = play_battle(runner, actual)
    emit(
        "CURRENT_BATTLE_FINISHED",
        profile=entry["profile"]["label"],
        day=day,
        stage=actual.get("stage_no"),
        result=outcome.get("result"),
        hits=outcome.get("hits"),
    )
    if outcome.get("result") == "cleared":
        hits = int(outcome.get("hits", 0) or 0)
        record_stage_clear(entry, stage_no, hits)
        if was_progress_attempt:
            record = preparation(entry, stage_no, day)
            record["completed_day"] = day
            record["attempts"].append(
                {
                    "day": day,
                    "result": "cleared",
                    "hits": hits,
                    "resumed": True,
                    "final_hp": outcome.get("final_hp"),
                    "monster_hp": outcome.get("monster_hp"),
                }
            )
    return outcome.get("result") != "paused"


def attempt_progress(runner: Runner, entry: dict[str, Any], day: int) -> dict[str, Any] | None:
    if not finish_current_normal_battle(runner, entry, day):
        emit("PROGRESS_WAIT", profile=entry["profile"]["label"], reason="이전 전투 진행 중")
        return None
    top = highest(runner)
    if top >= MAX_TARGET_STAGE:
        return None
    target_no = top + 1
    target = next((stage for stage in stages(runner) if int(stage.get("stage_no", 0)) == target_no and stage.get("is_unlocked")), None)
    if target is None:
        return None
    prepare_for_target(runner, entry, target_no, day)
    current_stats = runner.stats().get("final_stats", {})
    if target_no % 5 == 0:
        minimum_attack = {1: 20, 2: 40, 3: 85}.get((target_no - 1) // 5 + 1, 20)
        if int(current_stats.get("attack", 0) or 0) < minimum_attack:
            emit(
                "PROGRESS_PREP_REQUIRED",
                profile=entry["profile"]["label"],
                target=target_no,
                attack=current_stats.get("attack"),
                minimum_attack=minimum_attack,
                reason="장비와 공격력 준비 후 보스 도전",
            )
            return None
    balance = int(runner.main().get("attack_count_balance", 0) or 0)
    # Battles may span multiple real-life sessions. Requiring a full stored
    # balance made the simulator farm forever because the safe-farm session
    # consumes attacks before progression. A boss ticket is consumed only when
    # the battle is created; later sessions resume that same battle.
    minimum = 1
    if balance < minimum:
        emit("PROGRESS_WAIT", profile=entry["profile"]["label"], target=target_no, balance=balance, minimum=minimum)
        return None
    before = {"stats": runner.stats().get("final_stats", {}), "coins": runner.main().get("coin_balance"), "equipment": inventory_snapshot(runner)}
    outcome = play_battle(runner, target)
    record = preparation(entry, target_no, day)
    record["attempts"].append(
        {
            "day": day,
            "result": outcome.get("result"),
            "hits": outcome.get("hits"),
            "final_hp": outcome.get("final_hp"),
            "monster_hp": outcome.get("monster_hp"),
            "before": before,
        }
    )
    emit("PROGRESS_ATTEMPT", profile=entry["profile"]["label"], target=target_no, day=day, result=outcome.get("result"), hits=outcome.get("hits"), monster_hp=outcome.get("monster_hp"))
    if outcome.get("result") == "cleared":
        record["completed_day"] = day
        record_stage_clear(entry, target_no, int(outcome.get("hits", 0) or 0))
    return outcome


def run_day(state: dict[str, Any], entry: dict[str, Any], runner: Runner, day: int, date: dt.date) -> None:
    plan = entry["profile"]["weekend" if date.weekday() >= 5 else "weekday"]
    day_log = {"day": day, "date": date.isoformat(), "highest_before": highest(runner), "sessions": []}
    for session_type, step_count, clock in plan:
        hour, minute = map(int, clock.split(":"))
        captured = dt.datetime.combine(date, dt.time(hour, minute), dt.timezone(dt.timedelta(hours=9)))
        target = min(MAX_TARGET_STAGE, highest(runner) + 1)
        if session_type == "offline_farm":
            session = run_offline_session_with_returns(
                runner,
                entry,
                target,
                day,
                step_count,
                captured,
            )
            if entry["profile"]["key"] != "offline_returner":
                session["progress"] = attempt_progress(runner, entry, day)
            day_log["sessions"].append(session)
            continue

        sync_type = "offline" if session_type == "offline_farm" else "realtime"
        result = sync(runner, sync_type, step_count, captured)
        session = {
            "type": session_type,
            "steps": step_count,
            "attack_balance": result.get("attack_count_balance"),
            "mission_distance_m": result.get("mission_distance_m"),
            "ticket_fragments_earned": result.get("boss_ticket_fragment_earned", 0),
            "ticket_fragment_balance": result.get("boss_ticket_fragment_balance", 0),
            "offline_earned": result.get("offline_attack_count_earned", 0),
            "offline_stored": result.get("offline_attack_count_stored", 0),
            "offline_lost": result.get("offline_attack_count_lost", 0),
        }
        entry["ticket_fragments_earned"] = int(entry.get("ticket_fragments_earned", 0)) + int(
            result.get("boss_ticket_fragment_earned", 0) or 0
        )
        session["progress"] = attempt_progress(runner, entry, day)
        if session["progress"] and session["progress"].get("result") == "failed":
            session["farm_after_failure"] = farm_once(runner, entry, target, day, strict_ten=False)
        day_log["sessions"].append(session)
    day_log["mission"] = claim_completed_missions(runner, entry, day, date)
    day_log["notifications"] = check_notifications(runner, entry, day)
    day_log["highest_after"] = highest(runner)
    day_log["end"] = {key: runner.main().get(key) for key in ("level", "coin_balance", "stat_exp", "attack_count_balance")}
    entry["days"].append(day_log)
    entry["steps"] = runner.steps
    entry["distance_m"] = runner.distance_m
    emit("DAY_DONE", profile=entry["profile"]["label"], day=day, highest=day_log["highest_after"], level=day_log["end"]["level"])


RAID_FAMILIES = {
    "offline_returner": "채석단 창술사",
    "online_attacker": "채석단 광전사",
    "balanced_guided": "채석단 기사",
    "free_explorer": "채석단 검사",
}


def prepare_raid_gear(state: dict[str, Any], entry: dict[str, Any], runner: Runner) -> bool:
    family = RAID_FAMILIES[entry["profile"]["key"]]
    required = {"sword", "helmet", "armor", "shoes"}
    record = preparation(entry, 99, state["day"])
    for attempt in range(100):
        pieces: dict[str, dict[str, Any]] = {}
        for owned in runner.inventory():
            template = runner.template(owned)
            slot = normalize_slot(template.get("equipment_slot"))
            if family in str(template.get("name", "")) and template.get("rarity") == "rare" and slot in required:
                pieces[slot] = owned
        missing = required - set(pieces)
        if not missing:
            for slot in ("sword", "helmet", "armor", "shoes"):
                try:
                    runner.api.post(f"/api/characters/{runner.character_id}/equip", {"ownedEquipmentId": pieces[slot]["id"]})
                except ApiError as exc:
                    if "equipment is already equipped" not in str(exc):
                        raise
            record["completed_day"] = state["day"]
            emit("RAID_LOADOUT_READY", profile=entry["profile"]["label"], family=family, stats=runner.stats().get("final_stats", {}))
            return True
        coins = int(runner.main().get("coin_balance", 0) or 0)
        choices = []
        for shop_item in runner.shop_items():
            template = runner.template(shop_item)
            slot = normalize_slot(template.get("equipment_slot"))
            price = int(shop_item.get("price_coin", 0) or 0)
            if slot in missing and family in str(template.get("name", "")) and template.get("rarity") == "rare" and shop_item.get("is_purchase_unlocked", True) and 0 < price <= coins:
                choices.append((price, shop_item, template))
        if choices:
            price, shop_item, template = min(choices, key=lambda row: row[0])
            if runner.buy(shop_item):
                record["purchases"].append({"day": state["day"], "item": template.get("name"), "price": price})
                emit("RAID_GEAR_PURCHASE", profile=entry["profile"]["label"], item=template.get("name"), price=price)
            continue
        outcome = farm_once(runner, entry, 99, state["day"], strict_ten=False)
        if outcome is None or outcome.get("result") != "cleared":
            ensure_healing_potions(runner, 3)
            return False
    return False


def run_raid_preparation_day(
    state: dict[str, Any],
    entry: dict[str, Any],
    runner: Runner,
    day: int,
    date: dt.date,
) -> None:
    plan = entry["profile"]["weekend" if date.weekday() >= 5 else "weekday"]
    day_log = {
        "day": day,
        "date": date.isoformat(),
        "highest_before": highest(runner),
        "purpose": "3-3 희귀 장비 레이드 준비",
        "sessions": [],
    }
    for session_type, step_count, clock in plan:
        hour, minute = map(int, clock.split(":"))
        captured = dt.datetime.combine(
            date,
            dt.time(hour, minute),
            dt.timezone(dt.timedelta(hours=9)),
        )
        if session_type == "offline_farm":
            session = run_offline_session_with_returns(
                runner,
                entry,
                99,
                day,
                step_count,
                captured,
            )
            day_log["sessions"].append(session)
            continue

        sync_type = "offline" if session_type == "offline_farm" else "realtime"
        result = sync(runner, sync_type, step_count, captured)
        session = {
            "type": session_type,
            "steps": step_count,
            "attack_balance": result.get("attack_count_balance"),
            "mission_distance_m": result.get("mission_distance_m"),
            "ticket_fragments_earned": result.get("boss_ticket_fragment_earned", 0),
            "ticket_fragment_balance": result.get("boss_ticket_fragment_balance", 0),
            "offline_earned": result.get("offline_attack_count_earned", 0),
            "offline_stored": result.get("offline_attack_count_stored", 0),
            "offline_lost": result.get("offline_attack_count_lost", 0),
        }
        entry["ticket_fragments_earned"] = int(entry.get("ticket_fragments_earned", 0)) + int(
            result.get("boss_ticket_fragment_earned", 0) or 0
        )
        farms = []
        for _ in range(20):
            outcome = farm_once(runner, entry, 99, day, strict_ten=False)
            if outcome is None:
                break
            farms.append(outcome)
            if outcome.get("result") != "cleared":
                break
        session["farms"] = farms
        day_log["sessions"].append(session)
    day_log["mission"] = claim_completed_missions(runner, entry, day, date)
    day_log["notifications"] = check_notifications(runner, entry, day)
    day_log["highest_after"] = highest(runner)
    day_log["end"] = {
        key: runner.main().get(key)
        for key in ("level", "coin_balance", "stat_exp", "attack_count_balance")
    }
    entry["days"].append(day_log)
    entry["steps"] = runner.steps
    entry["distance_m"] = runner.distance_m
    emit(
        "RAID_PREP_DAY_DONE",
        profile=entry["profile"]["label"],
        day=day,
        coins=day_log["end"]["coin_balance"],
    )


def prepare_epic_raid_gear(state: dict[str, Any], entry: dict[str, Any], runner: Runner) -> bool:
    family = "균열자"
    required = {"sword", "helmet", "armor", "shoes"}
    record = preparation(entry, 100, state["day"])
    matching_shop_items = []
    for shop_item in runner.shop_items():
        template = runner.template(shop_item)
        if family in str(template.get("name", "")) and template.get("rarity") == "epic":
            matching_shop_items.append(shop_item)
    if not matching_shop_items:
        issue = (
            f"{entry['profile']['label']}: 3-5 클리어 후에도 균열자 에픽 장비가 "
            "상점 응답에 없어 실제 보유 최강 세트로 두 번째 레이드를 진행함"
        )
        if issue not in state["issues"]:
            state["issues"].append(issue)
        equip_best_complete_set(runner)
        equip_strongest_weapon(runner)
        record["completed_day"] = state["day"]
        emit(
            "EPIC_RAID_LOADOUT_FALLBACK",
            profile=entry["profile"]["label"],
            reason="균열자 에픽 상점 미노출",
            stats=runner.stats().get("final_stats", {}),
        )
        return True
    for _ in range(100):
        pieces: dict[str, dict[str, Any]] = {}
        for owned in runner.inventory():
            template = runner.template(owned)
            slot = normalize_slot(template.get("equipment_slot"))
            if family in str(template.get("name", "")) and template.get("rarity") == "epic" and slot in required:
                pieces[slot] = owned
        missing = required - set(pieces)
        if not missing:
            for slot in ("sword", "helmet", "armor", "shoes"):
                try:
                    runner.api.post(
                        f"/api/characters/{runner.character_id}/equip",
                        {"ownedEquipmentId": pieces[slot]["id"]},
                    )
                except ApiError as exc:
                    if "equipment is already equipped" not in str(exc):
                        raise
            record["completed_day"] = state["day"]
            emit(
                "EPIC_RAID_LOADOUT_READY",
                profile=entry["profile"]["label"],
                family=family,
                stats=runner.stats().get("final_stats", {}),
            )
            return True
        coins = int(runner.main().get("coin_balance", 0) or 0)
        choices = []
        for shop_item in runner.shop_items():
            template = runner.template(shop_item)
            slot = normalize_slot(template.get("equipment_slot"))
            price = int(shop_item.get("price_coin", 0) or 0)
            if (
                slot in missing
                and family in str(template.get("name", ""))
                and template.get("rarity") == "epic"
                and shop_item.get("is_purchase_unlocked", True)
                and 0 < price <= coins
            ):
                choices.append((price, shop_item, template))
        if choices:
            price, shop_item, template = min(choices, key=lambda row: row[0])
            if runner.buy(shop_item):
                record["purchases"].append(
                    {"day": state["day"], "item": template.get("name"), "price": price}
                )
                emit(
                    "EPIC_RAID_GEAR_PURCHASE",
                    profile=entry["profile"]["label"],
                    item=template.get("name"),
                    price=price,
                )
            continue
        outcome = farm_once(runner, entry, 100, state["day"], strict_ten=False)
        if outcome is None or outcome.get("result") != "cleared":
            return False
    return False


def run_raid(
    state: dict[str, Any],
    runners: list[Runner],
    *,
    phase: str = "final",
    max_cycles: int = 40,
    cancel_after_limit: bool = False,
) -> dict[str, Any]:
    monsters = unwrap_items(runners[0].api.get("/api/raid-monsters"))
    monster = next((item for item in monsters if "골렘" in str(item.get("name", "")) and item.get("is_active", True)), None)
    if monster is None:
        raise RuntimeError("active golem was not returned")
    created = runners[0].api.post("/api/raids", {"hostCharacterId": runners[0].character_id, "monsterId": monster["id"], "title": f"4계정 실생활 재검증 ({phase})", "description": "오프라인 가득 참 즉시 복귀 및 3-3/3-5 비교 테스트"})
    raid = created.get("data", created).get("raid", created.get("data", created))
    raid_id = raid["id"]
    invitation_checks = []
    for runner in runners[1:]:
        invite_result = runners[0].api.post(f"/api/raids/{raid_id}/invite", {
            "inviterCharacterId": runners[0].character_id,
            "invitedUserId": runner.account["user_id"],
        })
        invite_data = invite_result.get("data", invite_result)
        invitation = invite_data.get("invitation", invite_data)
        invitation_id = invitation.get("id")
        pending = unwrap_items(
            runner.api.get(f"/api/users/{runner.account['user_id']}/raid-invitations")
        )
        if not invitation_id or not any(item.get("id") == invitation_id for item in pending):
            raise RuntimeError(f"raid invitation did not appear for {runner.account['name']}")
        runner.api.post(
            f"/api/raid-invitations/{invitation_id}/accept",
            {"characterId": runner.character_id},
        )
        remaining = unwrap_items(
            runner.api.get(f"/api/users/{runner.account['user_id']}/raid-invitations")
        )
        if any(item.get("id") == invitation_id for item in remaining):
            raise RuntimeError(f"accepted raid invitation remained for {runner.account['name']}")
        invitation_checks.append({
            "guest": runner.account["name"],
            "invitation_id": invitation_id,
            "status": "accepted",
        })
        emit("RAID_INVITATION_CHECK", guest=runner.account["name"], invitation_id=invitation_id)
    start = runners[0].api.post(f"/api/raids/{raid_id}/start", {"characterId": runners[0].character_id})
    log = {
        "phase": phase,
        "raid_id": raid_id,
        "start": start,
        "cycles": [],
        "invitation_checks": invitation_checks,
    }
    defeated: set[str] = set()
    emit("RAID_STARTED", raid_id=raid_id, participants=4, phase=phase)
    for cycle in range(1, max_cycles + 1):
        for index, runner in enumerate(runners):
            if runner.character_id in defeated:
                continue
            try:
                response = runner.api.post(f"/api/raids/{raid_id}/distance", {"characterId": runner.character_id, "distanceM": 240.0})
            except ApiError as exc:
                if "defeated raid participant" in str(exc):
                    defeated.add(runner.character_id)
                    continue
                raise
            data = response.get("data", response)
            progress = data.get("progress", {})
            event = {
                "cycle": cycle,
                "member": index + 1,
                "status": progress.get("status"),
                "monster_hp": progress.get("monster_current_hp"),
                "attack_cycles": data.get("attack_cycles"),
                "damage": data.get("damage_dealt"),
                "monster_attack_cycles": data.get("monster_attack_cycles"),
                "monster_damage": data.get("monster_damage_dealt"),
                "defeated": data.get("defeated_participants", []),
            }
            defeated.update(str(value) for value in event["defeated"])
            log["cycles"].append(event)
            emit("RAID_DISTANCE", **event)
            if progress.get("status") in {"cleared", "failed", "canceled"}:
                log["final"] = data
                return log
        if cancel_after_limit and cycle == max_cycles:
            canceled = runners[0].api.post(
                f"/api/raids/{raid_id}/leave",
                {"characterId": runners[0].character_id},
            )
            data = canceled.get("data", canceled)
            log["final"] = data
            emit(
                "RAID_MEASUREMENT_CANCELED",
                raid_id=raid_id,
                phase=phase,
                cycle=cycle,
                monster_hp=(data.get("progress", {}) or {}).get("monster_current_hp"),
            )
            return log
        time.sleep(180)
    raise RuntimeError(f"raid did not finish within {max_cycles} cycles")


def summarize_preparation(entry: dict[str, Any]) -> list[dict[str, Any]]:
    rows = []
    for key, record in sorted(entry["preparations"].items(), key=lambda item: int(item[0])):
        if key in {"99", "100"}:
            continue
        completed = record.get("completed_day")
        rows.append(
            {
                "stage": int(key),
                "days": (completed - record["started_day"] + 1) if completed else None,
                "farm_clears": record["farm_clears"],
                "farm_stages": record["farm_stages"],
                "purchases": record["purchases"],
                "stat_upgrades": record["stat_upgrades"],
                "attempts": record["attempts"],
            }
        )
    return rows


def reconcile_preparation_completion_days(entry: dict[str, Any]) -> None:
    """Fill historical completion days that older checkpoints failed to record."""
    records = entry.get("preparations", {})
    ordered_targets = sorted(int(key) for key in records if key != "99")
    for target in ordered_targets:
        record = records[str(target)]
        if record.get("completed_day") is not None:
            continue
        completed_day = next(
            (
                int(day["day"])
                for day in entry.get("days", [])
                if int(day.get("highest_after", 0) or 0) >= target
            ),
            None,
        )
        if completed_day is not None:
            record["completed_day"] = completed_day
            record["completion_source"] = "inferred_from_daily_progress"
            continue
        next_record = records.get(str(target + 1))
        if next_record is None:
            continue
        inferred_day = next_record.get("started_day")
        if inferred_day is None:
            continue
        record["completed_day"] = int(inferred_day)
        record["completion_source"] = "inferred_from_next_stage"


def write_report(state: dict[str, Any], runners: list[Runner], raid: dict[str, Any]) -> None:
    for entry in state["profiles"]:
        reconcile_preparation_completion_days(entry)
    final = raid.get("final", {})
    progress = final.get("progress", {})
    lines = [
        "# 4계정 실생활 진행 및 골렘 레이드 재검증",
        "",
        f"- 공개 서버: {BASE}",
        f"- 최종 가상 진행일: {state['day']}일",
        f"- 레이드 상태: `{progress.get('status')}`",
        f"- 골렘 남은 HP: {progress.get('monster_current_hp')}",
        f"- 레이드 보상: {final.get('reward_coin', 0)}골드",
        "",
        "## 계정별 결과",
        "",
        "| 유형 | 최고 스테이지 | 레벨 | 누적 걸음 | 미션 골드 | 찢어진 입장권 | 최종 골드 | 최종 스탯 |",
        "|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for entry, runner in zip(state["profiles"], runners):
        main = runner.main()
        stats = runner.stats().get("final_stats", {})
        lines.append(f"| {entry['profile']['label']} | {highest(runner)} | {main.get('level')} | {entry['steps']:,} | {main.get('coin_balance')} | HP {stats.get('hp')} / 공 {stats.get('attack')} / 방 {stats.get('defense')} / 민 {stats.get('agility')} |")
    for entry in state["profiles"]:
        lines += ["", f"## {entry['profile']['label']} 준비 기록", "", entry["profile"]["note"], "", "| 목표 | 준비 기간 | 안전 파밍 | 구매 | 스탯 강화 | 도전 결과 |", "|---:|---:|---|---|---|---|"]
        for row in summarize_preparation(entry):
            purchases = ", ".join(str(item["item"]) for item in row["purchases"]) or "없음"
            upgrades = ", ".join(str(item["stat"]) for item in row["stat_upgrades"]) or "없음"
            attempts = ", ".join(f"{item['day']}일 {item['result']} {item.get('hits')}타" for item in row["attempts"]) or "대기"
            farms = ", ".join(f"{stage} {count}회" for stage, count in row["farm_stages"].items()) or "없음"
            lines.append(f"| {row['stage']} | {row['days'] or '미완료'}일 | {farms} | {purchases} | {upgrades} | {attempts} |")
    lines += ["", "## 발견한 문제", ""]
    lines.extend(f"- {issue}" for issue in state.get("issues", []))
    if not state.get("issues"):
        lines.append("- 치명적인 API 오류 없음")
    FINAL_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    FINAL_JSON.write_text(json.dumps({"state": state, "raid": raid}, ensure_ascii=False, indent=2), encoding="utf-8")


def write_readable_report(state: dict[str, Any], runners: list[Runner], raid: dict[str, Any]) -> None:
    for entry in state["profiles"]:
        reconcile_preparation_completion_days(entry)
    final = raid.get("final", {})
    progress = final.get("progress", {})
    lines = [
        "# 4계정 생활형 진행 및 골렘 레이드 검증",
        "",
        f"- 공개 서버: {BASE}",
        f"- 최종 가상 진행일: {state['day']}일",
        f"- 레이드 상태: `{progress.get('status')}`",
        f"- 골렘 잔여 HP: {progress.get('monster_current_hp')}",
        f"- 레이드 보상: {final.get('reward_coin', 0)}골드",
    ]
    if "third-run" in RUN_NAME:
        lines += [
            "- 참고: 3~27일 구간은 기존 테스트 도구의 '공격 기회 10회 이상' 진입 제한으로 진행이 막힌 기간입니다.",
            "  실제 게임 진행 기간이 아니라 테스트 도구 지연이며, 28일차부터 세션 간 전투 이어하기 방식으로 재검증했습니다.",
        ]
    lines += [
        "",
        "## 계정별 결과",
        "",
        "| 유형 | 최고 스테이지 | 레벨 | 누적 걸음 | 미션 골드 | 찢어진 입장권 획득 | 최종 골드 | 최종 스탯 |",
        "|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for entry, runner in zip(state["profiles"], runners):
        main_data = runner.main()
        stats = runner.stats().get("final_stats", {})
        lines.append(
            f"| {entry['profile']['label']} | {highest(runner)} | {main_data.get('level')} | "
            f"{entry['steps']:,} | {entry.get('mission_coin', 0)} | "
            f"{entry.get('ticket_fragments_earned', 0)} | {main_data.get('coin_balance')} | HP {stats.get('hp')} / "
            f"공격 {stats.get('attack')} / 방어 {stats.get('defense')} / 민첩 {stats.get('agility')} |"
        )
    lines += [
        "",
        "## 오프라인 걷기 및 알림",
        "",
        "| 유형 | 계산된 공격 기회 | 실제 보관 | 한도 초과 손실 | 알림 확인일 |",
        "|---|---:|---:|---:|---:|",
    ]
    for entry in state["profiles"]:
        sessions = [
            session
            for day in entry.get("days", [])
            for session in day.get("sessions", [])
        ]
        lines.append(
            f"| {entry['profile']['label']} | "
            f"{sum(int(session.get('offline_earned', 0) or 0) for session in sessions):,} | "
            f"{sum(int(session.get('offline_stored', 0) or 0) for session in sessions):,} | "
            f"{sum(int(session.get('offline_lost', 0) or 0) for session in sessions):,} | "
            f"{len(entry.get('notification_checks', []))} |"
        )
    raid_progress = progress or {}
    started_at = raid_progress.get("started_at")
    ended_at = raid_progress.get("ended_at")
    lines += [
        "",
        "## 골렘 레이드 상세",
        "",
        f"- 진행 시간: {started_at} ~ {ended_at}",
        f"- 합동 공격: {raid_progress.get('total_attack_cycles', 0)}회",
        f"- 골렘 반격: {raid_progress.get('total_monster_attack_cycles', 0)}회",
        f"- 팀 누적 이동: {raid_progress.get('total_distance_accumulated_m', 0):,}m",
        f"- 팀 민첩: {final.get('team_agility', 0)}",
        f"- 사망자: {len(final.get('defeated_participants', []))}명",
        "",
        "| 유형 | 클리어 후 회복 HP | 공격 기여 | 피해 기여 | 이동 기여 |",
        "|---|---:|---:|---:|---:|",
    ]
    try:
        participant_payload = runners[0].api.get(f"/api/raids/{raid['raid_id']}/participants")
        participant_items = participant_payload.get("data", {}).get("items", [])
    except Exception as exc:
        participant_items = []
        state.setdefault("issues", []).append(f"레이드 참가자 상세 조회 실패: {exc!r}")
    for participant in participant_items:
        lines.append(
            f"| {participant.get('character_name')} | "
            f"{participant.get('character_current_hp')} / {participant.get('character_max_hp')} | "
            f"{participant.get('contribution_attack_count')}회 | "
            f"{participant.get('contribution_damage')} | "
            f"{participant.get('contribution_distance_m')}m |"
        )
    if len(state.get("raid_attempts", [])) >= 2:
        lines += [
            "",
            "## 3-3 대비 3-5 레이드 비교",
            "",
            "| 구간 | 장비 | 진행 주기 | 누적 피해 | 골렘 잔여 HP | 상태 | 사망자 |",
            "|---|---|---:|---:|---:|---|---:|",
        ]
        used_epic_fallback = any(
            "균열자 에픽 장비가 상점 응답에 없어" in issue
            for issue in state.get("issues", [])
        )
        second_gear = "실제 보유 최강 혼합 장비" if used_epic_fallback else "균열자 에픽 세트"
        for attempt, gear in zip(
            state["raid_attempts"][-2:],
            ("3장 희귀 세트", second_gear),
        ):
            attempt_progress_data = (attempt.get("final", {}).get("progress", {}) or {})
            attempt_cycles = attempt.get("cycles", [])
            lines.append(
                f"| {attempt.get('phase')} | {gear} | "
                f"{max((int(event.get('cycle', 0) or 0) for event in attempt_cycles), default=0)} | "
                f"{sum(int(event.get('damage', 0) or 0) for event in attempt_cycles):,} | "
                f"{attempt_progress_data.get('monster_current_hp')} | "
                f"{attempt_progress_data.get('status')} | "
                f"{len(attempt.get('final', {}).get('defeated_participants', []))} |"
            )
    for entry in state["profiles"]:
        lines += [
            "",
            f"## {entry['profile']['label']} 준비 기록",
            "",
            entry["profile"]["note"],
            "",
            "| 목표 | 준비 기간 | 안전 파밍 | 구매 | 스탯 강화 | 도전 결과 |",
            "|---:|---:|---|---|---|---|",
        ]
        for row in summarize_preparation(entry):
            purchases = ", ".join(str(item["item"]) for item in row["purchases"]) or "없음"
            upgrades = ", ".join(str(item["stat"]) for item in row["stat_upgrades"]) or "없음"
            attempts = ", ".join(
                f"{item['day']}일 {item['result']} {item.get('hits')}타" for item in row["attempts"]
            ) or "대기"
            farms = ", ".join(
                f"{stage} {count}회" for stage, count in row["farm_stages"].items()
            ) or "없음"
            duration = f"{row['days']}일" if row["days"] is not None else "미완료"
            lines.append(
                f"| {row['stage']} | {duration} | {farms} | {purchases} | {upgrades} | {attempts} |"
            )
    lines += ["", "## 부가기능 검증", ""]
    lines.extend(
        f"- {check.get('feature')}: {check.get('guest', check.get('status', '확인'))}"
        for check in state.get("feature_checks", [])
    )
    lines.append(f"- 레이드 초대 수락: {len(raid.get('invitation_checks', []))}건")
    lines += ["", "## 발견된 문제", ""]
    lines.extend(f"- {issue}" for issue in state.get("issues", []))
    if not state.get("issues"):
        lines.append("- 치명적인 API 오류 없음")
    FINAL_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    FINAL_JSON.write_text(
        json.dumps({"state": state, "raid": raid}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> int:
    acquire_single_run_lock()
    state = load_or_create()
    runners = [runner_for(entry, 20260723 + index) for index, entry in enumerate(state["profiles"])]
    if not any(check.get("feature") == "friendship" for check in state.get("feature_checks", [])):
        setup_friendships(state, runners)
        save(state)
    start_date = dt.date(2026, 7, 23)
    while min(highest(runner) for runner in runners) < 13:
        state["day"] += 1
        if state["day"] > MAX_DAYS:
            raise RuntimeError("180 virtual days passed before all profiles reached 3-3")
        for entry, runner in zip(state["profiles"], runners):
            if highest(runner) < 13:
                profile_day = len(entry["days"]) + 1
                date = start_date + dt.timedelta(days=profile_day - 1)
                try:
                    run_day(state, entry, runner, profile_day, date)
                except Exception as exc:
                    issue = f"{entry['profile']['label']} {profile_day}일: {exc!r}"
                    state["issues"].append(issue)
                    emit("DAY_ERROR", issue=issue)
                    if isinstance(exc, ApiError) and "HTTP 5" not in str(exc):
                        raise
            save(state)
    raid_ready = [False] * len(runners)
    while not all(raid_ready):
        for index, (entry, runner) in enumerate(zip(state["profiles"], runners)):
            if not raid_ready[index]:
                raid_ready[index] = prepare_raid_gear(state, entry, runner)
                save(state)
        if all(raid_ready):
            break
        state["day"] += 1
        if state["day"] > MAX_DAYS:
            raise RuntimeError("180 virtual days passed before all profiles completed rare raid loadouts")
        for index, (entry, runner) in enumerate(zip(state["profiles"], runners)):
            if raid_ready[index]:
                continue
            profile_day = len(entry["days"]) + 1
            date = start_date + dt.timedelta(days=profile_day - 1)
            run_raid_preparation_day(state, entry, runner, profile_day, date)
            save(state)
    test_gold_mine_event(state, runners)
    if TWO_PHASE_RAID:
        first_raid = next(
            (
                attempt
                for attempt in state.get("raid_attempts", [])
                if attempt.get("phase") == FIRST_RAID_PHASE
            ),
            None,
        )
        if first_raid is None:
            first_raid = run_raid(
                state,
                runners,
                phase=FIRST_RAID_PHASE,
                max_cycles=17,
                cancel_after_limit=True,
            )
            state["raid_attempts"].append(first_raid)
            save(state)
        first_status = (first_raid.get("final", {}).get("progress", {}) or {}).get("status")
        if first_status == "cleared":
            state["issues"].append(
                "3-3 희귀 장비 레이드가 8주기 안에 클리어되어 같은 주 3-5 이후 비교가 제한될 수 있음"
            )
        while min(highest(runner) for runner in runners) < 15:
            state["day"] += 1
            if state["day"] > MAX_DAYS:
                raise RuntimeError("180 virtual days passed before all profiles reached 3-5")
            for entry, runner in zip(state["profiles"], runners):
                if highest(runner) < 15:
                    profile_day = len(entry["days"]) + 1
                    date = start_date + dt.timedelta(days=profile_day - 1)
                    try:
                        run_day(state, entry, runner, profile_day, date)
                    except Exception as exc:
                        issue = f"{entry['profile']['label']} {profile_day}일차: {exc!r}"
                        state["issues"].append(issue)
                        emit("DAY_ERROR", issue=issue)
                        if isinstance(exc, ApiError) and "HTTP 5" not in str(exc):
                            raise
                save(state)
        epic_ready = [False] * len(runners)
        while not all(epic_ready):
            for index, (entry, runner) in enumerate(zip(state["profiles"], runners)):
                if not epic_ready[index]:
                    epic_ready[index] = prepare_epic_raid_gear(state, entry, runner)
                    save(state)
            if all(epic_ready):
                break
            state["day"] += 1
            if state["day"] > MAX_DAYS:
                raise RuntimeError("180 virtual days passed before all profiles completed epic raid loadouts")
            for index, (entry, runner) in enumerate(zip(state["profiles"], runners)):
                if epic_ready[index]:
                    continue
                profile_day = len(entry["days"]) + 1
                date = start_date + dt.timedelta(days=profile_day - 1)
                run_raid_preparation_day(state, entry, runner, profile_day, date)
                save(state)
        used_epic_fallback = any(
            "균열자 에픽 장비가 상점 응답에 없어" in issue
            for issue in state.get("issues", [])
        )
        final_phase = (
            "3-5 최강 보유 장비 최종"
            if used_epic_fallback
            else FINAL_EPIC_RAID_PHASE
        )
        raid = run_raid(state, runners, phase=final_phase)
        state["raid_attempts"].append(raid)
        save(state)
        write_readable_report(state, runners, raid)
        emit("TEST_COMPLETE", report=str(FINAL_MD), raid_status=(raid.get("final", {}).get("progress", {}) or {}).get("status"))
        return 0
    while True:
        raid = run_raid(state, runners)
        state["raid_attempts"].append(raid)
        save(state)
        status = (raid.get("final", {}).get("progress", {}) or {}).get("status")
        if status == "cleared":
            break
        emit("RAID_RETRY_REQUIRED", status=status)
        for entry, runner in zip(state["profiles"], runners):
            prepare_raid_gear(state, entry, runner)
    write_readable_report(state, runners, raid)
    emit("TEST_COMPLETE", report=str(FINAL_MD), raid_status="cleared")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
