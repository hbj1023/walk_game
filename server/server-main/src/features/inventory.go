package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	itemTemplatesCollection           = "item_templates"
	ownedEquipmentsCollection         = "owned_equipments"
	characterConsumablesCollection    = "character_consumables"
	characterEquipmentsCollection     = "character_equipments"
	equipmentSlotBalancesCollection   = "equipment_slot_balances"
	equipmentRarityBalancesCollection = "equipment_rarity_balances"
	equipmentSellRefundRate           = 0.50
	bossEntranceTicketFragmentName    = "보스 입장권 조각"
	bossEntranceTicketFragmentCost    = 10
)

func itemsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	itemType := strings.TrimSpace(r.URL.Query().Get("type"))
	if itemType != "" && itemType != "equipment" && itemType != "consumable" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "type must be equipment or consumable"})
		return
	}

	items, err := listItems(r.Context(), token, itemType)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "items fetched", items)
}

func characterInventoryHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	characterID, resource, ok := parseCharacterInventoryPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, user.ID, characterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]string{"error": err.Error()})
		return
	}

	if r.Method == http.MethodPost {
		switch resource {
		case "consumables/use":
			handleConsumableUse(w, r, token, characterID)
		case "consumables/sell":
			handleConsumableSell(w, r, token, characterID)
		default:
			handleEquipmentAction(w, r, token, characterID, resource)
		}
		return
	}

	handleInventoryLookup(w, r, token, characterID, resource)
}

func handleInventoryLookup(w http.ResponseWriter, r *http.Request, token string, characterID string, resource string) {
	var (
		data    any
		err     error
		message string
	)

	switch resource {
	case "equipments":
		data, err = listOwnedEquipments(r.Context(), token, characterID)
		message = "owned equipments fetched"
	case "consumables":
		data, err = listCharacterConsumables(r.Context(), token, characterID)
		message = "character consumables fetched"
	case "equipped":
		data, err = listEquippedItems(r.Context(), token, characterID)
		message = "equipped items fetched"
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, message, data)
}

func handleEquipmentAction(w http.ResponseWriter, r *http.Request, token string, characterID string, resource string) {
	if resource != "equip" && resource != "unequip" && resource != "equipments/sell" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	var req equipmentActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.OwnedEquipmentID = strings.TrimSpace(req.OwnedEquipmentID)
	if req.OwnedEquipmentID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "ownedEquipmentId is required"})
		return
	}

	var (
		data    any
		err     error
		message string
	)
	switch resource {
	case "equip":
		data, err = equipOwnedEquipment(r.Context(), token, characterID, req.OwnedEquipmentID)
		message = "equipment equipped"
	case "unequip":
		data, err = unequipOwnedEquipment(r.Context(), token, characterID, req.OwnedEquipmentID)
		message = "equipment unequipped"
	case "equipments/sell":
		data, err = sellOwnedEquipment(r.Context(), token, characterID, req.OwnedEquipmentID)
		message = "equipment sold"
	}
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{
			"message": "equipment action failed",
			"error":   err.Error(),
		})
		return
	}

	writeInventoryResponse(w, http.StatusOK, message, data)
}

func equipmentSlotBalancesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	balances, err := listCollectionRecords(r.Context(), token, equipmentSlotBalancesCollection, "", "", "slot_type")
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "equipment slot balances fetched", balances)
}

func equipmentRarityBalancesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	balances, err := listCollectionRecords(r.Context(), token, equipmentRarityBalancesCollection, "", "", "rarity")
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "equipment rarity balances fetched", balances)
}

func parseCharacterInventoryPath(path string) (string, string, bool) {
	const prefix = "/api/characters/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) < 2 || parts[0] == "" {
		return "", "", false
	}
	for _, part := range parts[1:] {
		if part == "" {
			return "", "", false
		}
	}
	return parts[0], strings.Join(parts[1:], "/"), true
}

func writeInventoryResponse(w http.ResponseWriter, status int, message string, data any) {
	writeJSON(w, status, map[string]any{
		"message": message,
		"data":    data,
	})
}

func ensureCharacterOwner(ctx context.Context, token string, userID string, characterID string) error {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return err
	}
	if character.User != userID {
		return statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	return nil
}

func listItems(ctx context.Context, token string, itemType string) (pocketBaseListResponse[map[string]any], error) {
	filter := ""
	if itemType != "" {
		filter = fmt.Sprintf("item_type=%q", itemType)
	}
	return listCollectionRecords(ctx, token, itemTemplatesCollection, filter, "", "item_type,name")
}

func listOwnedEquipments(ctx context.Context, token string, characterID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("character=%q && status!=\"sold\" && status!=\"deleted\"", characterID)
	list, err := listCollectionRecords(ctx, token, ownedEquipmentsCollection, filter, "item_template", "-created")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	if err := enrichItemTemplatesWithSetBonuses(ctx, token, list.Items); err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return list, nil
}

func listCharacterConsumables(ctx context.Context, token string, characterID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("character=%q && quantity>0", characterID)
	return listCollectionRecords(ctx, token, characterConsumablesCollection, filter, "item_template", "-created")
}

func listEquippedItems(ctx context.Context, token string, characterID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("character=%q", characterID)
	return listCollectionRecords(ctx, token, characterEquipmentsCollection, filter, "owned_equipment,owned_equipment.item_template", "-equipped_at,-created")
}

func handleConsumableUse(w http.ResponseWriter, r *http.Request, token string, characterID string) {
	var req consumableUseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}

	req.ItemTemplateID = strings.TrimSpace(req.ItemTemplateID)
	if req.ItemTemplateID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "itemTemplateId is required"})
		return
	}
	if req.UseQuantity <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "useQuantity must be greater than 0"})
		return
	}

	data, err := useConsumable(r.Context(), token, characterID, req.ItemTemplateID, req.UseQuantity)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{
			"message": "consumable use failed",
			"error":   err.Error(),
		})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "consumable used", data)
}

func handleConsumableSell(w http.ResponseWriter, r *http.Request, token string, characterID string) {
	var req consumableUseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}

	req.ItemTemplateID = strings.TrimSpace(req.ItemTemplateID)
	if req.ItemTemplateID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "itemTemplateId is required"})
		return
	}
	if req.UseQuantity <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "useQuantity must be greater than 0"})
		return
	}

	data, err := sellConsumable(r.Context(), token, characterID, req.ItemTemplateID, req.UseQuantity)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{
			"message": "consumable sell failed",
			"error":   err.Error(),
		})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "consumable sold", data)
}

func useConsumable(ctx context.Context, token string, characterID string, itemTemplateID string, useQuantity int) (map[string]any, error) {
	itemTemplate, err := getItemTemplate(ctx, token, itemTemplateID)
	if err != nil {
		return nil, err
	}
	if itemTemplate.ItemType != "consumable" {
		return nil, statusError{status: http.StatusBadRequest, message: "item template is not consumable"}
	}
	if isBossEntranceTicketTemplate(itemTemplate) || isBossEntranceTicketFragmentTemplate(itemTemplate) {
		return nil, statusError{status: http.StatusBadRequest, message: "item cannot be used manually"}
	}

	consumable, err := getCharacterConsumable(ctx, token, characterID, itemTemplateID)
	if err != nil {
		return nil, err
	}
	if consumable.Quantity < float64(useQuantity) {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough consumable quantity"}
	}

	remainingQuantity := consumable.Quantity - float64(useQuantity)
	updated, err := patchCharacterConsumableQuantity(ctx, token, consumable.ID, remainingQuantity)
	if err != nil {
		return nil, err
	}

	var updatedCharacter any
	var updatedBattle any
	recoveredHP := 0
	if itemTemplate.RecoverHP > 0 {
		character, err := getBattleCharacterByID(ctx, token, characterID)
		if err != nil {
			return nil, err
		}
		maxHP, err := getCharacterFinalHP(ctx, token, characterID)
		if err != nil {
			return nil, err
		}
		recoverAmount := int(itemTemplate.RecoverHP) * useQuantity

		currentHP := character.CurrentHP
		var currentBattle *battleRecord
		if battle, found, err := findCurrentCharacterBattle(ctx, token, characterID); err != nil {
			return nil, err
		} else if found {
			unlockBattle := lockNormalBattle(battle.ID)
			defer unlockBattle()

			refreshedBattle, err := getBattleByID(ctx, token, battle.ID)
			if err != nil {
				return nil, err
			}
			if refreshedBattle.Status == "in_progress" && refreshedBattle.MonsterCurrentHP > 0 && refreshedBattle.CharacterCurrentHP > 0 {
				currentBattle = &refreshedBattle
				currentHP = refreshedBattle.CharacterCurrentHP
			}
		}

		nextHP := calculateRecoveredHP(currentHP, recoverAmount, maxHP)
		recoveredHP = nextHP - currentHP
		patchedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
			"current_hp": nextHP,
		})
		if err != nil {
			return nil, err
		}
		updatedCharacter = patchedCharacter
		if currentBattle != nil {
			patchedBattle, err := patchBattle(ctx, token, currentBattle.ID, map[string]any{
				"character_current_hp": nextHP,
			})
			if err != nil {
				return nil, err
			}
			updatedBattle = patchedBattle
		}
	}

	return map[string]any{
		"character_consumable": updated,
		"remaining_quantity":   remainingQuantity,
		"character":            updatedCharacter,
		"battle":               updatedBattle,
		"recovered_hp":         recoveredHP,
	}, nil
}

func findCurrentCharacterBattle(ctx context.Context, token string, characterID string) (battleRecord, bool, error) {
	for _, battleType := range []string{"normal", "boss"} {
		battle, found, err := findCurrentBattleByType(ctx, token, characterID, battleType)
		if err != nil {
			return battleRecord{}, false, err
		}
		if found {
			return battle, true, nil
		}
	}
	return battleRecord{}, false, nil
}

func getCharacterFinalHP(ctx context.Context, token string, characterID string) (int, error) {
	stats, err := getBattleCharacterStats(ctx, token, characterID)
	if err != nil {
		return 0, err
	}
	statContext, err := getBattleStatContext(ctx, token, characterID, stats)
	if err != nil {
		return 0, err
	}
	return statContext.Stats.HP, nil
}

func calculateRecoveredHP(currentHP int, recoverAmount int, maxHP int) int {
	nextHP := currentHP + recoverAmount
	if nextHP > maxHP {
		return maxHP
	}
	if nextHP < 0 {
		return 0
	}
	return nextHP
}

func syncCharacterHPAfterMaxHPChange(ctx context.Context, token string, characterID string, beforeMaxHP int) (battleCharacterRecord, any, int, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return battleCharacterRecord{}, nil, 0, err
	}
	afterMaxHP, err := getCharacterFinalHP(ctx, token, characterID)
	if err != nil {
		return battleCharacterRecord{}, nil, 0, err
	}
	if beforeMaxHP <= 0 || afterMaxHP <= 0 || beforeMaxHP == afterMaxHP {
		return character, nil, 0, nil
	}

	currentHP := character.CurrentHP
	var currentBattle *battleRecord
	if battle, found, err := findCurrentCharacterBattle(ctx, token, characterID); err != nil {
		return battleCharacterRecord{}, nil, 0, err
	} else if found {
		refreshedBattle, err := getBattleByID(ctx, token, battle.ID)
		if err != nil {
			return battleCharacterRecord{}, nil, 0, err
		}
		if refreshedBattle.Status == "in_progress" && refreshedBattle.MonsterCurrentHP > 0 {
			currentBattle = &refreshedBattle
			currentHP = refreshedBattle.CharacterCurrentHP
		}
	}

	nextHP := currentHP
	if afterMaxHP > beforeMaxHP {
		if currentHP > 0 {
			nextHP = currentHP + (afterMaxHP - beforeMaxHP)
			if nextHP > afterMaxHP {
				nextHP = afterMaxHP
			}
		}
	} else if currentHP > afterMaxHP {
		nextHP = afterMaxHP
	}
	if nextHP < 0 {
		nextHP = 0
	}
	hpDelta := nextHP - currentHP
	if nextHP == currentHP {
		return character, nil, 0, nil
	}

	patchedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"current_hp": nextHP,
	})
	if err != nil {
		return battleCharacterRecord{}, nil, 0, err
	}

	var updatedBattle any
	if currentBattle != nil && currentBattle.CharacterCurrentHP != nextHP {
		patchedBattle, err := patchBattle(ctx, token, currentBattle.ID, map[string]any{
			"character_current_hp": nextHP,
		})
		if err != nil {
			return battleCharacterRecord{}, nil, 0, err
		}
		updatedBattle = patchedBattle
	}
	return patchedCharacter, updatedBattle, hpDelta, nil
}

func sellConsumable(ctx context.Context, token string, characterID string, itemTemplateID string, sellQuantity int) (map[string]any, error) {
	itemTemplate, err := getItemTemplate(ctx, token, itemTemplateID)
	if err != nil {
		return nil, err
	}
	if itemTemplate.ItemType != "consumable" {
		return nil, statusError{status: http.StatusBadRequest, message: "item template is not consumable"}
	}
	if isBossEntranceTicketTemplate(itemTemplate) || isBossEntranceTicketFragmentTemplate(itemTemplate) {
		return nil, statusError{status: http.StatusBadRequest, message: "item cannot be sold"}
	}

	consumable, err := getCharacterConsumable(ctx, token, characterID, itemTemplateID)
	if err != nil {
		return nil, err
	}
	if consumable.Quantity < float64(sellQuantity) {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough consumable quantity"}
	}

	refundCoin := itemSellRefundCoin(itemTemplate.PriceCoin, sellQuantity)
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	coinBalance := character.CoinBalance + refundCoin

	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"coin_balance": coinBalance,
	})
	if err != nil {
		return nil, err
	}

	remainingQuantity := consumable.Quantity - float64(sellQuantity)
	updatedConsumable, err := patchCharacterConsumableQuantity(ctx, token, consumable.ID, remainingQuantity)
	if err != nil {
		return nil, err
	}

	if refundCoin > 0 {
		if err := createInventorySellResourceTransaction(ctx, token, characterID, "consumable_sell", itemTemplateID, refundCoin, coinBalance, "consumable sell refund"); err != nil {
			return nil, err
		}
	}

	return map[string]any{
		"character":            updatedCharacter,
		"character_consumable": updatedConsumable,
		"remaining_quantity":   remainingQuantity,
		"refund_coin":          refundCoin,
		"refund_rate":          equipmentSellRefundRate,
		"original_price_coin":  itemTemplate.PriceCoin,
		"sell_quantity":        sellQuantity,
	}, nil
}

func getItemTemplate(ctx context.Context, token string, itemTemplateID string) (itemTemplateRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(itemTemplatesCollection, itemTemplateID), token, nil)
	if err != nil {
		return itemTemplateRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		if resp.StatusCode == http.StatusNotFound {
			return itemTemplateRecord{}, statusError{status: http.StatusNotFound, message: "item template not found"}
		}
		return itemTemplateRecord{}, mapPocketBaseError(resp, "failed to get item template")
	}

	var record itemTemplateRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return itemTemplateRecord{}, errors.New("failed to parse item template response")
	}
	return record, nil
}

func getCharacterConsumable(ctx context.Context, token string, characterID string, itemTemplateID string) (characterConsumableRecord, error) {
	filter := fmt.Sprintf("character=%q && item_template=%q", characterID, itemTemplateID)
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(characterConsumablesCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return characterConsumableRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return characterConsumableRecord{}, mapPocketBaseError(resp, "failed to get character consumable")
	}

	var list pocketBaseListResponse[characterConsumableRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return characterConsumableRecord{}, errors.New("failed to parse character consumable response")
	}
	if len(list.Items) == 0 {
		return characterConsumableRecord{}, statusError{status: http.StatusNotFound, message: "character consumable not found"}
	}
	return list.Items[0], nil
}

func patchCharacterConsumableQuantity(ctx context.Context, token string, consumableID string, quantity float64) (map[string]any, error) {
	// Keep the record even when quantity reaches 0 so inventory history remains stable.
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(characterConsumablesCollection, consumableID), token, map[string]any{
		"quantity": quantity,
	})
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update consumable quantity")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse consumable update response")
	}
	return record, nil
}

func normalizedItemName(name string) string {
	return strings.ToLower(strings.ReplaceAll(strings.TrimSpace(name), " ", ""))
}

func isBossEntranceTicketTemplate(itemTemplate itemTemplateRecord) bool {
	return normalizedItemName(itemTemplate.Name) == normalizedItemName(bossEntranceTicketName)
}

func isBossEntranceTicketFragmentTemplate(itemTemplate itemTemplateRecord) bool {
	return normalizedItemName(itemTemplate.Name) == normalizedItemName(bossEntranceTicketFragmentName)
}

func getBossEntranceTicketFragmentTemplate(ctx context.Context, token string) (itemTemplateRecord, error) {
	return findItemTemplateByName(ctx, token, bossEntranceTicketFragmentName)
}

func getBossEntranceTicketFragmentBalance(ctx context.Context, token string, characterID string) (int, error) {
	template, err := getBossEntranceTicketFragmentTemplate(ctx, token)
	if err != nil {
		return 0, err
	}
	consumable, err := getCharacterConsumable(ctx, token, characterID, template.ID)
	if err == nil {
		return int(consumable.Quantity), nil
	}
	var statusErr statusError
	if errors.As(err, &statusErr) && statusErr.status == http.StatusNotFound {
		return 0, nil
	}
	return 0, err
}

func addBossEntranceTicketFragments(ctx context.Context, token string, characterID string, amount int) (int, error) {
	if amount <= 0 {
		return getBossEntranceTicketFragmentBalance(ctx, token, characterID)
	}
	template, err := getBossEntranceTicketFragmentTemplate(ctx, token)
	if err != nil {
		return 0, err
	}
	if _, err := addCharacterConsumableQuantity(ctx, token, characterID, template.ID, amount); err != nil {
		return 0, err
	}
	return getBossEntranceTicketFragmentBalance(ctx, token, characterID)
}

func spendBossEntranceTicketFragments(ctx context.Context, token string, characterID string, amount int) (int, error) {
	if amount <= 0 {
		return getBossEntranceTicketFragmentBalance(ctx, token, characterID)
	}
	template, err := getBossEntranceTicketFragmentTemplate(ctx, token)
	if err != nil {
		return 0, err
	}
	consumable, err := getCharacterConsumable(ctx, token, characterID, template.ID)
	if err != nil {
		var statusErr statusError
		if errors.As(err, &statusErr) && statusErr.status == http.StatusNotFound {
			return 0, statusError{status: http.StatusBadRequest, message: "not enough boss entrance ticket fragments"}
		}
		return 0, err
	}
	current := int(consumable.Quantity)
	if current < amount {
		return current, statusError{status: http.StatusBadRequest, message: "not enough boss entrance ticket fragments"}
	}
	balanceAfter := current - amount
	if _, err := patchCharacterConsumableQuantity(ctx, token, consumable.ID, float64(balanceAfter)); err != nil {
		return 0, err
	}
	return balanceAfter, nil
}

func equipOwnedEquipment(ctx context.Context, token string, characterID string, ownedEquipmentID string) (map[string]any, error) {
	owned, err := getOwnedEquipment(ctx, token, ownedEquipmentID)
	if err != nil {
		return nil, err
	}
	if owned.Character != characterID {
		return nil, statusError{status: http.StatusForbidden, message: "owned equipment does not belong to character"}
	}
	if owned.Status == "equipped" {
		return nil, statusError{status: http.StatusConflict, message: "equipment is already equipped"}
	}

	itemTemplate, ok := owned.Expand["item_template"]
	if !ok || itemTemplate.ID == "" {
		return nil, statusError{status: http.StatusBadRequest, message: "owned equipment item template not found"}
	}
	if itemTemplate.ItemType != "equipment" {
		return nil, statusError{status: http.StatusBadRequest, message: "owned item is not equipment"}
	}
	if itemTemplate.EquipmentSlot == "" {
		return nil, statusError{status: http.StatusBadRequest, message: "equipment slot is required"}
	}

	beforeMaxHP, err := getCharacterFinalHP(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if err := unequipSlot(ctx, token, characterID, itemTemplate.EquipmentSlot); err != nil {
		return nil, err
	}

	equipped, err := createCharacterEquipment(ctx, token, characterID, ownedEquipmentID)
	if err != nil {
		return nil, err
	}

	updatedOwned, err := patchOwnedEquipmentStatus(ctx, token, ownedEquipmentID, "equipped")
	if err != nil {
		return nil, err
	}

	updatedCharacter, updatedBattle, hpDelta, err := syncCharacterHPAfterMaxHPChange(ctx, token, characterID, beforeMaxHP)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"owned_equipment":     updatedOwned,
		"character_equipment": equipped,
		"character":           updatedCharacter,
		"battle":              updatedBattle,
		"hp_delta":            hpDelta,
	}, nil
}

func unequipOwnedEquipment(ctx context.Context, token string, characterID string, ownedEquipmentID string) (map[string]any, error) {
	owned, err := getOwnedEquipment(ctx, token, ownedEquipmentID)
	if err != nil {
		return nil, err
	}
	if owned.Character != characterID {
		return nil, statusError{status: http.StatusForbidden, message: "owned equipment does not belong to character"}
	}
	if owned.Status != "equipped" {
		return nil, statusError{status: http.StatusConflict, message: "equipment is not equipped"}
	}

	equippedItems, err := findCharacterEquipmentsByOwnedEquipment(ctx, token, characterID, ownedEquipmentID)
	if err != nil {
		return nil, err
	}
	if len(equippedItems.Items) == 0 {
		return nil, statusError{status: http.StatusNotFound, message: "equipped record not found"}
	}

	beforeMaxHP, err := getCharacterFinalHP(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	for _, equipped := range equippedItems.Items {
		if err := deleteCharacterEquipment(ctx, token, equipped.ID); err != nil {
			return nil, err
		}
	}

	updatedOwned, err := patchOwnedEquipmentStatus(ctx, token, ownedEquipmentID, "owned")
	if err != nil {
		return nil, err
	}

	updatedCharacter, updatedBattle, hpDelta, err := syncCharacterHPAfterMaxHPChange(ctx, token, characterID, beforeMaxHP)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"owned_equipment": updatedOwned,
		"character":       updatedCharacter,
		"battle":          updatedBattle,
		"hp_delta":        hpDelta,
	}, nil
}

func sellOwnedEquipment(ctx context.Context, token string, characterID string, ownedEquipmentID string) (map[string]any, error) {
	owned, err := getOwnedEquipment(ctx, token, ownedEquipmentID)
	if err != nil {
		return nil, err
	}
	if owned.Character != characterID {
		return nil, statusError{status: http.StatusForbidden, message: "owned equipment does not belong to character"}
	}
	if owned.Status == "sold" || owned.Status == "deleted" {
		return nil, statusError{status: http.StatusConflict, message: "equipment is not sellable"}
	}

	itemTemplate, ok := owned.Expand["item_template"]
	if !ok || itemTemplate.ID == "" {
		return nil, statusError{status: http.StatusBadRequest, message: "owned equipment item template not found"}
	}
	if itemTemplate.ItemType != "equipment" {
		return nil, statusError{status: http.StatusBadRequest, message: "owned item is not equipment"}
	}

	if owned.Status == "equipped" {
		return nil, statusError{status: http.StatusConflict, message: "equipped equipment cannot be sold"}
	}

	refundCoin := itemSellRefundCoin(itemTemplate.PriceCoin, 1)
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	coinBalance := character.CoinBalance + refundCoin

	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"coin_balance": coinBalance,
	})
	if err != nil {
		return nil, err
	}

	updatedOwned, err := patchOwnedEquipmentStatus(ctx, token, ownedEquipmentID, "sold")
	if err != nil {
		return nil, err
	}

	if refundCoin > 0 {
		if err := createInventorySellResourceTransaction(ctx, token, characterID, "equipment_sell", ownedEquipmentID, refundCoin, coinBalance, "equipment sell refund"); err != nil {
			return nil, err
		}
	}

	return map[string]any{
		"character":           updatedCharacter,
		"battle":              nil,
		"owned_equipment":     updatedOwned,
		"hp_delta":            0,
		"refund_coin":         refundCoin,
		"refund_rate":         equipmentSellRefundRate,
		"original_price_coin": itemTemplate.PriceCoin,
	}, nil
}

func itemSellRefundCoin(priceCoin float64, quantity int) int {
	if priceCoin <= 0 || quantity <= 0 {
		return 0
	}
	return int(math.Floor(priceCoin * float64(quantity) * equipmentSellRefundRate))
}

func unequipSlot(ctx context.Context, token string, characterID string, equipmentSlot string) error {
	equippedItems, err := findCharacterEquipmentsBySlot(ctx, token, characterID, equipmentSlot)
	if err != nil {
		return err
	}

	for _, equipped := range equippedItems.Items {
		if err := deleteCharacterEquipment(ctx, token, equipped.ID); err != nil {
			return err
		}
		if equipped.OwnedEquipment != "" {
			if _, err := patchOwnedEquipmentStatus(ctx, token, equipped.OwnedEquipment, "owned"); err != nil {
				return err
			}
		}
	}
	return nil
}

func getOwnedEquipment(ctx context.Context, token string, ownedEquipmentID string) (ownedEquipmentRecord, error) {
	endpoint := pocketBaseRecordURL(ownedEquipmentsCollection, ownedEquipmentID) + "?expand=item_template"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return ownedEquipmentRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		if resp.StatusCode == http.StatusNotFound {
			return ownedEquipmentRecord{}, statusError{status: http.StatusNotFound, message: "owned equipment not found"}
		}
		return ownedEquipmentRecord{}, mapPocketBaseError(resp, "failed to get owned equipment")
	}

	var record ownedEquipmentRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return ownedEquipmentRecord{}, errors.New("failed to parse owned equipment response")
	}
	return record, nil
}

func createCharacterEquipment(ctx context.Context, token string, characterID string, ownedEquipmentID string) (map[string]any, error) {
	payload := map[string]any{
		"character":       characterID,
		"owned_equipment": ownedEquipmentID,
		"equipped_at":     time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(characterEquipmentsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create equipped record")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse create equipped response")
	}
	return record, nil
}

func patchOwnedEquipmentStatus(ctx context.Context, token string, ownedEquipmentID string, status string) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(ownedEquipmentsCollection, ownedEquipmentID), token, map[string]any{
		"status": status,
	})
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update owned equipment status")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse owned equipment update response")
	}
	return record, nil
}

func deleteCharacterEquipment(ctx context.Context, token string, characterEquipmentID string) error {
	resp, err := pocketBaseRequest(ctx, http.MethodDelete, pocketBaseRecordURL(characterEquipmentsCollection, characterEquipmentID), token, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to delete equipped record")
	}
	return nil
}

func createInventorySellResourceTransaction(
	ctx context.Context,
	token string,
	characterID string,
	sourceType string,
	sourceID string,
	refundCoin int,
	balanceAfter int,
	reason string,
) error {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("resource_transactions"), token, map[string]any{
		"character":        characterID,
		"resource_type":    "coin",
		"transaction_type": "reward",
		"amount":           refundCoin,
		"balance_after":    balanceAfter,
		"source_type":      sourceType,
		"source_id":        sourceID,
		"reason":           reason,
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create inventory sell resource transaction")
	}
	return nil
}

func findCharacterEquipmentsByOwnedEquipment(
	ctx context.Context,
	token string,
	characterID string,
	ownedEquipmentID string,
) (pocketBaseListResponse[characterEquipmentRecord], error) {
	filter := fmt.Sprintf("character=%q && owned_equipment=%q", characterID, ownedEquipmentID)
	return listCharacterEquipmentRecords(ctx, token, filter, "")
}

func findCharacterEquipmentsBySlot(
	ctx context.Context,
	token string,
	characterID string,
	equipmentSlot string,
) (pocketBaseListResponse[characterEquipmentRecord], error) {
	filter := fmt.Sprintf("character=%q && owned_equipment.item_template.equipment_slot=%q", characterID, equipmentSlot)
	return listCharacterEquipmentRecords(ctx, token, filter, "owned_equipment.item_template")
}

func listCharacterEquipmentRecords(
	ctx context.Context,
	token string,
	filter string,
	expand string,
) (pocketBaseListResponse[characterEquipmentRecord], error) {
	query := url.Values{}
	query.Set("perPage", "100")
	query.Set("filter", filter)
	if expand != "" {
		query.Set("expand", expand)
	}

	endpoint := pocketBaseCollectionURL(characterEquipmentsCollection) + "?" + query.Encode()
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return pocketBaseListResponse[characterEquipmentRecord]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[characterEquipmentRecord]{}, mapPocketBaseError(resp, "failed to list equipped records")
	}

	var list pocketBaseListResponse[characterEquipmentRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[characterEquipmentRecord]{}, errors.New("failed to parse equipped records response")
	}
	return list, nil
}

func listCollectionRecords(
	ctx context.Context,
	token string,
	collection string,
	filter string,
	expand string,
	sort string,
) (pocketBaseListResponse[map[string]any], error) {
	query := url.Values{}
	query.Set("perPage", "100")
	if filter != "" {
		query.Set("filter", filter)
	}
	if expand != "" {
		query.Set("expand", expand)
	}
	if sort != "" {
		query.Set("sort", sort)
	}

	endpoint := pocketBaseCollectionURL(collection) + "?" + query.Encode()
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[map[string]any]{}, mapPocketBaseError(resp, "failed to list "+collection)
	}

	var list pocketBaseListResponse[map[string]any]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[map[string]any]{}, errors.New("failed to parse " + collection + " response")
	}
	return list, nil
}
