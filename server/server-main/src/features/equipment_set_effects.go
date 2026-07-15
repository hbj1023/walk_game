package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"sort"
	"strings"
)

const equipmentSetBonusesCollection = "equipment_set_bonuses"

type battleSetEffects struct {
	DamageTakenPercent        float64 `json:"damage_taken_percent"`
	MonsterGaugePercent       float64 `json:"monster_gauge_percent"`
	AttackDistancePercent     float64 `json:"attack_distance_percent"`
	BossDamagePercent         float64 `json:"boss_damage_percent"`
	DefensePenetrationPercent float64 `json:"defense_penetration_percent"`
	DefenseShredPerHit        float64 `json:"defense_shred_per_hit"`
	FixedDamage               float64 `json:"fixed_damage"`
}

type battleStatContext struct {
	Stats         statBlock                 `json:"stats"`
	SetBonusStats statBlock                 `json:"set_bonus_stats"`
	Effects       battleSetEffects          `json:"effects"`
	ActiveBonuses []equipmentSetBonusRecord `json:"active_bonuses"`
}

func getBattleStatContext(
	ctx context.Context,
	token string,
	characterID string,
	stats battleCharacterStatsRecord,
) (battleStatContext, error) {
	equipmentStats, equippedItems, err := getEquippedStats(ctx, token, characterID)
	if err != nil {
		return battleStatContext{}, err
	}
	return buildBattleStatContext(ctx, token, stats, equipmentStats, equippedItems)
}

func buildBattleStatContext(
	ctx context.Context,
	token string,
	stats battleCharacterStatsRecord,
	equipmentStats statBlock,
	equippedItems []equippedStatItem,
) (battleStatContext, error) {
	rawStats := addStatBlocks(statBlock{
		HP:      stats.HP(),
		Attack:  stats.Attack(),
		Defense: stats.Defense(),
		Agility: stats.Agility(),
	}, equipmentStats)

	setCounts := countEquippedSetPieces(equippedItems)
	activeBonuses, err := listActiveEquipmentSetBonuses(ctx, token, setCounts)
	if err != nil {
		return battleStatContext{}, err
	}

	setBonusStats, effects := summarizeSetBonuses(rawStats, activeBonuses)
	return battleStatContext{
		Stats:         addStatBlocks(rawStats, setBonusStats),
		SetBonusStats: setBonusStats,
		Effects:       effects,
		ActiveBonuses: activeBonuses,
	}, nil
}

func countEquippedSetPieces(items []equippedStatItem) map[string]int {
	piecesBySet := map[string]map[string]bool{}
	for _, item := range items {
		setKey := equippedItemSetKey(item)
		if setKey == "" {
			continue
		}
		piece := equippedItemPieceType(item)
		if piece == "" {
			continue
		}
		if piecesBySet[setKey] == nil {
			piecesBySet[setKey] = map[string]bool{}
		}
		piecesBySet[setKey][piece] = true
	}

	counts := map[string]int{}
	for setKey, pieces := range piecesBySet {
		counts[setKey] = len(pieces)
	}
	return counts
}

func equippedItemSetKey(item equippedStatItem) string {
	if setKey := strings.TrimSpace(item.SetKey); setKey != "" {
		return setKey
	}
	source := strings.ToLower(strings.Join([]string{
		item.Name,
		item.WeaponType,
		item.Slot,
	}, " "))
	for _, setKey := range []string{"vanguard", "berserker", "sentinel", "shadow", "colossus"} {
		if strings.Contains(source, setKey) {
			return setKey
		}
	}
	if strings.Contains(item.Name, "모험가") {
		return "vanguard"
	}
	if strings.Contains(item.Name, "광전사") {
		return "berserker"
	}
	if strings.Contains(item.Name, "창술사") {
		return "sentinel"
	}
	if strings.Contains(item.Name, "도적") {
		return "shadow"
	}
	if strings.Contains(item.Name, "견습기사") {
		return "colossus"
	}
	switch strings.TrimSpace(item.WeaponType) {
	case "axe":
		return "berserker"
	case "spear":
		return "sentinel"
	case "dagger":
		return "shadow"
	case "greatsword":
		return "colossus"
	default:
		return ""
	}
}

func equippedItemPieceType(item equippedStatItem) string {
	piece := strings.TrimSpace(item.SetPieceType)
	if piece == "sword" {
		return "weapon"
	}
	if piece != "" {
		return piece
	}
	if strings.TrimSpace(item.Slot) == "sword" || strings.TrimSpace(item.WeaponType) != "" {
		return "weapon"
	}
	if slot := strings.TrimSpace(item.Slot); slot != "" {
		return slot
	}
	return strings.TrimSpace(item.TemplateID)
}

func listActiveEquipmentSetBonuses(
	ctx context.Context,
	token string,
	setCounts map[string]int,
) ([]equipmentSetBonusRecord, error) {
	if len(setCounts) == 0 {
		return nil, nil
	}

	setKeys := make([]string, 0, len(setCounts))
	for setKey := range setCounts {
		setKeys = append(setKeys, setKey)
	}
	sort.Strings(setKeys)

	active := make([]equipmentSetBonusRecord, 0)
	for _, setKey := range setKeys {
		bonuses, err := listEquipmentSetBonusesByKey(ctx, token, setKey)
		if err != nil {
			return nil, err
		}
		count := setCounts[setKey]
		for _, bonus := range bonuses {
			if bonus.RequiredCount <= count {
				active = append(active, bonus)
			}
		}
	}

	sort.Slice(active, func(i, j int) bool {
		if active[i].SetKey != active[j].SetKey {
			return active[i].SetKey < active[j].SetKey
		}
		if active[i].RequiredCount != active[j].RequiredCount {
			return active[i].RequiredCount < active[j].RequiredCount
		}
		return active[i].BonusType < active[j].BonusType
	})
	return active, nil
}

func listEquipmentSetBonusesByKey(ctx context.Context, token string, setKey string) ([]equipmentSetBonusRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("set_key=%q && is_active=true", setKey))
	endpoint := pocketBaseCollectionURL(equipmentSetBonusesCollection) +
		"?filter=" + filter + "&sort=required_count,bonus_type&perPage=20"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list equipment set bonuses")
	}

	var list pocketBaseListResponse[equipmentSetBonusRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse equipment set bonuses response")
	}
	return list.Items, nil
}

func enrichItemTemplatesWithSetBonuses(ctx context.Context, token string, items []map[string]any) error {
	if len(items) == 0 {
		return nil
	}

	cache := map[string][]equipmentSetBonusRecord{}
	for _, item := range items {
		template, ok := expandedItemTemplateMap(item)
		if !ok {
			continue
		}

		setKey := inferEquipmentSetKeyFromMap(template)
		if setKey == "" {
			continue
		}

		bonuses, cached := cache[setKey]
		if !cached {
			var err error
			bonuses, err = listEquipmentSetBonusesByKey(ctx, token, setKey)
			if err != nil {
				return err
			}
			cache[setKey] = bonuses
		}
		template["set_bonuses"] = bonuses
	}
	return nil
}

func expandedItemTemplateMap(item map[string]any) (map[string]any, bool) {
	expand, ok := item["expand"].(map[string]any)
	if !ok {
		return nil, false
	}
	template, ok := expand["item_template"].(map[string]any)
	if ok {
		return template, true
	}
	return nil, false
}

func inferEquipmentSetKeyFromMap(template map[string]any) string {
	if setKey := mapString(template["set_key"]); setKey != "" {
		return setKey
	}

	source := strings.ToLower(
		mapString(template["image_path"]) + " " +
			mapString(template["name"]) + " " +
			mapString(template["description"]),
	)
	for _, setKey := range []string{"vanguard", "berserker", "sentinel", "shadow", "colossus"} {
		if strings.Contains(source, setKey) {
			return setKey
		}
	}

	pieceType := mapString(template["set_piece_type"])
	slot := mapString(template["equipment_slot"])
	if pieceType == "weapon" || slot == "sword" {
		switch mapString(template["weapon_type"]) {
		case "sword":
			return "vanguard"
		case "axe":
			return "berserker"
		case "spear":
			return "sentinel"
		case "dagger":
			return "shadow"
		case "greatsword":
			return "colossus"
		}
	}
	return ""
}

func summarizeSetBonuses(rawStats statBlock, bonuses []equipmentSetBonusRecord) (statBlock, battleSetEffects) {
	stats := statBlock{}
	effects := battleSetEffects{}
	for _, bonus := range bonuses {
		switch bonus.BonusType {
		case "hp_percent":
			stats.HP += percentStatDelta(rawStats.HP, bonus.BonusValue)
		case "attack_percent":
			stats.Attack += percentStatDelta(rawStats.Attack, bonus.BonusValue)
		case "defense_percent":
			stats.Defense += percentStatDelta(rawStats.Defense, bonus.BonusValue)
		case "agility_percent":
			stats.Agility += percentStatDelta(rawStats.Agility, bonus.BonusValue)
		case "damage_taken_percent":
			effects.DamageTakenPercent += bonus.BonusValue
		case "monster_gauge_percent":
			effects.MonsterGaugePercent += bonus.BonusValue
		case "attack_distance_percent":
			effects.AttackDistancePercent += bonus.BonusValue
		case "boss_damage_percent":
			effects.BossDamagePercent += bonus.BonusValue
		case "defense_penetration_percent":
			effects.DefensePenetrationPercent += bonus.BonusValue
		case "defense_shred_per_hit":
			effects.DefenseShredPerHit += bonus.BonusValue
		case "fixed_damage":
			effects.FixedDamage += bonus.BonusValue
		}
	}
	return stats, effects
}

func percentStatDelta(value int, percent float64) int {
	if value == 0 || percent == 0 {
		return 0
	}
	delta := float64(value) * percent / 100
	if delta > 0 {
		result := int(math.Floor(delta))
		if result == 0 {
			return 1
		}
		return result
	}
	result := int(math.Ceil(delta))
	if result == 0 {
		return -1
	}
	return result
}

func adjustedAttackDistance(distanceM float64, effects battleSetEffects) float64 {
	return applyBattlePercentToDistance(distanceM, effects.AttackDistancePercent)
}

func adjustedMonsterGaugeGain(distanceM float64, effects battleSetEffects) float64 {
	return applyBattlePercentToDistance(distanceM, effects.MonsterGaugePercent)
}

func adjustedPlayerDamage(damage int, battleType string, effects battleSetEffects) int {
	if battleType != "boss" {
		return damage + fixedSetDamage(effects)
	}
	return applyBattlePercentToDamage(damage, effects.BossDamagePercent) + fixedSetDamage(effects)
}

func fixedSetDamage(effects battleSetEffects) int {
	if effects.FixedDamage <= 0 {
		return 0
	}
	return int(math.Round(effects.FixedDamage))
}

func adjustedMonsterDamage(damage int, effects battleSetEffects) int {
	return applyBattlePercentToDamage(damage, effects.DamageTakenPercent)
}

func adjustedMonsterDefense(defense int, effects battleSetEffects) int {
	if defense <= 0 || effects.DefensePenetrationPercent <= 0 {
		return defense
	}
	penetration := effects.DefensePenetrationPercent
	if penetration > 100 {
		penetration = 100
	}
	adjusted := int(math.Ceil(float64(defense) * (1 - penetration/100)))
	if adjusted < 0 {
		return 0
	}
	return adjusted
}

func adjustedMonsterDefenseForHit(defense int, effects battleSetEffects, attackNumber int) int {
	adjusted := adjustedMonsterDefense(defense, effects)
	if adjusted <= 0 || effects.DefenseShredPerHit <= 0 || attackNumber <= 0 {
		return adjusted
	}
	shred := int(math.Round(effects.DefenseShredPerHit)) * attackNumber
	if shred >= adjusted {
		return 0
	}
	return adjusted - shred
}

func applyBattlePercentToDistance(distanceM float64, percent float64) float64 {
	if distanceM <= 0 || percent == 0 {
		return distanceM
	}
	adjusted := distanceM * (1 + percent/100)
	if adjusted < 1 {
		return 1
	}
	return adjusted
}

func applyBattlePercentToDamage(damage int, percent float64) int {
	if damage <= 0 || percent == 0 {
		return damage
	}
	adjusted := int(math.Floor(float64(damage) * (1 + percent/100)))
	if adjusted < 1 {
		return 1
	}
	return adjusted
}
