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
	"sync"
	"time"

	"server/src/utils/formulas"
)

const (
	raidsCollection            = "raids"
	raidParticipantsCollection = "raid_participants"
	raidInvitationsCollection  = "raid_invitations"
	raidProgressCollection     = "raid_progress"
	raidWeeklyClearsCollection = "raid_weekly_clears"
	friendshipsCollection      = "friendships"
	baseRaidAttackDistanceM    = 1000
	raidMonsterAttackInterval  = 3 * time.Minute
	defaultRaidMonsterHP       = 1800
	minRaidEntryLevel          = 5
)

var raidParticipantHPMultipliers = map[int]float64{
	1: 0.70,
	2: 0.80,
	3: 0.90,
	4: 1.00,
}

var raidWeeklyLocation = time.FixedZone("Asia/Seoul", 9*60*60)

var raidLocks sync.Map

func raidsHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		handleRaidList(w, r)
	case http.MethodPost:
		handleRaidCreate(w, r)
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
	}
}

func raidMonstersHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/raid-monsters" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	monsters, err := listCollectionRecords(r.Context(), token, "monsters", `monster_type="raid" && is_active=true`, "", "hp,name")
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid monsters fetch failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid monsters fetched", monsters)
}

func raidDetailHandler(w http.ResponseWriter, r *http.Request) {
	raidID, resource, ok := parseRaidPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	switch {
	case r.Method == http.MethodGet && resource == "":
		handleRaidDetail(w, r, raidID)
	case r.Method == http.MethodPost && resource == "join":
		handleRaidJoin(w, r, raidID)
	case r.Method == http.MethodPost && resource == "start":
		handleRaidStart(w, r, raidID)
	case r.Method == http.MethodPost && resource == "leave":
		handleRaidLeave(w, r, raidID)
	case r.Method == http.MethodGet && resource == "participants":
		handleRaidParticipants(w, r, raidID)
	case r.Method == http.MethodPost && resource == "invite":
		handleRaidInvite(w, r, raidID)
	case r.Method == http.MethodPost && resource == "distance":
		handleRaidDistance(w, r, raidID)
	case r.Method == http.MethodGet && resource == "progress":
		handleRaidProgress(w, r, raidID)
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	}
}

func raidInvitationActionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	invitationID, action, ok := parseRaidInvitationPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	if action != "accept" && action != "decline" && action != "cancel" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidInvitationResponseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "characterId is required"})
		return
	}

	var (
		data    any
		message string
	)
	if action == "accept" {
		data, err = acceptRaidInvitation(r.Context(), token, user.ID, invitationID, req.CharacterID)
		message = "raid invitation accepted"
	} else if action == "decline" {
		data, err = declineRaidInvitation(r.Context(), token, user.ID, invitationID, req.CharacterID)
		message = "raid invitation declined"
	} else {
		data, err = cancelRaidInvitation(r.Context(), token, user.ID, invitationID, req.CharacterID)
		message = "raid invitation canceled"
	}
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid invitation action failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, message, data)
}

func userRaidInvitationsHandler(w http.ResponseWriter, r *http.Request, userID string) bool {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return true
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return true
	}
	if user.ID != userID {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user does not match authenticated user"})
		return true
	}

	invitations, err := listRaidInvitations(r.Context(), token, userID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return true
	}

	writeInventoryResponse(w, http.StatusOK, "raid invitations fetched", invitations)
	return true
}

func handleRaidList(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/raids" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	raids, err := listCollectionRecords(r.Context(), token, raidsCollection, "", "monster,host_character", "-created")
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raids fetched", raids)
}

func handleRaidDetail(w http.ResponseWriter, r *http.Request, raidID string) {
	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	raid, err := getRaidMap(r.Context(), token, raidID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusNotFound), map[string]string{"error": err.Error()})
		return
	}
	participants, err := listRaidParticipantRecords(r.Context(), token, raidID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid fetched", map[string]any{
		"raid":              raid,
		"participant_count": len(participants.Items),
	})
}

func handleRaidCreate(w http.ResponseWriter, r *http.Request) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.HostCharacterID = strings.TrimSpace(req.HostCharacterID)
	req.MonsterID = strings.TrimSpace(req.MonsterID)
	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)
	if req.HostCharacterID == "" || req.MonsterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "hostCharacterId and monsterId are required"})
		return
	}

	data, err := createRaid(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid create failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusCreated, "raid created", data)
}

func handleRaidJoin(w http.ResponseWriter, r *http.Request, raidID string) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "characterId is required"})
		return
	}

	data, err := joinRaid(r.Context(), token, user.ID, raidID, req.CharacterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid join failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid joined", data)
}

func handleRaidStart(w http.ResponseWriter, r *http.Request, raidID string) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "characterId is required"})
		return
	}

	data, err := startRaid(r.Context(), token, user.ID, raidID, req.CharacterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid start failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid started", data)
}

func handleRaidLeave(w http.ResponseWriter, r *http.Request, raidID string) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "characterId is required"})
		return
	}

	data, err := leaveRaid(r.Context(), token, user.ID, raidID, req.CharacterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid leave failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid left", data)
}

func handleRaidParticipants(w http.ResponseWriter, r *http.Request, raidID string) {
	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	if _, err := getRaid(r.Context(), token, raidID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusNotFound), map[string]string{"error": err.Error()})
		return
	}
	participants, err := listRaidParticipantRecords(r.Context(), token, raidID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	summaries, err := raidParticipantSummaries(r.Context(), token, participants.Items)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	data := pocketBaseListResponse[map[string]any]{
		Page:       participants.Page,
		PerPage:    participants.PerPage,
		TotalItems: participants.TotalItems,
		TotalPages: participants.TotalPages,
		Items:      summaries,
	}

	writeInventoryResponse(w, http.StatusOK, "raid participants fetched", data)
}

func handleRaidInvite(w http.ResponseWriter, r *http.Request, raidID string) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidInviteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.InviterCharacterID = strings.TrimSpace(req.InviterCharacterID)
	req.InvitedUserID = strings.TrimSpace(req.InvitedUserID)
	if req.InviterCharacterID == "" || req.InvitedUserID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "inviterCharacterId and invitedUserId are required"})
		return
	}

	data, err := inviteRaidFriend(r.Context(), token, user.ID, raidID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid invite failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusCreated, "raid invitation created", data)
}

func handleRaidDistance(w http.ResponseWriter, r *http.Request, raidID string) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req raidDistanceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	if req.CharacterID == "" || req.DistanceM < 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "characterId and non-negative distanceM are required"})
		return
	}

	data, err := addRaidDistance(r.Context(), token, user.ID, raidID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid distance update failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid distance updated", data)
}

func handleRaidProgress(w http.ResponseWriter, r *http.Request, raidID string) {
	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	unlockRaid := lockRaid(raidID)
	defer unlockRaid()

	data, err := getRaidProgressSummary(r.Context(), token, raidID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "raid progress fetch failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "raid progress fetched", data)
}

func parseRaidPath(path string) (string, string, bool) {
	const prefix = "/api/raids/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) == 1 && parts[0] != "" {
		return parts[0], "", true
	}
	if len(parts) == 2 && parts[0] != "" && parts[1] != "" {
		return parts[0], parts[1], true
	}
	return "", "", false
}

func parseRaidInvitationPath(path string) (string, string, bool) {
	const prefix = "/api/raid-invitations/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}
	return parts[0], parts[1], true
}

func createRaid(ctx context.Context, token string, userID string, req raidCreateRequest) (map[string]any, error) {
	host, err := getBattleCharacterByID(ctx, token, req.HostCharacterID)
	if err != nil {
		return nil, err
	}
	if host.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "host character does not belong to authenticated user"}
	}
	if err := ensureRaidEntryLevel(host); err != nil {
		return nil, err
	}
	monster, err := getMonsterByID(ctx, token, req.MonsterID)
	if err != nil {
		return nil, err
	}
	if monster.MonsterType != "raid" {
		return nil, statusError{status: http.StatusBadRequest, message: "monster is not raid type"}
	}
	if isRaidMonsterComingSoon(monster) {
		return nil, statusError{status: http.StatusBadRequest, message: "raid monster is coming soon"}
	}
	if err := ensureRaidWeeklyClearAvailable(ctx, token, userID, monster.ID, time.Now()); err != nil {
		return nil, err
	}
	if err := cancelWaitingRaidsForHost(ctx, token, req.HostCharacterID, ""); err != nil {
		return nil, err
	}

	payload := map[string]any{
		"host_character":   req.HostCharacterID,
		"monster":          req.MonsterID,
		"title":            req.Title,
		"description":      req.Description,
		"max_participants": 4,
		"status":           "waiting",
		"reward_coin":      0,
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(raidsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create raid")
	}

	var raid map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&raid); err != nil {
		return nil, errors.New("failed to parse raid create response")
	}

	participant, err := createRaidParticipant(ctx, token, raid["id"].(string), req.HostCharacterID)
	if err != nil {
		return nil, err
	}

	progress, err := createRaidProgress(ctx, token, raid["id"].(string), raidMonsterInitialHP(monster))
	if err != nil {
		return nil, err
	}

	return map[string]any{"raid": raid, "participant": participant, "progress": progress}, nil
}

func joinRaid(ctx context.Context, token string, userID string, raidID string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	if err := ensureRaidEntryLevel(character); err != nil {
		return nil, err
	}
	unlockRaid := lockRaid(raidID)
	defer unlockRaid()

	raid, err := getRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if err := ensureRaidJoinable(ctx, token, raid, characterID); err != nil {
		return nil, err
	}
	if err := ensureRaidWeeklyClearAvailable(ctx, token, character.User, raid.Monster, time.Now()); err != nil {
		return nil, err
	}

	participant, err := createRaidParticipant(ctx, token, raidID, characterID)
	if err != nil {
		return nil, err
	}
	lobby, err := getRaidProgressSummary(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"raid":        raid,
		"participant": participant,
		"lobby":       lobby,
		"lobby_path":  raidLobbyPath(raidID),
	}, nil
}

func startRaid(ctx context.Context, token string, userID string, raidID string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	unlockRaid := lockRaid(raidID)
	defer unlockRaid()

	raid, err := getRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if raid.Status != "waiting" && raid.Status != "in_progress" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid is not active"}
	}
	if raid.HostCharacter != characterID {
		return nil, statusError{status: http.StatusForbidden, message: "only raid host can start raids"}
	}
	if raid.Status == "waiting" {
		if err := cancelWaitingRaidIfHostMissing(ctx, token, raid); err != nil {
			return nil, err
		}
	}
	participant, err := getJoinedRaidParticipant(ctx, token, raidID, characterID)
	if err != nil {
		return nil, err
	}
	if raid.Status == "waiting" {
		if err := cancelPendingRaidInvitations(ctx, token, raidID); err != nil {
			return nil, err
		}
	}
	invitations, err := listPendingRaidInvitationsByRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if len(invitations.Items) > 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "raid has pending invitations"}
	}
	participants, err := listRaidParticipantRecords(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	activeParticipants, err := listActiveRaidParticipantRecords(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if len(activeParticipants.Items) == 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "raid has no active participants"}
	}
	if err := ensureRaidWeeklyClearAvailableForParticipants(ctx, token, raid.Monster, activeParticipants.Items, time.Now()); err != nil {
		return nil, err
	}
	if raid.Status == "waiting" && len(activeParticipants.Items) != len(participants.Items) {
		return nil, statusError{status: http.StatusBadRequest, message: "raid participants are not ready"}
	}
	progress, err := getRaidProgress(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if progress.Status == "cleared" || progress.Status == "failed" || progress.Status == "canceled" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid progress is already finished"}
	}

	var updatedRaid any = raid
	var updatedProgress any = progress
	if progress.Status == "waiting" || raid.Status == "waiting" {
		now := time.Now().UTC().Format(time.RFC3339)
		if progress.Status == "waiting" {
			monster, err := getMonsterByID(ctx, token, raid.Monster)
			if err != nil {
				return nil, err
			}
			if isRaidMonsterComingSoon(monster) {
				return nil, statusError{status: http.StatusBadRequest, message: "raid monster is coming soon"}
			}
			participantsScaledHP := raidMonsterScaledHP(monster, len(activeParticipants.Items))
			progressPayload := map[string]any{
				"monster_current_hp": participantsScaledHP,
				"status":             "in_progress",
				"started_at":         now,
			}
			updatedProgress, err = patchRaidProgress(ctx, token, progress.ID, progressPayload)
			if err != nil {
				return nil, err
			}
		}
		if raid.Status == "waiting" {
			updatedRaid, err = patchRaid(ctx, token, raid.ID, map[string]any{
				"status":     "in_progress",
				"start_time": now,
			})
			if err != nil {
				return nil, err
			}
		}
	}

	lobby, err := getRaidProgressSummary(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"raid":        updatedRaid,
		"progress":    updatedProgress,
		"participant": participant,
		"lobby":       lobby,
		"lobby_path":  raidLobbyPath(raidID),
	}, nil
}

func leaveRaid(ctx context.Context, token string, userID string, raidID string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	unlockRaid := lockRaid(raidID)
	defer unlockRaid()

	raid, err := getRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if raid.Status != "waiting" && raid.Status != "in_progress" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid is not active"}
	}
	hostLeftRaid := raid.HostCharacter == characterID
	participant, err := getJoinedRaidParticipant(ctx, token, raidID, characterID)
	if err != nil {
		return nil, err
	}

	updatedParticipant, err := patchRaidParticipant(ctx, token, participant.ID, map[string]any{
		"join_status": "left",
	})
	if err != nil {
		return nil, err
	}
	if err := restoreRaidParticipantsHP(ctx, token, []raidParticipantRecord{participant}); err != nil {
		return nil, err
	}

	progress, err := getRaidProgress(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if hostLeftRaid {
		participants, err := listRaidParticipantRecords(ctx, token, raidID)
		if err != nil {
			return nil, err
		}
		if err := leaveAllRaidParticipants(ctx, token, raidID); err != nil {
			return nil, err
		}
		if err := restoreRaidParticipantsHP(ctx, token, participants.Items); err != nil {
			return nil, err
		}
		if err := cancelPendingRaidInvitations(ctx, token, raidID); err != nil {
			return nil, err
		}
		now := time.Now().UTC().Format(time.RFC3339)
		updatedProgress, err := patchRaidProgress(ctx, token, progress.ID, map[string]any{
			"status":   "canceled",
			"ended_at": now,
		})
		if err != nil {
			return nil, err
		}
		updatedRaid, err := patchRaid(ctx, token, raid.ID, map[string]any{
			"status":   "canceled",
			"end_time": now,
		})
		if err != nil {
			return nil, err
		}
		lobby, err := getRaidProgressSummary(ctx, token, raidID)
		if err != nil {
			return nil, err
		}
		return map[string]any{
			"raid":        updatedRaid,
			"progress":    updatedProgress,
			"participant": updatedParticipant,
			"lobby":       lobby,
			"lobby_path":  raidLobbyPath(raidID),
		}, nil
	}
	activeParticipants, err := listActiveRaidParticipantRecords(ctx, token, raidID)
	if err != nil {
		return nil, err
	}

	var updatedProgress any = progress
	var updatedRaid any = raid
	if len(activeParticipants.Items) == 0 && progress.Status != "cleared" && progress.Status != "failed" && progress.Status != "canceled" {
		now := time.Now().UTC().Format(time.RFC3339)
		updatedProgress, err = patchRaidProgress(ctx, token, progress.ID, map[string]any{
			"status":   "canceled",
			"ended_at": now,
		})
		if err != nil {
			return nil, err
		}
		updatedRaid, err = patchRaid(ctx, token, raid.ID, map[string]any{
			"status":   "canceled",
			"end_time": now,
		})
		if err != nil {
			return nil, err
		}
	}

	lobby, err := getRaidProgressSummary(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"raid":        updatedRaid,
		"progress":    updatedProgress,
		"participant": updatedParticipant,
		"lobby":       lobby,
		"lobby_path":  raidLobbyPath(raidID),
	}, nil
}

func inviteRaidFriend(ctx context.Context, token string, userID string, raidID string, req raidInviteRequest) (map[string]any, error) {
	raid, err := getRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if raid.Status != "waiting" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid is not waiting for invitations"}
	}
	inviter, err := getBattleCharacterByID(ctx, token, req.InviterCharacterID)
	if err != nil {
		return nil, err
	}
	if inviter.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "inviter character does not belong to authenticated user"}
	}
	if raid.HostCharacter != req.InviterCharacterID {
		return nil, statusError{status: http.StatusForbidden, message: "only raid host can invite users"}
	}
	if err := ensureUserExists(ctx, token, req.InvitedUserID); err != nil {
		return nil, err
	}
	if err := ensureAcceptedFriend(ctx, token, userID, req.InvitedUserID); err != nil {
		return nil, err
	}
	if err := ensureRaidWeeklyClearAvailable(ctx, token, req.InvitedUserID, raid.Monster, time.Now()); err != nil {
		return nil, err
	}
	if exists, err := isUserAlreadyInRaid(ctx, token, raidID, req.InvitedUserID); err != nil {
		return nil, err
	} else if exists {
		return nil, statusError{status: http.StatusConflict, message: "invited user is already participating in raid"}
	}
	if err := cancelStalePendingRaidInvitations(ctx, token, req.InviterCharacterID, req.InvitedUserID, raidID); err != nil {
		return nil, err
	}
	if exists, err := hasPendingRaidInvitation(ctx, token, raidID, req.InvitedUserID); err != nil {
		return nil, err
	} else if exists {
		return nil, statusError{status: http.StatusConflict, message: "pending invitation already exists"}
	}

	payload := map[string]any{
		"raid":              raidID,
		"inviter_character": req.InviterCharacterID,
		"invited_user":      req.InvitedUserID,
		"status":            "pending",
		"invited_at":        time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(raidInvitationsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create raid invitation")
	}

	var invitation map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&invitation); err != nil {
		return nil, errors.New("failed to parse raid invitation response")
	}
	invitationID := mapString(invitation["id"])
	createNotificationBestEffort(ctx, token, notificationCreateInput{
		UserID:     req.InvitedUserID,
		Type:       "raid_invite",
		Title:      "레이드 초대",
		Message:    "새 레이드 초대가 도착했습니다.",
		SourceType: "raid_invitation",
		SourceID:   invitationID,
		Data: map[string]any{
			"raid_id":              raidID,
			"invitation_id":        invitationID,
			"inviter_character_id": req.InviterCharacterID,
		},
	})
	lobby, err := getRaidProgressSummary(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"raid":         raid,
		"invitation":   invitation,
		"lobby":        lobby,
		"lobby_path":   raidLobbyPath(raidID),
		"invited_user": req.InvitedUserID,
	}, nil
}

func acceptRaidInvitation(ctx context.Context, token string, userID string, invitationID string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	if err := ensureRaidEntryLevel(character); err != nil {
		return nil, err
	}
	invitation, err := getRaidInvitation(ctx, token, invitationID)
	if err != nil {
		return nil, err
	}
	if invitation.InvitedUser != userID {
		return nil, statusError{status: http.StatusForbidden, message: "invitation does not belong to authenticated user"}
	}
	if invitation.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "invitation is not pending"}
	}
	unlockRaid := lockRaid(invitation.Raid)
	defer unlockRaid()

	invitation, err = getRaidInvitation(ctx, token, invitationID)
	if err != nil {
		return nil, err
	}
	if invitation.InvitedUser != userID {
		return nil, statusError{status: http.StatusForbidden, message: "invitation does not belong to authenticated user"}
	}
	if invitation.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "invitation is not pending"}
	}

	raid, err := getRaid(ctx, token, invitation.Raid)
	if err != nil {
		return nil, err
	}
	if raid.Status != "waiting" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid is not waiting for participants"}
	}
	if err := cancelWaitingRaidIfHostMissing(ctx, token, raid); err != nil {
		return nil, err
	}
	if err := ensureRaidJoinable(ctx, token, raid, characterID); err != nil {
		return nil, err
	}
	if err := ensureRaidWeeklyClearAvailable(ctx, token, character.User, raid.Monster, time.Now()); err != nil {
		return nil, err
	}

	participant, err := createRaidParticipant(ctx, token, invitation.Raid, characterID)
	if err != nil {
		return nil, err
	}
	updatedInvitation, err := patchRaidInvitationStatus(ctx, token, invitationID, "accepted")
	if err != nil {
		return nil, err
	}
	lobby, err := getRaidProgressSummary(ctx, token, invitation.Raid)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"invitation":  updatedInvitation,
		"participant": participant,
		"raid":        raid,
		"lobby":       lobby,
		"lobby_path":  raidLobbyPath(invitation.Raid),
	}, nil
}

func declineRaidInvitation(ctx context.Context, token string, userID string, invitationID string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	invitation, err := getRaidInvitation(ctx, token, invitationID)
	if err != nil {
		return nil, err
	}
	if invitation.InvitedUser != userID {
		return nil, statusError{status: http.StatusForbidden, message: "invitation does not belong to authenticated user"}
	}
	if invitation.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "invitation is not pending"}
	}

	updatedInvitation, err := patchRaidInvitationStatus(ctx, token, invitationID, "declined")
	if err != nil {
		return nil, err
	}
	return map[string]any{"invitation": updatedInvitation}, nil
}

func cancelRaidInvitation(ctx context.Context, token string, userID string, invitationID string, characterID string) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	invitation, err := getRaidInvitation(ctx, token, invitationID)
	if err != nil {
		return nil, err
	}
	if invitation.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "invitation is not pending"}
	}
	unlockRaid := lockRaid(invitation.Raid)
	defer unlockRaid()

	invitation, err = getRaidInvitation(ctx, token, invitationID)
	if err != nil {
		return nil, err
	}
	if invitation.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "invitation is not pending"}
	}
	raid, err := getRaid(ctx, token, invitation.Raid)
	if err != nil {
		return nil, err
	}
	if raid.Status != "waiting" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid is not waiting for invitations"}
	}
	if raid.HostCharacter != characterID && invitation.InviterCharacter != characterID {
		return nil, statusError{status: http.StatusForbidden, message: "only raid host can cancel invitations"}
	}

	updatedInvitation, err := patchRaidInvitationStatus(ctx, token, invitationID, "canceled")
	if err != nil {
		return nil, err
	}
	if err := cancelPendingRaidInvitationsForUser(ctx, token, invitation.Raid, invitation.InvitedUser); err != nil {
		return nil, err
	}
	lobby, err := getRaidProgressSummary(ctx, token, invitation.Raid)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"invitation": updatedInvitation,
		"raid":       raid,
		"lobby":      lobby,
		"lobby_path": raidLobbyPath(invitation.Raid),
	}, nil
}

func listRaidInvitations(ctx context.Context, token string, userID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("invited_user=%q && status=%q", userID, "pending")
	invitations, err := listCollectionRecords(ctx, token, raidInvitationsCollection, filter, "raid,raid.monster,raid.host_character,inviter_character,inviter_character.user", "-invited_at,-created")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	activeInvitations := make([]map[string]any, 0, len(invitations.Items))
	for _, invitation := range invitations.Items {
		active, err := ensureRaidInvitationStillActive(ctx, token, invitation)
		if err != nil {
			return pocketBaseListResponse[map[string]any]{}, err
		}
		if active {
			activeInvitations = append(activeInvitations, invitation)
		}
	}
	activeInvitations, err = pruneDuplicateRaidInvitations(ctx, token, activeInvitations)
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	activeInvitations, err = hydrateRaidInvitationUsers(ctx, token, activeInvitations)
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	invitations.Items = activeInvitations
	invitations.TotalItems = len(activeInvitations)
	return invitations, nil
}

func listPendingRaidInvitationsByRaid(ctx context.Context, token string, raidID string) (pocketBaseListResponse[map[string]any], error) {
	invitations, err := listPendingRaidInvitationRecordsByRaid(ctx, token, raidID)
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	invitations.Items, err = hydrateRaidInvitationUsers(ctx, token, invitations.Items)
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return invitations, nil
}

func listPendingRaidInvitationRecordsByRaid(ctx context.Context, token string, raidID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("raid=%q && status=%q", raidID, "pending")
	return listCollectionRecords(ctx, token, raidInvitationsCollection, filter, "invited_user,inviter_character", "invited_at,created")
}

func ensureRaidInvitationStillActive(ctx context.Context, token string, invitation map[string]any) (bool, error) {
	invitationID := stringField(invitation, "id")
	raidID := stringField(invitation, "raid")
	if invitationID == "" || raidID == "" {
		return false, nil
	}
	raid, err := getRaid(ctx, token, raidID)
	if err != nil {
		var statusErr statusError
		if errors.As(err, &statusErr) && statusErr.status == http.StatusNotFound {
			if _, err := patchRaidInvitationStatus(ctx, token, invitationID, "canceled"); err != nil {
				return false, err
			}
			return false, nil
		}
		return false, err
	}
	if raid.Status != "waiting" {
		if _, err := patchRaidInvitationStatus(ctx, token, invitationID, "canceled"); err != nil {
			return false, err
		}
		return false, nil
	}
	if err := cancelWaitingRaidIfHostMissing(ctx, token, raid); err != nil {
		var statusErr statusError
		if errors.As(err, &statusErr) && statusErr.status == http.StatusGone {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func addRaidDistance(ctx context.Context, token string, userID string, raidID string, req raidDistanceRequest) (map[string]any, error) {
	character, err := getBattleCharacterByID(ctx, token, req.CharacterID)
	if err != nil {
		return nil, err
	}
	if character.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "character does not belong to authenticated user"}
	}
	unlockRaid := lockRaid(raidID)
	defer unlockRaid()

	raid, err := getRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if raid.Status != "waiting" && raid.Status != "in_progress" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid is not active"}
	}
	pendingInvitations, err := listPendingRaidInvitationsByRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if len(pendingInvitations.Items) > 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "raid has pending invitations"}
	}
	participant, err := getJoinedRaidParticipant(ctx, token, raidID, req.CharacterID)
	if err != nil {
		return nil, err
	}
	progress, err := getRaidProgress(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if progress.Status == "cleared" || progress.Status == "failed" || progress.Status == "canceled" {
		return nil, statusError{status: http.StatusBadRequest, message: "raid progress is already finished"}
	}

	participants, err := listActiveRaidParticipantRecords(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	if len(participants.Items) == 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "raid has no active participants"}
	}
	monster, err := getMonsterByID(ctx, token, raid.Monster)
	if err != nil {
		return nil, err
	}
	teamAgility, err := calculateRaidTeamAgility(ctx, token, participants.Items)
	if err != nil {
		return nil, err
	}
	attackDistanceM := calculateRaidAttackDistance(teamAgility)
	attackGaugePercent, err := calculateRaidAttackGaugePercent(ctx, token, participants.Items)
	if err != nil {
		return nil, err
	}
	attackDistanceM = applyBattlePercentToDistance(attackDistanceM, attackGaugePercent)

	nowTime := time.Now()
	now := nowTime.UTC().Format(time.RFC3339)
	nextTotalDistance := progress.TotalDistanceAccumulatedM + req.DistanceM
	nextCycleDistance := progress.DistanceSinceLastAttackCycleM + req.DistanceM
	attackCycles := int(math.Floor(nextCycleDistance / attackDistanceM))
	nextCycleDistance = math.Mod(nextCycleDistance, attackDistanceM)
	nextTotalAttackCycles := progress.TotalAttackCycles + float64(attackCycles)
	damageDealt, totalAttackCount, participantDamages, participantAttackCounts, err := calculateRaidCycleDamage(ctx, token, attackCycles, participants.Items, monster)
	if err != nil {
		return nil, err
	}
	nextMonsterHP := applyRaidDamage(progress.MonsterCurrentHP, damageDealt)
	nextMonsterAttackDistance := 0.0
	monsterAttackCycles := 0
	totalMonsterDamage := 0
	defeatedParticipants := []string{}
	if nextMonsterHP > 0 {
		monsterAttackCycles = raidMonsterAttackCyclesDue(progress.StartedAt, nowTime, int(progress.TotalMonsterAttackCycles))
		totalMonsterDamage, defeatedParticipants, err = applyRaidMonsterAreaAttack(ctx, token, monster, participants.Items, monsterAttackCycles)
		if err != nil {
			return nil, err
		}
	}
	nextProgressStatus := progress.Status
	startedAt := progress.StartedAt
	endedAt := progress.EndedAt
	if nextProgressStatus == "" || nextProgressStatus == "waiting" {
		nextProgressStatus = "in_progress"
		startedAt = firstNonEmpty(startedAt, now)
	}
	if nextMonsterHP <= 0 {
		nextProgressStatus = "cleared"
		endedAt = now
	} else if len(defeatedParticipants) == len(participants.Items) {
		nextProgressStatus = "failed"
		endedAt = now
	}

	progressPayload := map[string]any{
		"monster_current_hp":                   nextMonsterHP,
		"total_distance_accumulated_m":         nextTotalDistance,
		"distance_since_last_attack_cycle_m":   nextCycleDistance,
		"distance_since_last_monster_attack_m": nextMonsterAttackDistance,
		"total_attack_cycles":                  nextTotalAttackCycles,
		"total_monster_attack_cycles":          progress.TotalMonsterAttackCycles + float64(monsterAttackCycles),
		"status":                               nextProgressStatus,
		"started_at":                           startedAt,
		"ended_at":                             endedAt,
	}
	updatedProgress, err := patchRaidProgress(ctx, token, progress.ID, progressPayload)
	if err != nil {
		return nil, err
	}
	if nextProgressStatus == "cleared" || nextProgressStatus == "failed" {
		if err := restoreRaidParticipantsHP(ctx, token, participants.Items); err != nil {
			return nil, err
		}
	}
	rewardCoin := 0
	if nextProgressStatus == "cleared" {
		if err := createRaidWeeklyClearsForParticipants(ctx, token, raid, participants.Items, nowTime); err != nil {
			return nil, err
		}
		rewardCoin = randomCoin(monster.RewardCoinMin, monster.RewardCoinMax)
		if err := awardRaidCoinToParticipants(ctx, token, participants.Items, rewardCoin); err != nil {
			return nil, err
		}
	}

	var updatedParticipant any
	for _, activeParticipant := range participants.Items {
		payload := map[string]any{
			"contribution_damage":       activeParticipant.ContributionDamage + float64(participantDamages[activeParticipant.ID]),
			"contribution_attack_count": activeParticipant.ContributionAttackCount + float64(participantAttackCounts[activeParticipant.ID]),
		}
		if activeParticipant.ID == participant.ID {
			payload["contribution_distance_m"] = activeParticipant.ContributionDistanceM + req.DistanceM
		}
		patchedParticipant, err := patchRaidParticipant(ctx, token, activeParticipant.ID, payload)
		if err != nil {
			return nil, err
		}
		if activeParticipant.ID == participant.ID {
			updatedParticipant = patchedParticipant
		}
	}

	var updatedRaid any = raid
	if raid.Status == "waiting" || nextProgressStatus == "cleared" || nextProgressStatus == "failed" {
		raidPayload := map[string]any{"status": "in_progress"}
		if raid.Status == "waiting" {
			raidPayload["start_time"] = now
		}
		if nextProgressStatus == "cleared" || nextProgressStatus == "failed" {
			raidPayload["status"] = "ended"
			raidPayload["end_time"] = now
			raidPayload["reward_coin"] = rewardCoin
		}
		updatedRaid, err = patchRaid(ctx, token, raid.ID, raidPayload)
		if err != nil {
			return nil, err
		}
	}

	return map[string]any{
		"raid":                      updatedRaid,
		"progress":                  updatedProgress,
		"participant":               updatedParticipant,
		"attack_cycles":             attackCycles,
		"total_attack_count":        totalAttackCount,
		"damage_dealt":              damageDealt,
		"monster_attack_cycles":     monsterAttackCycles,
		"monster_damage_dealt":      totalMonsterDamage,
		"reward_coin":               rewardCoin,
		"defeated_participants":     defeatedParticipants,
		"active_participants":       len(participants.Items),
		"team_agility":              teamAgility,
		"attack_distance_m":         attackDistanceM,
		"monster_attack_distance_m": 0,
		"monster_attack_interval_s": int(raidMonsterAttackInterval.Seconds()),
	}, nil
}

func awardRaidCoinToParticipants(
	ctx context.Context,
	token string,
	participants []raidParticipantRecord,
	rewardCoin int,
) error {
	if rewardCoin <= 0 {
		return nil
	}
	for _, participant := range participants {
		if participant.JoinStatus != "joined" {
			continue
		}
		character, err := getBattleCharacterByID(ctx, token, participant.Character)
		if err != nil {
			return err
		}
		if _, err := patchBattleCharacter(ctx, token, character.ID, map[string]any{
			"coin_balance": character.CoinBalance + rewardCoin,
		}); err != nil {
			return err
		}
	}
	return nil
}

func getRaidProgressSummary(ctx context.Context, token string, raidID string) (map[string]any, error) {
	raid, err := getRaidMap(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	progress, err := getRaidProgress(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	participants, err := listRaidParticipantRecords(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	participantSummaries, err := raidParticipantSummaries(ctx, token, participants.Items)
	if err != nil {
		return nil, err
	}
	activeParticipants := activeRaidParticipants(participants.Items)
	teamAgility := 0
	attackDistanceM := float64(baseRaidAttackDistanceM)
	if len(activeParticipants) > 0 {
		teamAgility, err = calculateRaidTeamAgility(ctx, token, activeParticipants)
		if err != nil {
			return nil, err
		}
		attackDistanceM = calculateRaidAttackDistance(teamAgility)
		attackGaugePercent, gaugeErr := calculateRaidAttackGaugePercent(ctx, token, activeParticipants)
		if gaugeErr != nil {
			return nil, gaugeErr
		}
		attackDistanceM = applyBattlePercentToDistance(attackDistanceM, attackGaugePercent)
	}
	invitations, err := listPendingRaidInvitationsByRaid(ctx, token, raidID)
	if err != nil {
		return nil, err
	}
	monsterID, _ := raid["monster"].(string)
	monster := map[string]any(nil)
	if expanded, ok := raid["expand"].(map[string]any); ok {
		if expandedMonster, ok := expanded["monster"].(map[string]any); ok {
			monster = expandedMonster
		}
	}
	if monster == nil && monsterID != "" {
		if record, err := getMonsterMap(ctx, token, monsterID); err == nil {
			monster = record
		}
	}
	return map[string]any{
		"raid":                      raid,
		"progress":                  progress,
		"monster":                   monster,
		"participants":              participantSummaries,
		"invitations":               invitations.Items,
		"pending_invitation_count":  len(invitations.Items),
		"participant_count":         len(participants.Items),
		"active_participants":       len(activeParticipants),
		"team_agility":              teamAgility,
		"attack_distance_m":         attackDistanceM,
		"monster_attack_distance_m": 0,
		"monster_attack_interval_s": int(raidMonsterAttackInterval.Seconds()),
		"lobby_path":                raidLobbyPath(raidID),
	}, nil
}

func activeRaidParticipants(participants []raidParticipantRecord) []raidParticipantRecord {
	active := make([]raidParticipantRecord, 0, len(participants))
	for _, participant := range participants {
		if participant.JoinStatus == "joined" {
			active = append(active, participant)
		}
	}
	return active
}

func leaveAllRaidParticipants(ctx context.Context, token string, raidID string) error {
	participants, err := listRaidParticipantRecords(ctx, token, raidID)
	if err != nil {
		return err
	}
	for _, participant := range participants.Items {
		if participant.JoinStatus != "joined" {
			continue
		}
		if _, err := patchRaidParticipant(ctx, token, participant.ID, map[string]any{
			"join_status": "left",
		}); err != nil {
			return err
		}
	}
	return nil
}

func cancelPendingRaidInvitations(ctx context.Context, token string, raidID string) error {
	invitations, err := listPendingRaidInvitationRecordsByRaid(ctx, token, raidID)
	if err != nil {
		return err
	}
	for _, invitation := range invitations.Items {
		id, _ := invitation["id"].(string)
		if id == "" {
			continue
		}
		if _, err := patchRaidInvitationStatus(ctx, token, id, "canceled"); err != nil {
			return err
		}
	}
	return nil
}

func cancelStalePendingRaidInvitations(ctx context.Context, token string, inviterCharacterID string, invitedUserID string, currentRaidID string) error {
	filter := fmt.Sprintf(
		"inviter_character=%q && invited_user=%q && status=%q",
		inviterCharacterID,
		invitedUserID,
		"pending",
	)
	invitations, err := listCollectionRecords(ctx, token, raidInvitationsCollection, filter, "", "-invited_at,-created")
	if err != nil {
		return err
	}
	for _, invitation := range invitations.Items {
		if stringField(invitation, "raid") == currentRaidID {
			continue
		}
		id := stringField(invitation, "id")
		if id == "" {
			continue
		}
		if _, err := patchRaidInvitationStatus(ctx, token, id, "canceled"); err != nil {
			return err
		}
	}
	return nil
}

func cancelPendingRaidInvitationsForUser(ctx context.Context, token string, raidID string, invitedUserID string) error {
	filter := fmt.Sprintf("raid=%q && invited_user=%q && status=%q", raidID, invitedUserID, "pending")
	invitations, err := listCollectionRecords(ctx, token, raidInvitationsCollection, filter, "", "-invited_at,-created")
	if err != nil {
		return err
	}
	for _, invitation := range invitations.Items {
		id := stringField(invitation, "id")
		if id == "" {
			continue
		}
		if _, err := patchRaidInvitationStatus(ctx, token, id, "canceled"); err != nil {
			return err
		}
	}
	return nil
}

func cancelWaitingRaidsForHost(ctx context.Context, token string, hostCharacterID string, exceptRaidID string) error {
	hostCharacterID = strings.TrimSpace(hostCharacterID)
	if hostCharacterID == "" {
		return nil
	}
	filter := fmt.Sprintf("host_character=%q && status=%q", hostCharacterID, "waiting")
	raids, err := listCollectionRecords(ctx, token, raidsCollection, filter, "", "-created")
	if err != nil {
		return err
	}
	for _, item := range raids.Items {
		raidID := stringField(item, "id")
		if raidID == "" || raidID == exceptRaidID {
			continue
		}
		if err := cancelWaitingRaid(ctx, token, raidRecord{
			ID:            raidID,
			HostCharacter: stringField(item, "host_character"),
			Monster:       stringField(item, "monster"),
			Status:        stringField(item, "status"),
		}); err != nil {
			return err
		}
	}
	return nil
}

func cancelWaitingRaidIfHostMissing(ctx context.Context, token string, raid raidRecord) error {
	if strings.TrimSpace(raid.HostCharacter) == "" {
		return cancelWaitingRaidAfterHostLeft(ctx, token, raid)
	}
	if _, err := getJoinedRaidParticipant(ctx, token, raid.ID, raid.HostCharacter); err != nil {
		var statusErr statusError
		if errors.As(err, &statusErr) && statusErr.status == http.StatusForbidden {
			return cancelWaitingRaidAfterHostLeft(ctx, token, raid)
		}
		return err
	}
	return nil
}

func cancelWaitingRaidAfterHostLeft(ctx context.Context, token string, raid raidRecord) error {
	if err := cancelWaitingRaid(ctx, token, raid); err != nil {
		return err
	}
	return statusError{status: http.StatusGone, message: "raid host left"}
}

func cancelWaitingRaid(ctx context.Context, token string, raid raidRecord) error {
	participants, err := listRaidParticipantRecords(ctx, token, raid.ID)
	if err != nil {
		return err
	}
	if err := leaveAllRaidParticipants(ctx, token, raid.ID); err != nil {
		return err
	}
	if err := restoreRaidParticipantsHP(ctx, token, participants.Items); err != nil {
		return err
	}
	if err := cancelPendingRaidInvitations(ctx, token, raid.ID); err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	progress, err := getRaidProgress(ctx, token, raid.ID)
	if err != nil {
		return err
	}
	if progress.Status != "cleared" && progress.Status != "failed" && progress.Status != "canceled" {
		if _, err := patchRaidProgress(ctx, token, progress.ID, map[string]any{
			"status":   "canceled",
			"ended_at": now,
		}); err != nil {
			return err
		}
	}
	if _, err := patchRaid(ctx, token, raid.ID, map[string]any{
		"status":   "canceled",
		"end_time": now,
	}); err != nil {
		return err
	}
	return nil
}

func pruneDuplicateRaidInvitations(ctx context.Context, token string, items []map[string]any) ([]map[string]any, error) {
	seen := map[string]bool{}
	pruned := make([]map[string]any, 0, len(items))
	for _, item := range items {
		key := raidInvitationDedupKey(item)
		if key == "" {
			pruned = append(pruned, item)
			continue
		}
		if seen[key] {
			if id := stringField(item, "id"); id != "" {
				if _, err := patchRaidInvitationStatus(ctx, token, id, "canceled"); err != nil {
					return nil, err
				}
			}
			continue
		}
		seen[key] = true
		pruned = append(pruned, item)
	}
	return pruned, nil
}

func raidInvitationDedupKey(item map[string]any) string {
	inviterCharacterID := stringField(item, "inviter_character")
	if inviterCharacterID == "" {
		return ""
	}
	monsterID := ""
	if expand, ok := item["expand"].(map[string]any); ok {
		if raid, ok := expand["raid"].(map[string]any); ok {
			monsterID = stringField(raid, "monster")
		}
	}
	if monsterID == "" {
		monsterID = stringField(item, "raid")
	}
	return inviterCharacterID + ":" + monsterID
}

func raidParticipantSummaries(ctx context.Context, token string, participants []raidParticipantRecord) ([]map[string]any, error) {
	summaries := make([]map[string]any, 0, len(participants))
	for _, participant := range participants {
		character, err := getBattleCharacterByID(ctx, token, participant.Character)
		if err != nil {
			return nil, err
		}
		user := map[string]any{}
		if strings.TrimSpace(character.User) != "" {
			if userRecord, err := getRaidParticipantUser(ctx, token, character.User); err == nil {
				user = userRecord
			}
		}
		stats, err := getRaidCharacterStats(ctx, token, participant.Character)
		if err != nil {
			return nil, err
		}
		summaries = append(summaries, map[string]any{
			"id":                        participant.ID,
			"raid":                      participant.Raid,
			"character":                 participant.Character,
			"contribution_damage":       participant.ContributionDamage,
			"contribution_distance_m":   participant.ContributionDistanceM,
			"contribution_attack_count": participant.ContributionAttackCount,
			"join_status":               participant.JoinStatus,
			"user":                      character.User,
			"user_name":                 stringField(user, "name"),
			"user_nickname":             stringField(user, "nickname"),
			"user_username":             stringField(user, "username"),
			"user_email":                stringField(user, "email"),
			"profile_image":             user["profile_image"],
			"character_name":            character.Name,
			"character_current_hp":      character.CurrentHP,
			"character_max_hp":          stats.HP,
		})
	}
	return summaries, nil
}

func getRaidParticipantUser(ctx context.Context, token string, userID string) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(usersCollection, userID)+"?expand=profile_emote", token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to get raid participant user")
	}
	var user map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, errors.New("failed to parse raid participant user response")
	}
	user["profile_image"] = buildProfileImage(user)
	return sanitizeProfileUser(user), nil
}

func hydrateRaidInvitationUsers(ctx context.Context, token string, items []map[string]any) ([]map[string]any, error) {
	userCache := map[string]map[string]any{}
	getUser := func(userID string) (map[string]any, error) {
		userID = strings.TrimSpace(userID)
		if userID == "" {
			return map[string]any{}, nil
		}
		if user, ok := userCache[userID]; ok {
			return user, nil
		}
		user, err := getRaidParticipantUser(ctx, token, userID)
		if err != nil {
			return nil, err
		}
		userCache[userID] = user
		return user, nil
	}

	for i, item := range items {
		expand, _ := item["expand"].(map[string]any)
		if expand == nil {
			expand = map[string]any{}
		}

		if invitedUserID := stringField(item, "invited_user"); invitedUserID != "" {
			user, err := getUser(invitedUserID)
			if err != nil {
				return nil, err
			}
			expand["invited_user"] = user
		}

		inviterCharacter, _ := expand["inviter_character"].(map[string]any)
		if inviterCharacter != nil {
			if inviterUserID := stringField(inviterCharacter, "user"); inviterUserID != "" {
				user, err := getUser(inviterUserID)
				if err != nil {
					return nil, err
				}
				characterExpand, _ := inviterCharacter["expand"].(map[string]any)
				if characterExpand == nil {
					characterExpand = map[string]any{}
				}
				characterExpand["user"] = user
				inviterCharacter["expand"] = characterExpand
				expand["inviter_character"] = inviterCharacter
				expand["inviter_character.user"] = user
			}
		}

		item["expand"] = expand
		items[i] = item
	}
	return items, nil
}

func raidLobbyPath(raidID string) string {
	return fmt.Sprintf("/api/raids/%s", raidID)
}

func getRaid(ctx context.Context, token string, raidID string) (raidRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(raidsCollection, raidID), token, nil)
	if err != nil {
		return raidRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return raidRecord{}, statusError{status: http.StatusNotFound, message: "raid not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return raidRecord{}, mapPocketBaseError(resp, "failed to get raid")
	}

	var raid raidRecord
	if err := json.NewDecoder(resp.Body).Decode(&raid); err != nil {
		return raidRecord{}, errors.New("failed to parse raid response")
	}
	return raid, nil
}

func patchRaid(ctx context.Context, token string, raidID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(raidsCollection, raidID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update raid")
	}

	var raid map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&raid); err != nil {
		return nil, errors.New("failed to parse raid update response")
	}
	return raid, nil
}

func getRaidMap(ctx context.Context, token string, raidID string) (map[string]any, error) {
	endpoint := pocketBaseRecordURL(raidsCollection, raidID) + "?expand=monster,host_character"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil, statusError{status: http.StatusNotFound, message: "raid not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to get raid")
	}

	var raid map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&raid); err != nil {
		return nil, errors.New("failed to parse raid response")
	}
	return raid, nil
}

func getMonsterMap(ctx context.Context, token string, monsterID string) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL("monsters", monsterID), token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil, statusError{status: http.StatusNotFound, message: "monster not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to get monster")
	}

	var monster map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&monster); err != nil {
		return nil, errors.New("failed to parse monster response")
	}
	return monster, nil
}

func ensureMonsterExists(ctx context.Context, token string, monsterID string) error {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL("monsters", monsterID), token, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return statusError{status: http.StatusNotFound, message: "monster not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return mapPocketBaseError(resp, "failed to get monster")
	}
	return nil
}

func ensureUserExists(ctx context.Context, token string, userID string) error {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(usersCollection, userID), token, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return statusError{status: http.StatusNotFound, message: "user not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return mapPocketBaseError(resp, "failed to get user")
	}
	return nil
}

func ensureRaidJoinable(ctx context.Context, token string, raid raidRecord, characterID string) error {
	if raid.Status != "waiting" && raid.Status != "in_progress" {
		return statusError{status: http.StatusBadRequest, message: "raid is not joinable"}
	}
	participants, err := listRaidParticipantRecords(ctx, token, raid.ID)
	if err != nil {
		return err
	}
	for _, participant := range participants.Items {
		if participant.Character == characterID && participant.JoinStatus != "left" && participant.JoinStatus != "kicked" {
			return statusError{status: http.StatusConflict, message: "character already joined raid"}
		}
	}
	activeCount := 0
	for _, participant := range participants.Items {
		if participant.JoinStatus != "left" && participant.JoinStatus != "kicked" {
			activeCount++
		}
	}
	maxParticipants := int(raid.MaxParticipants)
	if maxParticipants <= 0 {
		maxParticipants = 4
	}
	if activeCount >= maxParticipants {
		return statusError{status: http.StatusBadRequest, message: "raid is full"}
	}
	return nil
}

func ensureRaidEntryLevel(character battleCharacterRecord) error {
	if character.Level >= minRaidEntryLevel {
		return nil
	}
	return statusError{
		status:  http.StatusForbidden,
		message: fmt.Sprintf("raid requires level %d", minRaidEntryLevel),
	}
}

func raidWeekStartDate(now time.Time) string {
	local := now.In(raidWeeklyLocation)
	daysSinceMonday := (int(local.Weekday()) + 6) % 7
	start := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, raidWeeklyLocation).
		AddDate(0, 0, -daysSinceMonday)
	return start.Format("2006-01-02")
}

func ensureRaidWeeklyClearAvailable(
	ctx context.Context,
	token string,
	userID string,
	monsterID string,
	now time.Time,
) error {
	cleared, err := hasRaidWeeklyClear(ctx, token, userID, monsterID, now)
	if err != nil {
		return err
	}
	if cleared {
		return statusError{status: http.StatusConflict, message: "raid weekly clear already used"}
	}
	return nil
}

func ensureRaidWeeklyClearAvailableForParticipants(
	ctx context.Context,
	token string,
	monsterID string,
	participants []raidParticipantRecord,
	now time.Time,
) error {
	for _, participant := range participants {
		character, err := getBattleCharacterByID(ctx, token, participant.Character)
		if err != nil {
			return err
		}
		if err := ensureRaidWeeklyClearAvailable(ctx, token, character.User, monsterID, now); err != nil {
			return err
		}
	}
	return nil
}

func hasRaidWeeklyClear(ctx context.Context, token string, userID string, monsterID string, now time.Time) (bool, error) {
	if strings.TrimSpace(userID) == "" || strings.TrimSpace(monsterID) == "" {
		return false, nil
	}
	filter := fmt.Sprintf(
		"user=%q && monster=%q && week_start=%q",
		userID,
		monsterID,
		raidWeekStartDate(now),
	)
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(raidWeeklyClearsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, mapPocketBaseError(resp, "failed to check raid weekly clear")
	}

	var list pocketBaseListResponse[raidWeeklyClearRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return false, errors.New("failed to parse raid weekly clear response")
	}
	return len(list.Items) > 0, nil
}

func createRaidWeeklyClearsForParticipants(
	ctx context.Context,
	token string,
	raid raidRecord,
	participants []raidParticipantRecord,
	clearedAt time.Time,
) error {
	for _, participant := range participants {
		if participant.JoinStatus != "joined" {
			continue
		}
		character, err := getBattleCharacterByID(ctx, token, participant.Character)
		if err != nil {
			return err
		}
		if err := createRaidWeeklyClear(ctx, token, character.User, character.ID, raid.ID, raid.Monster, clearedAt); err != nil {
			return err
		}
	}
	return nil
}

func createRaidWeeklyClear(
	ctx context.Context,
	token string,
	userID string,
	characterID string,
	raidID string,
	monsterID string,
	clearedAt time.Time,
) error {
	if strings.TrimSpace(userID) == "" || strings.TrimSpace(characterID) == "" || strings.TrimSpace(monsterID) == "" {
		return nil
	}
	cleared, err := hasRaidWeeklyClear(ctx, token, userID, monsterID, clearedAt)
	if err != nil {
		return err
	}
	if cleared {
		return nil
	}

	payload := map[string]any{
		"user":       userID,
		"character":  characterID,
		"raid":       raidID,
		"monster":    monsterID,
		"week_start": raidWeekStartDate(clearedAt),
		"cleared_at": clearedAt.UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(raidWeeklyClearsCollection), token, payload)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create raid weekly clear")
	}
	return nil
}

func listRaidParticipantRecords(ctx context.Context, token string, raidID string) (pocketBaseListResponse[raidParticipantRecord], error) {
	filter := fmt.Sprintf("raid=%q", raidID)
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "100")
	query.Set("sort", "joined_at,created")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(raidParticipantsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return pocketBaseListResponse[raidParticipantRecord]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[raidParticipantRecord]{}, mapPocketBaseError(resp, "failed to list raid participants")
	}

	var list pocketBaseListResponse[raidParticipantRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[raidParticipantRecord]{}, errors.New("failed to parse raid participants response")
	}
	return list, nil
}

func listActiveRaidParticipantRecords(ctx context.Context, token string, raidID string) (pocketBaseListResponse[raidParticipantRecord], error) {
	filter := fmt.Sprintf("raid=%q && join_status=%q", raidID, "joined")
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "100")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(raidParticipantsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return pocketBaseListResponse[raidParticipantRecord]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[raidParticipantRecord]{}, mapPocketBaseError(resp, "failed to list active raid participants")
	}

	var list pocketBaseListResponse[raidParticipantRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[raidParticipantRecord]{}, errors.New("failed to parse active raid participants response")
	}
	return list, nil
}

func getJoinedRaidParticipant(ctx context.Context, token string, raidID string, characterID string) (raidParticipantRecord, error) {
	filter := fmt.Sprintf("raid=%q && character=%q && join_status=%q", raidID, characterID, "joined")
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(raidParticipantsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return raidParticipantRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return raidParticipantRecord{}, mapPocketBaseError(resp, "failed to get raid participant")
	}

	var list pocketBaseListResponse[raidParticipantRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return raidParticipantRecord{}, errors.New("failed to parse raid participant response")
	}
	if len(list.Items) == 0 {
		return raidParticipantRecord{}, statusError{status: http.StatusForbidden, message: "character is not participating in raid"}
	}
	return list.Items[0], nil
}

func createRaidParticipant(ctx context.Context, token string, raidID string, characterID string) (map[string]any, error) {
	payload := map[string]any{
		"raid":                      raidID,
		"character":                 characterID,
		"contribution_damage":       0,
		"contribution_distance_m":   0,
		"contribution_attack_count": 0,
		"join_status":               "joined",
		"joined_at":                 time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(raidParticipantsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create raid participant")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse raid participant response")
	}
	return record, nil
}

func patchRaidParticipant(ctx context.Context, token string, participantID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(raidParticipantsCollection, participantID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update raid participant")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse raid participant update response")
	}
	return record, nil
}

func createRaidProgress(ctx context.Context, token string, raidID string, monsterHP int) (map[string]any, error) {
	payload := map[string]any{
		"raid":                                 raidID,
		"monster_current_hp":                   monsterHP,
		"total_distance_accumulated_m":         0,
		"distance_since_last_attack_cycle_m":   0,
		"distance_since_last_monster_attack_m": 0,
		"total_attack_cycles":                  0,
		"total_monster_attack_cycles":          0,
		"status":                               "waiting",
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(raidProgressCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create raid progress")
	}

	var progress map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&progress); err != nil {
		return nil, errors.New("failed to parse raid progress response")
	}
	return progress, nil
}

func getRaidProgress(ctx context.Context, token string, raidID string) (raidProgressRecord, error) {
	filter := fmt.Sprintf("raid=%q", raidID)
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(raidProgressCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return raidProgressRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return raidProgressRecord{}, mapPocketBaseError(resp, "failed to get raid progress")
	}

	var list pocketBaseListResponse[raidProgressRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return raidProgressRecord{}, errors.New("failed to parse raid progress response")
	}
	if len(list.Items) == 0 {
		return raidProgressRecord{}, statusError{status: http.StatusNotFound, message: "raid progress not found"}
	}
	return list.Items[0], nil
}

func patchRaidProgress(ctx context.Context, token string, progressID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(raidProgressCollection, progressID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update raid progress")
	}

	var progress map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&progress); err != nil {
		return nil, errors.New("failed to parse raid progress update response")
	}
	return progress, nil
}

func getRaidInvitation(ctx context.Context, token string, invitationID string) (raidInvitationRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(raidInvitationsCollection, invitationID), token, nil)
	if err != nil {
		return raidInvitationRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return raidInvitationRecord{}, statusError{status: http.StatusNotFound, message: "raid invitation not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return raidInvitationRecord{}, mapPocketBaseError(resp, "failed to get raid invitation")
	}

	var invitation raidInvitationRecord
	if err := json.NewDecoder(resp.Body).Decode(&invitation); err != nil {
		return raidInvitationRecord{}, errors.New("failed to parse raid invitation response")
	}
	return invitation, nil
}

func patchRaidInvitationStatus(ctx context.Context, token string, invitationID string, status string) (map[string]any, error) {
	payload := map[string]any{
		"status":       status,
		"responded_at": time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(raidInvitationsCollection, invitationID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update raid invitation")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse raid invitation update response")
	}
	return record, nil
}

func ensureAcceptedFriend(ctx context.Context, token string, userA string, userB string) error {
	low, high := orderedUserPair(userA, userB)
	filter := fmt.Sprintf("user_low=%q && user_high=%q && status=%q", low, high, "accepted")
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(friendshipsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return mapPocketBaseError(resp, "failed to check friendship")
	}

	var list pocketBaseListResponse[friendshipRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return errors.New("failed to parse friendship response")
	}
	if len(list.Items) == 0 {
		return statusError{status: http.StatusForbidden, message: "invited user is not an accepted friend"}
	}
	return nil
}

func orderedUserPair(userA string, userB string) (string, string) {
	users := []string{userA, userB}
	sort.Strings(users)
	return users[0], users[1]
}

func hasPendingRaidInvitation(ctx context.Context, token string, raidID string, userID string) (bool, error) {
	filter := fmt.Sprintf("raid=%q && invited_user=%q && status=%q", raidID, userID, "pending")
	return hasRecord(ctx, token, raidInvitationsCollection, filter)
}

func isUserAlreadyInRaid(ctx context.Context, token string, raidID string, userID string) (bool, error) {
	filter := fmt.Sprintf("raid=%q && character.user=%q && join_status!=%q && join_status!=%q", raidID, userID, "left", "kicked")
	return hasRecord(ctx, token, raidParticipantsCollection, filter)
}

func hasRecord(ctx context.Context, token string, collection string, filter string) (bool, error) {
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(collection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, mapPocketBaseError(resp, "failed to check "+collection)
	}

	var list pocketBaseListResponse[map[string]any]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return false, errors.New("failed to parse " + collection + " response")
	}
	return len(list.Items) > 0, nil
}

func raidMonsterInitialHP(monster monsterRecord) int {
	if monster.HP > 0 {
		return monster.HP
	}
	// TODO: Remove this fallback after every raid monster has hp configured in PocketBase.
	return defaultRaidMonsterHP
}

func raidMonsterScaledHP(monster monsterRecord, participantCount int) int {
	baseHP := raidMonsterInitialHP(monster)
	if participantCount <= 1 {
		return int(math.Round(float64(baseHP) * raidParticipantHPMultipliers[1]))
	}
	if participantCount >= 4 {
		return baseHP
	}
	multiplier, ok := raidParticipantHPMultipliers[participantCount]
	if !ok {
		return baseHP
	}
	return int(math.Round(float64(baseHP) * multiplier))
}

func isRaidMonsterComingSoon(monster monsterRecord) bool {
	return strings.Contains(strings.TrimSpace(monster.Name), "와이번")
}

func calculateRaidCycleDamage(
	ctx context.Context,
	token string,
	attackCycles int,
	participants []raidParticipantRecord,
	monster monsterRecord,
) (int, int, map[string]int, map[string]int, error) {
	participantDamages := make(map[string]int, len(participants))
	participantAttackCounts := make(map[string]int, len(participants))
	if attackCycles <= 0 || len(participants) == 0 {
		return 0, 0, participantDamages, participantAttackCounts, nil
	}
	totalDamage := 0
	activeAttackers := 0
	for _, participant := range participants {
		character, err := getBattleCharacterByID(ctx, token, participant.Character)
		if err != nil {
			return 0, 0, nil, nil, err
		}
		if character.CurrentHP <= 0 {
			participantDamages[participant.ID] = 0
			continue
		}
		activeAttackers++
		statContext, err := getRaidCharacterStatContext(ctx, token, participant.Character)
		if err != nil {
			return 0, 0, nil, nil, err
		}
		monsterDefense := adjustedMonsterDefense(monster.Defense, statContext.Effects)
		damage := 0
		for range attackCycles {
			baseDamage := formulas.CalculateRandomDamage(statContext.Stats.Attack, monsterDefense)
			damage += adjustedPlayerDamage(baseDamage, "boss", statContext.Effects)
		}
		participantDamages[participant.ID] = damage
		participantAttackCounts[participant.ID] = attackCycles
		totalDamage += damage
	}
	return totalDamage, attackCycles * activeAttackers, participantDamages, participantAttackCounts, nil
}

func raidParticipantCycleDamage(attack int, monsterDefense int, attackCycles int) int {
	if attackCycles <= 0 {
		return 0
	}
	return formulas.CalculateDamage(attack, monsterDefense) * attackCycles
}

func raidPartyCycleDamage(participantAttacks []int, monsterDefense int, attackCycles int) int {
	totalDamage := 0
	for _, attack := range participantAttacks {
		totalDamage += raidParticipantCycleDamage(attack, monsterDefense, attackCycles)
	}
	return totalDamage
}

func applyRaidMonsterAreaAttack(
	ctx context.Context,
	token string,
	monster monsterRecord,
	participants []raidParticipantRecord,
	monsterAttackCycles int,
) (int, []string, error) {
	defeatedParticipants := []string{}
	if monsterAttackCycles <= 0 {
		return 0, defeatedParticipants, nil
	}

	totalDamage := 0
	for _, participant := range participants {
		character, err := getBattleCharacterByID(ctx, token, participant.Character)
		if err != nil {
			return 0, nil, err
		}
		if character.CurrentHP <= 0 {
			defeatedParticipants = append(defeatedParticipants, participant.Character)
			continue
		}
		statContext, err := getRaidCharacterStatContext(ctx, token, participant.Character)
		if err != nil {
			return 0, nil, err
		}
		damage := 0
		for range monsterAttackCycles {
			baseDamage := formulas.CalculateRandomDamage(monster.Attack, statContext.Stats.Defense)
			damage += adjustedMonsterDamage(baseDamage, statContext.Effects)
		}
		nextHP := character.CurrentHP - damage
		if nextHP < 0 {
			nextHP = 0
		}
		totalDamage += damage
		if _, err := patchBattleCharacter(ctx, token, participant.Character, map[string]any{
			"current_hp": nextHP,
		}); err != nil {
			return 0, nil, err
		}
		if nextHP <= 0 {
			defeatedParticipants = append(defeatedParticipants, participant.Character)
		}
	}
	return totalDamage, defeatedParticipants, nil
}

func restoreRaidParticipantsHP(ctx context.Context, token string, participants []raidParticipantRecord) error {
	for _, participant := range participants {
		statContext, err := getRaidCharacterStatContext(ctx, token, participant.Character)
		if err != nil {
			return err
		}
		if statContext.Stats.HP <= 0 {
			continue
		}
		if _, err := patchBattleCharacter(ctx, token, participant.Character, map[string]any{
			"current_hp": statContext.Stats.HP,
		}); err != nil {
			return err
		}
	}
	return nil
}

func getRaidCharacterStats(ctx context.Context, token string, characterID string) (statBlock, error) {
	statContext, err := getRaidCharacterStatContext(ctx, token, characterID)
	if err != nil {
		return statBlock{}, err
	}
	return statContext.Stats, nil
}

func getRaidCharacterStatContext(ctx context.Context, token string, characterID string) (battleStatContext, error) {
	stats, err := getBattleCharacterStats(ctx, token, characterID)
	if err != nil {
		return battleStatContext{}, err
	}
	return getBattleStatContext(ctx, token, characterID, stats)
}

func calculateRaidTeamAgility(ctx context.Context, token string, participants []raidParticipantRecord) (int, error) {
	totalAgility := 0
	for _, participant := range participants {
		stats, err := getRaidCharacterStats(ctx, token, participant.Character)
		if err != nil {
			return 0, err
		}
		totalAgility += stats.Agility
	}
	return totalAgility, nil
}

func calculateRaidAttackDistance(teamAgility int) float64 {
	return formulas.CalculateDistanceWithAgility(baseRaidAttackDistanceM, teamAgility)
}

func raidMonsterAttackCyclesDue(startedAt string, now time.Time, completedCycles int) int {
	startedTime, err := parseRaidTimestamp(startedAt)
	if err != nil || !now.After(startedTime) {
		return 0
	}
	totalDue := int(now.Sub(startedTime) / raidMonsterAttackInterval)
	remaining := totalDue - completedCycles
	if remaining < 0 {
		return 0
	}
	return remaining
}

func parseRaidTimestamp(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	var lastErr error
	for _, layout := range []string{
		time.RFC3339Nano,
		"2006-01-02 15:04:05.999999999Z07:00",
		"2006-01-02 15:04:05Z07:00",
	} {
		parsed, err := time.Parse(layout, value)
		if err == nil {
			return parsed, nil
		}
		lastErr = err
	}
	return time.Time{}, lastErr
}

func calculateRaidAttackGaugePercent(ctx context.Context, token string, participants []raidParticipantRecord) (float64, error) {
	if len(participants) == 0 {
		return 0, nil
	}
	totalPercent := 0.0
	for _, participant := range participants {
		statContext, err := getRaidCharacterStatContext(ctx, token, participant.Character)
		if err != nil {
			return 0, err
		}
		totalPercent += statContext.Effects.AttackDistancePercent
	}
	return totalPercent / float64(len(participants)), nil
}

func lockRaid(raidID string) func() {
	lockValue, _ := raidLocks.LoadOrStore(raidID, &sync.Mutex{})
	lock := lockValue.(*sync.Mutex)
	lock.Lock()
	return lock.Unlock
}

func applyRaidDamage(currentHP float64, damage int) float64 {
	nextHP := currentHP - float64(damage)
	if nextHP < 0 {
		return 0
	}
	return nextHP
}

func firstNonEmpty(value string, fallback string) string {
	if strings.TrimSpace(value) != "" {
		return value
	}
	return fallback
}
