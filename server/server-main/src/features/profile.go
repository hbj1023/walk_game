package features

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
)

const (
	profileEmotesCollection = "profile_emotes"
	maxProfileImageBytes    = 5 << 20
)

func profileEmotesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "profile emotes fetch failed", "error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/profile-emotes" {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "profile emotes fetch failed", "error": "not found"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "profile emotes fetch failed", "error": "unauthorized"})
		return
	}

	emotes, err := listProfileEmotes(r.Context(), token)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "profile emotes fetch failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "profile emotes fetched", emotes)
}

func userProfileHandler(w http.ResponseWriter, r *http.Request) {
	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "profile update failed", "error": "unauthorized"})
		return
	}

	switch {
	case r.Method == http.MethodPost && r.URL.Path == "/api/users/profile-emote":
		handleProfileEmoteSelect(w, r, token, user.ID)
	case r.Method == http.MethodPost && r.URL.Path == "/api/users/profile-image":
		handleProfileImageUpload(w, r, token, user.ID)
	case r.Method == http.MethodGet && r.URL.Path == "/api/users/profile":
		profile, err := getUserProfile(r.Context(), token, user.ID)
		if err != nil {
			writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "profile fetch failed", "error": err.Error()})
			return
		}
		writeInventoryResponse(w, http.StatusOK, "profile fetched", profile)
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "profile update failed", "error": "not found"})
	}
}

func handleProfileEmoteSelect(w http.ResponseWriter, r *http.Request, token string, userID string) {
	var req profileEmoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "profile emote update failed", "error": "invalid request body"})
		return
	}
	req.ProfileEmoteID = strings.TrimSpace(req.ProfileEmoteID)
	if req.ProfileEmoteID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "profile emote update failed", "error": "profileEmoteId is required"})
		return
	}

	if err := ensureProfileEmoteActive(r.Context(), token, req.ProfileEmoteID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "profile emote update failed", "error": err.Error()})
		return
	}

	profile, err := patchUserProfile(r.Context(), token, userID, map[string]any{
		"profile_emote":        req.ProfileEmoteID,
		"profile_image_source": "emote",
		"profile_image_url":    "",
	})
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "profile emote update failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "profile emote updated", profile)
}

func handleProfileImageUpload(w http.ResponseWriter, r *http.Request, token string, userID string) {
	if err := r.ParseMultipartForm(maxProfileImageBytes); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "profile image update failed", "error": "invalid multipart form"})
		return
	}

	file, header, err := r.FormFile("image")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "profile image update failed", "error": "image file is required"})
		return
	}
	defer file.Close()

	if header.Size > maxProfileImageBytes {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "profile image update failed", "error": "image file is too large"})
		return
	}
	if !isAllowedProfileImage(header) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "profile image update failed", "error": "image must be png, jpg, jpeg, or webp"})
		return
	}

	profile, err := uploadUserProfileImage(r.Context(), token, userID, file, header)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"message": "profile image update failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "profile image updated", profile)
}

func listProfileEmotes(ctx context.Context, token string) (pocketBaseListResponse[map[string]any], error) {
	return listCollectionRecords(ctx, token, profileEmotesCollection, "is_active=true", "", "sort_order,name")
}

func ensureProfileEmoteActive(ctx context.Context, token string, profileEmoteID string) error {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(profileEmotesCollection, profileEmoteID), token, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return statusError{status: http.StatusNotFound, message: "profile emote not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return mapPocketBaseError(resp, "failed to get profile emote")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return errors.New("failed to parse profile emote response")
	}
	if active, ok := record["is_active"].(bool); !ok || !active {
		return statusError{status: http.StatusBadRequest, message: "profile emote is not active"}
	}
	return nil
}

func patchUserProfile(ctx context.Context, token string, userID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(usersCollection, userID)+"?expand=profile_emote", token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update profile")
	}
	return decodeProfileUser(resp.Body)
}

func getUserProfile(ctx context.Context, token string, userID string) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(usersCollection, userID)+"?expand=profile_emote", token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to get profile")
	}
	return decodeProfileUser(resp.Body)
}

func uploadUserProfileImage(ctx context.Context, token string, userID string, file multipart.File, header *multipart.FileHeader) (map[string]any, error) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	part, err := writer.CreateFormFile("avatar", sanitizeProfileImageFilename(header.Filename))
	if err != nil {
		return nil, err
	}
	if _, err := io.Copy(part, file); err != nil {
		return nil, err
	}
	if err := writer.WriteField("profile_emote", ""); err != nil {
		return nil, err
	}
	if err := writer.WriteField("profile_image_url", ""); err != nil {
		return nil, err
	}
	if err := writer.WriteField("profile_image_source", "custom"); err != nil {
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, pocketBaseRecordURL(usersCollection, userID)+"?expand=profile_emote", &body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := pocketBaseHTTPClient.Do(req)
	if err != nil {
		return nil, statusError{status: http.StatusInternalServerError, message: fmt.Sprintf("PocketBase request failed: %v", err)}
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to upload profile image")
	}
	return decodeProfileUser(resp.Body)
}

func decodeProfileUser(body io.Reader) (map[string]any, error) {
	var record map[string]any
	if err := json.NewDecoder(body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse profile response")
	}
	record["profile_image"] = buildProfileImage(record)
	return sanitizeProfileUser(record), nil
}

func sanitizeProfileUser(record map[string]any) map[string]any {
	return map[string]any{
		"id":                   stringField(record, "id"),
		"email":                stringField(record, "email"),
		"name":                 stringField(record, "name"),
		"nickname":             stringField(record, "nickname"),
		"username":             stringField(record, "username"),
		"avatar":               stringField(record, "avatar"),
		"profile_image_source": stringField(record, "profile_image_source"),
		"profile_image_url":    stringField(record, "profile_image_url"),
		"profile_emote":        record["profile_emote"],
		"profile_image":        record["profile_image"],
		"expand":               record["expand"],
	}
}

func buildProfileImage(record map[string]any) map[string]any {
	source := stringField(record, "profile_image_source")
	if source == "emote" {
		if image := profileEmoteImage(record); image != nil {
			return image
		}
	}

	userID := stringField(record, "id")
	avatar := stringField(record, "avatar")
	if source == "custom" && userID != "" && avatar != "" {
		return map[string]any{
			"source": "custom",
			"url":    pocketBaseFileURL(usersCollection, userID, avatar),
			"avatar": avatar,
		}
	}
	if userID != "" && avatar != "" {
		return map[string]any{
			"source": "custom",
			"url":    pocketBaseFileURL(usersCollection, userID, avatar),
			"avatar": avatar,
		}
	}
	if image := profileEmoteImage(record); image != nil {
		return image
	}

	if url := stringField(record, "profile_image_url"); url != "" {
		return map[string]any{
			"source": "url",
			"url":    url,
		}
	}
	return map[string]any{"source": "none"}
}

func profileEmoteImage(record map[string]any) map[string]any {
	if expand, ok := record["expand"].(map[string]any); ok {
		if emote, ok := expand["profile_emote"].(map[string]any); ok && stringField(emote, "id") != "" {
			return map[string]any{
				"source":    "emote",
				"id":        stringField(emote, "id"),
				"name":      stringField(emote, "name"),
				"asset_key": stringField(emote, "asset_key"),
				"image_url": stringField(emote, "image_url"),
			}
		}
	}
	return nil
}

func pocketBaseFileURL(collection string, recordID string, filename string) string {
	escapedFile := url.PathEscape(filename)
	return fmt.Sprintf("%s/api/files/%s/%s/%s", pocketBaseURL(), collection, recordID, escapedFile)
}

func isAllowedProfileImage(header *multipart.FileHeader) bool {
	contentType := strings.ToLower(strings.TrimSpace(header.Header.Get("Content-Type")))
	switch contentType {
	case "image/png", "image/jpeg", "image/jpg", "image/webp":
		return true
	}

	ext := strings.ToLower(filepath.Ext(header.Filename))
	return ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".webp"
}

func sanitizeProfileImageFilename(filename string) string {
	filename = filepath.Base(strings.TrimSpace(filename))
	if filename == "" || filename == "." {
		return "profile.png"
	}
	return filename
}
