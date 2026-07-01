package features

import "testing"

func TestNormalBattleExpRewardFirstClear(t *testing.T) {
	got := normalBattleExpReward(1, false, stageProgressRecord{}, false, 1)
	if got != 51 {
		t.Fatalf("stage 1 first clear exp = %d, want 51", got)
	}

	got = normalBattleExpReward(5, true, stageProgressRecord{}, false, 5)
	if got != 375 {
		t.Fatalf("boss stage 5 first clear exp = %d, want 375", got)
	}
}

func TestNormalBattleExpRewardRepeatClear(t *testing.T) {
	progress := stageProgressRecord{ClearCount: 1}

	got := normalBattleExpReward(3, false, progress, true, 3)
	if got != 60 {
		t.Fatalf("stage 3 repeat exp = %d, want 60", got)
	}

	got = normalBattleExpReward(5, true, progress, true, 5)
	if got != 150 {
		t.Fatalf("boss stage 5 repeat exp = %d, want 150", got)
	}
}

func TestNormalBattleExpRewardLowStageFarmingFallsOff(t *testing.T) {
	progress := stageProgressRecord{ClearCount: 1}

	got := normalBattleExpReward(1, false, progress, true, 10)
	if got != 7 {
		t.Fatalf("high level stage 1 repeat exp = %d, want 7", got)
	}
}
