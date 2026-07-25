package features

import (
	"testing"
	"time"
)

func TestGoldMineRewardsForDistance(t *testing.T) {
	tests := []struct{ distance, coin, statExp, fragments int }{
		{99, 0, 0, 0}, {400, 520, 0, 1}, {500, 700, 1, 1}, {600, 900, 1, 4}, {900, 900, 1, 4},
	}
	for _, tc := range tests {
		coin, statExp, fragments := goldMineRewardsForDistance(tc.distance)
		if coin != tc.coin || statExp != tc.statExp || fragments != tc.fragments {
			t.Fatalf("distance %d rewards = (%d,%d,%d), want (%d,%d,%d)", tc.distance, coin, statExp, fragments, tc.coin, tc.statExp, tc.fragments)
		}
	}
}

func TestGoldMineStartedAtAcceptsPocketBaseTimestamp(t *testing.T) {
	rfc3339, err := parsePocketBaseDate("2026-07-25T03:06:17Z")
	if err != nil {
		t.Fatalf("parse RFC3339 timestamp: %v", err)
	}
	pocketBase, err := parsePocketBaseDate("2026-07-25 03:06:17.000Z")
	if err != nil {
		t.Fatalf("parse PocketBase timestamp: %v", err)
	}
	if !rfc3339.Equal(pocketBase) {
		t.Fatalf("timestamps differ: %s != %s", rfc3339, pocketBase)
	}
	if rfc3339.Location() != time.UTC {
		t.Fatalf("timestamp location = %s, want UTC", rfc3339.Location())
	}
}

func TestValidateGoldMineCheckpointRejectsBackwardsProgress(t *testing.T) {
	run := goldMineEventRun{
		ID: "run", DistanceM: 120, StepCount: 150, MaxSpeedKmh: 12,
		RemainingSeconds: 90,
	}
	valid := goldMineCheckpointRequest{
		RunID: "run", DistanceM: 130, StepCount: 160, MaxSpeedKmh: 13,
		RemainingSeconds: 85,
	}
	if err := validateGoldMineCheckpoint(valid, run); err != nil {
		t.Fatalf("valid checkpoint rejected: %v", err)
	}
	backwards := valid
	backwards.DistanceM = 119
	if err := validateGoldMineCheckpoint(backwards, run); err == nil {
		t.Fatal("backwards checkpoint should be rejected")
	}
}

func TestGoldMineRunResumable(t *testing.T) {
	run := goldMineEventRun{Status: "paused", RemainingSeconds: 75}
	if !isGoldMineRunResumable(run) {
		t.Fatal("paused run with time remaining should be resumable")
	}
	run.RemainingSeconds = 0
	if isGoldMineRunResumable(run) {
		t.Fatal("run without time remaining should not be resumable")
	}
}
