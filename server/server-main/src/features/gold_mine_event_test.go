package features

import "testing"

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
