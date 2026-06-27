package features

import (
	"encoding/json"
	"fmt"
	"net/http"
)

func mainHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	gameCharacter, characterCreated, err := ensureDefaultCharacter(r.Context(), token, user)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusInternalServerError), map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"message":              fmt.Sprintf("환영합니다, %s 님", user.Email),
		"token":                token,
		"user_id":              user.ID,
		"email":                user.Email,
		"name":                 user.Name,
		"character_id":         gameCharacter.ID,
		"character_created":    characterCreated,
		"character_exists":     true,
		"coin_balance":         gameCharacter.CoinBalance,
		"attack_count_balance": gameCharacter.AttackCountBalance,
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
