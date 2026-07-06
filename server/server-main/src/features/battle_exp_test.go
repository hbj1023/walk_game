package features

import "testing"

func TestCombatPowerMatchesClientFormula(t *testing.T) {
	got := combatPower(statBlock{HP: 100, Attack: 10, Defense: 5, Agility: 5})
	if got != 158 {
		t.Fatalf("combat power = %d, want 158", got)
	}
}

func TestRecommendedCombatPowerForStage(t *testing.T) {
	if got := recommendedCombatPowerForStage(5); got != 360 {
		t.Fatalf("stage 5 recommended power = %d, want 360", got)
	}
	if got := recommendedCombatPowerForStage(11); got != 1650 {
		t.Fatalf("stage 11 fallback recommended power = %d, want 1650", got)
	}
}

func TestNormalBattleExpRewardFirstClear(t *testing.T) {
	got := normalBattleExpReward(1, false, stageProgressRecord{}, false, 0)
	if got != 51 {
		t.Fatalf("stage 1 first clear exp = %d, want 51", got)
	}

	got = normalBattleExpReward(5, true, stageProgressRecord{}, false, 0)
	if got != 375 {
		t.Fatalf("boss stage 5 first clear exp = %d, want 375", got)
	}
}

func TestNormalBattleExpRewardRepeatClear(t *testing.T) {
	progress := stageProgressRecord{ClearCount: 1}

	got := normalBattleExpReward(3, false, progress, true, 230)
	if got != 60 {
		t.Fatalf("stage 3 repeat exp = %d, want 60", got)
	}

	got = normalBattleExpReward(5, true, progress, true, 360)
	if got != 150 {
		t.Fatalf("boss stage 5 repeat exp = %d, want 150", got)
	}
}

func TestNormalBattleExpRewardLowStageFarmingFallsOffByCombatPower(t *testing.T) {
	progress := stageProgressRecord{ClearCount: 1}

	got := normalBattleExpReward(1, false, progress, true, 520)
	if got != 7 {
		t.Fatalf("high power stage 1 repeat exp = %d, want 7", got)
	}
}

func TestNormalBattleCoinRewardFirstClear(t *testing.T) {
	got := normalBattleCoinReward(100, 3, stageProgressRecord{}, false, 0)
	if got != 100 {
		t.Fatalf("first clear coin = %d, want 100", got)
	}
}

func TestNormalBattleCoinRewardRepeatClear(t *testing.T) {
	progress := stageProgressRecord{ClearCount: 1}

	got := normalBattleCoinReward(100, 3, progress, true, 230)
	if got != 50 {
		t.Fatalf("repeat clear coin = %d, want 50", got)
	}
}

func TestNormalBattleCoinRewardLowStageFarmingFallsOffByCombatPower(t *testing.T) {
	progress := stageProgressRecord{ClearCount: 1}

	got := normalBattleCoinReward(100, 1, progress, true, 520)
	if got != 15 {
		t.Fatalf("high power stage 1 repeat coin = %d, want 15", got)
	}
}
