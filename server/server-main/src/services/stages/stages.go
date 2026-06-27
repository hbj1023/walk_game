package stages

import "server/src/models"

const FirstNormalStageNo = 1

func BuildNormalStageResponse(
	stage models.StageRecord,
	progress models.StageProgressRecord,
	found bool,
) models.NormalStageResponse {
	status := NormalStageStatus(stage, progress, found)
	return models.NormalStageResponse{
		ID:             stage.ID,
		StageNo:        stage.StageNo,
		Title:          stage.Title,
		StageType:      stage.StageType,
		MonsterCount:   stage.MonsterCount,
		IsActive:       stage.IsActive,
		Status:         status,
		ClearCount:     progress.ClearCount,
		FirstClearedAt: progress.FirstClearedAt,
		LastClearedAt:  progress.LastClearedAt,
		IsUnlocked:     status == "unlocked" || status == "cleared",
		IsCleared:      status == "cleared",
	}
}

func NormalStageStatus(
	stage models.StageRecord,
	progress models.StageProgressRecord,
	found bool,
) string {
	if found && progress.Status != "" {
		return progress.Status
	}
	if stage.StageNo <= FirstNormalStageNo {
		return "unlocked"
	}
	return "locked"
}

func IsStageCleared(progress models.StageProgressRecord, found bool) bool {
	return found && progress.Status == "cleared"
}

func BuildClearNormalStagePayload(
	characterID string,
	stageID string,
	clearedAt string,
	progress models.StageProgressRecord,
	found bool,
) map[string]any {
	payload := map[string]any{
		"status":          "cleared",
		"clear_count":     1,
		"last_cleared_at": clearedAt,
	}
	if found {
		payload["clear_count"] = progress.ClearCount + 1
		if progress.FirstClearedAt == "" {
			payload["first_cleared_at"] = clearedAt
		}
		return payload
	}

	payload["character"] = characterID
	payload["stage"] = stageID
	payload["first_cleared_at"] = clearedAt
	return payload
}
