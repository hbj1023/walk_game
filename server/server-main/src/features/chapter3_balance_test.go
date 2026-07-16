package features

import (
	"testing"

	"server/src/utils/formulas"
)

func TestChapter3RarePacingAtAverageDamage(t *testing.T) {
	tests := []struct {
		name        string
		hp          int
		defense     int
		attack      int
		maxHitCount int
	}{
		{name: "stage 3-1 balanced rare", hp: 220, defense: 22, attack: 72, maxHitCount: 5},
		{name: "stage 3-3 balanced rare", hp: 330, defense: 32, attack: 78, maxHitCount: 8},
		{name: "stage 3-4 balanced rare", hp: 400, defense: 38, attack: 80, maxHitCount: 10},
		{name: "stage 3-5 penetration set", hp: 520, defense: 32, attack: 80, maxHitCount: 11},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			damage := formulas.CalculateDamageAtPercent(tt.attack, tt.defense, 100)
			hits := ceilDiv(tt.hp, damage)
			if hits > tt.maxHitCount {
				t.Fatalf("hits to clear = %d, want at most %d (damage %d)", hits, tt.maxHitCount, damage)
			}
		})
	}
}
