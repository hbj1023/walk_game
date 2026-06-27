package features

import (
	"encoding/json"
	"net/http"
	"strconv"

	"server/src/utils/formulas"
)

func normalBattleStartHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req NormalBattleStartRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := startNormalBattle(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func normalBattleAttackHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req NormalBattleAttackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := attackNormalBattle(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func normalBattleLeaveHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req NormalBattleLeaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := leaveNormalBattle(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func bossBattleStartHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req NormalBattleStartRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := startBossBattle(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func bossBattleAttackHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req NormalBattleAttackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := attackBossBattle(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func bossBattleLeaveHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req NormalBattleLeaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := leaveBossBattle(r.Context(), token, user.ID, req)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func normalBattleCurrentHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	character, err := getCharacterByProfileID(r, token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	battle, found, err := findCurrentNormalBattle(r.Context(), token, character.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	battleCharacter, err := getBattleCharacterByID(r.Context(), token, character.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	if !found {
		stats, err := getBattleCharacterStats(r.Context(), token, character.ID)
		if err != nil {
			writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
			return
		}
		characterMaxHP, err := getBattleCharacterMaxHP(r.Context(), token, character.ID, stats)
		if err != nil {
			writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
			return
		}
		if _, err := recoverBattleCharacterHP(r.Context(), token, battleCharacter, characterMaxHP); err != nil {
			writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"battle":               nil,
			"character":            battleCharacter,
			"character_max_hp":     characterMaxHP,
			"attack_count_balance": battleCharacter.AttackCountBalance,
		})
		return
	}
	stats, err := getBattleCharacterStats(r.Context(), token, character.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	characterMaxHP, err := getBattleCharacterMaxHP(r.Context(), token, character.ID, stats)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	battleCharacter, err = recoverBattleCharacterHP(r.Context(), token, battleCharacter, battle.CharacterCurrentHP)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	if battle.MonsterCurrentHP <= 0 || battle.CharacterCurrentHP <= 0 {
		if err := finishBrokenNormalBattle(r.Context(), token, battle); err != nil {
			writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"battle":               nil,
			"character":            battleCharacter,
			"character_max_hp":     characterMaxHP,
			"attack_count_balance": battleCharacter.AttackCountBalance,
		})
		return
	}
	monster, err := getMonsterByID(r.Context(), token, battle.Monster)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, NormalBattleResponse{
		Battle:                 battle,
		Character:              battleCharacter,
		CharacterMaxHP:         characterMaxHP,
		Monster:                monster,
		AttackCountBalance:     battleCharacter.AttackCountBalance,
		MonsterAttackGaugeM:    round2(battle.MonsterAttackGaugeM),
		MonsterAttackDistanceM: round2(formulas.CalculateMonsterAttackDistance()),
	})
}

func normalBattleHistoryHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	page := queryInt(r, "page", 1)
	perPage := queryInt(r, "per_page", 20)
	if perPage > 100 {
		perPage = 100
	}

	character, err := getCharacterByProfileID(r, token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	history, err := listNormalBattleHistory(r.Context(), token, character.ID, page, perPage)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, history)
}

func queryInt(r *http.Request, name string, fallback int) int {
	value := r.URL.Query().Get(name)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}
