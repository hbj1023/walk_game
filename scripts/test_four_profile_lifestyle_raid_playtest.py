import sys
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parent))
import four_profile_lifestyle_raid_playtest as playtest


class FakeRunner:
    def __init__(self, balance: int = 0):
        self.balance = balance
        self.steps = 0
        self.distance_m = 0

    def main(self):
        return {"attack_count_balance": self.balance}


class PlaytestToolTests(unittest.TestCase):
    def test_record_stage_clear_tracks_best_and_worst_hits(self):
        entry = {"clear_hits": {}, "clear_hit_max": {}}

        playtest.record_stage_clear(entry, 3, 8)
        playtest.record_stage_clear(entry, 3, 11)

        self.assertEqual(entry["clear_hits"]["3"], 8)
        self.assertEqual(entry["clear_hit_max"]["3"], 11)

    @patch.object(playtest, "highest", return_value=3)
    @patch.object(playtest, "stages")
    def test_safe_farm_stage_uses_worst_observed_hits(self, mock_stages, _mock_highest):
        mock_stages.return_value = [{"stage_no": 1}, {"stage_no": 2}, {"stage_no": 3}]
        entry = {
            "clear_hits": {"1": 6, "2": 6, "3": 7},
            "clear_hit_max": {"1": 9, "2": 12, "3": 13},
        }

        stage, expected = playtest.safe_farm_stage(entry, FakeRunner())

        self.assertEqual(stage["stage_no"], 1)
        self.assertEqual(expected, 9)

    @patch.object(playtest, "highest", return_value=3)
    @patch.object(playtest, "stages")
    def test_affordable_farm_stage_keeps_attack_margin(self, mock_stages, _mock_highest):
        mock_stages.return_value = [{"stage_no": 1}, {"stage_no": 2}, {"stage_no": 3}]
        entry = {
            "clear_hits": {"1": 5, "2": 8, "3": 9},
            "clear_hit_max": {"1": 5, "2": 8, "3": 9},
        }

        stage, expected = playtest.affordable_farm_stage(entry, FakeRunner(balance=10))

        self.assertEqual(stage["stage_no"], 1)
        self.assertEqual(expected, 5)

    def test_reconcile_completion_day_from_next_stage(self):
        entry = {
            "preparations": {
                "3": {"started_day": 1, "completed_day": None},
                "4": {"started_day": 3, "completed_day": 4},
            }
        }

        playtest.reconcile_preparation_completion_days(entry)

        self.assertEqual(entry["preparations"]["3"]["completed_day"], 3)
        self.assertEqual(
            entry["preparations"]["3"]["completion_source"],
            "inferred_from_next_stage",
        )

    @patch.object(playtest, "consume_full_offline_storage")
    @patch.object(playtest, "sync")
    def test_offline_session_returns_every_time_storage_fills(
        self,
        mock_sync,
        mock_consume,
    ):
        runner = FakeRunner()
        entry = {
            "profile": {"key": "offline_returner", "label": "오프라인 복귀형"},
            "ticket_fragments_earned": 0,
        }
        balances = iter([5, 10, 4, 10])

        def sync_side_effect(_runner, _sync_type, steps, _captured):
            balance = next(balances)
            runner.balance = balance
            runner.steps += steps
            return {
                "attack_count_balance": balance,
                "offline_attack_count_cap": 10,
                "offline_attack_count_earned": 5,
                "offline_attack_count_stored": 5,
                "offline_attack_count_lost": 0,
            }

        def consume_side_effect(_runner, _entry, _target, _day):
            runner.balance = 0
            return [{"result": "cleared"}]

        mock_sync.side_effect = sync_side_effect
        mock_consume.side_effect = consume_side_effect

        result = playtest.run_offline_session_with_returns(
            runner,
            entry,
            target=3,
            day=1,
            step_count=2000,
            captured=playtest.dt.datetime(
                2026,
                7,
                25,
                9,
                0,
                tzinfo=playtest.dt.timezone(playtest.dt.timedelta(hours=9)),
            ),
        )

        self.assertEqual(result["full_storage_return_count"], 2)
        self.assertEqual(
            [row["alert_after_steps"] for row in result["full_storage_returns"]],
            [1000, 2000],
        )
        self.assertEqual(mock_consume.call_count, 2)
        self.assertEqual(result["offline_lost"], 0)
        first_return = playtest.dt.datetime.fromisoformat(
            result["full_storage_returns"][0]["returned_at"]
        )
        third_chunk = playtest.dt.datetime.fromisoformat(
            result["chunks"][2]["captured_at"]
        )
        self.assertGreaterEqual(third_chunk, first_return)


if __name__ == "__main__":
    unittest.main()
