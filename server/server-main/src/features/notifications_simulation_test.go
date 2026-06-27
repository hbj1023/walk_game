package features

import (
	"encoding/json"
	"testing"
)

func TestNotificationScenarioSimulation(t *testing.T) {
	scenarios := []notificationCreateInput{
		friendRequestNotification("user_requester", "user_receiver", "friendship_001"),
		{
			UserID:     "user_requester",
			Type:       "friend_accept",
			Title:      "친구 요청 수락",
			Message:    "보낸 친구 요청이 수락되었습니다.",
			SourceType: "friendship",
			SourceID:   "friendship_001",
			Data: map[string]any{
				"friendship_id": "friendship_001",
				"accepted_by":   "user_receiver",
			},
		},
		{
			UserID:     "user_receiver",
			Type:       "raid_invite",
			Title:      "레이드 초대",
			Message:    "새 레이드 초대가 도착했습니다.",
			SourceType: "raid_invitation",
			SourceID:   "raid_invitation_001",
			Data: map[string]any{
				"raid_id":              "raid_001",
				"invitation_id":        "raid_invitation_001",
				"inviter_character_id": "character_host",
			},
		},
		missionCompletedNotification("user_receiver", "user_mission_001", missionRecord{
			ID:         "mission_001",
			Title:      "1km 걷기",
			RewardCoin: 100,
		}),
	}

	for _, scenario := range scenarios {
		payload := simulatedNotificationPayload(scenario)
		data, err := json.MarshalIndent(payload, "", "  ")
		if err != nil {
			t.Fatalf("failed to marshal simulated notification: %v", err)
		}
		t.Logf("\n%s", data)
	}
}

func simulatedNotificationPayload(input notificationCreateInput) map[string]any {
	return map[string]any{
		"user":        input.UserID,
		"type":        input.Type,
		"title":       input.Title,
		"message":     input.Message,
		"data":        notificationData(input.Data),
		"source_type": input.SourceType,
		"source_id":   input.SourceID,
		"is_read":     false,
	}
}
