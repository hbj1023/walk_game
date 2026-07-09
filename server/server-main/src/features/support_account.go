package features

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
)

const supportReportsCollection = "support_reports"

type supportBugReportRequest struct {
	Screen  string `json:"screen"`
	Message string `json:"message"`
}

type accountDeleteRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func supportBugReportHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "bug report failed", "error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/support/bug-reports" {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "bug report failed", "error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "bug report failed", "error": "unauthorized"})
		return
	}

	var req supportBugReportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "bug report failed", "error": "invalid request body"})
		return
	}

	screen := strings.TrimSpace(req.Screen)
	message := strings.TrimSpace(req.Message)
	if message == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "bug report failed", "error": "message is required"})
		return
	}
	if len([]rune(screen)) > 80 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "bug report failed", "error": "screen is too long"})
		return
	}
	if len([]rune(message)) > 1000 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "bug report failed", "error": "message is too long"})
		return
	}

	report, err := createSupportBugReport(r.Context(), token, user, screen, message)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "bug report failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusCreated, "bug report submitted", report)
}

func accountDeleteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "account delete failed", "error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/users/delete-account" {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "account delete failed", "error": "not found"})
		return
	}

	user, _, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "account delete failed", "error": "unauthorized"})
		return
	}

	var req accountDeleteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "account delete failed", "error": "invalid request body"})
		return
	}

	confirmedEmail := strings.TrimSpace(strings.ToLower(req.Email))
	currentEmail := strings.TrimSpace(strings.ToLower(user.Email))
	if confirmedEmail != "" && confirmedEmail != currentEmail {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "account delete failed", "error": "email confirmation does not match current account"})
		return
	}
	if strings.TrimSpace(req.Password) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "account delete failed", "error": "password is required"})
		return
	}

	auth, err := loginPocketBaseUser(r.Context(), LoginRequest{
		Email:    user.Email,
		Password: req.Password,
	})
	if err != nil || auth.Record.ID != user.ID {
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "account delete failed", "error": "invalid password"})
		return
	}

	if err := deletePocketBaseUser(r.Context(), auth.Token, user.ID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "account delete failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "account deleted", map[string]any{"deleted": true})
}

func createSupportBugReport(ctx context.Context, token string, user pocketBaseUser, screen string, message string) (map[string]any, error) {
	payload := map[string]any{
		"user":    user.ID,
		"email":   user.Email,
		"screen":  screen,
		"message": message,
		"status":  "open",
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(supportReportsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create bug report")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, statusError{status: http.StatusInternalServerError, message: "failed to parse bug report response"}
	}
	return record, nil
}

func deletePocketBaseUser(ctx context.Context, token string, userID string) error {
	resp, err := pocketBaseRequest(ctx, http.MethodDelete, pocketBaseRecordURL(usersCollection, userID), token, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusNoContent {
		return nil
	}
	return mapPocketBaseError(resp, "failed to delete account")
}
