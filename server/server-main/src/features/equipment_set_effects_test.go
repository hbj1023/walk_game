package features

import "testing"

func TestCountEquippedSetPiecesUsesUniquePieces(t *testing.T) {
	items := []equippedStatItem{
		{SetKey: "shadow", SetPieceType: "helmet"},
		{SetKey: "shadow", SetPieceType: "armor"},
		{SetKey: "shadow", SetPieceType: "armor"},
		{SetKey: "shadow", SetPieceType: "weapon"},
		{SetKey: "", SetPieceType: "shoes"},
	}

	got := countEquippedSetPieces(items)
	if got["shadow"] != 3 {
		t.Fatalf("shadow set count = %d, want 3", got["shadow"])
	}
}

func TestSummarizeSetBonusesAppliesStatAndBattleEffects(t *testing.T) {
	raw := statBlock{HP: 300, Attack: 80, Defense: 40, Agility: 50}
	bonuses := []equipmentSetBonusRecord{
		{BonusType: "attack_percent", BonusValue: 10},
		{BonusType: "damage_taken_percent", BonusValue: -3},
		{BonusType: "attack_distance_percent", BonusValue: -8},
		{BonusType: "boss_damage_percent", BonusValue: 10},
	}

	stats, effects := summarizeSetBonuses(raw, bonuses)
	if stats.Attack != 8 {
		t.Fatalf("attack bonus = %d, want 8", stats.Attack)
	}
	if effects.DamageTakenPercent != -3 {
		t.Fatalf("damage taken percent = %v, want -3", effects.DamageTakenPercent)
	}
	if effects.AttackDistancePercent != -8 {
		t.Fatalf("attack distance percent = %v, want -8", effects.AttackDistancePercent)
	}
	if effects.BossDamagePercent != 10 {
		t.Fatalf("boss damage percent = %v, want 10", effects.BossDamagePercent)
	}
}

func TestAdjustedBattleEffects(t *testing.T) {
	effects := battleSetEffects{
		DamageTakenPercent:    -3,
		MonsterGaugePercent:   -8,
		AttackDistancePercent: -8,
		BossDamagePercent:     10,
	}

	if got := adjustedAttackDistance(100, effects); got != 92 {
		t.Fatalf("adjusted attack distance = %v, want 92", got)
	}
	if got := adjustedMonsterGaugeGain(100, effects); got != 92 {
		t.Fatalf("adjusted monster gauge gain = %v, want 92", got)
	}
	if got := adjustedPlayerDamage(100, "boss", effects); got != 110 {
		t.Fatalf("adjusted boss player damage = %d, want 110", got)
	}
	if got := adjustedPlayerDamage(100, "normal", effects); got != 100 {
		t.Fatalf("adjusted normal player damage = %d, want 100", got)
	}
	if got := adjustedMonsterDamage(100, effects); got != 97 {
		t.Fatalf("adjusted monster damage = %d, want 97", got)
	}
}
