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
	statBalanceSettingsCollection = "stat_balance_settings"
	statUpgradeLogsCollection     = "stat_upgrade_logs"
)

var supportedStatTypes = map[string]bool{
	"hp":      true,
	"attack":  true,
	"defense": true,
	"agility": true,
}

func statUpgradeCostsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "stat upgrade costs fetch failed", "error": "method not allowed"})
		return
	}

	characterID, ok := parseStatUpgradeCostsPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "stat upgrade costs fetch failed", "error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "stat upgrade costs fetch failed", "error": "unauthorized"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, user.ID, characterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]string{"message": "stat upgrade costs fetch failed", "error": err.Error()})
		return
	}

	summary, err := getStatUpgradeSummary(r.Context(), token, characterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "stat upgrade costs fetch failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "stat upgrade costs fetched", summary)
}

func statUpgradeHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/stat-upgrades" {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "stat upgrade failed", "error": "not found"})
		return
	}
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "stat upgrade failed", "error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "stat upgrade failed", "error": "unauthorized"})
		return
	}

	var req statUpgradeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "stat upgrade failed", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	req.StatType = strings.TrimSpace(req.StatType)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "stat upgrade failed", "error": "characterId is required"})
		return
	}
	if !supportedStatTypes[req.StatType] {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "stat upgrade failed", "error": "statType must be hp, attack, defense, or agility"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, user.ID, req.CharacterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]string{"message": "stat upgrade failed", "error": err.Error()})
		return
	}

	data, err := upgradeCharacterStat(r.Context(), token, req.CharacterID, req.StatType)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "stat upgrade failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "stat upgraded", data)
}

func parseStatUpgradeCostsPath(path string) (string, bool) {
	const prefix = "/api/stat-upgrades/costs/"
	if !strings.HasPrefix(path, prefix) {
		return "", false
	}
	characterID := strings.Trim(strings.TrimPrefix(path, prefix), "/")
	return characterID, characterID != ""
}

func getStatUpgradeCosts(ctx context.Context, token string, characterID string) (map[string]int, error) {
	stats, err := getBattleCharacterStats(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	costs := map[string]int{}
	for _, statType := range []string{"hp", "attack", "defense", "agility"} {
		setting, err := getStatBalanceSetting(ctx, token, statType)
		if err != nil {
			return nil, err
		}
		costs[statType] = calculateStatUpgradeCost(currentStatValue(stats, statType), setting)
	}
	return costs, nil
}

func getStatUpgradeSummary(ctx context.Context, token string, characterID string) (map[string]any, error) {
	stats, err := getBattleCharacterStats(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	costs := map[string]int{}
	current := map[string]int{}
	upgraded := map[string]int{}
	for _, statType := range []string{"hp", "attack", "defense", "agility"} {
		setting, err := getStatBalanceSetting(ctx, token, statType)
		if err != nil {
			return nil, err
		}
		current[statType] = currentStatValue(stats, statType)
		upgraded[statType] = upgradedStatValue(stats, statType)
		costs[statType] = calculateStatUpgradeCost(current[statType], setting)
	}

	return map[string]any{
		"costs":           costs,
		"current_stats":   current,
		"upgraded_stats":  upgraded,
		"character_stats": stats,
	}, nil
}

func upgradeCharacterStat(ctx context.Context, token string, characterID string, statType string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	stats, err := getBattleCharacterStats(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	setting, err := getStatBalanceSetting(ctx, token, statType)
	if err != nil {
		return nil, err
	}

	currentStat := currentStatValue(stats, statType)
	cost := calculateStatUpgradeCost(currentStat, setting)
	if character.CoinBalance < cost {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough coin balance"}
	}

	beforeMaxHP := 0
	if statType == "hp" {
		beforeMaxHP, err = getCharacterFinalHP(ctx, token, characterID)
		if err != nil {
			return nil, err
		}
	}
	afterCoin := character.CoinBalance - cost
	updatedStatValue := upgradedStatValue(stats, statType) + 1

	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"coin_balance": afterCoin,
	})
	if err != nil {
		return nil, err
	}

	updatedStats, err := patchCharacterStats(ctx, token, stats.ID, map[string]any{
		upgradedStatField(statType): updatedStatValue,
	})
	if err != nil {
		return nil, err
	}

	var updatedBattle any
	hpDelta := 0
	if statType == "hp" {
		syncedCharacter, syncedBattle, delta, err := syncCharacterHPAfterMaxHPChange(ctx, token, characterID, beforeMaxHP)
		if err != nil {
			return nil, err
		}
		updatedCharacter = syncedCharacter
		updatedBattle = syncedBattle
		hpDelta = delta
	}

	logRecord, err := createStatUpgradeLog(ctx, token, characterID, statType, currentStat, currentStat+1, cost, afterCoin)
	if err != nil {
		return nil, err
	}

	if err := createStatUpgradeResourceTransaction(ctx, token, characterID, logRecord["id"], cost, afterCoin, fmt.Sprintf("%s stat upgrade", statType)); err != nil {
		return nil, err
	}

	return map[string]any{
		"statType":          statType,
		"usedCoin":          cost,
		"coin_balance":      updatedCharacter.CoinBalance,
		"upgraded_stat_key": upgradedStatField(statType),
		"upgraded_stat":     updatedStatValue,
		"character_stats":   updatedStats,
		"character":         updatedCharacter,
		"battle":            updatedBattle,
		"hp_delta":          hpDelta,
	}, nil
}

func getStatBalanceSetting(ctx context.Context, token string, statType string) (statBalanceSettingRecord, error) {
	query := url.Values{}
	query.Set("filter", fmt.Sprintf("stat_type=%q && is_active=true", statType))
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(statBalanceSettingsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return statBalanceSettingRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return statBalanceSettingRecord{}, mapPocketBaseError(resp, "failed to get stat balance setting")
	}

	var list pocketBaseListResponse[statBalanceSettingRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return statBalanceSettingRecord{}, errors.New("failed to parse stat balance setting response")
	}
	if len(list.Items) == 0 {
		return defaultStatBalanceSetting(statType), nil
	}
	setting := list.Items[0]
	if setting.SquareDivisor == 0 {
		return statBalanceSettingRecord{}, statusError{status: http.StatusBadRequest, message: "stat balance square_divisor must not be 0"}
	}
	return setting, nil
}

func defaultStatBalanceSetting(statType string) statBalanceSettingRecord {
	return statBalanceSettingRecord{
		StatType:         statType,
		BaseCost:         100,
		SquareDivisor:    20,
		LinearMultiplier: 2,
		FormulaText:      "base_cost + (currentStat * currentStat) / square_divisor + (currentStat * linear_multiplier)",
		IsActive:         true,
	}
}

func calculateStatUpgradeCost(currentStat int, setting statBalanceSettingRecord) int {
	value := setting.BaseCost +
		(float64(currentStat*currentStat) / setting.SquareDivisor) +
		(float64(currentStat) * setting.LinearMultiplier)
	return int(math.Floor(value))
}

func currentStatValue(stats battleCharacterStatsRecord, statType string) int {
	switch statType {
	case "hp":
		return stats.BaseHP + stats.UpgradedHP
	case "attack":
		return stats.BaseAttack + stats.UpgradedAttack
	case "defense":
		return stats.BaseDefense + stats.UpgradedDefense
	case "agility":
		return stats.BaseAgility + stats.UpgradedAgility
	default:
		return 0
	}
}

func upgradedStatValue(stats battleCharacterStatsRecord, statType string) int {
	switch statType {
	case "hp":
		return stats.UpgradedHP
	case "attack":
		return stats.UpgradedAttack
	case "defense":
		return stats.UpgradedDefense
	case "agility":
		return stats.UpgradedAgility
	default:
		return 0
	}
}

func upgradedStatField(statType string) string {
	return "upgraded_" + statType
}

func patchCharacterStats(ctx context.Context, token string, statsID string, payload map[string]any) (battleCharacterStatsRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL("character_stats", statsID), token, payload)
	if err != nil {
		return battleCharacterStatsRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return battleCharacterStatsRecord{}, mapPocketBaseError(resp, "failed to update character stats")
	}

	var stats battleCharacterStatsRecord
	if err := json.NewDecoder(resp.Body).Decode(&stats); err != nil {
		return battleCharacterStatsRecord{}, errors.New("failed to parse character stats update response")
	}
	return stats, nil
}

func createStatUpgradeLog(ctx context.Context, token string, characterID string, statType string, beforeValue int, afterValue int, costCoin int, balanceAfter int) (map[string]any, error) {
	payload := map[string]any{
		"character":     characterID,
		"stat_type":     statType,
		"before_value":  beforeValue,
		"after_value":   afterValue,
		"cost_coin":     costCoin,
		"balance_after": balanceAfter,
		"upgraded_at":   time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(statUpgradeLogsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create stat upgrade log")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse stat upgrade log response")
	}
	return record, nil
}

func createStatUpgradeResourceTransaction(ctx context.Context, token string, characterID string, sourceID any, costCoin int, balanceAfter int, reason string) error {
	payload := map[string]any{
		"character":        characterID,
		"resource_type":    "coin",
		"transaction_type": "use",
		"amount":           -costCoin,
		"balance_after":    balanceAfter,
		"source_type":      "stat_upgrade",
		"reason":           reason,
	}
	if sourceIDString, ok := sourceID.(string); ok {
		payload["source_id"] = sourceIDString
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("resource_transactions"), token, payload)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create resource transaction")
	}
	return nil
}
