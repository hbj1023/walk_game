package features

import (
	"encoding/json"
	"net/http"
	"strings"
)

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Name = strings.TrimSpace(req.Name)
	if req.Email == "" || req.Password == "" || req.Name == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "email, password and name are required"})
		return
	}

	userCreated := true
	if err := registerPocketBaseUser(r.Context(), req); err != nil {
		if !isAlreadyRegisteredError(err) {
			status := statusCodeForError(err, http.StatusBadRequest)
			writeJSON(w, status, map[string]string{"error": err.Error()})
			return
		}
		userCreated = false
	}

	auth, err := loginPocketBaseUser(r.Context(), LoginRequest{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		status := statusCodeForError(err, http.StatusUnauthorized)
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	gameCharacter, created, err := ensureDefaultCharacter(r.Context(), auth.Token, auth.Record)
	if err != nil {
		status := statusCodeForError(err, http.StatusInternalServerError)
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	status := http.StatusCreated
	message := "회원가입 완료"
	if !userCreated {
		status = http.StatusOK
		message = "이미 가입된 계정입니다. 캐릭터 정보를 확인했습니다."
	}

	writeJSON(w, status, map[string]any{
		"message":              message,
		"token":                auth.Token,
		"user_id":              auth.Record.ID,
		"email":                auth.Record.Email,
		"name":                 auth.Record.Name,
		"user_created":         userCreated,
		"character_id":         gameCharacter.ID,
		"character_created":    created,
		"character_exists":     true,
		"level":                gameCharacter.Level,
		"exp":                  gameCharacter.Exp,
		"stat_exp":             gameCharacter.StatExp,
		"coin_balance":         gameCharacter.CoinBalance,
		"attack_count_balance": gameCharacter.AttackCountBalance,
	})
}

func isAlreadyRegisteredError(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), "이미 가입된 이메일")
}
