package features

import (
	"math"
	"testing"

	"server/src/utils/formulas"
)

func chapter2ExpectedCounterattacks(hitCount int, attackDistance float64, gaugePercent int) int {
	if hitCount <= 1 {
		return 0
	}
	gaugeGain := attackDistance * float64(100+gaugePercent) / 100
	return int(math.Floor(float64(hitCount-1) * gaugeGain / 100))
}

func TestChapter2BossKeepsHighRiskFastKillIdentity(t *testing.T) {
	const (
		bossHP      = 400
		bossDefense = 10
		bossAttack  = 110
	)

	builds := []struct {
		name                 string
		hp                   int
		attack               int
		defense              int
		agility              int
		bossDamagePercent    int
		damageTakenPercent   int
		gaugePercent         int
		maxHits              int
		expectPotionPressure bool
	}{
		{name: "vanguard", hp: 518, attack: 40, defense: 44, agility: 21, damageTakenPercent: -4, maxHits: 14, expectPotionPressure: true},
		{name: "berserker", hp: 504, attack: 69, defense: 21, agility: 9, bossDamagePercent: 15, damageTakenPercent: 5, maxHits: 7},
		{name: "sentinel", hp: 480, attack: 35, defense: 47, agility: 28, bossDamagePercent: 6, gaugePercent: -10, maxHits: 15, expectPotionPressure: true},
		{name: "shadow", hp: 480, attack: 32, defense: 21, agility: 68, maxHits: 19},
		{name: "colossus", hp: 528, attack: 67, defense: 30, agility: 7, bossDamagePercent: 8, damageTakenPercent: -8, maxHits: 7},
	}

	for _, build := range builds {
		t.Run(build.name, func(t *testing.T) {
			baseDamage := formulas.CalculateDamageAtPercent(build.attack, bossDefense, 100)
			playerDamage := int(math.Round(float64(baseDamage) * float64(100+build.bossDamagePercent) / 100))
			hits := ceilDiv(bossHP, playerDamage)
			if hits > build.maxHits {
				t.Fatalf("boss hits = %d, want at most %d", hits, build.maxHits)
			}

			attackDistance := formulas.CalculateAttackDistance(build.agility)
			counterattacks := chapter2ExpectedCounterattacks(hits, attackDistance, build.gaugePercent)
			baseTaken := formulas.CalculateDamageAtPercent(bossAttack, build.defense, 100)
			damageTaken := int(math.Round(float64(baseTaken) * float64(100+build.damageTakenPercent) / 100))
			remainingHP := build.hp - damageTaken*counterattacks
			if build.expectPotionPressure && remainingHP > 0 {
				t.Fatalf("remaining HP = %d, want potion or near-death pressure", remainingHP)
			}
			if !build.expectPotionPressure && remainingHP <= 0 {
				t.Fatalf("remaining HP = %d, build should survive average boss damage", remainingHP)
			}
		})
	}
}
