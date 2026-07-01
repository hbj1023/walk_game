package features

import (
	"encoding/json"
	"net/http"
	"strings"
)

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" || req.Password == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "email and password are required"})
		return
	}

	auth, err := loginPocketBaseUser(r.Context(), req)
	if err != nil {
		status := statusCodeForError(err, http.StatusUnauthorized)
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	gameCharacter, characterCreated, err := ensureDefaultCharacter(r.Context(), auth.Token, auth.Record)
	if err != nil {
		status := statusCodeForError(err, http.StatusInternalServerError)
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"message":              "로그인 성공",
		"token":                auth.Token,
		"user_id":              auth.Record.ID,
		"email":                auth.Record.Email,
		"name":                 auth.Record.Name,
		"character_id":         gameCharacter.ID,
		"character_created":    characterCreated,
		"character_exists":     true,
		"level":                gameCharacter.Level,
		"exp":                  gameCharacter.Exp,
		"stat_exp":             gameCharacter.StatExp,
		"coin_balance":         gameCharacter.CoinBalance,
		"attack_count_balance": gameCharacter.AttackCountBalance,
	})
}
