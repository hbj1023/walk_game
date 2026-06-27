package features

import (
	"context"
	"errors"
	"net/http"

	stageService "server/src/services/stages"
)

const firstNormalStageNo = stageService.FirstNormalStageNo

func normalStageListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	response, err := listNormalStageProgress(r.Context(), token, user.ID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func listNormalStageProgress(ctx context.Context, token string, userID string) (NormalStageListResponse, error) {
	character, err := getBattleCharacterByUserID(ctx, token, userID)
	if err != nil {
		return NormalStageListResponse{}, err
	}
	stages, err := listNormalStages(ctx, token)
	if err != nil {
		return NormalStageListResponse{}, err
	}
	progressList, err := listStageProgressByCharacter(ctx, token, character.ID)
	if err != nil {
		return NormalStageListResponse{}, err
	}

	progressByStageID := make(map[string]stageProgressRecord, len(progressList))
	for _, progress := range progressList {
		progressByStageID[progress.Stage] = progress
	}

	response := NormalStageListResponse{
		Stages: make([]NormalStageResponse, 0, len(stages)),
	}
	for _, stage := range stages {
		progress, found := progressByStageID[stage.ID]
		stageResponse := buildNormalStageResponse(stage, progress, found)
		if monster, err := firstNormalStageMonsterSummary(ctx, token, stage.ID); err == nil {
			stageResponse.MonsterID = monster.ID
			stageResponse.MonsterName = monster.Name
			stageResponse.MonsterHP = monster.HP
		}
		response.Stages = append(response.Stages, stageResponse)
	}
	return response, nil
}

func ensureNormalStageUnlocked(ctx context.Context, token string, characterID string, stage stageRecord) error {
	progress, found, err := getStageProgress(ctx, token, characterID, stage.ID)
	if err != nil {
		return err
	}
	if found && progress.Status != "locked" {
		return nil
	}
	if stage.StageNo <= firstNormalStageNo {
		return unlockNormalStage(ctx, token, characterID, stage.ID, progress, found)
	}

	previousStage, err := getNormalStageByNo(ctx, token, stage.StageNo-1)
	if err != nil {
		return err
	}
	previousProgress, previousFound, err := getStageProgress(ctx, token, characterID, previousStage.ID)
	if err != nil {
		return err
	}
	if !isStageCleared(previousProgress, previousFound) {
		return statusError{status: http.StatusForbidden, message: "previous stage must be cleared first"}
	}

	return unlockNormalStage(ctx, token, characterID, stage.ID, progress, found)
}

func clearNormalStageAndUnlockNext(ctx context.Context, token string, characterID string, stageID string, clearedAt string) error {
	stage, err := getStageByID(ctx, token, stageID)
	if err != nil {
		return err
	}
	if err := clearNormalStage(ctx, token, characterID, stage, clearedAt); err != nil {
		return err
	}

	nextStage, err := getNormalStageByNo(ctx, token, stage.StageNo+1)
	if err != nil {
		var statusErr statusError
		if errors.As(err, &statusErr) && statusErr.status == http.StatusNotFound {
			return nil
		}
		return err
	}

	nextProgress, nextFound, err := getStageProgress(ctx, token, characterID, nextStage.ID)
	if err != nil {
		return err
	}
	return unlockNormalStage(ctx, token, characterID, nextStage.ID, nextProgress, nextFound)
}

func clearNormalStage(ctx context.Context, token string, characterID string, stage stageRecord, clearedAt string) error {
	progress, found, err := getStageProgress(ctx, token, characterID, stage.ID)
	if err != nil {
		return err
	}

	payload := buildClearNormalStagePayload(characterID, stage.ID, clearedAt, progress, found)
	if found {
		_, err = patchStageProgress(ctx, token, progress.ID, payload)
		return err
	}

	_, err = createStageProgress(ctx, token, payload)
	return err
}

func unlockNormalStage(ctx context.Context, token string, characterID string, stageID string, progress stageProgressRecord, found bool) error {
	if found {
		if progress.Status == "locked" {
			_, err := patchStageProgress(ctx, token, progress.ID, map[string]any{"status": "unlocked"})
			return err
		}
		return nil
	}

	_, err := createStageProgress(ctx, token, map[string]any{
		"character":   characterID,
		"stage":       stageID,
		"status":      "unlocked",
		"clear_count": 0,
	})
	return err
}

func buildNormalStageResponse(stage stageRecord, progress stageProgressRecord, found bool) NormalStageResponse {
	return stageService.BuildNormalStageResponse(stage, progress, found)
}

func normalStageStatus(stage stageRecord, progress stageProgressRecord, found bool) string {
	return stageService.NormalStageStatus(stage, progress, found)
}

func isStageCleared(progress stageProgressRecord, found bool) bool {
	return stageService.IsStageCleared(progress, found)
}

func firstNormalStageMonsterSummary(ctx context.Context, token string, stageID string) (monsterRecord, error) {
	stageMonster, err := getFirstNormalStageMonster(ctx, token, stageID)
	if err != nil {
		return monsterRecord{}, err
	}
	return getMonsterByID(ctx, token, stageMonster.Monster)
}

func buildClearNormalStagePayload(characterID string, stageID string, clearedAt string, progress stageProgressRecord, found bool) map[string]any {
	return stageService.BuildClearNormalStagePayload(
		characterID,
		stageID,
		clearedAt,
		progress,
		found,
	)
}
