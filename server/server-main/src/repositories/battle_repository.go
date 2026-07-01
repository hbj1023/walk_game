package repositories

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"

	"server/src/models"
)

func GetBattleCharacterByID(ctx context.Context, token string, characterID string) (models.CharacterRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL("characters", characterID), token, nil)
	if err != nil {
		return models.CharacterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		if resp.StatusCode == http.StatusNotFound {
			return models.CharacterRecord{}, StatusError{status: http.StatusNotFound, message: "character not found"}
		}
		return models.CharacterRecord{}, mapPocketBaseError(resp, "failed to get character")
	}

	var character models.CharacterRecord
	if err := json.NewDecoder(resp.Body).Decode(&character); err != nil {
		return models.CharacterRecord{}, errors.New("failed to parse character response")
	}
	return character, nil
}

func GetBattleCharacterByUserID(ctx context.Context, token string, userID string) (models.CharacterRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("user=%q", userID))
	endpoint := pocketBaseCollectionURL("characters") + "?filter=" + filter + "&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return models.CharacterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.CharacterRecord{}, mapPocketBaseError(resp, "failed to get character by user")
	}

	var list ListResponse[models.CharacterRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.CharacterRecord{}, errors.New("failed to parse character by user response")
	}
	if len(list.Items) == 0 {
		return models.CharacterRecord{}, StatusError{status: http.StatusNotFound, message: "character not found"}
	}
	return list.Items[0], nil
}

func GetBattleCharacterStats(ctx context.Context, token string, characterID string) (models.CharacterStatsRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q", characterID))
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL("character_stats")+"?filter="+filter+"&perPage=1", token, nil)
	if err != nil {
		return models.CharacterStatsRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.CharacterStatsRecord{}, mapPocketBaseError(resp, "failed to get character stats")
	}

	var list ListResponse[models.CharacterStatsRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.CharacterStatsRecord{}, errors.New("failed to parse character stats response")
	}
	if len(list.Items) == 0 {
		return models.CharacterStatsRecord{}, StatusError{status: http.StatusNotFound, message: "character stats not found"}
	}
	return list.Items[0], nil
}

func GetStageByID(ctx context.Context, token string, stageID string) (models.StageRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL("stages", stageID), token, nil)
	if err != nil {
		return models.StageRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.StageRecord{}, mapPocketBaseError(resp, "failed to get stage")
	}

	var stage models.StageRecord
	if err := json.NewDecoder(resp.Body).Decode(&stage); err != nil {
		return models.StageRecord{}, errors.New("failed to parse stage response")
	}
	return stage, nil
}

func GetNormalStageByNo(ctx context.Context, token string, stageNo int) (models.StageRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("stage_no=%d && stage_type=%q && is_active=true", stageNo, "normal"))
	endpoint := pocketBaseCollectionURL("stages") + "?filter=" + filter + "&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return models.StageRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.StageRecord{}, mapPocketBaseError(resp, "failed to get stage by stage_no")
	}

	var list ListResponse[models.StageRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.StageRecord{}, errors.New("failed to parse stage by stage_no response")
	}
	if len(list.Items) == 0 {
		return models.StageRecord{}, StatusError{status: http.StatusNotFound, message: "normal stage not found"}
	}
	return list.Items[0], nil
}

func GetBossStageByNo(ctx context.Context, token string, stageNo int) (models.StageRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("stage_no=%d && stage_type=%q && is_active=true", stageNo, "boss"))
	endpoint := pocketBaseCollectionURL("stages") + "?filter=" + filter + "&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return models.StageRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.StageRecord{}, mapPocketBaseError(resp, "failed to get boss stage by stage_no")
	}

	var list ListResponse[models.StageRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.StageRecord{}, errors.New("failed to parse boss stage by stage_no response")
	}
	if len(list.Items) == 0 {
		return models.StageRecord{}, StatusError{status: http.StatusNotFound, message: "boss stage not found"}
	}
	return list.Items[0], nil
}

func ListNormalStages(ctx context.Context, token string) ([]models.StageRecord, error) {
	filter := url.QueryEscape(`(stage_type="normal" || stage_type="boss") && is_active=true`)
	endpoint := pocketBaseCollectionURL("stages") + "?filter=" + filter + "&sort=stage_no&perPage=100"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list normal stages")
	}

	var list ListResponse[models.StageRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse normal stages response")
	}
	return list.Items, nil
}

func GetStageProgress(ctx context.Context, token string, characterID string, stageID string) (models.StageProgressRecord, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && stage=%q", characterID, stageID))
	endpoint := pocketBaseCollectionURL("user_stage_progress") + "?filter=" + filter + "&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return models.StageProgressRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.StageProgressRecord{}, false, mapPocketBaseError(resp, "failed to get stage progress")
	}

	var list ListResponse[models.StageProgressRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.StageProgressRecord{}, false, errors.New("failed to parse stage progress response")
	}
	if len(list.Items) == 0 {
		return models.StageProgressRecord{}, false, nil
	}
	return list.Items[0], true, nil
}

func ListStageProgressByCharacter(ctx context.Context, token string, characterID string) ([]models.StageProgressRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q", characterID))
	endpoint := pocketBaseCollectionURL("user_stage_progress") + "?filter=" + filter + "&perPage=100"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list stage progress")
	}

	var list ListResponse[models.StageProgressRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse stage progress list response")
	}
	return list.Items, nil
}

func CreateStageProgress(ctx context.Context, token string, payload map[string]any) (models.StageProgressRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("user_stage_progress"), token, payload)
	if err != nil {
		return models.StageProgressRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return models.StageProgressRecord{}, mapPocketBaseError(resp, "failed to create stage progress")
	}

	var progress models.StageProgressRecord
	if err := json.NewDecoder(resp.Body).Decode(&progress); err != nil {
		return models.StageProgressRecord{}, errors.New("failed to parse create stage progress response")
	}
	return progress, nil
}

func PatchStageProgress(ctx context.Context, token string, progressID string, payload map[string]any) (models.StageProgressRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL("user_stage_progress", progressID), token, payload)
	if err != nil {
		return models.StageProgressRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return models.StageProgressRecord{}, mapPocketBaseError(resp, "failed to update stage progress")
	}

	var progress models.StageProgressRecord
	if err := json.NewDecoder(resp.Body).Decode(&progress); err != nil {
		return models.StageProgressRecord{}, errors.New("failed to parse update stage progress response")
	}
	return progress, nil
}

func GetFirstNormalStageMonster(ctx context.Context, token string, stageID string) (models.StageMonsterRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("stage=%q && is_boss=false", stageID))
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL("stage_monsters")+"?filter="+filter+"&sort=spawn_order&perPage=1", token, nil)
	if err != nil {
		return models.StageMonsterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.StageMonsterRecord{}, mapPocketBaseError(resp, "failed to get stage monster")
	}

	var list ListResponse[models.StageMonsterRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.StageMonsterRecord{}, errors.New("failed to parse stage monster response")
	}
	if len(list.Items) == 0 {
		return models.StageMonsterRecord{}, StatusError{status: http.StatusNotFound, message: "normal stage monster not found"}
	}
	return list.Items[0], nil
}

func GetFirstStageMonster(ctx context.Context, token string, stageID string) (models.StageMonsterRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("stage=%q", stageID))
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL("stage_monsters")+"?filter="+filter+"&sort=spawn_order&perPage=1", token, nil)
	if err != nil {
		return models.StageMonsterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.StageMonsterRecord{}, mapPocketBaseError(resp, "failed to get stage monster")
	}

	var list ListResponse[models.StageMonsterRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.StageMonsterRecord{}, errors.New("failed to parse stage monster response")
	}
	if len(list.Items) == 0 {
		return models.StageMonsterRecord{}, StatusError{status: http.StatusNotFound, message: "stage monster not found"}
	}
	return list.Items[0], nil
}

func GetMonsterByID(ctx context.Context, token string, monsterID string) (models.MonsterRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL("monsters", monsterID), token, nil)
	if err != nil {
		return models.MonsterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.MonsterRecord{}, mapPocketBaseError(resp, "failed to get monster")
	}

	var monster models.MonsterRecord
	if err := json.NewDecoder(resp.Body).Decode(&monster); err != nil {
		return models.MonsterRecord{}, errors.New("failed to parse monster response")
	}
	return monster, nil
}

func FindCurrentNormalBattle(ctx context.Context, token string, characterID string) (models.BattleRecord, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && battle_type=%q && status=%q && monster_current_hp>0 && character_current_hp>0", characterID, "normal", "in_progress"))
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL("battles")+"?filter="+filter+"&sort=-created&perPage=1", token, nil)
	if err != nil {
		return models.BattleRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.BattleRecord{}, false, mapPocketBaseError(resp, "failed to get current battle")
	}

	var list ListResponse[models.BattleRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.BattleRecord{}, false, errors.New("failed to parse current battle response")
	}
	if len(list.Items) == 0 {
		return models.BattleRecord{}, false, nil
	}
	return list.Items[0], true, nil
}

func FindCurrentBattleByType(ctx context.Context, token string, characterID string, battleType string) (models.BattleRecord, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && battle_type=%q && status=%q && monster_current_hp>0 && character_current_hp>0", characterID, battleType, "in_progress"))
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL("battles")+"?filter="+filter+"&sort=-created&perPage=1", token, nil)
	if err != nil {
		return models.BattleRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.BattleRecord{}, false, mapPocketBaseError(resp, "failed to get current battle")
	}

	var list ListResponse[models.BattleRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return models.BattleRecord{}, false, errors.New("failed to parse current battle response")
	}
	if len(list.Items) == 0 {
		return models.BattleRecord{}, false, nil
	}
	return list.Items[0], true, nil
}

func HasBattleHistory(ctx context.Context, token string, characterID string, stageID string, battleType string) (bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && stage=%q && battle_type=%q", characterID, stageID, battleType))
	endpoint := pocketBaseCollectionURL("battles") + "?filter=" + filter + "&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, mapPocketBaseError(resp, "failed to get battle history")
	}

	var list ListResponse[models.BattleRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return false, errors.New("failed to parse battle history response")
	}
	return len(list.Items) > 0, nil
}

func ListNormalBattleHistory(ctx context.Context, token string, characterID string, page int, perPage int) (ListResponse[models.BattleRecord], error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && battle_type=%q", characterID, "normal"))
	endpoint := fmt.Sprintf("%s?filter=%s&sort=-created&page=%d&perPage=%d", pocketBaseCollectionURL("battles"), filter, page, perPage)
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return ListResponse[models.BattleRecord]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return ListResponse[models.BattleRecord]{}, mapPocketBaseError(resp, "failed to get battle history")
	}

	var list ListResponse[models.BattleRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return ListResponse[models.BattleRecord]{}, errors.New("failed to parse battle history response")
	}
	return list, nil
}

func CreateNormalBattle(ctx context.Context, token string, payload map[string]any) (models.BattleRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("battles"), token, payload)
	if err != nil {
		return models.BattleRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return models.BattleRecord{}, mapPocketBaseError(resp, "failed to create battle")
	}

	var battle models.BattleRecord
	if err := json.NewDecoder(resp.Body).Decode(&battle); err != nil {
		return models.BattleRecord{}, errors.New("failed to parse create battle response")
	}
	return battle, nil
}

func GetBattleByID(ctx context.Context, token string, battleID string) (models.BattleRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL("battles", battleID), token, nil)
	if err != nil {
		return models.BattleRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return models.BattleRecord{}, mapPocketBaseError(resp, "failed to get battle")
	}

	var battle models.BattleRecord
	if err := json.NewDecoder(resp.Body).Decode(&battle); err != nil {
		return models.BattleRecord{}, errors.New("failed to parse battle response")
	}
	return battle, nil
}

func PatchBattle(ctx context.Context, token string, battleID string, payload map[string]any) (models.BattleRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL("battles", battleID), token, payload)
	if err != nil {
		return models.BattleRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return models.BattleRecord{}, mapPocketBaseError(resp, "failed to update battle")
	}

	var battle models.BattleRecord
	if err := json.NewDecoder(resp.Body).Decode(&battle); err != nil {
		return models.BattleRecord{}, errors.New("failed to parse update battle response")
	}
	return battle, nil
}

func PatchBattleCharacter(ctx context.Context, token string, characterID string, payload map[string]any) (models.CharacterRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL("characters", characterID), token, payload)
	if err != nil {
		return models.CharacterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return models.CharacterRecord{}, mapPocketBaseError(resp, "failed to update character")
	}

	var character models.CharacterRecord
	if err := json.NewDecoder(resp.Body).Decode(&character); err != nil {
		return models.CharacterRecord{}, errors.New("failed to parse update character response")
	}
	return character, nil
}

func CreateRewardLog(ctx context.Context, token string, characterID string, battleID string, rewardCoin int) error {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("reward_logs"), token, map[string]any{
		"character":            characterID,
		"source_type":          "battle",
		"source_id":            battleID,
		"reward_item_quantity": 0,
		"reward_coin":          rewardCoin,
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create reward log")
	}
	return nil
}

func CreateBattleResourceTransaction(ctx context.Context, token string, characterID string, battleID string, resourceType string, transactionType string, amount int, balanceAfter int, reason string) error {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("resource_transactions"), token, map[string]any{
		"character":        characterID,
		"resource_type":    resourceType,
		"transaction_type": transactionType,
		"amount":           amount,
		"balance_after":    balanceAfter,
		"source_type":      "battle",
		"source_id":        battleID,
		"reason":           reason,
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create resource transaction")
	}
	return nil
}
