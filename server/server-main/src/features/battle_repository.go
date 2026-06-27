package features

import (
	"context"
	"errors"

	"server/src/repositories"
)

func normalizeRepositoryError(err error) error {
	if err == nil {
		return nil
	}
	var repositoryStatusErr repositories.StatusError
	if errors.As(err, &repositoryStatusErr) {
		return statusError{
			status:  repositoryStatusErr.StatusCode(),
			message: repositoryStatusErr.Error(),
		}
	}
	return err
}

func getBattleCharacterByID(ctx context.Context, token string, characterID string) (battleCharacterRecord, error) {
	character, err := repositories.GetBattleCharacterByID(ctx, token, characterID)
	return character, normalizeRepositoryError(err)
}

func getBattleCharacterByUserID(ctx context.Context, token string, userID string) (battleCharacterRecord, error) {
	character, err := repositories.GetBattleCharacterByUserID(ctx, token, userID)
	return character, normalizeRepositoryError(err)
}

func getBattleCharacterStats(ctx context.Context, token string, characterID string) (battleCharacterStatsRecord, error) {
	stats, err := repositories.GetBattleCharacterStats(ctx, token, characterID)
	return stats, normalizeRepositoryError(err)
}

func getStageByID(ctx context.Context, token string, stageID string) (stageRecord, error) {
	stage, err := repositories.GetStageByID(ctx, token, stageID)
	return stage, normalizeRepositoryError(err)
}

func getNormalStageByNo(ctx context.Context, token string, stageNo int) (stageRecord, error) {
	stage, err := repositories.GetNormalStageByNo(ctx, token, stageNo)
	return stage, normalizeRepositoryError(err)
}

func getBossStageByNo(ctx context.Context, token string, stageNo int) (stageRecord, error) {
	stage, err := repositories.GetBossStageByNo(ctx, token, stageNo)
	return stage, normalizeRepositoryError(err)
}

func listNormalStages(ctx context.Context, token string) ([]stageRecord, error) {
	stages, err := repositories.ListNormalStages(ctx, token)
	return stages, normalizeRepositoryError(err)
}

func getStageProgress(ctx context.Context, token string, characterID string, stageID string) (stageProgressRecord, bool, error) {
	progress, found, err := repositories.GetStageProgress(ctx, token, characterID, stageID)
	return progress, found, normalizeRepositoryError(err)
}

func listStageProgressByCharacter(ctx context.Context, token string, characterID string) ([]stageProgressRecord, error) {
	progress, err := repositories.ListStageProgressByCharacter(ctx, token, characterID)
	return progress, normalizeRepositoryError(err)
}

func createStageProgress(ctx context.Context, token string, payload map[string]any) (stageProgressRecord, error) {
	progress, err := repositories.CreateStageProgress(ctx, token, payload)
	return progress, normalizeRepositoryError(err)
}

func patchStageProgress(ctx context.Context, token string, progressID string, payload map[string]any) (stageProgressRecord, error) {
	progress, err := repositories.PatchStageProgress(ctx, token, progressID, payload)
	return progress, normalizeRepositoryError(err)
}

func getFirstNormalStageMonster(ctx context.Context, token string, stageID string) (stageMonsterRecord, error) {
	stageMonster, err := repositories.GetFirstNormalStageMonster(ctx, token, stageID)
	return stageMonster, normalizeRepositoryError(err)
}

func getFirstStageMonster(ctx context.Context, token string, stageID string) (stageMonsterRecord, error) {
	stageMonster, err := repositories.GetFirstStageMonster(ctx, token, stageID)
	return stageMonster, normalizeRepositoryError(err)
}

func getMonsterByID(ctx context.Context, token string, monsterID string) (monsterRecord, error) {
	monster, err := repositories.GetMonsterByID(ctx, token, monsterID)
	return monster, normalizeRepositoryError(err)
}

func findCurrentNormalBattle(ctx context.Context, token string, characterID string) (battleRecord, bool, error) {
	battle, found, err := repositories.FindCurrentNormalBattle(ctx, token, characterID)
	return battle, found, normalizeRepositoryError(err)
}

func findCurrentBattleByType(ctx context.Context, token string, characterID string, battleType string) (battleRecord, bool, error) {
	battle, found, err := repositories.FindCurrentBattleByType(ctx, token, characterID, battleType)
	return battle, found, normalizeRepositoryError(err)
}

func hasBattleHistory(ctx context.Context, token string, characterID string, stageID string, battleType string) (bool, error) {
	found, err := repositories.HasBattleHistory(ctx, token, characterID, stageID, battleType)
	return found, normalizeRepositoryError(err)
}

func listNormalBattleHistory(ctx context.Context, token string, characterID string, page int, perPage int) (pocketBaseListResponse[battleRecord], error) {
	history, err := repositories.ListNormalBattleHistory(ctx, token, characterID, page, perPage)
	return pocketBaseListResponse[battleRecord]{
		Page:       history.Page,
		PerPage:    history.PerPage,
		TotalItems: history.TotalItems,
		TotalPages: history.TotalPages,
		Items:      history.Items,
	}, normalizeRepositoryError(err)
}

func createNormalBattle(ctx context.Context, token string, payload map[string]any) (battleRecord, error) {
	battle, err := repositories.CreateNormalBattle(ctx, token, payload)
	return battle, normalizeRepositoryError(err)
}

func getBattleByID(ctx context.Context, token string, battleID string) (battleRecord, error) {
	battle, err := repositories.GetBattleByID(ctx, token, battleID)
	return battle, normalizeRepositoryError(err)
}

func patchBattle(ctx context.Context, token string, battleID string, payload map[string]any) (battleRecord, error) {
	battle, err := repositories.PatchBattle(ctx, token, battleID, payload)
	return battle, normalizeRepositoryError(err)
}

func patchBattleCharacter(ctx context.Context, token string, characterID string, payload map[string]any) (battleCharacterRecord, error) {
	character, err := repositories.PatchBattleCharacter(ctx, token, characterID, payload)
	return character, normalizeRepositoryError(err)
}

func createRewardLog(ctx context.Context, token string, characterID string, battleID string, rewardCoin int) error {
	return normalizeRepositoryError(
		repositories.CreateRewardLog(ctx, token, characterID, battleID, rewardCoin),
	)
}

func createBattleResourceTransaction(ctx context.Context, token string, characterID string, battleID string, resourceType string, transactionType string, amount int, balanceAfter int, reason string) error {
	return normalizeRepositoryError(
		repositories.CreateBattleResourceTransaction(
			ctx,
			token,
			characterID,
			battleID,
			resourceType,
			transactionType,
			amount,
			balanceAfter,
			reason,
		),
	)
}
