package features

import "testing"

func TestBossRewardRarityForRoll(t *testing.T) {
	tests := []struct {
		roll int
		want string
	}{
		{roll: 0, want: "common"},
		{roll: 49, want: "common"},
		{roll: 50, want: "rare"},
		{roll: 84, want: "rare"},
		{roll: 85, want: "epic"},
		{roll: 99, want: "epic"},
	}

	for _, tt := range tests {
		if got := bossRewardRarityForRoll(tt.roll); got != tt.want {
			t.Fatalf("bossRewardRarityForRoll(%d) = %q, want %q", tt.roll, got, tt.want)
		}
	}
}
