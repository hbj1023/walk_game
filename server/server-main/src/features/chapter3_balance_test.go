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

func TestChapter3EntryCounterattackPressure(t *testing.T) {
	const (
		chapter2RareHP      = 522
		chapter2RareDefense = 55
		stage31Attack       = 88
		counterattacks      = 12
	)

	damage := formulas.CalculateDamageAtPercent(stage31Attack, chapter2RareDefense, 100)
	remainingHP := chapter2RareHP - damage*counterattacks
	if remainingHP < 80 || remainingHP > 180 {
		t.Fatalf("remaining HP after stage 3-1 entry pressure = %d, want 80..180", remainingHP)
	}
}

func TestChapter3CommonFourPieceSetsCanClearStage33(t *testing.T) {
	const (
		stage33HP      = 280
		stage33Defense = 32
	)

	builds := []struct {
		name               string
		attack             int
		penetrationPercent int
		maxHitCount        int
	}{
		{name: "swordsman", attack: 63, penetrationPercent: 30, maxHitCount: 8},
		{name: "berserker", attack: 90, penetrationPercent: 20, maxHitCount: 5},
		{name: "spearmaster", attack: 48, penetrationPercent: 30, maxHitCount: 13},
		{name: "rogue", attack: 51, penetrationPercent: 25, maxHitCount: 11},
		{name: "knight", attack: 74, penetrationPercent: 20, maxHitCount: 6},
	}

	for _, build := range builds {
		t.Run(build.name, func(t *testing.T) {
			effectiveDefense := stage33Defense * (100 - build.penetrationPercent) / 100
			damage := formulas.CalculateDamageAtPercent(build.attack, effectiveDefense, 100)
			hits := ceilDiv(stage33HP, damage)
			if hits > build.maxHitCount {
				t.Fatalf("stage 3-3 hits = %d, want at most %d", hits, build.maxHitCount)
			}
		})
	}
}
