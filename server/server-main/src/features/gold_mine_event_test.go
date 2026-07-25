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
