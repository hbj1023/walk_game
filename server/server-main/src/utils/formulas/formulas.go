package formulas

import "math"

func CalculateDamage(atk int, def int) int {
	damage := atk - def
	if damage < 1 {
		return 1
	}
	return damage
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
