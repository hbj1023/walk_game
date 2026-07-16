package features

import "testing"

func TestBossTicketFragmentDropChanceBoundary(t *testing.T) {
	for roll := 0; roll < 100; roll++ {
		got := shouldDropBossTicketFragment(roll)
		want := roll < 10
		if got != want {
			t.Fatalf("roll %d drop = %v, want %v", roll, got, want)
		}
	}
}

func TestBossTicketFragmentDropRejectsInvalidRoll(t *testing.T) {
	if shouldDropBossTicketFragment(-1) || shouldDropBossTicketFragment(100) {
		t.Fatal("invalid roll must not drop a torn boss ticket")
	}
}

func TestBossTicketFragmentDropsOnlyInRecommendedCombatPowerRange(t *testing.T) {
	if isRecommendedCombatPowerRange(10, 829) {
		t.Fatal("power below the recommended value must not be eligible")
	}
	if !isRecommendedCombatPowerRange(10, 830) {
		t.Fatal("recommended power must be eligible")
	}
	if !isRecommendedCombatPowerRange(10, 1162) {
		t.Fatal("the upper edge of the recommended range must be eligible")
	}
	if isRecommendedCombatPowerRange(10, 1163) {
		t.Fatal("the reward-reduction range must not be eligible")
	}
}
