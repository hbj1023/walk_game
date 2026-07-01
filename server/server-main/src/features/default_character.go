package features

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
)

const (
	defaultCharacterLevel              = 1
	defaultCharacterExp                = 0
	defaultCharacterStatExp            = 0
	defaultCharacterHP                 = 100
	defaultCharacterCoinBalance        = 0
	defaultCharacterAttackCountBalance = 0

	defaultBaseHP      = 100
	defaultBaseAttack  = 10
	defaultBaseDefense = 5
	defaultBaseAgility = 5

	defaultCharacterGender        = "other"
	defaultCharacterHairType      = "basic"
	defaultCharacterHairColor     = "brown"
	defaultCharacterSkinColor     = "default"
	defaultCharacterOutfitType    = "basic"
	defaultCharacterAccessoryType = "none"
)

func ensureDefaultCharacter(ctx context.Context, token string, user pocketBaseUser) (battleCharacterRecord, bool, error) {
	character, err := getBattleCharacterByUserID(ctx, token, user.ID)
	if err == nil {
		if err := ensureDefaultCharacterStats(ctx, token, character.ID); err != nil {
			return battleCharacterRecord{}, false, err
		}
		return character, false, nil
	}

	var statusErr statusError
	if !errors.As(err, &statusErr) || statusErr.status != http.StatusNotFound {
		return battleCharacterRecord{}, false, err
	}

	character, err = createDefaultCharacter(ctx, token, user)
	if err != nil {
		return battleCharacterRecord{}, false, err
	}
	if err := createDefaultCharacterStats(ctx, token, character.ID); err != nil {
		return battleCharacterRecord{}, false, err
	}

	return character, true, nil
}

func ensureDefaultCharacterStats(ctx context.Context, token string, characterID string) error {
	if _, err := getBattleCharacterStats(ctx, token, characterID); err == nil {
		return nil
	} else {
		var statusErr statusError
		if !errors.As(err, &statusErr) || statusErr.status != http.StatusNotFound {
			return err
		}
	}

	return createDefaultCharacterStats(ctx, token, characterID)
}

func createDefaultCharacter(ctx context.Context, token string, user pocketBaseUser) (battleCharacterRecord, error) {
	name := strings.TrimSpace(user.Name)
	if name == "" {
		name = strings.TrimSpace(user.Email)
	}
	if name == "" {
		name = "Adventurer"
	}

	payload := map[string]any{
		"user":                 user.ID,
		"name":                 name,
		"gender":               defaultCharacterGender,
		"level":                defaultCharacterLevel,
		"exp":                  defaultCharacterExp,
		"stat_exp":             defaultCharacterStatExp,
		"current_hp":           defaultCharacterHP,
		"coin_balance":         defaultCharacterCoinBalance,
		"attack_count_balance": defaultCharacterAttackCountBalance,
		"hair_type":            defaultCharacterHairType,
		"hair_color":           defaultCharacterHairColor,
		"skin_color":           defaultCharacterSkinColor,
		"outfit_type":          defaultCharacterOutfitType,
		"accessory_type":       defaultCharacterAccessoryType,
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("characters"), token, payload)
	if err != nil {
		return battleCharacterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return battleCharacterRecord{}, mapPocketBaseError(resp, "failed to create default character")
	}

	var character battleCharacterRecord
	if err := json.NewDecoder(resp.Body).Decode(&character); err != nil {
		return battleCharacterRecord{}, errors.New("failed to parse default character response")
	}
	return character, nil
}

func createDefaultCharacterStats(ctx context.Context, token string, characterID string) error {
	payload := map[string]any{
		"character":        characterID,
		"base_hp":          defaultBaseHP,
		"base_attack":      defaultBaseAttack,
		"base_defense":     defaultBaseDefense,
		"base_agility":     defaultBaseAgility,
		"upgraded_hp":      0,
		"upgraded_attack":  0,
		"upgraded_defense": 0,
		"upgraded_agility": 0,
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("character_stats"), token, payload)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create default character stats")
	}
	return nil
}
