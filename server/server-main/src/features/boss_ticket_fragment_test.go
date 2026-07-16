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
