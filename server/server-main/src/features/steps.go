package features

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"time"

	"server/src/utils/formulas"
)

const (
	defaultStrideM                 = 0.75
	baseAttackDistanceM            = 100.0
	offlineAgilityReductionPenalty = 0.3
	defaultOfflineAttackCountCap   = 10
	bossTicketFragmentDistanceM    = 1800.0
)

type pocketBaseListResponse[T any] struct {
	Page       int `json:"page"`
	PerPage    int `json:"perPage"`
	TotalItems int `json:"totalItems"`
	TotalPages int `json:"totalPages"`
	Items      []T `json:"items"`
}

func stepSyncHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req StepSyncRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	response, err := processStepSync(r, user.ID, token, req)
	if err != nil {
		status := statusCodeForError(err, http.StatusBadRequest)
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func processStepSync(r *http.Request, profileID string, token string, req StepSyncRequest) (StepSyncResponse, error) {
	normalized, capturedAt, recordDate, err := normalizeStepSyncRequest(req)
	if err != nil {
		return StepSyncResponse{}, err
	}

	character, err := getCharacterByProfileID(r, token, profileID)
	if err != nil {
		return StepSyncResponse{}, fmt.Errorf("get character failed: %w", err)
	}

	stats, err := getCharacterStats(r, token, character.ID)
	if err != nil {
		return StepSyncResponse{}, fmt.Errorf("get character stats failed: %w", err)
	}

	existingSummary, summaryFound, err := findDailyStepSummary(r, token, profileID, recordDate)
	if err != nil {
		return StepSyncResponse{}, fmt.Errorf("find daily step summary failed: %w", err)
	}

	deltaStepCount, deltaDistanceM := calculateDailyDelta(normalized, existingSummary, summaryFound)
	totalStepCount, totalDistanceM := calculateDailyTotals(normalized, existingSummary, summaryFound)
	missionDistanceM := calculateMissionDistance(normalized.SyncType, existingSummary.MissionDistanceM, deltaDistanceM)

	agility := stats.BaseAgility + stats.UpgradedAgility
	attackDistanceM := getStepAttackDistanceM(agility, normalized.SyncType, character.OfflineEfficiencyLevel)
	attackCountEarned := 0
	attackDistanceRemainderM := existingSummary.AttackDistanceRemainderM
	summaryAttackDistanceRemainderM := existingSummary.AttackDistanceRemainderM
	realtimeAttackCountBalance := 0
	bossTicketFragmentEarned := 0
	bossTicketFragmentDistanceRemainderM := existingSummary.BossTicketFragmentDistanceRemainderM
	bossTicketFragmentEarned, bossTicketFragmentDistanceRemainderM = calculateBossTicketFragmentsEarned(
		normalized.SyncType,
		existingSummary.BossTicketFragmentDistanceRemainderM,
		deltaDistanceM,
	)
	offlineAttackCountEarned := 0
	offlineAttackCountStored := 0
	offlineAttackCountLost := 0
	if normalized.SyncType == "offline" {
		attackCountEarned, attackDistanceRemainderM = calculateAttackCountEarned(
			existingSummary.AttackDistanceRemainderM,
			deltaDistanceM,
			attackDistanceM,
		)
		summaryAttackDistanceRemainderM = attackDistanceRemainderM
		offlineAttackCountEarned = attackCountEarned
		offlineAttackCountCap := offlineAttackCountCapForLevel(character.OfflineStorageLevel)
		offlineAttackCountStored, offlineAttackCountLost = calculateOfflineStorage(
			attackCountEarned,
			character.AttackCountBalance,
			offlineAttackCountCap,
		)
		attackCountEarned = offlineAttackCountStored
	} else if normalized.BattleID != "" {
		unlockBattle := lockNormalBattle(normalized.BattleID)
		battle, battleErr := getBattleByID(r.Context(), token, normalized.BattleID)
		if battleErr != nil {
			unlockBattle()
			return StepSyncResponse{}, fmt.Errorf("get active battle failed: %w", battleErr)
		}
		if battle.Character != character.ID || battle.Status != "in_progress" {
			unlockBattle()
			return StepSyncResponse{}, statusError{
				status:  http.StatusBadRequest,
				message: "battle is not active for this character",
			}
		}
		attackCountEarned, attackDistanceRemainderM = calculateAttackCountEarned(
			battle.RealtimeAttackDistanceRemainderM,
			deltaDistanceM,
			attackDistanceM,
		)
		realtimeAttackCountBalance = battle.RealtimeAttackCountBalance + attackCountEarned
		_, battleErr = patchBattle(r.Context(), token, battle.ID, map[string]any{
			"realtime_attack_count_balance":        realtimeAttackCountBalance,
			"realtime_attack_distance_remainder_m": round2(attackDistanceRemainderM),
		})
		unlockBattle()
		if battleErr != nil {
			return StepSyncResponse{}, fmt.Errorf("save realtime battle gauge failed: %w", battleErr)
		}
	}

	stepLog, err := createStepSyncLog(r, token, profileID, normalized, capturedAt)
	if err != nil {
		return StepSyncResponse{}, fmt.Errorf("create step sync log failed: %w", err)
	}

	dailySummary, err := upsertDailyStepSummary(
		r,
		token,
		profileID,
		recordDate,
		normalized,
		existingSummary,
		summaryFound,
		totalStepCount,
		totalDistanceM,
		missionDistanceM,
		attackCountEarned,
		summaryAttackDistanceRemainderM,
		offlineAttackCountEarned,
		offlineAttackCountStored,
		offlineAttackCountLost,
		bossTicketFragmentEarned,
		bossTicketFragmentDistanceRemainderM,
	)
	if err != nil {
		return StepSyncResponse{}, fmt.Errorf("save daily step summary failed: %w", err)
	}

	attackCountBalance := character.AttackCountBalance
	if normalized.SyncType == "offline" {
		attackCountBalance += attackCountEarned
		if err := updateCharacterAttackCount(r, token, character.ID, attackCountBalance); err != nil {
			return StepSyncResponse{}, fmt.Errorf("update character attack count failed: %w", err)
		}
	}

	if normalized.SyncType == "offline" && attackCountEarned > 0 {
		if err := createAttackCountTransaction(r, token, character.ID, stepLog.ID, attackCountEarned, attackCountBalance); err != nil {
			return StepSyncResponse{}, fmt.Errorf("create resource transaction failed: %w", err)
		}
	}

	bossTicketFragmentBalance, err := getBossEntranceTicketFragmentBalance(r.Context(), token, character.ID)
	if err != nil {
		return StepSyncResponse{}, fmt.Errorf("get boss entrance ticket fragment balance failed: %w", err)
	}
	if bossTicketFragmentEarned > 0 {
		bossTicketFragmentBalance, err = addBossEntranceTicketFragments(
			r.Context(),
			token,
			character.ID,
			bossTicketFragmentEarned,
		)
		if err != nil {
			return StepSyncResponse{}, fmt.Errorf("add boss entrance ticket fragments failed: %w", err)
		}
		if err := createBossEntranceTicketFragmentTransaction(
			r,
			token,
			character.ID,
			stepLog.ID,
			bossTicketFragmentEarned,
			bossTicketFragmentBalance,
		); err != nil {
			return StepSyncResponse{}, fmt.Errorf("create boss entrance ticket fragment transaction failed: %w", err)
		}
	}

	if err := syncUserDistanceMissions(r.Context(), token, profileID, recordDate, missionDistanceM); err != nil {
		return StepSyncResponse{}, fmt.Errorf("sync missions failed: %w", err)
	}

	return StepSyncResponse{
		ProfileID:                            profileID,
		CharacterID:                          character.ID,
		StepSyncLogID:                        stepLog.ID,
		DailySummaryID:                       dailySummary.ID,
		RecordDate:                           recordDate,
		StepCount:                            totalStepCount,
		DistanceM:                            totalDistanceM,
		DeltaStepCount:                       deltaStepCount,
		DeltaDistanceM:                       deltaDistanceM,
		Agility:                              agility,
		AttackDistanceM:                      round2(attackDistanceM),
		OfflineAttackDistanceM:               round2(getStepAttackDistanceM(agility, "offline", character.OfflineEfficiencyLevel)),
		AttackDistanceRemainderM:             round2(attackDistanceRemainderM),
		AttackCountEarned:                    attackCountEarned,
		AttackCountBalance:                   attackCountBalance,
		RealtimeAttackCountBalance:           realtimeAttackCountBalance,
		OfflineAttackCountCap:                offlineAttackCountCapForLevel(character.OfflineStorageLevel),
		OfflineAttackCountEarned:             offlineAttackCountEarned,
		OfflineAttackCountStored:             offlineAttackCountStored,
		OfflineAttackCountLost:               offlineAttackCountLost,
		BossTicketFragmentEarned:             bossTicketFragmentEarned,
		BossTicketFragmentBalance:            bossTicketFragmentBalance,
		BossTicketFragmentDistanceM:          bossTicketFragmentDistanceM,
		BossTicketFragmentDistanceRemainderM: round2(bossTicketFragmentDistanceRemainderM),
		Token:                                token,
	}, nil
}

func calculateBossTicketFragmentsEarned(syncType string, currentRemainderM float64, deltaDistanceM int) (int, float64) {
	if syncType == "offline" {
		return 0, currentRemainderM
	}
	return calculateAttackCountEarned(currentRemainderM, deltaDistanceM, bossTicketFragmentDistanceM)
}

func calculateMissionDistance(syncType string, currentDistanceM int, deltaDistanceM int) int {
	if syncType == "offline" {
		return currentDistanceM
	}
	return currentDistanceM + maxInt(deltaDistanceM, 0)
}

func calculateOfflineStorage(earned int, currentBalance int, capacity int) (stored int, lost int) {
	availableSlots := maxInt(capacity-currentBalance, 0)
	stored = minInt(maxInt(earned, 0), availableSlots)
	return stored, maxInt(earned-stored, 0)
}

func normalizeStepSyncRequest(req StepSyncRequest) (StepSyncRequest, time.Time, string, error) {
	if req.SourceType == "" {
		req.SourceType = "sensor"
	}
	if req.SyncType == "" {
		req.SyncType = "realtime"
	}
	if req.SourceType != "sensor" && req.SourceType != "api" {
		return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "source_type must be sensor or api"}
	}
	if req.SyncType != "realtime" && req.SyncType != "periodic" && req.SyncType != "offline" {
		return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "sync_type must be realtime, periodic, or offline"}
	}
	if req.StepCount < 0 || req.DistanceM < 0 {
		return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "step_count and distance_m cannot be negative"}
	}
	if req.GpsDistanceM < 0 {
		return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "gps_distance_m cannot be negative"}
	}
	if req.DistanceM == 0 && req.StepCount > 0 {
		strideM := req.StrideM
		if strideM == 0 {
			strideM = defaultStrideM
		}
		if strideM <= 0 {
			return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "stride_m must be greater than 0"}
		}
		req.DistanceM = int(math.Round(float64(req.StepCount) * strideM))
	}
	if req.StepCount == 0 && req.DistanceM == 0 {
		return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "step_count or distance_m is required"}
	}

	capturedAt := time.Now().UTC()
	if req.CapturedAt != "" {
		parsed, err := time.Parse(time.RFC3339, req.CapturedAt)
		if err != nil {
			return StepSyncRequest{}, time.Time{}, "", statusError{status: http.StatusBadRequest, message: "captured_at must be RFC3339 format"}
		}
		capturedAt = parsed.UTC()
	}

	return req, capturedAt, capturedAt.Format("2006-01-02"), nil
}

func getCharacterByProfileID(r *http.Request, token string, profileID string) (characterRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("user=%q", profileID))
	resp, err := pocketBaseRequest(r.Context(), http.MethodGet, pocketBaseCollectionURL("characters")+"?filter="+filter+"&perPage=1", token, nil)
	if err != nil {
		return characterRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return characterRecord{}, mapPocketBaseError(resp, "failed to find character")
	}

	var list pocketBaseListResponse[characterRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return characterRecord{}, errors.New("failed to parse character response")
	}
	if len(list.Items) == 0 {
		return characterRecord{}, statusError{status: http.StatusNotFound, message: "character not found"}
	}
	return list.Items[0], nil
}

func getCharacterStats(r *http.Request, token string, characterID string) (characterStatsRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q", characterID))
	resp, err := pocketBaseRequest(r.Context(), http.MethodGet, pocketBaseCollectionURL("character_stats")+"?filter="+filter+"&perPage=1", token, nil)
	if err != nil {
		return characterStatsRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return characterStatsRecord{}, mapPocketBaseError(resp, "failed to find character stats")
	}

	var list pocketBaseListResponse[characterStatsRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return characterStatsRecord{}, errors.New("failed to parse character stats response")
	}
	if len(list.Items) == 0 {
		return characterStatsRecord{}, statusError{status: http.StatusNotFound, message: "character stats not found"}
	}
	return list.Items[0], nil
}

func createStepSyncLog(r *http.Request, token string, profileID string, req StepSyncRequest, capturedAt time.Time) (stepSyncLogRecord, error) {
	payload := map[string]any{
		"profile_id":      profileID,
		"source_type":     req.SourceType,
		"sync_type":       req.SyncType,
		"step_count":      req.StepCount,
		"distance_m":      req.DistanceM,
		"gps_distance_m":  req.GpsDistanceM,
		"captured_at":     capturedAt.Format(time.RFC3339),
		"abnormal_flag":   req.AbnormalFlag,
		"abnormal_reason": truncateString(req.AbnormalReason, 255),
	}

	resp, err := pocketBaseRequest(r.Context(), http.MethodPost, pocketBaseCollectionURL("step_sync_logs"), token, payload)
	if err != nil {
		return stepSyncLogRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return stepSyncLogRecord{}, mapPocketBaseError(resp, "failed to create step sync log")
	}

	var record stepSyncLogRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return stepSyncLogRecord{}, errors.New("failed to parse step sync log response")
	}
	return record, nil
}

func upsertDailyStepSummary(
	r *http.Request,
	token string,
	profileID string,
	recordDate string,
	req StepSyncRequest,
	summary dailyStepSummaryRecord,
	found bool,
	totalStepCount int,
	totalDistanceM int,
	missionDistanceM int,
	attackCountEarned int,
	attackDistanceRemainderM float64,
	offlineAttackCountEarned int,
	offlineAttackCountStored int,
	offlineAttackCountLost int,
	bossTicketFragmentEarned int,
	bossTicketFragmentDistanceRemainderM float64,
) (dailyStepSummaryRecord, error) {
	payload := map[string]any{
		"user":                                      profileID,
		"record_date":                               recordDate,
		"total_step_count":                          totalStepCount,
		"total_distance_m":                          totalDistanceM,
		"mission_distance_m":                        missionDistanceM,
		"attack_count_earned":                       attackCountEarned,
		"attack_distance_remainder_m":               round2(attackDistanceRemainderM),
		"offline_attack_count_earned":               offlineAttackCountStored,
		"offline_attack_count_lost":                 offlineAttackCountLost,
		"boss_ticket_fragment_earned":               bossTicketFragmentEarned,
		"boss_ticket_fragment_distance_remainder_m": round2(bossTicketFragmentDistanceRemainderM),
	}
	method := http.MethodPost
	url := pocketBaseCollectionURL("daily_step_summaries")

	if found {
		payload["attack_count_earned"] = summary.AttackCountEarned + attackCountEarned
		payload["offline_attack_count_earned"] = summary.OfflineAttackCountEarned + offlineAttackCountStored
		payload["offline_attack_count_lost"] = summary.OfflineAttackCountLost + offlineAttackCountLost
		payload["boss_ticket_fragment_earned"] = summary.BossTicketFragmentEarned + bossTicketFragmentEarned
		method = http.MethodPatch
		url = pocketBaseRecordURL("daily_step_summaries", summary.ID)
	}

	resp, err := pocketBaseRequest(r.Context(), method, url, token, payload)
	if err != nil {
		return dailyStepSummaryRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return dailyStepSummaryRecord{}, mapPocketBaseError(resp, "failed to save daily step summary")
	}

	var saved dailyStepSummaryRecord
	if err := json.NewDecoder(resp.Body).Decode(&saved); err != nil {
		return dailyStepSummaryRecord{}, errors.New("failed to parse daily step summary response")
	}
	return saved, nil
}

func calculateDailyDelta(req StepSyncRequest, summary dailyStepSummaryRecord, found bool) (int, int) {
	if req.IsDelta {
		return req.StepCount, req.DistanceM
	}
	if !found {
		return req.StepCount, req.DistanceM
	}
	return maxInt(req.StepCount-summary.TotalStepCount, 0), maxInt(req.DistanceM-summary.TotalDistanceM, 0)
}

func calculateDailyTotals(req StepSyncRequest, summary dailyStepSummaryRecord, found bool) (int, int) {
	if req.IsDelta {
		if !found {
			return req.StepCount, req.DistanceM
		}
		return summary.TotalStepCount + req.StepCount, summary.TotalDistanceM + req.DistanceM
	}
	if !found {
		return req.StepCount, req.DistanceM
	}
	return maxInt(req.StepCount, summary.TotalStepCount), maxInt(req.DistanceM, summary.TotalDistanceM)
}

func calculateAttackCountEarned(previousRemainderM float64, deltaDistanceM int, attackDistanceM float64) (int, float64) {
	availableDistanceM := previousRemainderM + float64(deltaDistanceM)
	if availableDistanceM < attackDistanceM {
		return 0, availableDistanceM
	}

	earned := int(math.Floor(availableDistanceM / attackDistanceM))
	remainder := math.Mod(availableDistanceM, attackDistanceM)
	return earned, remainder
}

func maxInt(a int, b int) int {
	if a > b {
		return a
	}
	return b
}

func minInt(a int, b int) int {
	if a < b {
		return a
	}
	return b
}

func truncateString(value string, maxRunes int) string {
	if maxRunes <= 0 {
		return ""
	}
	runes := []rune(value)
	if len(runes) <= maxRunes {
		return value
	}
	return string(runes[:maxRunes])
}

func findDailyStepSummary(r *http.Request, token string, profileID string, recordDate string) (dailyStepSummaryRecord, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("user=%q", profileID))
	resp, err := pocketBaseRequest(r.Context(), http.MethodGet, pocketBaseCollectionURL("daily_step_summaries")+"?filter="+filter+"&perPage=100", token, nil)
	if err != nil {
		return dailyStepSummaryRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return dailyStepSummaryRecord{}, false, mapPocketBaseError(resp, "failed to find daily step summary")
	}

	var list pocketBaseListResponse[dailyStepSummaryRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return dailyStepSummaryRecord{}, false, errors.New("failed to parse daily step summary response")
	}
	for _, item := range list.Items {
		if sameRecordDate(item.RecordDate, recordDate) {
			return item, true, nil
		}
	}
	return dailyStepSummaryRecord{}, false, nil
}

func sameRecordDate(a string, b string) bool {
	parsedA, errA := parseRecordDate(a)
	parsedB, errB := parseRecordDate(b)
	return errA == nil && errB == nil &&
		parsedA.Year() == parsedB.Year() &&
		parsedA.Month() == parsedB.Month() &&
		parsedA.Day() == parsedB.Day()
}

func parseRecordDate(value string) (time.Time, error) {
	for _, layout := range []string{time.RFC3339, "2006-01-02 15:04:05.000Z", "2006-01-02 15:04:05Z", "2006-01-02"} {
		parsed, err := time.Parse(layout, value)
		if err == nil {
			return parsed.UTC(), nil
		}
	}
	return time.Time{}, errors.New("invalid record date")
}

func updateCharacterAttackCount(r *http.Request, token string, characterID string, balance int) error {
	resp, err := pocketBaseRequest(r.Context(), http.MethodPatch, pocketBaseRecordURL("characters", characterID), token, map[string]any{
		"attack_count_balance": balance,
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to update character attack count")
	}
	return nil
}

func createAttackCountTransaction(r *http.Request, token string, characterID string, sourceID string, amount int, balanceAfter int) error {
	resp, err := pocketBaseRequest(r.Context(), http.MethodPost, pocketBaseCollectionURL("resource_transactions"), token, map[string]any{
		"character":        characterID,
		"resource_type":    "attack_count",
		"transaction_type": "earn",
		"amount":           amount,
		"balance_after":    balanceAfter,
		"source_type":      "step",
		"source_id":        sourceID,
		"reason":           "step distance converted to attack count",
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

func createBossEntranceTicketFragmentTransaction(r *http.Request, token string, characterID string, sourceID string, amount int, balanceAfter int) error {
	resp, err := pocketBaseRequest(r.Context(), http.MethodPost, pocketBaseCollectionURL("resource_transactions"), token, map[string]any{
		"character":        characterID,
		"resource_type":    "boss_ticket_fragment",
		"transaction_type": "earn",
		"amount":           amount,
		"balance_after":    balanceAfter,
		"source_type":      "step",
		"source_id":        sourceID,
		"reason":           "active walking distance converted to boss entrance ticket fragments",
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create boss entrance ticket fragment transaction")
	}
	return nil
}

func getAttackDistanceM(agility int) float64 {
	return formulas.CalculateAttackDistance(agility)
}

func getStepAttackDistanceM(agility int, syncType string, offlineEfficiencyLevel int) float64 {
	attackDistanceM := getAttackDistanceM(agility)
	if syncType != "offline" {
		return attackDistanceM
	}

	reductionM := baseAttackDistanceM - attackDistanceM
	if reductionM <= 0 {
		return attackDistanceM
	}
	return round2(attackDistanceM + reductionM*offlineAgilityPenaltyForLevel(offlineEfficiencyLevel))
}

func round2(value float64) float64 {
	return math.Round(value*100) / 100
}
