package features

import "testing"

func TestBossRewardRarityForRoll(t *testing.T) {
	tests := []struct {
		roll int
		want string
	}{
		{roll: 0, want: ""},
		{roll: 39, want: ""},
		{roll: 40, want: "epic"},
		{roll: 99, want: "epic"},
	}

	for _, tt := range tests {
		if got := bossRewardRarityForRoll(tt.roll); got != tt.want {
			t.Fatalf("bossRewardRarityForRoll(%d) = %q, want %q", tt.roll, got, tt.want)
		}
	}
}

func TestBossClearRequiresTicket(t *testing.T) {
	if bossClearRequiresTicket(stageProgressRecord{}, false) {
		t.Fatal("missing progress should not require a boss ticket")
	}

	if bossClearRequiresTicket(stageProgressRecord{ClearCount: 0}, true) {
		t.Fatal("first boss clear should not require a boss ticket")
	}

	if !bossClearRequiresTicket(stageProgressRecord{ClearCount: 1}, true) {
		t.Fatal("repeat boss clear should require a boss ticket")
	}
}
