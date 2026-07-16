package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	goldMineEventRunsCollection = "gold_mine_event_runs"
	goldMineUnlockStageNo       = 13
	goldMineDurationSeconds     = 180
	goldMineMaxRewardDistanceM  = 600
	goldMineMaxSpeedKmh         = 30.0
)

type goldMineEventRun struct {
	ID                    string  `json:"id"`
	Character             string  `json:"character"`
	RunDate               string  `json:"run_date"`
	Status                string  `json:"status"`
	StartedAt             string  `json:"started_at"`
	FinishedAt            string  `json:"finished_at"`
	DistanceM             float64 `json:"distance_m"`
	StepCount             int     `json:"step_count"`
	MaxSpeedKmh           float64 `json:"max_speed_kmh"`
	RewardCoin            int     `json:"reward_coin"`
	RewardStatExp         int     `json:"reward_stat_exp"`
	RewardTicketFragments int     `json:"reward_ticket_fragments"`
}

type goldMineFinishRequest struct {
	RunID       string  `json:"run_id"`
	DistanceM   float64 `json:"distance_m"`
	StepCount   int     `json:"step_count"`
	MaxSpeedKmh float64 `json:"max_speed_kmh"`
}

func goldMineEventStatusHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	data, err := goldMineEventStatus(r.Context(), token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "gold mine event status fetched", data)
}

func goldMineEventStartHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	data, err := startGoldMineEvent(r.Context(), token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusCreated, "gold mine event started", data)
}

func goldMineEventFinishHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var req goldMineFinishRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}
	data, err := finishGoldMineEvent(r.Context(), token, user.ID, req, time.Now().UTC())
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "gold mine event finished", data)
}

func goldMineEventStatus(ctx context.Context, token, userID string) (map[string]any, error) {
	character, err := getBattleCharacterByUserID(ctx, token, userID)
	if err != nil {
		return nil, err
	}
	unlocked, err := isGoldMineEventUnlocked(ctx, token, character.ID)
	if err != nil {
		return nil, err
	}
	run, found, err := findGoldMineRun(ctx, token, character.ID, currentShopOfferDate())
	if err != nil {
		return nil, err
	}
	return buildGoldMineStatus(unlocked, run, found), nil
}

func startGoldMineEvent(ctx context.Context, token, userID string) (map[string]any, error) {
	character, err := getBattleCharacterByUserID(ctx, token, userID)
	if err != nil {
		return nil, err
	}
	unlocked, err := isGoldMineEventUnlocked(ctx, token, character.ID)
	if err != nil {
		return nil, err
	}
	if !unlocked {
		return nil, statusError{status: http.StatusForbidden, message: "clear stage 3-3 to unlock the gold mine event"}
	}
	runDate := currentShopOfferDate()
	if _, found, err := findGoldMineRun(ctx, token, character.ID, runDate); err != nil {
		return nil, err
	} else if found {
		return nil, statusError{status: http.StatusConflict, message: "gold mine event already attempted today"}
	}
	now := time.Now().UTC()
	payload := map[string]any{
		"user": userID, "character": character.ID, "run_date": runDate,
		"status": "running", "started_at": now.Format(time.RFC3339),
		"distance_m": 0, "step_count": 0, "max_speed_kmh": 0,
		"reward_coin": 0, "reward_stat_exp": 0, "reward_ticket_fragments": 0,
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(goldMineEventRunsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to create gold mine event run")
	}
	var run goldMineEventRun
	if err := json.NewDecoder(resp.Body).Decode(&run); err != nil {
		return nil, err
	}
	return map[string]any{"run": run, "duration_seconds": goldMineDurationSeconds}, nil
}

func finishGoldMineEvent(ctx context.Context, token, userID string, req goldMineFinishRequest, now time.Time) (map[string]any, error) {
	req.RunID = strings.TrimSpace(req.RunID)
	if req.RunID == "" || req.DistanceM < 0 || req.StepCount < 0 || req.MaxSpeedKmh < 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "invalid gold mine event result"}
	}
	character, err := getBattleCharacterByUserID(ctx, token, userID)
	if err != nil {
		return nil, err
	}
	run, err := getGoldMineRun(ctx, token, req.RunID)
	if err != nil {
		return nil, err
	}
	if run.Character != character.ID || run.Status != "running" {
		return nil, statusError{status: http.StatusConflict, message: "gold mine event run is not active"}
	}
	startedAt, err := time.Parse(time.RFC3339Nano, run.StartedAt)
	if err != nil {
		return nil, errors.New("invalid gold mine event start time")
	}
	elapsed := now.Sub(startedAt).Seconds()
	if elapsed < 10 || elapsed > goldMineDurationSeconds+30 {
		return nil, statusError{status: http.StatusBadRequest, message: "gold mine event duration is invalid"}
	}
	if req.MaxSpeedKmh > goldMineMaxSpeedKmh || req.DistanceM > elapsed*(goldMineMaxSpeedKmh/3.6)+15 {
		return nil, statusError{status: http.StatusBadRequest, message: "abnormal movement speed detected"}
	}
	if req.DistanceM >= 50 && req.StepCount <= 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "step verification failed"}
	}

	rewardDistance := minInt(int(req.DistanceM), goldMineMaxRewardDistanceM)
	rewardCoin, rewardStatExp, rewardFragments := goldMineRewardsForDistance(rewardDistance)
	fragmentBalance, err := getBossEntranceTicketFragmentBalance(ctx, token, character.ID)
	if err != nil {
		return nil, err
	}
	if rewardFragments > 0 {
		fragmentBalance, err = addBossEntranceTicketFragments(ctx, token, character.ID, rewardFragments)
		if err != nil {
			return nil, err
		}
	}
	updatedCharacter, err := patchBattleCharacter(ctx, token, character.ID, map[string]any{
		"coin_balance": character.CoinBalance + rewardCoin,
		"stat_exp":     character.StatExp + rewardStatExp,
	})
	if err != nil {
		return nil, err
	}
	payload := map[string]any{
		"status": "finished", "finished_at": now.Format(time.RFC3339),
		"distance_m": req.DistanceM, "step_count": req.StepCount, "max_speed_kmh": req.MaxSpeedKmh,
		"reward_coin": rewardCoin, "reward_stat_exp": rewardStatExp, "reward_ticket_fragments": rewardFragments,
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(goldMineEventRunsCollection, run.ID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to finish gold mine event run")
	}
	return map[string]any{
		"distance_m": req.DistanceM, "reward_distance_m": rewardDistance,
		"reward_coin": rewardCoin, "reward_stat_exp": rewardStatExp,
		"reward_ticket_fragments": rewardFragments, "boss_ticket_fragment_balance": fragmentBalance,
		"character": updatedCharacter, "cleared": rewardDistance >= 400,
	}, nil
}

func goldMineRewardsForDistance(distanceM int) (coin, statExp, fragments int) {
	for _, milestone := range []struct{ distance, coin int }{{100, 100}, {200, 120}, {300, 140}, {400, 160}, {500, 180}, {600, 200}} {
		if distanceM >= milestone.distance {
			coin += milestone.coin
		}
	}
	if distanceM >= 400 {
		fragments++
	}
	if distanceM >= 500 {
		statExp++
	}
	if distanceM >= 600 {
		fragments += 3
	}
	return
}

func isGoldMineEventUnlocked(ctx context.Context, token, characterID string) (bool, error) {
	stage, err := getNormalStageByNo(ctx, token, goldMineUnlockStageNo)
	if err != nil {
		return false, err
	}
	progress, found, err := getStageProgress(ctx, token, characterID, stage.ID)
	if err != nil {
		return false, err
	}
	return found && progress.ClearCount > 0, nil
}

func findGoldMineRun(ctx context.Context, token, characterID, runDate string) (goldMineEventRun, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && run_date=%q", characterID, runDate))
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(goldMineEventRunsCollection)+"?filter="+filter+"&perPage=1", token, nil)
	if err != nil {
		return goldMineEventRun{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return goldMineEventRun{}, false, mapPocketBaseError(resp, "failed to find gold mine event run")
	}
	var list pocketBaseListResponse[goldMineEventRun]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return goldMineEventRun{}, false, err
	}
	if len(list.Items) == 0 {
		return goldMineEventRun{}, false, nil
	}
	return list.Items[0], true, nil
}

func getGoldMineRun(ctx context.Context, token, runID string) (goldMineEventRun, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(goldMineEventRunsCollection, runID), token, nil)
	if err != nil {
		return goldMineEventRun{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return goldMineEventRun{}, mapPocketBaseError(resp, "gold mine event run not found")
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return goldMineEventRun{}, err
	}
	var run goldMineEventRun
	if err := json.Unmarshal(body, &run); err != nil {
		return goldMineEventRun{}, err
	}
	return run, nil
}

func buildGoldMineStatus(unlocked bool, run goldMineEventRun, found bool) map[string]any {
	data := map[string]any{
		"unlocked": unlocked, "attempted_today": found,
		"duration_seconds": goldMineDurationSeconds, "clear_distance_m": 400,
		"max_reward_distance_m": goldMineMaxRewardDistanceM, "max_speed_kmh": goldMineMaxSpeedKmh,
	}
	if found {
		data["run"] = run
	}
	return data
}
