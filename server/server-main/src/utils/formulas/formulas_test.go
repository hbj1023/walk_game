package formulas

import "testing"

func TestCalculateDamageMinimumOne(t *testing.T) {
	if got := CalculateDamage(5, 10); got != 1 {
		t.Fatalf("CalculateDamage() = %d, want 1", got)
	}
}

func TestCalculateDamageAttackMinusDefense(t *testing.T) {
	if got := CalculateDamage(20, 7); got != 13 {
		t.Fatalf("CalculateDamage() = %d, want 13", got)
	}
}

func TestCalculateAttackDistance(t *testing.T) {
	got := CalculateAttackDistance(100)
	want := 1.0
	if got != want {
		t.Fatalf("CalculateAttackDistance() = %v, want %v", got, want)
	}
}

func TestCalculateDistanceWithAgility(t *testing.T) {
	if got := CalculateDistanceWithAgility(1000, 125); got != 875 {
		t.Fatalf("CalculateDistanceWithAgility() = %v, want 875", got)
	}
	if got := CalculateDistanceWithAgility(1000, 1500); got != 1 {
		t.Fatalf("CalculateDistanceWithAgility() = %v, want 1", got)
	}
}

func TestCalculateMonsterAttackDistance(t *testing.T) {
	if got := CalculateMonsterAttackDistance(); got != 100 {
		t.Fatalf("CalculateMonsterAttackDistance() = %v, want 100", got)
	}
}

func TestCalculateEarnedAttackCount(t *testing.T) {
	earned, remainder := CalculateEarnedAttackCount(20, 180, 75)
	if earned != 2 {
		t.Fatalf("earned = %d, want 2", earned)
	}
	if remainder != 50 {
		t.Fatalf("remainder = %v, want 50", remainder)
	}
}
