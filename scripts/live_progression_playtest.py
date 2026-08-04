#!/usr/bin/env python3
"""Run a reproducible four-account progression test against the public API."""

from __future__ import annotations

import argparse
import json
import os
import random
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


BASE = os.environ.get("WALKMASTER_API_BASE_URL", "https://walk-master.com").rstrip("/")
SHOP_ID = "h36hx72gbskptte"
WALK_METERS_PER_MINUTE = 80.0
STEP_METERS = 0.75
MAX_STAGE_ATTEMPTS = 8
MAX_HITS_PER_BATTLE = 45
RARITY = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}
SLOT_ORDER = {"sword": 0, "weapon": 0, "helmet": 1, "armor": 2, "shoes": 3}


class ApiError(RuntimeError):
    pass


class Api:
    def __init__(self, email: str, password: str):
        self.email = email
        self.password = password
        self.token = ""

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        headers = {"Accept": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json; charset=utf-8"
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read().decode("utf-8-sig")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8-sig", errors="replace")
            try:
                detail = json.loads(raw)
            except json.JSONDecodeError:
                detail = raw
            raise ApiError(f"{method} {path}: HTTP {exc.code}: {detail}") from exc

    def get(self, path: str) -> Any:
        return self.request("GET", path)

    def post(self, path: str, body: dict[str, Any]) -> Any:
        return self.request("POST", path, body)

    def login(self) -> dict[str, Any]:
        result = self.post("/login", {"email": self.email, "password": self.password})
        self.token = result["token"]
        return result


@dataclass
class Runner:
    role: str
    account: dict[str, Any]
    rng: random.Random
    api: Api = field(init=False)
    events: list[dict[str, Any]] = field(default_factory=list)
    distance_m: float = 0
    steps: int = 0
    repeats: dict[int, int] = field(default_factory=dict)
    failures: dict[int, int] = field(default_factory=dict)
    stage_attempts: dict[int, int] = field(default_factory=dict)
    started: float = field(default_factory=time.monotonic)

    def __post_init__(self) -> None:
        self.api = Api(self.account["email"], self.account["password"])

    @property
    def character_id(self) -> str:
        return self.account["character_id"]

    def log(self, kind: str, **data: Any) -> None:
        self.events.append({
            "elapsed_s": round(time.monotonic() - self.started, 2),
            "virtual_walk_min": round(self.distance_m / WALK_METERS_PER_MINUTE, 2),
            "kind": kind,
            **data,
        })

    def main(self) -> dict[str, Any]:
        return self.api.get("/main")

    def stages(self) -> list[dict[str, Any]]:
        result = self.api.get("/stages/normal")
        return result.get("stages", result.get("data", result if isinstance(result, list) else []))

    def stats(self) -> dict[str, Any]:
        result = self.api.get(f"/api/characters/stats/{self.character_id}")
        return result.get("data", result)

    def shop_items(self) -> list[dict[str, Any]]:
        result = self.api.get(f"/api/shops/{SHOP_ID}/items")
        return result.get("data", result).get("items", [])

    def inventory(self) -> list[dict[str, Any]]:
        result = self.api.get(f"/api/characters/{self.character_id}/equipments")
        data = result.get("data", result)
        return data.get("items", data if isinstance(data, list) else [])

    def walk(self, minimum_attacks: int = 12) -> None:
        balance = int(self.main().get("attack_count_balance", 0))
        while balance < minimum_attacks:
            step_count = 1000
            distance = round(step_count * STEP_METERS)
            payload = {
                "source_type": "api",
                "sync_type": "realtime",
                "step_count": step_count,
                "distance_m": distance,
                "stride_m": STEP_METERS,
                "captured_at": datetime.now(timezone.utc).isoformat(),
                "is_delta": True,
                "gps_distance_m": distance,
                "abnormal_flag": False,
                "abnormal_reason": "",
            }
            result = self.api.post("/steps/sync", payload)
            self.steps += step_count
            self.distance_m += distance
            balance = int(result.get("attack_count_balance", self.main().get("attack_count_balance", 0)))
            self.log("walk", steps=step_count, distance_m=distance, attack_balance=balance)
            if self.steps > 120000:
                raise RuntimeError("walking safety cap exceeded")

    @staticmethod
    def template(item: dict[str, Any]) -> dict[str, Any]:
        return item.get("expand", {}).get("item_template", {})

    def buy(self, item: dict[str, Any]) -> bool:
        template = self.template(item)
        before = {x.get("id") for x in self.inventory()}
        try:
            self.api.post(f"/api/shops/{SHOP_ID}/purchase", {
                "characterId": self.character_id,
                "shopItemId": item["id"],
                "offerId": "",
                "quantity": 1,
            })
        except ApiError as exc:
            self.log("purchase_error", item=template.get("name"), error=str(exc))
            return False
        self.log("purchase", item=template.get("name"), price=item.get("price_coin"), rarity=template.get("rarity"))
        if template.get("item_type") == "equipment":
            owned = [x for x in self.inventory() if x.get("id") not in before]
            if owned:
                try:
                    self.api.post(f"/api/characters/{self.character_id}/equip", {"ownedEquipmentId": owned[-1]["id"]})
                    self.log("equip", item=template.get("name"), slot=template.get("equipment_slot"))
                except ApiError as exc:
                    self.log("equip_error", item=template.get("name"), error=str(exc))
        return True

    def buy_best_affordable(self, chapter: int) -> bool:
        coins = int(self.main().get("coin_balance", 0))
        owned_templates = {
            x.get("item_template") or x.get("expand", {}).get("item_template", {}).get("id")
            for x in self.inventory()
        }
        candidates = []
        for item in self.shop_items():
            t = self.template(item)
            if t.get("item_type") != "equipment" or t.get("id") in owned_templates:
                continue
            if not item.get("is_purchase_unlocked", True) or int(item.get("price_coin", 0)) > coins:
                continue
            name = str(t.get("name", ""))
            item_chapter = 3 if ("채석" in name or "균열" in name or "+" in name) else 2 if any(x in name for x in ("도적", "광전사", "창술사", "견습기사", "모험가")) else 1
            if item_chapter > chapter:
                continue
            if self.role == "guided" and chapter >= 2:
                target_names = ("도적",) if chapter == 2 else ("채석단 도적", "균열자")
                if item_chapter == chapter and not any(target in name for target in target_names):
                    continue
            attack = float(t.get("base_attack", 0) or 0)
            defense = float(t.get("base_defense", 0) or 0)
            hp = float(t.get("base_hp", 0) or 0)
            agility = float(t.get("base_agility", 0) or 0)
            rarity = RARITY.get(str(t.get("rarity", "")), 0)
            price = max(1, int(item.get("price_coin", 0)))
            if self.role == "guided":
                set_match = 40 if any(x in name for x in ("모험가", "도적", "균열자")) else 0
                score = rarity * 35 + set_match + attack * 3 + defense * 2 + hp / 15 + agility
            elif self.role == "attacker":
                score = attack * 7 + rarity * 20 + agility - defense * 0.2
            elif self.role == "tank":
                score = defense * 7 + hp / 5 + rarity * 18 + attack * 0.5
            else:
                score = (attack * 2 + defense * 2 + hp / 15 + agility + rarity * 10) / price * 100 + self.rng.random() * 8
            candidates.append((score, -price, item))
        if not candidates:
            return False
        candidates.sort(key=lambda x: (x[0], x[1]), reverse=True)
        return self.buy(candidates[0][2])

    def upgrade_stats(self) -> None:
        preference = {
            "guided": ["attack", "defense", "hp", "agility"],
            "attacker": ["attack", "attack", "agility", "hp"],
            "tank": ["defense", "hp", "defense", "attack"],
            "scavenger": ["agility", "attack", "hp", "defense"],
        }[self.role]
        for _ in range(30):
            costs_raw = self.api.get(f"/api/stat-upgrades/costs/{self.character_id}")
            costs_data = costs_raw.get("data", costs_raw)
            costs = costs_data.get("costs", costs_data)
            stat_exp = int(self.main().get("stat_exp", 0))
            selected = None
            for stat in preference:
                raw = costs.get(stat) or costs.get(f"{stat}_cost")
                cost = int(raw.get("cost", raw) if isinstance(raw, dict) else raw or 10**9)
                if cost <= stat_exp:
                    selected = (stat, cost)
                    break
            if not selected:
                return
            try:
                result = self.api.post("/api/stat-upgrades", {"characterId": self.character_id, "statType": selected[0]})
                self.log("stat_upgrade", stat=selected[0], cost=selected[1], result=result.get("message", ""))
            except ApiError as exc:
                self.log("stat_upgrade_error", stat=selected[0], error=str(exc))
                return

    def prepare(self, chapter: int) -> None:
        self.upgrade_stats()
        for _ in range(8):
            if not self.buy_best_affordable(chapter):
                break

    def battle(self, stage: dict[str, Any], ensure_attacks: bool = True) -> bool:
        stage_no = int(stage.get("stage_no", 0))
        is_boss = bool(stage.get("is_boss")) or stage_no % 5 == 0
        prefix = "/battle/boss" if is_boss else "/battle/normal"
        if ensure_attacks:
            self.walk(20)
        before = self.main()
        self.stage_attempts[stage_no] = self.stage_attempts.get(stage_no, 0) + 1
        try:
            start = self.api.post(prefix + "/start", {
                "character_id": self.character_id,
                "stage_id": stage["id"],
                "stage_no": stage_no,
            })
        except ApiError as exc:
            self.log("battle_start_error", stage=stage_no, error=str(exc))
            return False
        battle_id = start.get("battle_id") or start.get("battle", {}).get("id") or start.get("id")
        self.log("battle_start", stage=stage_no, boss=is_boss, power=self.stats().get("combat_power"), coins=before.get("coin_balance"))
        hits = []
        result = start
        for hit_no in range(1, MAX_HITS_PER_BATTLE + 1):
            battle_state = result.get("battle", result)
            status = str(battle_state.get("status") or result.get("battle_status") or result.get("status") or "").lower()
            if status in {"cleared", "finished", "failed", "defeated", "won", "lost", "win", "lose"}:
                break
            try:
                result = self.api.post(prefix + "/attack", {"battle_id": battle_id})
            except ApiError as exc:
                if ensure_attacks and "attack_count_balance is not enough" in str(exc):
                    self.walk(12)
                    result = self.api.post(prefix + "/attack", {"battle_id": battle_id})
                else:
                    self.log("battle_attack_error", stage=stage_no, hit=hit_no, error=str(exc))
                    return False
            battle_state = result.get("battle", result)
            hits.append({
                "n": hit_no,
                "dealt": result.get("player_damage", 0),
                "received": result.get("monster_damage", 0),
                "player_hp": battle_state.get("character_current_hp"),
                "monster_hp": battle_state.get("monster_current_hp"),
            })
        battle_state = result.get("battle", result)
        status = str(battle_state.get("status") or result.get("battle_status") or result.get("status") or "").lower()
        monster_hp = int(battle_state.get("monster_current_hp", 0) or 0)
        cleared = status in {"cleared", "finished", "won", "win"} and monster_hp <= 0
        if cleared:
            if self.stage_attempts[stage_no] > 1:
                self.repeats[stage_no] = self.repeats.get(stage_no, 0) + 1
            self.log("battle_clear", stage=stage_no, hits=len(hits), final_hp=battle_state.get("character_current_hp"), coin_reward=result.get("reward_coin", 0), exp_reward=result.get("reward_exp", 0), stat_exp_reward=result.get("stat_exp_reward", 0), drop=result.get("reward_item"), hit_log=hits)
        else:
            self.failures[stage_no] = self.failures.get(stage_no, 0) + 1
            self.log("battle_fail", stage=stage_no, status=status, hits=len(hits), final_hp=battle_state.get("character_current_hp"), monster_hp=monster_hp, hit_log=hits)
        return cleared

    def run(self) -> dict[str, Any]:
        login = self.api.login()
        self.log("login", level=login.get("level"), coins=login.get("coin_balance"))
        consecutive_no_progress = 0
        while True:
            stages = self.stages()
            cleared = [int(s.get("stage_no", 0)) for s in stages if s.get("is_cleared")]
            highest = max(cleared, default=0)
            if highest >= 15:
                break
            chapter = highest // 5 + 1
            self.prepare(chapter)
            stages = self.stages()
            target = next((s for s in stages if int(s.get("stage_no", 0)) == highest + 1 and s.get("is_unlocked")), None)
            if target is None:
                target = next((s for s in stages if s.get("is_unlocked") and not s.get("is_cleared")), None)
            if target is None or self.stage_attempts.get(int(target.get("stage_no", 0)), 0) >= MAX_STAGE_ATTEMPTS:
                self.log("blocked", highest_stage=highest, reason="no unlocked target or attempt cap")
                break
            success = self.battle(target)
            new_highest = max([int(s.get("stage_no", 0)) for s in self.stages() if s.get("is_cleared")], default=0)
            if new_highest > highest:
                consecutive_no_progress = 0
                continue
            consecutive_no_progress += 1
            # Earn coins/EXP from the latest cleared normal stage before retrying.
            if highest > 0 and highest % 5 != 0 and consecutive_no_progress <= 6:
                repeat_stage = next(s for s in self.stages() if int(s.get("stage_no", 0)) == highest)
                self.battle(repeat_stage)
            elif not success and consecutive_no_progress > 6:
                self.log("blocked", highest_stage=highest, reason="six retries without progress")
                break
        final_main = self.main()
        final_stages = self.stages()
        return {
            "role": self.role,
            "email": self.account["email"],
            "character_id": self.character_id,
            "actual_elapsed_s": round(time.monotonic() - self.started, 2),
            "simulated_steps": self.steps,
            "simulated_distance_m": self.distance_m,
            "simulated_walk_min": round(self.distance_m / WALK_METERS_PER_MINUTE, 2),
            "highest_cleared": max([int(s.get("stage_no", 0)) for s in final_stages if s.get("is_cleared")], default=0),
            "final_main": {k: final_main.get(k) for k in ("level", "exp", "stat_exp", "coin_balance", "attack_count_balance")},
            "final_stats": self.stats(),
            "failures": self.failures,
            "repeats": self.repeats,
            "events": self.events,
        }


def write_markdown(results: list[dict[str, Any]], path: Path) -> None:
    labels = {"guided": "정석 세트", "attacker": "공격 집중", "tank": "생존 우선", "scavenger": "즉흥 선택"}
    lines = ["# 4계정 공개 서버 진행 테스트", "", f"- 실행 시각: {datetime.now().astimezone().isoformat(timespec='seconds')}", f"- 서버: {BASE}", "- 방식: 실제 게임 API로 걷기 동기화, 전투, 구매, 장착, 스탯 강화를 수행", f"- 시간 환산: 80m/분, {STEP_METERS}m/보", ""]
    lines += ["## 요약", "", "| 경로 | 최고 클리어 | 걸음 | 거리 | 환산 걷기 | 실패 | 반복 | 최종 레벨 | 최종 골드 |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for r in results:
        lines.append(f"| {labels[r['role']]} | {r['highest_cleared']} | {r['simulated_steps']:,} | {r['simulated_distance_m']:,.0f}m | {r['simulated_walk_min']:.1f}분 | {sum(r['failures'].values())} | {sum(r['repeats'].values())} | {r['final_main'].get('level')} | {r['final_main'].get('coin_balance')} |")
    for r in results:
        lines += ["", f"## {labels[r['role']]}", "", f"- 계정: `{r['email']}`", f"- 실제 자동화 시간: {r['actual_elapsed_s']:.1f}초", f"- 최종 스탯: `{json.dumps(r['final_stats'], ensure_ascii=False)}`", "", "| 환산 시간 | 내용 |", "|---:|---|"]
        for e in r["events"]:
            kind = e["kind"]
            if kind == "walk":
                text = f"{e['steps']:,}보 걷기, 공격 기회 {e['attack_balance']}회"
            elif kind == "purchase":
                text = f"구매: {e['item']} ({e['price']}G)"
            elif kind == "equip":
                text = f"장착: {e['item']}"
            elif kind == "stat_upgrade":
                text = f"스탯 강화: {e['stat']} (비용 {e['cost']})"
            elif kind == "battle_start":
                text = f"스테이지 {e['stage']} 시작, 전투력 {e.get('power')}, 골드 {e.get('coins')}"
            elif kind == "battle_clear":
                text = f"스테이지 {e['stage']} 클리어: {e['hits']}타, 남은 HP {e.get('final_hp')}, +{e.get('coin_reward')}G"
            elif kind == "battle_fail":
                text = f"스테이지 {e['stage']} 실패: {e['hits']}타, 몬스터 HP {e.get('monster_hp')}"
            elif kind.endswith("error") or kind == "blocked":
                text = f"{kind}: {e.get('error') or e.get('reason')}"
            else:
                continue
            lines.append(f"| {e['virtual_walk_min']:.1f}분 | {text} |")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--accounts", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--roles", default="guided,attacker,tank,scavenger")
    args = parser.parse_args()
    accounts = json.loads(args.accounts.read_text(encoding="utf-8-sig"))
    roles = [x.strip() for x in args.roles.split(",") if x.strip()]
    selected = [x for x in accounts if x["role"] in roles]
    results = []
    for index, account in enumerate(selected):
        print(f"START {account['role']} {account['email']}", flush=True)
        runner = Runner(account["role"], account, random.Random(20260722 + index))
        try:
            result = runner.run()
        except Exception as exc:  # Keep the remaining independent paths running.
            runner.log("fatal_error", error=repr(exc))
            result = {
                "role": account["role"], "email": account["email"], "character_id": account["character_id"],
                "actual_elapsed_s": round(time.monotonic() - runner.started, 2), "simulated_steps": runner.steps,
                "simulated_distance_m": runner.distance_m, "simulated_walk_min": round(runner.distance_m / WALK_METERS_PER_MINUTE, 2),
                "highest_cleared": 0, "final_main": {}, "final_stats": {}, "failures": runner.failures,
                "repeats": runner.repeats, "events": runner.events,
            }
        results.append(result)
        print(f"DONE {account['role']} highest={result['highest_cleared']} steps={result['simulated_steps']}", flush=True)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        write_markdown(results, args.output.with_suffix(".md"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
