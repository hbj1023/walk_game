package features

import (
	"testing"
	"time"
)

func TestFilterUserMissionListForDateKeepsOnlyRequestedDate(t *testing.T) {
	list := pocketBaseListResponse[map[string]any]{
		Items: []map[string]any{
			userMissionTestItem("today", "mission-a", "1km 걷기", "2026-05-30 00:00:00.000Z", "in_progress", 100),
			userMissionTestItem("yesterday", "mission-a", "1km 걷기", "2026-05-29 00:00:00.000Z", "completed", 1000),
		},
	}

	filtered := filterUserMissionListForDate(list, time.Date(2026, 5, 30, 9, 0, 0, 0, time.UTC))

	if filtered.TotalItems != 1 {
		t.Fatalf("expected 1 mission, got %d", filtered.TotalItems)
	}
	if got := mapString(filtered.Items[0]["id"]); got != "today" {
		t.Fatalf("expected today mission, got %q", got)
	}
}

func TestFilterUserMissionListForDateDedupesSameQuestDisplay(t *testing.T) {
	list := pocketBaseListResponse[map[string]any]{
		Items: []map[string]any{
			userMissionTestItem("old", "mission-a", "1km 걷기", "2026-05-30 00:00:00.000Z", "in_progress", 100),
			userMissionTestItem("new", "mission-b", "1km 걷기", "2026-05-30 00:00:00.000Z", "completed", 1000),
		},
	}

	filtered := filterUserMissionListForDate(list, time.Date(2026, 5, 30, 9, 0, 0, 0, time.UTC))

	if filtered.TotalItems != 1 {
		t.Fatalf("expected 1 mission, got %d", filtered.TotalItems)
	}
	if got := mapString(filtered.Items[0]["id"]); got != "new" {
		t.Fatalf("expected completed duplicate to be kept, got %q", got)
	}
}

func TestFilterUserMissionListForDateKeepsCurrentWeeklyPeriod(t *testing.T) {
	list := pocketBaseListResponse[map[string]any]{
		Items: []map[string]any{
			userMissionTestItemWithType("current-week", "mission-a", "3km 걷기", "weekly", "2026-05-25 00:00:00.000Z", "in_progress", 1000),
			userMissionTestItemWithType("last-week", "mission-a", "3km 걷기", "weekly", "2026-05-18 00:00:00.000Z", "completed", 3000),
		},
	}

	filtered := filterUserMissionListForDate(list, time.Date(2026, 5, 30, 9, 0, 0, 0, time.UTC))

	if filtered.TotalItems != 1 {
		t.Fatalf("expected 1 mission, got %d", filtered.TotalItems)
	}
	if got := mapString(filtered.Items[0]["id"]); got != "current-week" {
		t.Fatalf("expected current week mission, got %q", got)
	}
}

func TestMissionProgressValueUsesMissionPeriodAndTargetType(t *testing.T) {
	snapshot := missionProgressSnapshot{
		DailyDistanceM:          750,
		WeeklyDistanceM:         3200,
		DailyNormalStageClears:  2,
		WeeklyNormalStageClears: 12,
		DailyBossStageClears:    1,
		WeeklyBossStageClears:   4,
	}

	cases := []struct {
		name    string
		mission missionRecord
		want    float64
	}{
		{
			name:    "daily distance",
			mission: missionRecord{MissionType: "daily", TargetType: "distance", TargetValue: 1000},
			want:    750,
		},
		{
			name:    "weekly distance",
			mission: missionRecord{MissionType: "weekly", TargetType: "distance", TargetValue: 5000},
			want:    3200,
		},
		{
			name:    "daily normal clears",
			mission: missionRecord{MissionType: "daily", TargetType: "normal_stage_clear", TargetValue: 3},
			want:    2,
		},
		{
			name:    "weekly boss clears",
			mission: missionRecord{MissionType: "weekly", TargetType: "boss_stage_clear", TargetValue: 7},
			want:    4,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := missionProgressValue(tc.mission, snapshot); got != tc.want {
				t.Fatalf("missionProgressValue() = %v, want %v", got, tc.want)
			}
		})
	}
}

func userMissionTestItem(id string, missionID string, title string, missionDate string, status string, progress float64) map[string]any {
	return userMissionTestItemWithType(id, missionID, title, "daily", missionDate, status, progress)
}

func userMissionTestItemWithType(id string, missionID string, title string, missionType string, missionDate string, status string, progress float64) map[string]any {
	return map[string]any{
		"id":             id,
		"mission":        missionID,
		"mission_date":   missionDate,
		"status":         status,
		"progress_value": progress,
		"expand": map[string]any{
			"mission": map[string]any{
				"mission_type": missionType,
				"title":        title,
				"target_type":  "distance",
				"target_value": 1000.0,
			},
		},
	}
}
