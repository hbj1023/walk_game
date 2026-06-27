package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const notificationsCollection = "notifications"

func notificationsHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/notifications" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	unreadOnly := parseBoolQuery(r.URL.Query().Get("unreadOnly"))
	page := boundedIntQuery(r.URL.Query().Get("page"), 1, 1, 1000)
	perPage := boundedIntQuery(r.URL.Query().Get("perPage"), 50, 1, 100)
	notifications, err := listUserNotifications(r.Context(), token, user.ID, unreadOnly, page, perPage)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "notifications fetched", notifications)
}

func notificationUnreadCountHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/notifications/unread-count" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	count, err := countUnreadNotifications(r.Context(), token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "unread notifications counted", map[string]any{"unread_count": count})
}

func notificationReadAllHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/notifications/read-all" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	count, err := markAllNotificationsRead(r.Context(), token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "notifications marked read", map[string]any{"updated_count": count})
}

func notificationActionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	notificationID, action, ok := parseNotificationActionPath(r.URL.Path)
	if !ok || action != "read" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	notification, err := markNotificationRead(r.Context(), token, user.ID, notificationID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "notification marked read", notification)
}

func createNotificationBestEffort(ctx context.Context, token string, input notificationCreateInput) {
	if _, err := createNotification(ctx, token, input); err != nil {
		log.Printf("notification create failed: user=%q type=%q source=%q/%q error=%v", input.UserID, input.Type, input.SourceType, input.SourceID, err)
	}
}

func createNotification(ctx context.Context, token string, input notificationCreateInput) (map[string]any, error) {
	input.UserID = strings.TrimSpace(input.UserID)
	input.Type = strings.TrimSpace(input.Type)
	input.Title = strings.TrimSpace(input.Title)
	if input.UserID == "" || input.Type == "" || input.Title == "" {
		return nil, errors.New("notification user, type, and title are required")
	}
	payload := map[string]any{
		"user":        input.UserID,
		"type":        input.Type,
		"title":       input.Title,
		"message":     strings.TrimSpace(input.Message),
		"data":        notificationData(input.Data),
		"source_type": strings.TrimSpace(input.SourceType),
		"source_id":   strings.TrimSpace(input.SourceID),
		"is_read":     false,
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(notificationsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create notification")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse notification response")
	}
	return record, nil
}

func listUserNotifications(ctx context.Context, token string, userID string, unreadOnly bool, page int, perPage int) (pocketBaseListResponse[notificationRecord], error) {
	filter := fmt.Sprintf("user=%q", userID)
	if unreadOnly {
		filter += " && is_read=false"
	}
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("page", strconv.Itoa(page))
	query.Set("perPage", strconv.Itoa(perPage))
	query.Set("sort", "-created")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(notificationsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return pocketBaseListResponse[notificationRecord]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[notificationRecord]{}, mapPocketBaseError(resp, "failed to list notifications")
	}

	var list pocketBaseListResponse[notificationRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[notificationRecord]{}, errors.New("failed to parse notifications response")
	}
	return list, nil
}

func countUnreadNotifications(ctx context.Context, token string, userID string) (int, error) {
	list, err := listUserNotifications(ctx, token, userID, true, 1, 1)
	if err != nil {
		return 0, err
	}
	return list.TotalItems, nil
}

func markNotificationRead(ctx context.Context, token string, userID string, notificationID string) (map[string]any, error) {
	notification, err := getNotification(ctx, token, notificationID)
	if err != nil {
		return nil, err
	}
	if notification.User != userID {
		return nil, statusError{status: http.StatusForbidden, message: "notification does not belong to authenticated user"}
	}
	return patchNotificationRead(ctx, token, notificationID)
}

func markAllNotificationsRead(ctx context.Context, token string, userID string) (int, error) {
	count := 0
	page := 1
	for {
		list, err := listUserNotifications(ctx, token, userID, true, page, 100)
		if err != nil {
			return count, err
		}
		if len(list.Items) == 0 {
			return count, nil
		}
		for _, notification := range list.Items {
			if _, err := patchNotificationRead(ctx, token, notification.ID); err != nil {
				return count, err
			}
			count++
		}
		if len(list.Items) < 100 {
			return count, nil
		}
	}
}

func getNotification(ctx context.Context, token string, notificationID string) (notificationRecord, error) {
	notificationID = strings.TrimSpace(notificationID)
	if notificationID == "" {
		return notificationRecord{}, statusError{status: http.StatusBadRequest, message: "notification id is required"}
	}
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(notificationsCollection, notificationID), token, nil)
	if err != nil {
		return notificationRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return notificationRecord{}, statusError{status: http.StatusNotFound, message: "notification not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return notificationRecord{}, mapPocketBaseError(resp, "failed to get notification")
	}

	var record notificationRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return notificationRecord{}, errors.New("failed to parse notification response")
	}
	return record, nil
}

func patchNotificationRead(ctx context.Context, token string, notificationID string) (map[string]any, error) {
	payload := map[string]any{
		"is_read": true,
		"read_at": time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(notificationsCollection, notificationID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update notification")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse notification update response")
	}
	return record, nil
}

func parseNotificationActionPath(path string) (string, string, bool) {
	const prefix = "/api/notifications/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}
	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}
	return parts[0], parts[1], true
}

func parseBoolQuery(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "y":
		return true
	default:
		return false
	}
}

func boundedIntQuery(value string, fallback int, min int, max int) int {
	parsed, err := strconv.Atoi(strings.TrimSpace(value))
	if err != nil {
		return fallback
	}
	if parsed < min {
		return min
	}
	if parsed > max {
		return max
	}
	return parsed
}

func notificationData(data map[string]any) map[string]any {
	if data == nil {
		return map[string]any{}
	}
	return data
}
