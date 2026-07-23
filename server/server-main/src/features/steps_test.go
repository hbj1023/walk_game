package features

import "testing"

func TestNormalizeStepSyncRequestUsesDistance(t *testing.T) {
	req, _, _, err := normalizeStepSyncRequest(StepSyncRequest{
		SourceType: "sensor",
		SyncType:   "realtime",
		StepCount:  1000,
		DistanceM:  800,
	})
	if err != nil {
		t.Fatalf("normalizeStepSyncRequest returned error: %v", err)
	}

	if req.DistanceM != 800 {
		t.Fatalf("DistanceM = %d, want 800", req.DistanceM)
	}
}

func TestNormalizeStepSyncRequestCalculatesDistanceFromSteps(t *testing.T) {
	req, _, _, err := normalizeStepSyncRequest(StepSyncRequest{
		StepCount: 2000,
		StrideM:   0.75,
	})
	if err != nil {
		t.Fatalf("normalizeStepSyncRequest returned error: %v", err)
	}

	if req.DistanceM != 1500 {
		t.Fatalf("DistanceM = %d, want 1500", req.DistanceM)
	}
}

func TestNormalizeStepSyncRequestRejectsNegativeGpsDistance(t *testing.T) {
	_, _, _, err := normalizeStepSyncRequest(StepSyncRequest{
		StepCount:    100,
		GpsDistanceM: -1,
	})
	if err == nil {
		t.Fatal("normalizeStepSyncRequest returned nil error")
	}
}

func TestGetAttackDistanceMMatchesBalanceFormula(t *testing.T) {
	distance := getAttackDistanceM(5)
	if round2(distance) != 95 {
		t.Fatalf("getAttackDistanceM(5) = %.2f, want 95.00", distance)
	}
}

func TestGetStepAttackDistanceMAddsOfflineAgilityPenalty(t *testing.T) {
	distance := getStepAttackDistanceM(20, "offline", 0)
	if round2(distance) != 86 {
		t.Fatalf("getStepAttackDistanceM(20, offline) = %.2f, want 86.00", distance)
	}
}

func TestNormalizeStepSyncRequestAcceptsOfflineSync(t *testing.T) {
	req, _, _, err := normalizeStepSyncRequest(StepSyncRequest{
		SourceType: "sensor",
		SyncType:   "offline",
		StepCount:  100,
		DistanceM:  75,
		IsDelta:    true,
	})
	if err != nil {
		t.Fatalf("normalizeStepSyncRequest returned error: %v", err)
	}

	if req.SyncType != "offline" {
		t.Fatalf("SyncType = %q, want offline", req.SyncType)
	}
}

func TestCalculateOfflineStorageUsesCurrentBalanceInsteadOfDailyTotal(t *testing.T) {
	stored, lost := calculateOfflineStorage(7, 4, 10)
	if stored != 6 || lost != 1 {
		t.Fatalf("stored/lost = %d/%d, want 6/1", stored, lost)
	}
}

func TestCalculateOfflineStorageRefillsAfterAttacksAreUsed(t *testing.T) {
	firstStored, _ := calculateOfflineStorage(10, 0, 10)
	secondStored, secondLost := calculateOfflineStorage(5, 3, 10)
	if firstStored != 10 {
		t.Fatalf("first stored = %d, want 10", firstStored)
	}
	if secondStored != 5 || secondLost != 0 {
		t.Fatalf("second stored/lost = %d/%d, want 5/0", secondStored, secondLost)
	}
}

func TestCalculateOfflineStorageRejectsWhenInventoryIsFull(t *testing.T) {
	stored, lost := calculateOfflineStorage(4, 10, 10)
	if stored != 0 || lost != 4 {
		t.Fatalf("stored/lost = %d/%d, want 0/4", stored, lost)
	}
}

func TestExplorationUpgradeSummaryReflectsCharacterLevels(t *testing.T) {
	summary := buildExplorationUpgradeSummary(battleCharacterRecord{
		CoinBalance:            900,
		OfflineStorageLevel:    1,
		OfflineEfficiencyLevel: 2,
	})

	if summary["coin_balance"] != 900 {
		t.Fatalf("coin_balance = %v, want 900", summary["coin_balance"])
	}

	upgrades := summary["upgrades"].(map[string]any)
	storage := upgrades[explorationUpgradeStorage].(map[string]any)
	if storage["level"] != 1 {
		t.Fatalf("storage level = %v, want 1", storage["level"])
	}
	if storage["current_value"] != 15 {
		t.Fatalf("storage current_value = %v, want 15", storage["current_value"])
	}
	if storage["cost_coin"] != 350 {
		t.Fatalf("storage cost_coin = %v, want 350", storage["cost_coin"])
	}

	efficiency := upgrades[explorationUpgradeEfficiency].(map[string]any)
	if efficiency["level"] != 2 {
		t.Fatalf("efficiency level = %v, want 2", efficiency["level"])
	}
	if efficiency["current_value"] != 22 {
		t.Fatalf("efficiency current_value = %v, want 22", efficiency["current_value"])
	}
}

func TestCalculateDailyDeltaUsesCumulativeValues(t *testing.T) {
	req := StepSyncRequest{
		StepCount: 1200,
		DistanceM: 900,
	}
	summary := dailyStepSummaryRecord{
		TotalStepCount: 1000,
		TotalDistanceM: 750,
	}

	deltaSteps, deltaDistance := calculateDailyDelta(req, summary, true)

	if deltaSteps != 200 || deltaDistance != 150 {
		t.Fatalf("delta = %d steps/%dm, want 200 steps/150m", deltaSteps, deltaDistance)
	}
}

func TestCalculateDailyDeltaIgnoresLowerCumulativeValues(t *testing.T) {
	req := StepSyncRequest{
		StepCount: 900,
		DistanceM: 675,
	}
	summary := dailyStepSummaryRecord{
		TotalStepCount: 1000,
		TotalDistanceM: 750,
	}

	deltaSteps, deltaDistance := calculateDailyDelta(req, summary, true)

	if deltaSteps != 0 || deltaDistance != 0 {
		t.Fatalf("delta = %d steps/%dm, want 0 steps/0m", deltaSteps, deltaDistance)
	}
}

func TestCalculateDailyTotalsDoesNotDecreaseStoredValues(t *testing.T) {
	req := StepSyncRequest{
		StepCount: 900,
		DistanceM: 675,
	}
	summary := dailyStepSummaryRecord{
		TotalStepCount: 1000,
		TotalDistanceM: 750,
	}

	totalSteps, totalDistance := calculateDailyTotals(req, summary, true)

	if totalSteps != 1000 || totalDistance != 750 {
		t.Fatalf("totals = %d steps/%dm, want existing 1000 steps/750m", totalSteps, totalDistance)
	}
}

func TestCalculateAttackCountEarnedKeepsRemainder(t *testing.T) {
	earned, remainder := calculateAttackCountEarned(60, 50, 100)

	if earned != 1 {
		t.Fatalf("earned = %d, want 1", earned)
	}
	if remainder != 10 {
		t.Fatalf("remainder = %.2f, want 10", remainder)
	}
}

func TestOnlineWalkingEarnsBossTicketFragmentAt1800Meters(t *testing.T) {
	earned, remainder := calculateBossTicketFragmentsEarned("realtime", 0, 1800)

	if earned != 1 || remainder != 0 {
		t.Fatalf("earned/remainder = %d/%.2f, want 1/0", earned, remainder)
	}
}

func TestOnlineWalkingCarriesBossTicketFragmentRemainder(t *testing.T) {
	earned, remainder := calculateBossTicketFragmentsEarned("periodic", 1700, 250)

	if earned != 1 || remainder != 150 {
		t.Fatalf("earned/remainder = %d/%.2f, want 1/150", earned, remainder)
	}
}

func TestOfflineWalkingDoesNotEarnBossTicketFragments(t *testing.T) {
	earned, remainder := calculateBossTicketFragmentsEarned("offline", 600, 3600)

	if earned != 0 || remainder != 600 {
		t.Fatalf("earned/remainder = %d/%.2f, want 0/600", earned, remainder)
	}
}

func TestOnlineWalkingAddsMissionDistance(t *testing.T) {
	got := calculateMissionDistance("realtime", 700, 300)
	if got != 1000 {
		t.Fatalf("mission distance = %d, want 1000", got)
	}
}

func TestOfflineWalkingDoesNotAddMissionDistance(t *testing.T) {
	got := calculateMissionDistance("offline", 700, 3000)
	if got != 700 {
		t.Fatalf("mission distance = %d, want 700", got)
	}
}

func TestSameRecordDateAcceptsPocketBaseDateFormat(t *testing.T) {
	if !sameRecordDate("2026-05-09 00:00:00.000Z", "2026-05-09") {
		t.Fatal("sameRecordDate returned false for equivalent dates")
	}
}
