package features

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
)

const (
	explorationUpgradeStorage    = "offline_storage"
	explorationUpgradeEfficiency = "offline_efficiency"
	maxOfflineStorageLevel       = 5
	maxOfflineEfficiencyLevel    = 5
)

var offlineStorageUpgradeCosts = []int{150, 350, 700, 1200, 2000}
var offlineEfficiencyUpgradeCosts = []int{250, 600, 1100, 1800, 2800}

type explorationUpgradeRequest struct {
	CharacterID string `json:"characterId"`
	UpgradeType string `json:"upgradeType"`
}

func explorationUpgradeCostsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "exploration upgrade costs fetch failed", "error": "method not allowed"})
		return
	}

	characterID, ok := parseExplorationUpgradeCostsPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "exploration upgrade costs fetch failed", "error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "exploration upgrade costs fetch failed", "error": "unauthorized"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, user.ID, characterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]string{"message": "exploration upgrade costs fetch failed", "error": err.Error()})
		return
	}

	summary, err := getExplorationUpgradeSummary(r.Context(), token, characterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "exploration upgrade costs fetch failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "exploration upgrade costs fetched", summary)
}

func explorationUpgradeHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/exploration-upgrades" {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "exploration upgrade failed", "error": "not found"})
		return
	}
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "exploration upgrade failed", "error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "exploration upgrade failed", "error": "unauthorized"})
		return
	}

	var req explorationUpgradeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "exploration upgrade failed", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	req.UpgradeType = strings.TrimSpace(req.UpgradeType)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "exploration upgrade failed", "error": "characterId is required"})
		return
	}
	if req.UpgradeType != explorationUpgradeStorage && req.UpgradeType != explorationUpgradeEfficiency {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "exploration upgrade failed", "error": "upgradeType must be offline_storage or offline_efficiency"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, user.ID, req.CharacterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]string{"message": "exploration upgrade failed", "error": err.Error()})
		return
	}

	data, err := upgradeExploration(r.Context(), token, req.CharacterID, req.UpgradeType)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "exploration upgrade failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "exploration upgraded", data)
}

func parseExplorationUpgradeCostsPath(path string) (string, bool) {
	const prefix = "/api/exploration-upgrades/costs/"
	if !strings.HasPrefix(path, prefix) {
		return "", false
	}
	characterID := strings.Trim(strings.TrimPrefix(path, prefix), "/")
	return characterID, characterID != ""
}

func getExplorationUpgradeSummary(ctx context.Context, token string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	return buildExplorationUpgradeSummary(character), nil
}

func upgradeExploration(ctx context.Context, token string, characterID string, upgradeType string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}

	level := explorationUpgradeLevel(character, upgradeType)
	maxLevel := explorationUpgradeMaxLevel(upgradeType)
	if level >= maxLevel {
		return nil, statusError{status: http.StatusBadRequest, message: "exploration upgrade is already max level"}
	}

	cost := explorationUpgradeCost(upgradeType, level)
	if character.CoinBalance < cost {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough coin balance"}
	}

	nextLevel := level + 1
	coinBalance := character.CoinBalance - cost
	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		explorationUpgradeField(upgradeType): nextLevel,
		"coin_balance":                       coinBalance,
	})
	if err != nil {
		return nil, err
	}

	if err := createExplorationUpgradeResourceTransaction(ctx, token, characterID, upgradeType, -cost, coinBalance); err != nil {
		return nil, err
	}

	summary := buildExplorationUpgradeSummary(updatedCharacter)
	summary["used_coin"] = cost
	summary["upgraded_type"] = upgradeType
	summary["character"] = updatedCharacter
	return summary, nil
}

func buildExplorationUpgradeSummary(character battleCharacterRecord) map[string]any {
	storageLevel := clampInt(character.OfflineStorageLevel, 0, maxOfflineStorageLevel)
	efficiencyLevel := clampInt(character.OfflineEfficiencyLevel, 0, maxOfflineEfficiencyLevel)
	return map[string]any{
		"coin_balance": character.CoinBalance,
		"upgrades": map[string]any{
			explorationUpgradeStorage: map[string]any{
				"level":         storageLevel,
				"max_level":     maxOfflineStorageLevel,
				"cost_coin":     explorationUpgradeCost(explorationUpgradeStorage, storageLevel),
				"current_value": offlineAttackCountCapForLevel(storageLevel),
				"next_value":    offlineAttackCountCapForLevel(minInt(storageLevel+1, maxOfflineStorageLevel)),
				"value_unit":    "회",
				"title":         "공격기회 보관함",
				"description":   "앱을 꺼둔 동안 쌓을 수 있는 공격기회 최대치를 늘립니다.",
			},
			explorationUpgradeEfficiency: map[string]any{
				"level":         efficiencyLevel,
				"max_level":     maxOfflineEfficiencyLevel,
				"cost_coin":     explorationUpgradeCost(explorationUpgradeEfficiency, efficiencyLevel),
				"current_value": offlinePenaltyPercentForLevel(efficiencyLevel),
				"next_value":    offlinePenaltyPercentForLevel(minInt(efficiencyLevel+1, maxOfflineEfficiencyLevel)),
				"value_unit":    "%",
				"title":         "탐험 효율",
				"description":   "오프라인 걷기에서 추가로 더 걸어야 하는 부담을 줄입니다.",
			},
		},
	}
}

func explorationUpgradeLevel(character battleCharacterRecord, upgradeType string) int {
	switch upgradeType {
	case explorationUpgradeEfficiency:
		return character.OfflineEfficiencyLevel
	default:
		return character.OfflineStorageLevel
	}
}

func explorationUpgradeMaxLevel(upgradeType string) int {
	if upgradeType == explorationUpgradeEfficiency {
		return maxOfflineEfficiencyLevel
	}
	return maxOfflineStorageLevel
}

func explorationUpgradeField(upgradeType string) string {
	if upgradeType == explorationUpgradeEfficiency {
		return "offline_efficiency_level"
	}
	return "offline_storage_level"
}

func explorationUpgradeCost(upgradeType string, level int) int {
	costs := offlineStorageUpgradeCosts
	if upgradeType == explorationUpgradeEfficiency {
		costs = offlineEfficiencyUpgradeCosts
	}
	if level < 0 || level >= len(costs) {
		return 0
	}
	return costs[level]
}

func offlineAttackCountCapForLevel(level int) int {
	return defaultOfflineAttackCountCap + clampInt(level, 0, maxOfflineStorageLevel)*5
}

func offlineAgilityPenaltyForLevel(level int) float64 {
	penalty := offlineAgilityReductionPenalty - float64(clampInt(level, 0, maxOfflineEfficiencyLevel))*0.04
	if penalty < 0.10 {
		return 0.10
	}
	return penalty
}

func offlinePenaltyPercentForLevel(level int) int {
	return int(round2(offlineAgilityPenaltyForLevel(level) * 100))
}

func clampInt(value int, minValue int, maxValue int) int {
	if value < minValue {
		return minValue
	}
	if value > maxValue {
		return maxValue
	}
	return value
}

func createExplorationUpgradeResourceTransaction(ctx context.Context, token string, characterID string, upgradeType string, amount int, balanceAfter int) error {
	return createShopResourceTransaction(
		ctx,
		token,
		characterID,
		"exploration_upgrade",
		upgradeType,
		amount,
		balanceAfter,
		fmt.Sprintf("%s exploration upgrade", upgradeType),
	)
}
