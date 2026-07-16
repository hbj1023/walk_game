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

func TestCalculateDamageAtPercentAppliesDefenseAfterVariance(t *testing.T) {
	tests := []struct {
		percent int
		want    int
	}{
		{percent: 85, want: 27},
		{percent: 100, want: 35},
		{percent: 115, want: 42},
	}
	for _, tt := range tests {
		if got := CalculateDamageAtPercent(50, 15, tt.percent); got != tt.want {
			t.Fatalf("CalculateDamageAtPercent(50, 15, %d) = %d, want %d", tt.percent, got, tt.want)
		}
	}
}

func TestCalculateRandomDamageStaysWithinConfiguredRange(t *testing.T) {
	for i := 0; i < 1000; i++ {
		got := CalculateRandomDamage(50, 15)
		if got < 27 || got > 42 {
			t.Fatalf("CalculateRandomDamage() = %d, want between 27 and 42", got)
		}
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
