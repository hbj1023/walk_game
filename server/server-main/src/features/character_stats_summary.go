package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

func characterStatsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "character stats fetch failed", "error": "method not allowed"})
		return
	}

	characterID, ok := parseCharacterStatsPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "character stats fetch failed", "error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "character stats fetch failed", "error": "unauthorized"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, user.ID, characterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]string{"message": "character stats fetch failed", "error": err.Error()})
		return
	}

	summary, err := getCharacterStatsSummary(r.Context(), token, characterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "character stats fetch failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "character stats fetched", summary)
}

func parseCharacterStatsPath(path string) (string, bool) {
	const prefix = "/api/characters/stats/"
	if !strings.HasPrefix(path, prefix) {
		return "", false
	}
	characterID := strings.Trim(strings.TrimPrefix(path, prefix), "/")
	return characterID, characterID != ""
}

func getCharacterStatsSummary(ctx context.Context, token string, characterID string) (map[string]any, error) {
	stats, err := getBattleCharacterStats(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	baseStats := statBlock{
		HP:      stats.BaseHP,
		Attack:  stats.BaseAttack,
		Defense: stats.BaseDefense,
		Agility: stats.BaseAgility,
	}
	upgradeStats := statBlock{
		HP:      stats.UpgradedHP,
		Attack:  stats.UpgradedAttack,
		Defense: stats.UpgradedDefense,
		Agility: stats.UpgradedAgility,
	}

	equipmentStats, equippedItems, err := getEquippedStats(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	finalStats := addStatBlocks(baseStats, upgradeStats, equipmentStats)
	return map[string]any{
		"character_id":    characterID,
		"base_stats":      baseStats,
		"upgrade_stats":   upgradeStats,
		"equipment_stats": equipmentStats,
		"final_stats":     finalStats,
		"equipped_items":  equippedItems,
		"character_stats": stats,
	}, nil
}

func getEquippedStats(ctx context.Context, token string, characterID string) (statBlock, []equippedStatItem, error) {
	records, err := listEquippedStatRecords(ctx, token, characterID)
	if err != nil {
		return statBlock{}, nil, err
	}

	total := statBlock{}
	items := make([]equippedStatItem, 0, len(records))
	for _, record := range records {
		owned := record.Expand.OwnedEquipment
		template := owned.Expand.ItemTemplate
		itemStats := statBlock{
			HP:      owned.RolledHP,
			Attack:  owned.RolledAttack,
			Defense: owned.RolledDefense,
			Agility: owned.RolledAgility,
		}
		total = addStatBlocks(total, itemStats)
		items = append(items, equippedStatItem{
			EquipmentID: owned.ID,
			TemplateID:  owned.ItemTemplate,
			Name:        template.Name,
			Slot:        template.EquipmentSlot,
			Rarity:      template.Rarity,
			Stats:       itemStats,
		})
	}
	return total, items, nil
}

func listEquippedStatRecords(ctx context.Context, token string, characterID string) ([]equippedStatRecord, error) {
	query := url.Values{}
	query.Set("filter", fmt.Sprintf("character=%q", characterID))
	query.Set("expand", "owned_equipment,owned_equipment.item_template")
	query.Set("sort", "owned_equipment.item_template.equipment_slot")
	query.Set("perPage", "100")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(characterEquipmentsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list equipped stat records")
	}

	var list pocketBaseListResponse[equippedStatRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse equipped stat records response")
	}
	return list.Items, nil
}

func addStatBlocks(blocks ...statBlock) statBlock {
	total := statBlock{}
	for _, block := range blocks {
		total.HP += block.HP
		total.Attack += block.Attack
		total.Defense += block.Defense
		total.Agility += block.Agility
	}
	return total
}
