package features

import "testing"

func TestParseNotificationActionPath(t *testing.T) {
	id, action, ok := parseNotificationActionPath("/api/notifications/abc123/read")
	if !ok {
		t.Fatal("expected path to parse")
	}
	if id != "abc123" || action != "read" {
		t.Fatalf("unexpected parse result: id=%q action=%q", id, action)
	}
}

func TestParseNotificationActionPathRejectsInvalidPaths(t *testing.T) {
	invalidPaths := []string{
		"/api/notifications",
		"/api/notifications/",
		"/api/notifications/read-all",
		"/api/notifications/abc123",
		"/api/notifications/abc123/read/extra",
	}
	for _, path := range invalidPaths {
		if _, _, ok := parseNotificationActionPath(path); ok {
			t.Fatalf("expected invalid path: %s", path)
		}
	}
}

func TestBoundedIntQuery(t *testing.T) {
	tests := []struct {
		name     string
		value    string
		fallback int
		min      int
		max      int
		want     int
	}{
		{name: "valid", value: "25", fallback: 10, min: 1, max: 50, want: 25},
		{name: "fallback", value: "oops", fallback: 10, min: 1, max: 50, want: 10},
		{name: "min", value: "-3", fallback: 10, min: 1, max: 50, want: 1},
		{name: "max", value: "500", fallback: 10, min: 1, max: 50, want: 50},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := boundedIntQuery(tt.value, tt.fallback, tt.min, tt.max)
			if got != tt.want {
				t.Fatalf("boundedIntQuery()=%d want %d", got, tt.want)
			}
		})
	}
}

func TestNotificationInputBuilders(t *testing.T) {
	friend := friendRequestNotification("requester", "target", "friendship")
	if friend.UserID != "target" || friend.Type != "friend_request" || friend.SourceID != "friendship" {
		t.Fatalf("unexpected friend notification: %+v", friend)
	}

	mission := missionCompletedNotification("user", "userMission", missionRecord{
		ID:         "mission",
		Title:      "1km 걷기",
		RewardCoin: 100,
	})
	if mission.UserID != "user" || mission.Type != "mission_completed" || mission.SourceID != "userMission" {
		t.Fatalf("unexpected mission notification: %+v", mission)
	}
	if mission.Message != "1km 걷기 미션을 완료했습니다." {
		t.Fatalf("unexpected mission message: %q", mission.Message)
	}
}
