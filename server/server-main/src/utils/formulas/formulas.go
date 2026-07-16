package formulas

import (
	"math"
	"math/rand"
)

const (
	MinimumDamagePercent = 85
	MaximumDamagePercent = 115
)

func CalculateDamage(atk int, def int) int {
	damage := atk - def
	if damage < 1 {
		return 1
	}
	return damage
}

func CalculateDamageAtPercent(atk int, def int, percent int) int {
	if percent < MinimumDamagePercent {
		percent = MinimumDamagePercent
	}
	if percent > MaximumDamagePercent {
		percent = MaximumDamagePercent
	}
	variedAttack := int(math.Floor(float64(atk) * float64(percent) / 100))
	return CalculateDamage(variedAttack, def)
}

func CalculateRandomDamage(atk int, def int) int {
	percent := MinimumDamagePercent + rand.Intn(MaximumDamagePercent-MinimumDamagePercent+1)
	return CalculateDamageAtPercent(atk, def, percent)
}

func CalculateAttackDistance(agility int) float64 {
	return CalculateDistanceWithAgility(100, agility)
}

func CalculateDistanceWithAgility(baseDistanceM float64, agility int) float64 {
	distanceM := baseDistanceM - float64(agility)
	if distanceM < 1 {
		return 1
	}
	return distanceM
}

func CalculateMonsterAttackDistance() float64 {
	return 100
}

func CalculateEarnedAttackCount(previousRemainderM float64, deltaDistanceM int, attackDistanceM float64) (int, float64) {
	availableDistanceM := previousRemainderM + float64(deltaDistanceM)
	if attackDistanceM <= 0 || availableDistanceM < attackDistanceM {
		return 0, availableDistanceM
	}

	earned := int(math.Floor(availableDistanceM / attackDistanceM))
	remainder := math.Mod(availableDistanceM, attackDistanceM)
	return earned, remainder
}

func CalculateStatUpgradeCost(stat int) int {
	return int(math.Floor(15 + float64(stat*stat)/5 + float64(stat*2)))
}
