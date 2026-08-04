#!/usr/bin/env python3
"""Run three realistic lifestyle profiles through progression and a live raid."""

from __future__ import annotations

import datetime as dt
import json
import random
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from live_progression_playtest import Api, ApiError, BASE, Runner


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports" / "playtests"
CHECKPOINT = REPORT_DIR / "2026-07-22-three-profile-raid-checkpoint.json"
FINAL_JSON = REPORT_DIR / "2026-07-22-three-profile-raid-final.json"
FINAL_MD = REPORT_DIR / "2026-07-22-three-profile-raid-final.md"
LOG = REPORT_DIR / "2026-07-22-three-profile-raid-live.log"
MAX_DAYS = 180
STEP_M = 0.75

PROFILES = [
    {
        "key": "notification_returner",
        "label": "알림 복귀형",
        "strategy": "guided",
        "weekday": [("offline", 2600, "08:30"), ("offline", 2600, "12:30"), ("offline", 1300, "18:00"), ("realtime", 1000, "19:00")],
        "weekend": [("offline", 2500, "11:00"), ("offline", 2500, "15:00"), ("realtime", 3000, "19:00")],
        "note": "보관함 알림을 받으면 30분 안에 접속해 공격을 쓰고 다시 오프라인 걷기",
    },
    {
        "key": "online_heavy",
        "label": "온라인 위주형",
        "strategy": "attacker",
        "weekday": [("offline", 1800, "08:30"), ("realtime", 6500, "19:00")],
        "weekend": [("offline", 1000, "11:00"), ("realtime", 9000, "16:00")],
        "note": "퇴근 후 걷기 대부분을 앱을 켠 상태로 진행",
    },
    {
        "key": "mixed_normal",
        "label": "일반 혼합형",
        "strategy": "guided",
        "weekday": [("offline", 5500, "18:00"), ("realtime", 2000, "19:30")],
        "weekend": [("offline", 3000, "14:00"), ("realtime", 5000, "18:00")],
        "note": "출퇴근은 오프라인, 저녁에 한 번 정산하고 플레이",
    },
]


def emit(message: str, **data: Any) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    line = f"{dt.datetime.now().isoformat(timespec='seconds')} {message}"
    if data:
        line += " " + json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    with LOG.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")
    print(line, flush=True)


class RobustApi(Api):
    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        last: Exception | None = None
        refreshed = False
        for attempt, delay in enumerate((0, 2, 5, 10, 20), start=1):
            if delay:
                time.sleep(delay)
            try:
                return super().request(method, path, body)
            except ApiError as exc:
                last = exc
                text = str(exc)
                if "HTTP 401" in text and path != "/login" and not refreshed:
                    self.token = ""
                    login = super().request(
                        "POST",
                        "/login",
                        {"email": self.email, "password": self.password},
                    )
                    self.token = login["token"]
                    refreshed = True
                    emit("API_REAUTH", method=method, path=path, attempt=attempt)
                    continue
                if not any(f"HTTP {code}" in text for code in (500, 502, 503, 504)):
                    raise
                emit("API_RETRY", method=method, path=path, attempt=attempt, error=text)
            except (TimeoutError, urllib.error.URLError) as exc:
                last = exc
                emit("API_RETRY", method=method, path=path, attempt=attempt, error=repr(exc))
        raise ApiError(f"{method} {path}: retries exhausted: {last!r}")


def register(profile: dict[str, Any], stamp: str) -> dict[str, Any]:
    email = f"dlr.raid3.{stamp}.{profile['key']}@example.com"
    password = f"DlrRaid3!{stamp}-{profile['key']}"
    api = RobustApi(email, password)
    result = api.post("/register", {"email": email, "password": password, "name": profile["label"]})
    return {
        "role": profile["strategy"], "email": email, "password": password,
        "name": profile["label"], "user_id": result["user_id"], "character_id": result["character_id"],
    }


def stages(runner: Runner) -> list[dict[str, Any]]:
    return runner.stages()


def highest(runner: Runner) -> int:
    return max((int(x.get("stage_no", 0)) for x in stages(runner) if x.get("is_cleared")), default=0)


def sync(runner: Runner, sync_type: str, steps: int, when: dt.datetime) -> dict[str, Any]:
    result = runner.api.post("/steps/sync", {
        "source_type": "sensor", "sync_type": sync_type, "step_count": steps,
        "distance_m": round(steps * STEP_M), "stride_m": STEP_M,
        "captured_at": when.astimezone(dt.timezone.utc).isoformat(), "is_delta": True,
        "gps_distance_m": round(steps * STEP_M) if sync_type == "realtime" else 0,
        "abnormal_flag": False, "abnormal_reason": "",
    })
    runner.steps += steps
    runner.distance_m += round(steps * STEP_M)
    return result


def battle_status(data: dict[str, Any]) -> tuple[str, int]:
    battle = data.get("battle") or data
    status = str(battle.get("status") or data.get("battle_status") or data.get("status") or "").lower()
    return status, int(battle.get("monster_current_hp", 0) or 0)


def consumables(runner: Runner) -> list[dict[str, Any]]:
    response = runner.api.get(f"/api/characters/{runner.character_id}/consumables")
    return unwrap_items(response)


def healing_template(item: dict[str, Any]) -> dict[str, Any]:
    return item.get("expand", {}).get("item_template", {}) or item.get("item_template_data", {})


def ensure_healing_potions(runner: Runner, desired: int = 2) -> None:
    owned = consumables(runner)
    quantity = sum(int(x.get("quantity", 0) or 0) for x in owned if float(healing_template(x).get("recover_hp", 0) or 0) > 0)
    if quantity >= desired:
        return
    coins = int(runner.main().get("coin_balance", 0))
    candidates = []
    for shop_item in runner.shop_items():
        template = runner.template(shop_item)
        recover = int(template.get("recover_hp", 0) or 0)
        price = int(shop_item.get("price_coin", 0) or 0)
        if recover > 0 and 0 < price <= coins and shop_item.get("is_purchase_unlocked", True):
            candidates.append((price, -recover, shop_item))
    if not candidates:
        return
    candidates.sort(key=lambda row: (row[0], row[1]))
    item = candidates[0][2]
    quantity_to_buy = min(desired - quantity, max(1, coins // max(1, int(item.get("price_coin", 1)))))
    try:
        runner.api.post(f"/api/shops/h36hx72gbskptte/purchase", {
            "characterId": runner.character_id, "shopItemId": item["id"], "offerId": "", "quantity": quantity_to_buy,
        })
        emit("POTION_PURCHASE", profile=runner.account.get("name"), quantity=quantity_to_buy, item=runner.template(item).get("name"))
    except ApiError as exc:
        emit("POTION_PURCHASE_ERROR", profile=runner.account.get("name"), error=str(exc))


def equipment_family(name: str) -> str:
    for family in ("균열자", "채석단 도적", "채석단 검사", "채석단 광전사", "채석단 창술사", "채석단 기사",
                   "맹독 암살자", "모험가", "도적", "광전사", "창술사", "견습기사"):
        if family in name:
            return family
    return ""


def equip_best_complete_set(runner: Runner) -> None:
    grouped: dict[str, dict[str, tuple[float, dict[str, Any]]]] = {}
    rarity_score = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}
    for owned in runner.inventory():
        template = runner.template(owned)
        name = str(template.get("name", ""))
        family = equipment_family(name)
        slot = str(template.get("equipment_slot", ""))
        if not family or slot not in {"sword", "weapon", "helmet", "armor", "shoes"}:
            continue
        if slot == "weapon":
            slot = "sword"
        score = (
            rarity_score.get(str(template.get("rarity", "")), 0) * 1000
            + float(template.get("base_attack", 0) or 0) * 5
            + float(template.get("base_defense", 0) or 0) * 4
            + float(template.get("base_hp", 0) or 0)
            + float(template.get("base_agility", 0) or 0) * 2
        )
        current = grouped.setdefault(family, {}).get(slot)
        if current is None or score > current[0]:
            grouped[family][slot] = (score, owned)
    complete = [(sum(value[0] for value in pieces.values()), family, pieces) for family, pieces in grouped.items()
                if {"sword", "helmet", "armor", "shoes"}.issubset(pieces)]
    if not complete:
        return
    _, family, pieces = max(complete, key=lambda row: row[0])
    for slot in ("sword", "helmet", "armor", "shoes"):
        owned = pieces[slot][1]
        try:
            runner.api.post(f"/api/characters/{runner.character_id}/equip", {"ownedEquipmentId": owned["id"]})
        except ApiError as exc:
            if "equipment is already equipped" in str(exc):
                continue
            emit("SET_EQUIP_ERROR", profile=runner.account.get("name"), family=family, slot=slot, error=str(exc))
            return
    emit("SET_EQUIPPED", profile=runner.account.get("name"), family=family)


def equip_strongest_weapon(runner: Runner) -> None:
    """Adapt to a damage check while retaining the equipped three-piece armor set."""
    candidates: list[tuple[float, dict[str, Any], dict[str, Any]]] = []
    rarity_score = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}
    for owned in runner.inventory():
        template = runner.template(owned)
        if str(template.get("equipment_slot", "")) not in {"sword", "weapon"}:
            continue
        score = (
            float(template.get("base_attack", 0) or 0) * 100
            + rarity_score.get(str(template.get("rarity", "")), 0)
        )
        candidates.append((score, owned, template))
    if not candidates:
        return
    _, owned, template = max(candidates, key=lambda row: row[0])
    try:
        runner.api.post(
            f"/api/characters/{runner.character_id}/equip",
            {"ownedEquipmentId": owned["id"]},
        )
    except ApiError as exc:
        if "equipment is already equipped" not in str(exc):
            emit("WEAPON_EQUIP_ERROR", profile=runner.account.get("name"), error=str(exc))
            return
    emit(
        "STRONGEST_WEAPON_EQUIPPED",
        profile=runner.account.get("name"),
        item=template.get("name"),
        attack=template.get("base_attack"),
    )


def buy_attack_upgrade(runner: Runner) -> bool:
    top = highest(runner)
    current_attack = max(
        (
            int(runner.template(item).get("base_attack", 0) or 0)
            for item in runner.inventory()
            if str(runner.template(item).get("equipment_slot", "")) in {"sword", "weapon"}
        ),
        default=0,
    )
    coins = int(runner.main().get("coin_balance", 0) or 0)
    candidates = []
    for shop_item in runner.shop_items():
        template = runner.template(shop_item)
        if str(template.get("equipment_slot", "")) not in {"sword", "weapon"}:
            continue
        name = str(template.get("name", ""))
        # A chapter-3 shop unlock leak exists on the server. Do not exploit it
        # before clearing chapter 2 in this progression test.
        if top < 10 and ("채석단" in name or "균열자" in name):
            continue
        attack = int(template.get("base_attack", 0) or 0)
        price = int(shop_item.get("price_coin", 0) or 0)
        if (
            attack > current_attack
            and 0 < price <= coins
            and shop_item.get("is_purchase_unlocked", True)
        ):
            candidates.append((attack, -price, shop_item, template))
    if not candidates:
        return False
    attack, _, shop_item, template = max(candidates, key=lambda row: (row[0], row[1]))
    runner.api.post(
        "/api/shops/h36hx72gbskptte/purchase",
        {
            "characterId": runner.character_id,
            "shopItemId": shop_item["id"],
            "offerId": "",
            "quantity": 1,
        },
    )
    emit(
        "WEAPON_UPGRADE_PURCHASED",
        profile=runner.account.get("name"),
        item=template.get("name"),
        attack=attack,
        price=shop_item.get("price_coin"),
    )
    return True


def use_healing_potion(runner: Runner) -> dict[str, Any] | None:
    choices = []
    for item in consumables(runner):
        template = healing_template(item)
        if int(item.get("quantity", 0) or 0) > 0 and float(template.get("recover_hp", 0) or 0) > 0:
            choices.append((int(template.get("recover_hp", 0)), template.get("id"), template.get("name")))
    if not choices:
        return None
    choices.sort()
    _, template_id, name = choices[0]
    result = runner.api.post(f"/api/characters/{runner.character_id}/consumables/use", {
        "itemTemplateId": template_id, "useQuantity": 1,
    })
    data = result.get("data", result)
    emit("POTION_USED", profile=runner.account.get("name"), item=name, recovered=data.get("recovered_hp"))
    return data


def play_battle(runner: Runner, target: dict[str, Any]) -> dict[str, Any]:
    stage_no = int(target.get("stage_no", 0))
    is_boss = bool(target.get("is_boss")) or stage_no % 5 == 0
    prefix = "/battle/boss" if is_boss else "/battle/normal"
    result: dict[str, Any]
    resumed = False
    if not is_boss:
        current = runner.api.get("/battle/normal/current")
        if current.get("battle"):
            result = current
            resumed = True
        else:
            result = runner.api.post(prefix + "/start", {
                "character_id": runner.character_id, "stage_id": target["id"], "stage_no": stage_no,
            })
    else:
        result = runner.api.post(prefix + "/start", {
            "character_id": runner.character_id, "stage_id": target["id"], "stage_no": stage_no,
        })
    battle = result.get("battle") or result
    battle_id = result.get("battle_id") or battle.get("id") or result.get("id")
    hit_log: list[dict[str, Any]] = []
    while len(hit_log) < 60:
        status, monster_hp = battle_status(result)
        if status in {"cleared", "finished", "failed", "defeated", "won", "lost", "win", "lose"}:
            break
        if int(runner.main().get("attack_count_balance", 0)) <= 0:
            return {"result": "paused", "stage": stage_no, "hits": len(hit_log), "resumed": resumed, "monster_hp": monster_hp}
        state = result.get("battle") or result
        current_hp = int(state.get("character_current_hp", 0) or 0)
        max_hp = int(result.get("character_max_hp", 0) or runner.stats().get("final_stats", {}).get("hp", 0) or 0)
        if current_hp > 0 and max_hp > 0 and current_hp <= max_hp * 0.40:
            try:
                potion_result = use_healing_potion(runner)
                if potion_result:
                    if potion_result.get("battle"):
                        result = {**result, "battle": potion_result["battle"]}
                    elif not is_boss:
                        current = runner.api.get("/battle/normal/current")
                        if current.get("battle"):
                            result = current
            except ApiError as exc:
                emit("POTION_USE_ERROR", profile=runner.account.get("name"), stage=stage_no, error=str(exc))
        try:
            result = runner.api.post(prefix + "/attack", {"battle_id": battle_id})
        except ApiError as exc:
            if "attack_count_balance is not enough" in str(exc):
                return {"result": "paused", "stage": stage_no, "hits": len(hit_log), "resumed": resumed, "error": str(exc)}
            raise
        state = result.get("battle") or result
        hit_log.append({
            "dealt": result.get("player_damage", 0), "received": result.get("monster_damage", 0),
            "player_hp": state.get("character_current_hp"), "monster_hp": state.get("monster_current_hp"),
        })
    status, monster_hp = battle_status(result)
    cleared = status in {"cleared", "finished", "won", "win"} and monster_hp <= 0
    return {
        "result": "cleared" if cleared else "failed", "stage": stage_no, "hits": len(hit_log),
        "resumed": resumed, "monster_hp": monster_hp,
        "final_hp": (result.get("battle") or result).get("character_current_hp"), "hit_log": hit_log,
    }


def spend_session(runner: Runner, progress_only: bool = False) -> list[dict[str, Any]]:
    outcomes: list[dict[str, Any]] = []
    chapter = highest(runner) // 5 + 1
    runner.prepare(chapter)
    equip_best_complete_set(runner)
    if highest(runner) >= 9:
        buy_attack_upgrade(runner)
        equip_strongest_weapon(runner)
    # At a boss damage check, reserve gold for a permanent weapon upgrade.
    # Repeated potion purchases otherwise create a progression deadlock.
    if highest(runner) % 5 != 4:
        ensure_healing_potions(runner)
    for _ in range(12):
        if int(runner.main().get("attack_count_balance", 0)) <= 0:
            break
        available = stages(runner)
        top = highest(runner)
        if top >= 13:
            break
        target = next((x for x in available if int(x.get("stage_no", 0)) == top + 1 and x.get("is_unlocked")), None)
        if target is None:
            break
        target_no = int(target.get("stage_no", 0))
        if target_no % 5 == 0 and int(runner.main().get("attack_count_balance", 0)) < 24:
            # Do not waste a boss attempt that cannot physically finish before
            # the stored attacks run out. Save realtime attacks for later.
            outcomes.append({"result": "boss_waiting_for_attacks", "stage": target_no})
            break
        try:
            outcome = play_battle(runner, target)
        except ApiError as exc:
            outcome = {"result": "api_error", "stage": int(target.get("stage_no", 0)), "error": str(exc)}
            outcomes.append(outcome)
            if "already in progress" in str(exc) or "attack_count_balance is not enough" in str(exc):
                break
            raise
        outcomes.append(outcome)
        if outcome["result"] == "paused":
            break
        if outcome["result"] == "failed":
            # After a progression loss, spend the remaining attacks on the
            # latest cleared normal stage. This mirrors a player farming 2-3
            # times for gold/EXP instead of repeatedly entering the same boss.
            for repeat in range(3):
                if int(runner.main().get("attack_count_balance", 0)) <= 0:
                    break
                farm_outcome = None
                for farm_no in range(highest(runner), 0, -1):
                    if farm_no % 5 == 0:
                        continue
                    farm = next((x for x in stages(runner) if int(x.get("stage_no", 0)) == farm_no), None)
                    if farm is None:
                        continue
                    try:
                        candidate = play_battle(runner, farm)
                        candidate["farming"] = True
                        candidate["repeat"] = repeat + 1
                        outcomes.append(candidate)
                        farm_outcome = candidate
                    except ApiError as exc:
                        outcomes.append({"result": "api_error", "stage": farm_no, "farming": True, "error": str(exc)})
                        break
                    if candidate["result"] == "cleared" or candidate["result"] == "paused":
                        break
                if farm_outcome is None or farm_outcome["result"] != "cleared":
                    break
            break
        if progress_only and highest(runner) >= 10:
            break
        runner.prepare(highest(runner) // 5 + 1)
        equip_best_complete_set(runner)
        if highest(runner) >= 9:
            buy_attack_upgrade(runner)
            equip_strongest_weapon(runner)
    return outcomes


def save(state: dict[str, Any]) -> None:
    CHECKPOINT.parent.mkdir(parents=True, exist_ok=True)
    CHECKPOINT.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def load_or_create() -> dict[str, Any]:
    if CHECKPOINT.exists():
        state = json.loads(CHECKPOINT.read_text(encoding="utf-8-sig"))
        current_profiles = {profile["key"]: profile for profile in PROFILES}
        for entry in state.get("profiles", []):
            key = entry.get("profile", {}).get("key")
            if key in current_profiles:
                entry["profile"] = current_profiles[key]
        return state
    stamp = dt.datetime.now().strftime("%m%d%H%M%S")
    state = {"created_at": dt.datetime.now().isoformat(), "day": 0, "profiles": [], "issues": [], "raid": {}}
    for profile in PROFILES:
        account = register(profile, stamp)
        state["profiles"].append({"profile": profile, "account": account, "days": [], "steps": 0, "distance_m": 0})
        emit("ACCOUNT_CREATED", profile=profile["label"], email=account["email"])
    save(state)
    return state


def runner_for(entry: dict[str, Any], seed: int) -> Runner:
    runner = Runner(entry["profile"]["strategy"], entry["account"], random.Random(seed))
    runner.api = RobustApi(entry["account"]["email"], entry["account"]["password"])
    runner.api.login()
    runner.steps = int(entry.get("steps", 0))
    runner.distance_m = float(entry.get("distance_m", 0))
    return runner


def play_progression(state: dict[str, Any]) -> list[Runner]:
    runners = [runner_for(entry, 20260722 + i) for i, entry in enumerate(state["profiles"])]
    start_date = dt.date(2026, 7, 22)
    while min(highest(r) for r in runners) < 13:
        state["day"] += 1
        if state["day"] > MAX_DAYS:
            raise RuntimeError("90 virtual days passed before all accounts reached the raid prerequisite")
        date = start_date + dt.timedelta(days=state["day"] - 1)
        for index, (entry, runner) in enumerate(zip(state["profiles"], runners)):
            plan = entry["profile"]["weekend" if date.weekday() >= 5 else "weekday"]
            day_log = {"day": state["day"], "date": date.isoformat(), "sessions": [], "highest_before": highest(runner)}
            for session_index, (sync_type, step_count, clock) in enumerate(plan):
                hour, minute = map(int, clock.split(":"))
                when = dt.datetime.combine(date, dt.time(hour, minute), dt.timezone(dt.timedelta(hours=9)))
                sync_result = sync(runner, sync_type, step_count, when)
                session = {
                    "sync_type": sync_type, "steps": step_count, "clock": clock,
                    "attack_balance": sync_result.get("attack_count_balance"),
                    "offline_earned": sync_result.get("offline_attack_count_earned", 0),
                    "offline_stored": sync_result.get("offline_attack_count_stored", 0),
                    "offline_lost": sync_result.get("offline_attack_count_lost", 0),
                }
                if entry["profile"]["key"] == "notification_returner" and sync_type == "offline":
                    session["notification_return_minutes"] = 24 + session_index * 2
                    emit("STORAGE_NOTIFICATION_RETURN", profile=entry["profile"]["label"], day=state["day"], minutes=session["notification_return_minutes"], balance=session["attack_balance"])
                session["battles"] = spend_session(runner)
                day_log["sessions"].append(session)
            day_log["highest_after"] = highest(runner)
            day_log["end"] = {k: runner.main().get(k) for k in ("level", "coin_balance", "stat_exp", "attack_count_balance")}
            entry["days"].append(day_log)
            entry["steps"] = runner.steps
            entry["distance_m"] = runner.distance_m
            emit("DAY_DONE", profile=entry["profile"]["label"], day=state["day"], highest=day_log["highest_after"], level=day_log["end"]["level"])
            save(state)
    if min(highest(r) for r in runners) < 10:
        state.setdefault("issues", []).append(
            "자유 구매형 2개 계정은 혼합 장비로 세트 효과를 받지 못해 2장 진행이 장기간 정체됨"
        )
        save(state)
    return runners


def unwrap_items(response: Any) -> list[dict[str, Any]]:
    if isinstance(response, list):
        return response
    data = response.get("data", response) if isinstance(response, dict) else {}
    if isinstance(data, list):
        return data
    return data.get("items", []) if isinstance(data, dict) else []


def prepare_raid_loadouts(state: dict[str, Any], runners: list[Runner]) -> None:
    families = {
        "notification_returner": "채석단 창술사",
        "online_heavy": "채석단 광전사",
        "mixed_normal": "채석단 기사",
    }
    required_slots = {"sword", "helmet", "armor", "shoes"}
    for entry, runner in zip(state["profiles"], runners):
        family = families[entry["profile"]["key"]]
        for attempt in range(80):
            owned_slots = set()
            for owned in runner.inventory():
                template = runner.template(owned)
                slot = str(template.get("equipment_slot", ""))
                if slot == "weapon":
                    slot = "sword"
                if family in str(template.get("name", "")) and template.get("rarity") == "rare":
                    owned_slots.add(slot)
            missing = required_slots - owned_slots
            if not missing:
                break
            coins = int(runner.main().get("coin_balance", 0) or 0)
            purchases = []
            for shop_item in runner.shop_items():
                template = runner.template(shop_item)
                slot = str(template.get("equipment_slot", ""))
                if slot == "weapon":
                    slot = "sword"
                price = int(shop_item.get("price_coin", 0) or 0)
                if (
                    slot in missing
                    and family in str(template.get("name", ""))
                    and template.get("rarity") == "rare"
                    and shop_item.get("is_purchase_unlocked", True)
                    and 0 < price <= coins
                ):
                    purchases.append((price, shop_item, template))
            if purchases:
                price, shop_item, template = min(purchases, key=lambda row: row[0])
                runner.api.post(
                    "/api/shops/h36hx72gbskptte/purchase",
                    {
                        "characterId": runner.character_id,
                        "shopItemId": shop_item["id"],
                        "offerId": "",
                        "quantity": 1,
                    },
                )
                emit("RAID_GEAR_PURCHASED", profile=entry["profile"]["label"], item=template.get("name"), price=price)
                continue
            if int(runner.main().get("attack_count_balance", 0) or 0) <= 0:
                break
            outcome = None
            farm_stage = None
            for stage_no in (13, 12, 11):
                stage = next((x for x in stages(runner) if int(x.get("stage_no", 0)) == stage_no), None)
                if stage is None:
                    continue
                candidate = play_battle(runner, stage)
                if candidate.get("result") == "cleared":
                    outcome = candidate
                    farm_stage = stage_no
                    break
            emit(
                "RAID_GEAR_FARM",
                profile=entry["profile"]["label"],
                attempt=attempt + 1,
                stage=farm_stage,
                result=(outcome or {}).get("result", "failed"),
                hits=(outcome or {}).get("hits"),
            )
            if outcome is None:
                break
        family_pieces: dict[str, dict[str, Any]] = {}
        for owned in runner.inventory():
            template = runner.template(owned)
            slot = str(template.get("equipment_slot", ""))
            if slot == "weapon":
                slot = "sword"
            if (
                slot in required_slots
                and family in str(template.get("name", ""))
                and template.get("rarity") == "rare"
            ):
                family_pieces[slot] = owned
        for slot in ("sword", "helmet", "armor", "shoes"):
            owned = family_pieces.get(slot)
            if owned is None:
                continue
            try:
                runner.api.post(
                    f"/api/characters/{runner.character_id}/equip",
                    {"ownedEquipmentId": owned["id"]},
                )
            except ApiError as exc:
                if "equipment is already equipped" not in str(exc):
                    raise
        final_stats = runner.stats().get("final_stats", {})
        emit("RAID_LOADOUT_READY", profile=entry["profile"]["label"], family=family, stats=final_stats)


def run_raid(state: dict[str, Any], runners: list[Runner]) -> dict[str, Any]:
    monsters = unwrap_items(runners[0].api.get("/api/raid-monsters"))
    golem = next((x for x in monsters if "골렘" in str(x.get("name", "")) and x.get("is_active", True)), None)
    if golem is None:
        golem = next((x for x in monsters if x.get("is_active", True)), None)
    if golem is None:
        raise RuntimeError("No active raid monster was returned")
    created = runners[0].api.post("/api/raids", {
        "hostCharacterId": runners[0].character_id, "monsterId": golem["id"],
        "title": "3계정 실생활 검증", "description": "오프라인·온라인 혼합 공개 서버 테스트",
    })
    raid_data = created.get("data", created)
    raid = raid_data.get("raid", raid_data)
    raid_id = raid["id"]
    emit("RAID_CREATED", raid_id=raid_id, monster=golem.get("name"))
    for runner in runners[1:]:
        runner.api.post(f"/api/raids/{raid_id}/join", {"characterId": runner.character_id})
        emit("RAID_JOINED", raid_id=raid_id, character_id=runner.character_id)
    start = runners[0].api.post(f"/api/raids/{raid_id}/start", {"characterId": runners[0].character_id})
    raid_log: dict[str, Any] = {"raid_id": raid_id, "monster": golem, "start": start, "cycles": []}
    # Three walkers contribute about 80m/min each. Send a contribution every three real minutes.
    cycle = 0
    defeated: set[str] = set()
    while cycle < 40:
        cycle += 1
        for index, runner in enumerate(runners):
            if runner.character_id in defeated:
                continue
            result = runner.api.post(f"/api/raids/{raid_id}/distance", {
                "characterId": runner.character_id, "distanceM": 240.0,
            })
            data = result.get("data", result)
            progress = data.get("progress", {})
            event = {
                "cycle": cycle, "member": index + 1, "distance_m": 240,
                "status": progress.get("status"), "monster_hp": progress.get("monster_current_hp"),
                "attack_cycles": data.get("attack_cycles"), "damage": data.get("damage_dealt"),
                "monster_attack_cycles": data.get("monster_attack_cycles"),
                "monster_damage": data.get("monster_damage_dealt"),
                "defeated": data.get("defeated_participants", []),
            }
            raid_log["cycles"].append(event)
            emit("RAID_DISTANCE", **event)
            defeated.update(str(value) for value in event["defeated"])
            if progress.get("status") in {"cleared", "failed", "canceled"}:
                raid_log["final"] = data
                state["raid"] = raid_log
                save(state)
                return raid_log
        state["raid"] = raid_log
        save(state)
        time.sleep(180)
    raise RuntimeError("Raid did not finish within 40 three-minute cycles")


def write_report(state: dict[str, Any], runners: list[Runner], raid: dict[str, Any]) -> None:
    lines = [
        "# 3계정 실생활 진행 및 골렘 레이드 테스트", "",
        f"- 공개 서버: {BASE}",
        f"- 가상 진행 일수: {state['day']}일", "- 오프라인 보관함은 사용 후 같은 날 다시 채워지는지 포함", "",
        "## 계정별 결과", "", "| 유형 | 최고 스테이지 | 레벨 | 누적 걸음 | 골드 | 설명 |", "|---|---:|---:|---:|---:|---|",
    ]
    for entry, runner in zip(state["profiles"], runners):
        main = runner.main()
        lines.append(f"| {entry['profile']['label']} | {highest(runner)} | {main.get('level')} | {entry['steps']:,} | {main.get('coin_balance')} | {entry['profile']['note']} |")
    final = raid.get("final", {})
    progress = final.get("progress", {})
    lines += [
        "", "## 레이드 결과", "",
        f"- 상태: `{progress.get('status')}`",
        f"- 남은 골렘 HP: {progress.get('monster_current_hp')}",
        f"- 총 거리: {progress.get('total_distance_accumulated_m')}m",
        f"- 기록된 거리 요청: {len(raid.get('cycles', []))}회",
        f"- 보상 골드: {final.get('reward_coin', 0)}",
        "", "## 발견 사항", "",
    ]
    issues = state.get("issues", [])
    if issues:
        lines.extend(f"- {issue}" for issue in issues)
    else:
        lines.append("- 테스트 러너가 포착한 치명적 API 오류 없음")
    FINAL_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    final_payload = {"state": state, "raid": raid}
    FINAL_JSON.write_text(json.dumps(final_payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    state = load_or_create()
    try:
        runners = play_progression(state)
        prepare_raid_loadouts(state, runners)
        previous_raid = state.get("raid") or {}
        previous_status = (previous_raid.get("final", {}).get("progress", {}) or {}).get("status")
        raid = previous_raid if previous_status == "cleared" else run_raid(state, runners)
        status = (raid.get("final", {}).get("progress", {}) or {}).get("status")
        if status != "cleared":
            raise RuntimeError(f"Raid ended without success: {status}")
        write_report(state, runners, raid)
        emit("TEST_COMPLETE", report=str(FINAL_MD), raid_status=status)
        return 0
    except Exception as exc:
        state.setdefault("issues", []).append(repr(exc))
        save(state)
        emit("TEST_FATAL", error=repr(exc))
        raise


if __name__ == "__main__":
    raise SystemExit(main())
