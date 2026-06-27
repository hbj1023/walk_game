package stages

import (
	"testing"

	"server/src/models"
)

func TestNormalStageStatusUnlocksFirstStageWithoutProgress(t *testing.T) {
	stage := models.StageRecord{ID: "stage-1", StageNo: 1}

	status := NormalStageStatus(stage, models.StageProgressRecord{}, false)

	if status != "unlocked" {
		t.Fatalf("status = %q, want unlocked", status)
	}
}

func TestNormalStageStatusLocksLaterStageWithoutProgress(t *testing.T) {
	stage := models.StageRecord{ID: "stage-2", StageNo: 2}

	status := NormalStageStatus(stage, models.StageProgressRecord{}, false)

	if status != "locked" {
		t.Fatalf("status = %q, want locked", status)
	}
}

func TestPreviousStageMustBeCleared(t *testing.T) {
	if IsStageCleared(models.StageProgressRecord{}, false) {
		t.Fatal("missing progress should not count as cleared")
	}
	if IsStageCleared(models.StageProgressRecord{Status: "unlocked"}, true) {
		t.Fatal("unlocked progress should not count as cleared")
	}
	if !IsStageCleared(models.StageProgressRecord{Status: "cleared"}, true) {
		t.Fatal("cleared progress should count as cleared")
	}
}

func TestBuildNormalStageResponseMarksClearedAsUnlocked(t *testing.T) {
	stage := models.StageRecord{ID: "stage-1", StageNo: 1, Title: "1-1", StageType: "normal", IsActive: true}
	progress := models.StageProgressRecord{Status: "cleared", ClearCount: 1}

	response := BuildNormalStageResponse(stage, progress, true)

	if !response.IsUnlocked {
		t.Fatal("cleared stage should be unlocked")
	}
	if !response.IsCleared {
		t.Fatal("cleared stage should be marked as cleared")
	}
}

func TestBuildClearNormalStagePayloadIncrementsClearCount(t *testing.T) {
	progress := models.StageProgressRecord{
		Status:         "cleared",
		ClearCount:     2,
		FirstClearedAt: "2026-05-01T00:00:00Z",
	}

	payload := BuildClearNormalStagePayload("character-1", "stage-1", "2026-05-02T00:00:00Z", progress, true)

	if payload["clear_count"] != 3 {
		t.Fatalf("clear_count = %v, want 3", payload["clear_count"])
	}
	if _, ok := payload["character"]; ok {
		t.Fatal("existing progress patch payload should not include character")
	}
	if _, ok := payload["stage"]; ok {
		t.Fatal("existing progress patch payload should not include stage")
	}
	if _, ok := payload["first_cleared_at"]; ok {
		t.Fatal("first_cleared_at should not be overwritten")
	}
}

func TestBuildClearNormalStagePayloadCreatesFirstClear(t *testing.T) {
	payload := BuildClearNormalStagePayload("character-1", "stage-1", "2026-05-02T00:00:00Z", models.StageProgressRecord{}, false)

	if payload["character"] != "character-1" {
		t.Fatalf("character = %v, want character-1", payload["character"])
	}
	if payload["stage"] != "stage-1" {
		t.Fatalf("stage = %v, want stage-1", payload["stage"])
	}
	if payload["clear_count"] != 1 {
		t.Fatalf("clear_count = %v, want 1", payload["clear_count"])
	}
	if payload["first_cleared_at"] != "2026-05-02T00:00:00Z" {
		t.Fatalf("first_cleared_at = %v, want clearedAt", payload["first_cleared_at"])
	}
}
