package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	missionsCollection     = "missions"
	userMissionsCollection = "user_missions"
)

func missionsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/missions" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	missions, err := listActiveMissions(r.Context(), token)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "missions fetched", missions)
}

func userMissionsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	userID, resource, ok := parseUserResourcePath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	if resource == "raid-invitations" {
		userRaidInvitationsHandler(w, r, userID)
		return
	}
	if resource == "friends" {
		userFriendsHandler(w, r, userID)
		return
	}
	if resource == "friend-requests" {
		userFriendRequestsHandler(w, r, userID)
		return
	}
	if resource == "sent-friend-requests" {
		userSentFriendRequestsHandler(w, r, userID)
		return
	}
	if resource == "blocked-friends" {
		userBlockedFriendsHandler(w, r, userID)
		return
	}
	if resource != "missions" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if user.ID != userID {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user does not match authenticated user"})
		return
	}

	if err := ensureUserMissionsForDate(r.Context(), token, userID, time.Now().UTC(), 0); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	missions, err := listUserMissions(r.Context(), token, userID, time.Now().UTC())
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "user missions fetched", missions)
}

func userMissionClaimHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	userMissionID, ok := parseUserMissionClaimPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	data, err := claimUserMission(r.Context(), token, user.ID, userMissionID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{
			"message": "mission claim failed",
			"error":   err.Error(),
		})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "mission reward claimed", data)
}

func parseUserResourcePath(path string) (string, string, bool) {
	const prefix = "/api/users/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}
	return parts[0], parts[1], true
}

func parseUserMissionClaimPath(path string) (string, bool) {
	const prefix = "/api/user-missions/"
	if !strings.HasPrefix(path, prefix) {
		return "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] != "claim" {
		return "", false
	}
	return parts[0], true
}

func listActiveMissions(ctx context.Context, token string) (pocketBaseListResponse[map[string]any], error) {
	return listCollectionRecords(ctx, token, missionsCollection, "is_active=true", "", "mission_type,title")
}

func listActiveMissionRecords(ctx context.Context, token string) ([]missionRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(missionsCollection)+"?filter=is_active=true&sort=mission_type,target_value,title&perPage=100", token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list missions")
	}

	var list pocketBaseListResponse[missionRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse missions response")
	}
	return list.Items, nil
}

func listUserMissions(ctx context.Context, token string, userID string, date time.Time) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("user=%q", userID)
	list, err := listCollectionRecords(ctx, token, userMissionsCollection, filter, "mission", "-mission_date,-created")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return filterUserMissionListForDate(list, date), nil
}

func filterUserMissionListForDate(list pocketBaseListResponse[map[string]any], date time.Time) pocketBaseListResponse[map[string]any] {
	filtered := make([]map[string]any, 0, len(list.Items))
	indexByKey := make(map[string]int)

	for _, item := range list.Items {
		mission := expandedMissionMap(item)
		periodStart := missionPeriodStart(mapString(mission["mission_type"]), date)
		if !sameRecordDate(mapString(item["mission_date"]), periodStart.Format("2006-01-02")) {
			continue
		}

		key := userMissionDedupeKey(item)
		if key == "" {
			key = mapString(item["id"])
		}
		if key == "" {
			filtered = append(filtered, item)
			continue
		}

		if existingIndex, ok := indexByKey[key]; ok {
			if preferUserMissionItem(item, filtered[existingIndex]) {
				filtered[existingIndex] = item
			}
			continue
		}

		indexByKey[key] = len(filtered)
		filtered = append(filtered, item)
	}

	list.Items = filtered
	list.TotalItems = len(filtered)
	if len(filtered) == 0 {
		list.TotalPages = 0
	} else {
		list.TotalPages = 1
	}
	if list.PerPage <= 0 {
		list.PerPage = 100
	}
	return list
}

func userMissionDedupeKey(item map[string]any) string {
	mission := expandedMissionMap(item)
	missionType := strings.ToLower(mapString(mission["mission_type"]))
	title := strings.ToLower(mapString(mission["title"]))
	targetType := strings.ToLower(mapString(mission["target_type"]))
	targetValue := mapString(mission["target_value"])
	if missionType != "" || title != "" || targetType != "" || targetValue != "" {
		return "mission-display:" + missionType + "|" + title + "|" + targetType + "|" + targetValue
	}

	missionID := mapString(item["mission"])
	if missionID != "" {
		return "mission:" + missionID
	}
	return ""
}

func expandedMissionMap(item map[string]any) map[string]any {
	expand, ok := item["expand"].(map[string]any)
	if !ok {
		return nil
	}
	mission, ok := expand["mission"].(map[string]any)
	if !ok {
		return nil
	}
	return mission
}

func preferUserMissionItem(candidate map[string]any, current map[string]any) bool {
	candidateRank := userMissionStatusRank(mapString(candidate["status"]))
	currentRank := userMissionStatusRank(mapString(current["status"]))
	if candidateRank != currentRank {
		return candidateRank > currentRank
	}

	candidateProgress := mapFloat(candidate["progress_value"])
	currentProgress := mapFloat(current["progress_value"])
	if candidateProgress != currentProgress {
		return candidateProgress > currentProgress
	}

	return mapString(candidate["updated"]) > mapString(current["updated"])
}

func userMissionStatusRank(status string) int {
	switch status {
	case "claimed":
		return 3
	case "completed":
		return 2
	case "in_progress":
		return 1
	default:
		return 0
	}
}

func mapFloat(value any) float64 {
	switch v := value.(type) {
	case float64:
		return v
	case float32:
		return float64(v)
	case int:
		return float64(v)
	case int64:
		return float64(v)
	case json.Number:
		f, _ := v.Float64()
		return f
	default:
		return 0
	}
}

type missionProgressSnapshot struct {
	DailyDistanceM          float64
	WeeklyDistanceM         float64
	DailyNormalStageClears  float64
	WeeklyNormalStageClears float64
	DailyBossStageClears    float64
	WeeklyBossStageClears   float64
}

func buildMissionProgressSnapshot(ctx context.Context, token string, userID string, date time.Time, fallbackDailyDistanceM float64) (missionProgressSnapshot, error) {
	dailyStart := missionPeriodStart("daily", date)
	dailyEnd := dailyStart.AddDate(0, 0, 1)
	weeklyStart := missionPeriodStart("weekly", date)
	weeklyEnd := weeklyStart.AddDate(0, 0, 7)

	snapshot := missionProgressSnapshot{}

	summaries, err := listDailyStepSummariesByUser(ctx, token, userID)
	if err != nil {
		return snapshot, err
	}
	for _, summary := range summaries {
		summaryDate, err := parseRecordDate(summary.RecordDate)
		if err != nil {
			continue
		}
		summaryDay := missionPeriodStart("daily", summaryDate)
		if !summaryDay.Before(dailyStart) && summaryDay.Before(dailyEnd) {
			snapshot.DailyDistanceM = float64(summary.MissionDistanceM)
		}
		if !summaryDay.Before(weeklyStart) && summaryDay.Before(weeklyEnd) {
			snapshot.WeeklyDistanceM += float64(summary.MissionDistanceM)
		}
	}

	if fallbackDailyDistanceM > snapshot.DailyDistanceM {
		delta := fallbackDailyDistanceM - snapshot.DailyDistanceM
		snapshot.DailyDistanceM = fallbackDailyDistanceM
		snapshot.WeeklyDistanceM += delta
	}

	character, err := getBattleCharacterByUserID(ctx, token, userID)
	if err != nil {
		return snapshot, err
	}

	dailyNormalClears, err := countBattleWinsInPeriod(ctx, token, character.ID, "normal", dailyStart, dailyEnd)
	if err != nil {
		return snapshot, err
	}
	weeklyNormalClears, err := countBattleWinsInPeriod(ctx, token, character.ID, "normal", weeklyStart, weeklyEnd)
	if err != nil {
		return snapshot, err
	}
	dailyBossClears, err := countBattleWinsInPeriod(ctx, token, character.ID, "boss", dailyStart, dailyEnd)
	if err != nil {
		return snapshot, err
	}
	weeklyBossClears, err := countBattleWinsInPeriod(ctx, token, character.ID, "boss", weeklyStart, weeklyEnd)
	if err != nil {
		return snapshot, err
	}

	snapshot.DailyNormalStageClears = float64(dailyNormalClears)
	snapshot.WeeklyNormalStageClears = float64(weeklyNormalClears)
	snapshot.DailyBossStageClears = float64(dailyBossClears)
	snapshot.WeeklyBossStageClears = float64(weeklyBossClears)

	return snapshot, nil
}

func missionPeriodStart(missionType string, date time.Time) time.Time {
	utc := date.UTC()
	year, month, day := utc.Date()
	start := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	if missionType != "weekly" {
		return start
	}

	daysSinceMonday := (int(start.Weekday()) + 6) % 7
	return start.AddDate(0, 0, -daysSinceMonday)
}

func listDailyStepSummariesByUser(ctx context.Context, token string, userID string) ([]dailyStepSummaryRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("user=%q", userID))
	endpoint := pocketBaseCollectionURL("daily_step_summaries") + "?filter=" + filter + "&sort=-record_date&perPage=100"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list daily step summaries")
	}

	var list pocketBaseListResponse[dailyStepSummaryRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse daily step summaries response")
	}
	return list.Items, nil
}

func countBattleWinsInPeriod(ctx context.Context, token string, characterID string, battleType string, start time.Time, end time.Time) (int, error) {
	filter := url.QueryEscape(fmt.Sprintf("character=%q && battle_type=%q && status=%q", characterID, battleType, "win"))
	endpoint := pocketBaseCollectionURL("battles") + "?filter=" + filter + "&sort=-ended_at&perPage=500"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, mapPocketBaseError(resp, "failed to list battle wins")
	}

	var list pocketBaseListResponse[battleRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return 0, errors.New("failed to parse battle wins response")
	}

	count := 0
	for _, battle := range list.Items {
		completedAt, err := parsePocketBaseDate(battle.EndedAt)
		if err != nil {
			completedAt, err = parsePocketBaseDate(battle.StartedAt)
			if err != nil {
				continue
			}
		}
		completedAt = completedAt.UTC()
		if !completedAt.Before(start) && completedAt.Before(end) {
			count++
		}
	}
	return count, nil
}

func ensureUserMissionsForDate(ctx context.Context, token string, userID string, date time.Time, progressDistanceM float64) error {
	snapshot, err := buildMissionProgressSnapshot(ctx, token, userID, date, progressDistanceM)
	if err != nil {
		return err
	}

	missions, err := listActiveMissionRecords(ctx, token)
	if err != nil {
		return err
	}

	for _, mission := range missions {
		if mission.ID == "" || !mission.IsActive {
			continue
		}
		periodStart := missionPeriodStart(mission.MissionType, date).Format("2006-01-02")
		if err := upsertUserMissionProgress(ctx, token, userID, mission, periodStart, snapshot); err != nil {
			return err
		}
	}
	return nil
}

func syncUserDistanceMissions(ctx context.Context, token string, userID string, recordDate string, totalDistanceM int) error {
	date, err := parseRecordDate(recordDate)
	if err != nil {
		date = time.Now().UTC()
	}
	return ensureUserMissionsForDate(ctx, token, userID, date, float64(totalDistanceM))
}

func syncUserBattleClearMissions(ctx context.Context, token string, userID string, completedAt string) error {
	date, err := parsePocketBaseDate(completedAt)
	if err != nil {
		date = time.Now().UTC()
	}
	return ensureUserMissionsForDate(ctx, token, userID, date, 0)
}

func upsertUserMissionProgress(ctx context.Context, token string, userID string, mission missionRecord, recordDate string, snapshot missionProgressSnapshot) error {
	progress := missionProgressValue(mission, snapshot)
	status := "in_progress"
	completedAt := ""
	if mission.TargetValue > 0 && progress >= mission.TargetValue {
		status = "completed"
		completedAt = time.Now().UTC().Format(time.RFC3339)
	}

	existing, found, err := findUserMissionByDate(ctx, token, userID, mission.ID, recordDate)
	if err != nil {
		return err
	}
	if found {
		if progress < existing.ProgressValue {
			progress = existing.ProgressValue
		}
		payload := map[string]any{
			"progress_value": progress,
		}
		if existing.Status != "claimed" {
			nextStatus := "in_progress"
			if existing.Status == "completed" || (mission.TargetValue > 0 && progress >= mission.TargetValue) {
				nextStatus = "completed"
			}
			payload["status"] = nextStatus
			if nextStatus == "completed" && strings.TrimSpace(existing.CompletedAt) == "" {
				if completedAt == "" {
					completedAt = time.Now().UTC().Format(time.RFC3339)
				}
				payload["completed_at"] = completedAt
			}
			notifyCompleted := nextStatus == "completed" && existing.Status != "completed" && existing.Status != "claimed"
			if err := patchUserMission(ctx, token, existing.ID, payload); err != nil {
				return err
			}
			if notifyCompleted {
				createNotificationBestEffort(ctx, token, missionCompletedNotification(userID, existing.ID, mission))
			}
			return nil
		}
		return patchUserMission(ctx, token, existing.ID, payload)
	}

	payload := map[string]any{
		"user":           userID,
		"mission":        mission.ID,
		"mission_date":   recordDate + " 00:00:00.000Z",
		"progress_value": progress,
		"status":         status,
		"started_at":     time.Now().UTC().Format(time.RFC3339),
	}
	if status == "completed" {
		payload["completed_at"] = completedAt
	}
	record, err := createUserMission(ctx, token, payload)
	if err != nil {
		return err
	}
	if status == "completed" {
		createNotificationBestEffort(ctx, token, missionCompletedNotification(userID, mapString(record["id"]), mission))
	}
	return nil
}

func missionProgressValue(mission missionRecord, snapshot missionProgressSnapshot) float64 {
	progress := 0.0
	switch mission.TargetType {
	case "distance":
		if mission.MissionType == "weekly" {
			progress = snapshot.WeeklyDistanceM
		} else {
			progress = snapshot.DailyDistanceM
		}
	case "normal_stage_clear":
		if mission.MissionType == "weekly" {
			progress = snapshot.WeeklyNormalStageClears
		} else {
			progress = snapshot.DailyNormalStageClears
		}
	case "boss_stage_clear":
		if mission.MissionType == "weekly" {
			progress = snapshot.WeeklyBossStageClears
		} else {
			progress = snapshot.DailyBossStageClears
		}
	}

	if progress < 0 {
		return 0
	}
	if mission.TargetValue > 0 && progress > mission.TargetValue {
		return mission.TargetValue
	}
	return progress
}

func findUserMissionByDate(ctx context.Context, token string, userID string, missionID string, recordDate string) (userMissionRecord, bool, error) {
	filter := fmt.Sprintf("user=%q && mission=%q", userID, missionID)
	list, err := listUserMissionRecords(ctx, token, filter, "mission", "-mission_date,-created")
	if err != nil {
		return userMissionRecord{}, false, err
	}
	for _, item := range list.Items {
		if sameRecordDate(item.MissionDate, recordDate) {
			return item, true, nil
		}
	}
	return userMissionRecord{}, false, nil
}

func listUserMissionRecords(ctx context.Context, token string, filter string, expand string, sort string) (pocketBaseListResponse[userMissionRecord], error) {
	endpoint := pocketBaseCollectionURL(userMissionsCollection) + "?filter=" + url.QueryEscape(filter) + "&perPage=100"
	if expand != "" {
		endpoint += "&expand=" + url.QueryEscape(expand)
	}
	if sort != "" {
		endpoint += "&sort=" + url.QueryEscape(sort)
	}

	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return pocketBaseListResponse[userMissionRecord]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[userMissionRecord]{}, mapPocketBaseError(resp, "failed to list user missions")
	}

	var list pocketBaseListResponse[userMissionRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[userMissionRecord]{}, errors.New("failed to parse user missions response")
	}
	return list, nil
}

func createUserMission(ctx context.Context, token string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(userMissionsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create user mission")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse user mission response")
	}
	return record, nil
}

func missionCompletedNotification(userID string, userMissionID string, mission missionRecord) notificationCreateInput {
	title := strings.TrimSpace(mission.Title)
	if title == "" {
		title = "미션 완료"
	}
	return notificationCreateInput{
		UserID:     userID,
		Type:       "mission_completed",
		Title:      "미션 완료",
		Message:    title + " 미션을 완료했습니다.",
		SourceType: "user_mission",
		SourceID:   userMissionID,
		Data: map[string]any{
			"user_mission_id": userMissionID,
			"mission_id":      mission.ID,
			"mission_title":   mission.Title,
			"reward_coin":     mission.RewardCoin,
		},
	}
}

func patchUserMission(ctx context.Context, token string, userMissionID string, payload map[string]any) error {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(userMissionsCollection, userMissionID), token, payload)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to update user mission")
	}
	return nil
}

func claimUserMission(ctx context.Context, token string, userID string, userMissionID string) (map[string]any, error) {
	userMission, err := getUserMission(ctx, token, userMissionID)
	if err != nil {
		return nil, err
	}
	if userMission.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "user mission does not belong to authenticated user"}
	}
	if userMission.Status == "claimed" || strings.TrimSpace(userMission.ClaimedAt) != "" {
		return nil, statusError{status: http.StatusConflict, message: "mission reward already claimed"}
	}
	if userMission.Status != "completed" {
		return nil, statusError{status: http.StatusBadRequest, message: "mission is not completed"}
	}

	mission, ok := userMission.Expand["mission"]
	if !ok || mission.ID == "" {
		mission, err = getMission(ctx, token, userMission.Mission)
		if err != nil {
			return nil, err
		}
	}
	if !mission.IsActive {
		return nil, statusError{status: http.StatusBadRequest, message: "mission is not active"}
	}

	rewardCoin, err := wholeCoinReward(mission.RewardCoin)
	if err != nil {
		return nil, err
	}

	character, err := getBattleCharacterByUserID(ctx, token, userID)
	if err != nil {
		return nil, err
	}

	var updatedCharacter any
	if rewardCoin > 0 {
		updated, err := patchBattleCharacter(ctx, token, character.ID, map[string]any{
			"coin_balance": character.CoinBalance + rewardCoin,
		})
		if err != nil {
			return nil, err
		}
		updatedCharacter = updated
	} else {
		updatedCharacter = character
	}

	updatedUserMission, err := patchUserMissionClaimed(ctx, token, userMissionID)
	if err != nil {
		return nil, err
	}

	rewardLog, err := createMissionRewardLog(ctx, token, character.ID, userMissionID, rewardCoin)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"user_mission": updatedUserMission,
		"mission":      mission,
		"character":    updatedCharacter,
		"reward_log":   rewardLog,
		"reward_coin":  rewardCoin,
	}, nil
}

func getUserMission(ctx context.Context, token string, userMissionID string) (userMissionRecord, error) {
	endpoint := pocketBaseRecordURL(userMissionsCollection, userMissionID) + "?expand=mission"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return userMissionRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return userMissionRecord{}, statusError{status: http.StatusNotFound, message: "user mission not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return userMissionRecord{}, mapPocketBaseError(resp, "failed to get user mission")
	}

	var record userMissionRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return userMissionRecord{}, errors.New("failed to parse user mission response")
	}
	return record, nil
}

func getMission(ctx context.Context, token string, missionID string) (missionRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(missionsCollection, missionID), token, nil)
	if err != nil {
		return missionRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return missionRecord{}, statusError{status: http.StatusNotFound, message: "mission not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return missionRecord{}, mapPocketBaseError(resp, "failed to get mission")
	}

	var record missionRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return missionRecord{}, errors.New("failed to parse mission response")
	}
	return record, nil
}

func patchUserMissionClaimed(ctx context.Context, token string, userMissionID string) (map[string]any, error) {
	payload := map[string]any{
		"status":     "claimed",
		"claimed_at": time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(userMissionsCollection, userMissionID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update user mission")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse user mission update response")
	}
	return record, nil
}

func createMissionRewardLog(ctx context.Context, token string, characterID string, userMissionID string, rewardCoin int) (map[string]any, error) {
	payload := map[string]any{
		"character":            characterID,
		"source_type":          "mission",
		"source_id":            userMissionID,
		"reward_item_quantity": 0,
		"reward_coin":          rewardCoin,
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("reward_logs"), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create reward log")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse reward log response")
	}
	return record, nil
}

func wholeCoinReward(rewardCoin float64) (int, error) {
	if rewardCoin < 0 {
		return 0, statusError{status: http.StatusBadRequest, message: "mission reward coin is invalid"}
	}
	if rewardCoin != float64(int(rewardCoin)) {
		return 0, statusError{status: http.StatusBadRequest, message: "mission reward coin must be whole coin"}
	}
	return int(rewardCoin), nil
}
