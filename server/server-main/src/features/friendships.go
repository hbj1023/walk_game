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

func friendshipRequestHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/friendships/request" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req friendshipRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}
	req.RequesterUserID = strings.TrimSpace(req.RequesterUserID)
	req.TargetUserID = strings.TrimSpace(req.TargetUserID)
	if req.RequesterUserID == "" {
		req.RequesterUserID = user.ID
	}
	if req.TargetUserID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "targetUserId is required"})
		return
	}
	if req.RequesterUserID != user.ID {
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "friend request failed", "error": "requesterUserId must match authenticated user"})
		return
	}

	data, err := createFriendRequest(r.Context(), token, req.RequesterUserID, req.TargetUserID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "friend request failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusCreated, "friend request created", data)
}

func friendshipActionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	friendshipID, action, ok := parseFriendshipActionPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var (
		data    any
		message string
	)
	switch action {
	case "accept":
		data, err = updateFriendshipRequest(r.Context(), token, user.ID, friendshipID, "accepted", true)
		message = "friend request accepted"
	case "reject":
		data, err = updateFriendshipRequest(r.Context(), token, user.ID, friendshipID, "rejected", true)
		message = "friend request rejected"
	case "cancel":
		data, err = cancelFriendshipRequest(r.Context(), token, user.ID, friendshipID)
		message = "friend request cancelled"
	case "block":
		data, err = blockFriendship(r.Context(), token, user.ID, friendshipID)
		message = "friendship blocked"
	case "unblock":
		data, err = unblockFriendship(r.Context(), token, user.ID, friendshipID)
		message = "friendship unblocked"
	case "unfriend":
		data, err = unfriendFriendship(r.Context(), token, user.ID, friendshipID)
		message = "friendship removed"
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "friendship action failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, message, data)
}

func userSearchHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/users/search" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	query := strings.TrimSpace(r.URL.Query().Get("q"))
	users, err := searchUsers(r.Context(), token, user.ID, query)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "users fetched", users)
}

func userFriendsHandler(w http.ResponseWriter, r *http.Request, userID string) bool {
	return handleUserFriendshipList(w, r, userID, "friends")
}

func userFriendRequestsHandler(w http.ResponseWriter, r *http.Request, userID string) bool {
	return handleUserFriendshipList(w, r, userID, "friend-requests")
}

func userSentFriendRequestsHandler(w http.ResponseWriter, r *http.Request, userID string) bool {
	return handleUserFriendshipList(w, r, userID, "sent-friend-requests")
}

func userBlockedFriendsHandler(w http.ResponseWriter, r *http.Request, userID string) bool {
	return handleUserFriendshipList(w, r, userID, "blocked-friends")
}

func handleUserFriendshipList(w http.ResponseWriter, r *http.Request, userID string, resource string) bool {
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

	var (
		data    any
		message string
	)
	switch resource {
	case "friends":
		data, err = listFriends(r.Context(), token, userID)
		message = "friends fetched"
	case "friend-requests":
		data, err = listReceivedFriendRequests(r.Context(), token, userID)
		message = "friend requests fetched"
	case "sent-friend-requests":
		data, err = listSentFriendRequests(r.Context(), token, userID)
		message = "sent friend requests fetched"
	case "blocked-friends":
		data, err = listBlockedFriendships(r.Context(), token, userID)
		message = "blocked friendships fetched"
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return true
	}
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return true
	}

	writeInventoryResponse(w, http.StatusOK, message, data)
	return true
}

func parseFriendshipActionPath(path string) (string, string, bool) {
	const prefix = "/api/friendships/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}
	return parts[0], parts[1], true
}

func createFriendRequest(ctx context.Context, token string, requesterUserID string, targetUserID string) (map[string]any, error) {
	if requesterUserID == targetUserID {
		return nil, statusError{status: http.StatusBadRequest, message: "cannot request friendship with yourself"}
	}

	low, high := orderedUserPair(requesterUserID, targetUserID)
	friendship, exists, err := getFriendshipBetweenUsers(ctx, token, low, high)
	if err != nil {
		return nil, err
	}
	if exists {
		switch friendship.Status {
		case "rejected":
			payload := map[string]any{
				"status":            "pending",
				"requested_by_user": requesterUserID,
				"requested_at":      time.Now().UTC().Format(time.RFC3339),
			}
			record, err := patchFriendship(ctx, token, friendship.ID, payload)
			if err != nil {
				return nil, err
			}
			createNotificationBestEffort(ctx, token, friendRequestNotification(requesterUserID, targetUserID, mapString(record["id"])))
			return record, nil
		case "pending":
			return nil, statusError{status: http.StatusConflict, message: "friend request already pending"}
		case "accepted":
			return nil, statusError{status: http.StatusConflict, message: "friendship already accepted"}
		case "blocked":
			return nil, statusError{status: http.StatusConflict, message: "friendship is blocked"}
		default:
			return nil, statusError{status: http.StatusConflict, message: "friendship already exists"}
		}
	}

	payload := map[string]any{
		"user_low":          low,
		"user_high":         high,
		"status":            "pending",
		"requested_by_user": requesterUserID,
		"requested_at":      time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(friendshipsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create friendship")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse friendship response")
	}
	createNotificationBestEffort(ctx, token, friendRequestNotification(requesterUserID, targetUserID, mapString(record["id"])))
	return record, nil
}

func updateFriendshipRequest(ctx context.Context, token string, userID string, friendshipID string, status string, mustBeReceiver bool) (map[string]any, error) {
	friendship, err := getFriendship(ctx, token, friendshipID)
	if err != nil {
		return nil, err
	}
	if !friendshipIncludesUser(friendship, userID) {
		return nil, statusError{status: http.StatusForbidden, message: "friendship does not belong to authenticated user"}
	}
	if mustBeReceiver && friendship.RequestedByUser == userID {
		return nil, statusError{status: http.StatusForbidden, message: "only the request receiver can respond"}
	}
	if friendship.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "friend request is not pending"}
	}
	record, err := patchFriendshipStatus(ctx, token, friendshipID, status)
	if err != nil {
		return nil, err
	}
	if status == "accepted" && friendship.RequestedByUser != "" && friendship.RequestedByUser != userID {
		createNotificationBestEffort(ctx, token, notificationCreateInput{
			UserID:     friendship.RequestedByUser,
			Type:       "friend_accept",
			Title:      "친구 요청 수락",
			Message:    "보낸 친구 요청이 수락되었습니다.",
			SourceType: "friendship",
			SourceID:   friendshipID,
			Data: map[string]any{
				"friendship_id": friendshipID,
				"accepted_by":   userID,
			},
		})
	}
	return record, nil
}

func friendRequestNotification(requesterUserID string, targetUserID string, friendshipID string) notificationCreateInput {
	return notificationCreateInput{
		UserID:     targetUserID,
		Type:       "friend_request",
		Title:      "친구 요청",
		Message:    "새 친구 요청이 도착했습니다.",
		SourceType: "friendship",
		SourceID:   friendshipID,
		Data: map[string]any{
			"friendship_id": friendshipID,
			"requester_id":  requesterUserID,
		},
	}
}

func cancelFriendshipRequest(ctx context.Context, token string, userID string, friendshipID string) (map[string]any, error) {
	friendship, err := getFriendship(ctx, token, friendshipID)
	if err != nil {
		return nil, err
	}
	if !friendshipIncludesUser(friendship, userID) {
		return nil, statusError{status: http.StatusForbidden, message: "friendship does not belong to authenticated user"}
	}
	if friendship.RequestedByUser != userID {
		return nil, statusError{status: http.StatusForbidden, message: "only the request sender can cancel"}
	}
	if friendship.Status != "pending" {
		return nil, statusError{status: http.StatusConflict, message: "friend request is not pending"}
	}
	return patchFriendshipStatus(ctx, token, friendshipID, "rejected")
}

func blockFriendship(ctx context.Context, token string, userID string, friendshipID string) (map[string]any, error) {
	friendship, err := getFriendship(ctx, token, friendshipID)
	if err != nil {
		return nil, err
	}
	if !friendshipIncludesUser(friendship, userID) {
		return nil, statusError{status: http.StatusForbidden, message: "friendship does not belong to authenticated user"}
	}
	if friendship.Status == "blocked" {
		return nil, statusError{status: http.StatusConflict, message: "friendship is already blocked"}
	}
	return patchFriendshipStatus(ctx, token, friendshipID, "blocked")
}

func unblockFriendship(ctx context.Context, token string, userID string, friendshipID string) (map[string]any, error) {
	friendship, err := getFriendship(ctx, token, friendshipID)
	if err != nil {
		return nil, err
	}
	if !friendshipIncludesUser(friendship, userID) {
		return nil, statusError{status: http.StatusForbidden, message: "friendship does not belong to authenticated user"}
	}
	if friendship.Status != "blocked" {
		return nil, statusError{status: http.StatusConflict, message: "friendship is not blocked"}
	}
	return patchFriendshipStatus(ctx, token, friendshipID, "rejected")
}

func unfriendFriendship(ctx context.Context, token string, userID string, friendshipID string) (map[string]any, error) {
	friendship, err := getFriendship(ctx, token, friendshipID)
	if err != nil {
		return nil, err
	}
	if !friendshipIncludesUser(friendship, userID) {
		return nil, statusError{status: http.StatusForbidden, message: "friendship does not belong to authenticated user"}
	}
	if friendship.Status != "accepted" {
		return nil, statusError{status: http.StatusConflict, message: "friendship is not accepted"}
	}
	return patchFriendshipStatus(ctx, token, friendshipID, "rejected")
}

func searchUsers(ctx context.Context, token string, currentUserID string, query string) ([]map[string]any, error) {
	if len([]rune(query)) < 2 {
		return []map[string]any{}, nil
	}

	filter := fmt.Sprintf(
		"id!=%q && (email~%q || name~%q || nickname~%q)",
		currentUserID,
		query,
		query,
		query,
	)
	list, err := listCollectionRecords(ctx, token, usersCollection, filter, "profile_emote", "nickname,name,email")
	if err != nil {
		return nil, err
	}

	users := make([]map[string]any, 0, len(list.Items))
	for _, item := range list.Items {
		users = append(users, sanitizeFriendUser(item))
	}
	return users, nil
}

func listFriends(ctx context.Context, token string, userID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("(user_low=%q || user_high=%q) && status=%q", userID, userID, "accepted")
	list, err := listCollectionRecords(ctx, token, friendshipsCollection, filter, friendshipUserExpand(), "-responded_at,-created")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return hydrateFriendshipUsers(ctx, token, list)
}

func listReceivedFriendRequests(ctx context.Context, token string, userID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("(user_low=%q || user_high=%q) && requested_by_user!=%q && status=%q", userID, userID, userID, "pending")
	list, err := listCollectionRecords(ctx, token, friendshipsCollection, filter, friendshipUserExpand(), "-requested_at,-created")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return hydrateFriendshipUsers(ctx, token, list)
}

func listSentFriendRequests(ctx context.Context, token string, userID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("(user_low=%q || user_high=%q) && requested_by_user=%q && status=%q", userID, userID, userID, "pending")
	list, err := listCollectionRecords(ctx, token, friendshipsCollection, filter, friendshipUserExpand(), "-requested_at,-created")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return hydrateFriendshipUsers(ctx, token, list)
}

func listBlockedFriendships(ctx context.Context, token string, userID string) (pocketBaseListResponse[map[string]any], error) {
	filter := fmt.Sprintf("(user_low=%q || user_high=%q) && status=%q", userID, userID, "blocked")
	list, err := listCollectionRecords(ctx, token, friendshipsCollection, filter, friendshipUserExpand(), "-responded_at,-updated")
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	return hydrateFriendshipUsers(ctx, token, list)
}

func friendshipUserExpand() string {
	return "user_low,user_high,requested_by_user,user_low.profile_emote,user_high.profile_emote,requested_by_user.profile_emote"
}

func hydrateFriendshipUsers(ctx context.Context, token string, list pocketBaseListResponse[map[string]any]) (pocketBaseListResponse[map[string]any], error) {
	userCache := map[string]map[string]any{}
	for i, item := range list.Items {
		expand, _ := item["expand"].(map[string]any)
		if expand == nil {
			expand = map[string]any{}
		}

		for _, field := range []string{"user_low", "user_high", "requested_by_user"} {
			userID := strings.TrimSpace(mapString(item[field]))
			if userID == "" {
				continue
			}
			user, ok := userCache[userID]
			if !ok {
				fetchedUser, err := getFriendUserMap(ctx, token, userID)
				if err != nil {
					return pocketBaseListResponse[map[string]any]{}, err
				}
				user = fetchedUser
				userCache[userID] = user
			}
			expand[field] = user
		}

		item["expand"] = expand
		list.Items[i] = item
	}
	return list, nil
}

func getFriendUserMap(ctx context.Context, token string, userID string) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(usersCollection, userID)+"?expand=profile_emote", token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil, statusError{status: http.StatusNotFound, message: "user not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to get user")
	}

	var user map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, errors.New("failed to parse user response")
	}
	return sanitizeFriendUser(user), nil
}

func getFriendship(ctx context.Context, token string, friendshipID string) (friendshipRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(friendshipsCollection, friendshipID), token, nil)
	if err != nil {
		return friendshipRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return friendshipRecord{}, statusError{status: http.StatusNotFound, message: "friendship not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return friendshipRecord{}, mapPocketBaseError(resp, "failed to get friendship")
	}

	var record friendshipRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return friendshipRecord{}, errors.New("failed to parse friendship response")
	}
	return record, nil
}

func getFriendshipBetweenUsers(ctx context.Context, token string, low string, high string) (friendshipRecord, bool, error) {
	filter := fmt.Sprintf("user_low=%q && user_high=%q", low, high)
	query := url.Values{}
	query.Set("filter", filter)
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(friendshipsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return friendshipRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return friendshipRecord{}, false, mapPocketBaseError(resp, "failed to check friendship")
	}

	var list pocketBaseListResponse[friendshipRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return friendshipRecord{}, false, errors.New("failed to parse friendship response")
	}
	if len(list.Items) == 0 {
		return friendshipRecord{}, false, nil
	}
	return list.Items[0], true, nil
}

func patchFriendshipStatus(ctx context.Context, token string, friendshipID string, status string) (map[string]any, error) {
	payload := map[string]any{
		"status":       status,
		"responded_at": time.Now().UTC().Format(time.RFC3339),
	}
	return patchFriendship(ctx, token, friendshipID, payload)
}

func patchFriendship(ctx context.Context, token string, friendshipID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(friendshipsCollection, friendshipID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update friendship")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse friendship update response")
	}
	return record, nil
}

func friendshipIncludesUser(friendship friendshipRecord, userID string) bool {
	return friendship.UserLow == userID || friendship.UserHigh == userID
}

func sanitizeFriendUser(item map[string]any) map[string]any {
	return map[string]any{
		"id":                stringField(item, "id"),
		"email":             stringField(item, "email"),
		"name":              stringField(item, "name"),
		"nickname":          stringField(item, "nickname"),
		"username":          stringField(item, "username"),
		"avatar":            stringField(item, "avatar"),
		"profile_image_url": stringField(item, "profile_image_url"),
		"profile_emote":     item["profile_emote"],
		"profile_image":     buildProfileImage(item),
		"expand":            item["expand"],
	}
}

func stringField(item map[string]any, key string) string {
	value, ok := item[key].(string)
	if !ok {
		return ""
	}
	return value
}
