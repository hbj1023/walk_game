package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"sync"
	"time"

	"server/src/utils/formulas"
)

var normalBattleLocks sync.Map

const bossEntranceTicketName = "보스 입장권"

func startNormalBattle(ctx context.Context, token string, userID string, req NormalBattleStartRequest) (NormalBattleResponse, error) {
	stage, err := resolveNormalStage(ctx, token, req)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	characterID := req.CharacterID
	if characterID == "" {
		characterByUser, err := getBattleCharacterByUserID(ctx, token, userID)
		if err != nil {
			return NormalBattleResponse{}, err
		}
		characterID = characterByUser.ID
	}
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.User != userID {
		return NormalBattleResponse{}, statusError{status: http.StatusForbidden, message: "character does not belong to user"}
	}

	stats, err := getBattleCharacterStats(ctx, token, character.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	characterMaxHP, err := getBattleCharacterMaxHP(ctx, token, character.ID, stats)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	if current, found, err := findCurrentNormalBattle(ctx, token, character.ID); err != nil {
		return NormalBattleResponse{}, err
	} else if found {
		if current.MonsterCurrentHP > 0 && current.CharacterCurrentHP > 0 {
			return buildCurrentNormalBattleResponse(ctx, token, character, characterMaxHP, current, stage.ID)
		}
		if err := finishBrokenNormalBattle(ctx, token, current); err != nil {
			return NormalBattleResponse{}, err
		}
	}
	if err := ensureNormalStageUnlocked(ctx, token, character.ID, stage); err != nil {
		return NormalBattleResponse{}, err
	}

	stageMonster, err := getFirstNormalStageMonster(ctx, token, stage.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	monster, err := getMonsterByID(ctx, token, stageMonster.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if monster.MonsterType != "normal" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "monster is not normal type"}
	}
	if monster.HP <= 0 || monster.Attack <= 0 {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "monster battle stats are not configured"}
	}

	characterHP := character.CurrentHP
	if characterHP <= 0 {
		characterHP = characterMaxHP
		character, err = patchBattleCharacter(ctx, token, character.ID, map[string]any{
			"current_hp": characterHP,
		})
		if err != nil {
			return NormalBattleResponse{}, err
		}
	}
	if characterHP <= 0 {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "character hp is not configured"}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	battle, err := createNormalBattle(ctx, token, map[string]any{
		"character":              character.ID,
		"stage":                  stage.ID,
		"monster":                monster.ID,
		"battle_type":            "normal",
		"status":                 "in_progress",
		"distance_used_m":        0,
		"attack_count_used":      0,
		"total_damage_dealt":     0,
		"total_damage_taken":     0,
		"reward_coin":            0,
		"started_at":             now,
		"monster_current_hp":     monster.HP,
		"character_current_hp":   characterHP,
		"monster_attack_gauge_m": 0,
		"current_spawn_order":    stageMonster.SpawnOrder,
	})
	if err != nil {
		return NormalBattleResponse{}, err
	}

	return NormalBattleResponse{
		Battle:             battle,
		Character:          character,
		CharacterMaxHP:     characterMaxHP,
		Monster:            monster,
		AttackCountBalance: character.AttackCountBalance,
	}, nil
}

func startBossBattle(ctx context.Context, token string, userID string, req NormalBattleStartRequest) (NormalBattleResponse, error) {
	stage, err := resolveBossStage(ctx, token, req)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	characterID := req.CharacterID
	if characterID == "" {
		characterByUser, err := getBattleCharacterByUserID(ctx, token, userID)
		if err != nil {
			return NormalBattleResponse{}, err
		}
		characterID = characterByUser.ID
	}
	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.User != userID {
		return NormalBattleResponse{}, statusError{status: http.StatusForbidden, message: "character does not belong to user"}
	}

	stats, err := getBattleCharacterStats(ctx, token, character.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	characterMaxHP, err := getBattleCharacterMaxHP(ctx, token, character.ID, stats)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	if err := ensureBossStageUnlocked(ctx, token, character.ID, stage); err != nil {
		return NormalBattleResponse{}, err
	}

	progress, progressFound, err := getStageProgress(ctx, token, character.ID, stage.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if bossClearRequiresTicket(progress, progressFound) {
		if err := ensureBossEntranceTicketAvailable(ctx, token, character.ID); err != nil {
			return NormalBattleResponse{}, err
		}
	}

	if current, found, err := findCurrentBattleByType(ctx, token, character.ID, "boss"); err != nil {
		return NormalBattleResponse{}, err
	} else if found {
		if current.MonsterCurrentHP > 0 && current.CharacterCurrentHP > 0 {
			return buildCurrentNormalBattleResponse(ctx, token, character, characterMaxHP, current, stage.ID)
		}
		if err := finishBrokenNormalBattle(ctx, token, current); err != nil {
			return NormalBattleResponse{}, err
		}
	}

	stageMonster, err := getFirstStageMonster(ctx, token, stage.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	monster, err := getMonsterByID(ctx, token, stageMonster.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if monster.MonsterType != "boss" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "monster is not boss type"}
	}
	if monster.HP <= 0 || monster.Attack <= 0 {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "monster battle stats are not configured"}
	}

	characterHP := character.CurrentHP
	if characterHP <= 0 {
		characterHP = characterMaxHP
		character, err = patchBattleCharacter(ctx, token, character.ID, map[string]any{
			"current_hp": characterHP,
		})
		if err != nil {
			return NormalBattleResponse{}, err
		}
	}
	if characterHP <= 0 {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "character hp is not configured"}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	battle, err := createNormalBattle(ctx, token, map[string]any{
		"character":              character.ID,
		"stage":                  stage.ID,
		"monster":                monster.ID,
		"battle_type":            "boss",
		"status":                 "in_progress",
		"distance_used_m":        0,
		"attack_count_used":      0,
		"total_damage_dealt":     0,
		"total_damage_taken":     0,
		"reward_coin":            0,
		"started_at":             now,
		"monster_current_hp":     monster.HP,
		"character_current_hp":   characterHP,
		"monster_attack_gauge_m": 0,
		"current_spawn_order":    stageMonster.SpawnOrder,
	})
	if err != nil {
		return NormalBattleResponse{}, err
	}

	return NormalBattleResponse{
		Battle:             battle,
		Character:          character,
		CharacterMaxHP:     characterMaxHP,
		Monster:            monster,
		AttackCountBalance: character.AttackCountBalance,
	}, nil
}

func attackNormalBattle(ctx context.Context, token string, userID string, req NormalBattleAttackRequest) (NormalBattleResponse, error) {
	if req.BattleID == "" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle_id is required"}
	}

	unlockBattle := lockNormalBattle(req.BattleID)
	defer unlockBattle()

	battle, err := getBattleByID(ctx, token, req.BattleID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if battle.BattleType != "normal" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle is not normal type"}
	}

	character, err := getBattleCharacterByID(ctx, token, battle.Character)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.User != userID {
		return NormalBattleResponse{}, statusError{status: http.StatusForbidden, message: "battle does not belong to user"}
	}

	stats, err := getBattleCharacterStats(ctx, token, character.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	statContext, err := getBattleStatContext(ctx, token, character.ID, stats)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	characterMaxHP := statContext.Stats.HP
	monster, err := getMonsterByID(ctx, token, battle.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if battle.Status != "in_progress" {
		return buildStoredBattleResponse(character, characterMaxHP, battle, monster), nil
	}
	if character.AttackCountBalance < 1 {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "attack_count_balance is not enough"}
	}
	if battle.MonsterCurrentHP <= 0 || battle.CharacterCurrentHP <= 0 {
		if err := finishBrokenNormalBattle(ctx, token, battle); err != nil {
			return NormalBattleResponse{}, err
		}
		if _, err := recoverBattleCharacterHP(ctx, token, character, characterMaxHP); err != nil {
			return NormalBattleResponse{}, err
		}
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle is already finished"}
	}

	monsterDefense := adjustedMonsterDefenseForHit(monster.Defense, statContext.Effects, battle.AttackCountUsed+1)
	playerDamage := formulas.CalculateDamage(statContext.Stats.Attack, monsterDefense)
	playerDamage = adjustedPlayerDamage(playerDamage, battle.BattleType, statContext.Effects)
	monsterCurrentHP := battle.MonsterCurrentHP - playerDamage
	if monsterCurrentHP < 0 {
		monsterCurrentHP = 0
	}

	attackDistanceM := formulas.CalculateAttackDistance(statContext.Stats.Agility)
	attackDistanceM = adjustedAttackDistance(attackDistanceM, statContext.Effects)
	monsterAttackDistanceM := formulas.CalculateMonsterAttackDistance()
	monsterGaugeGainM := adjustedMonsterGaugeGain(attackDistanceM, statContext.Effects)
	monsterAttackGaugeM := battle.MonsterAttackGaugeM + monsterGaugeGainM

	monsterDamage := 0
	monsterAttacked := false
	characterCurrentHP := battle.CharacterCurrentHP
	if characterCurrentHP <= 0 {
		characterCurrentHP = character.CurrentHP
	}

	status := "in_progress"
	rewardCoin := 0
	rewardExp := 0
	totalDamageTaken := battle.TotalDamageTaken

	if monsterCurrentHP <= 0 {
		status = "win"
		rewardCoin = randomCoin(monster.RewardCoinMin, monster.RewardCoinMax)
		stage, err := getStageByID(ctx, token, battle.Stage)
		if err != nil {
			return NormalBattleResponse{}, err
		}
		progress, progressFound, err := getStageProgress(ctx, token, character.ID, battle.Stage)
		if err != nil {
			return NormalBattleResponse{}, err
		}
		rewardCoin = normalBattleCoinReward(rewardCoin, stage.StageNo, progress, progressFound, combatPower(statContext.Stats))
		rewardExp = normalBattleExpReward(stage.StageNo, false, progress, progressFound, combatPower(statContext.Stats))
		monsterAttackGaugeM = 0
	} else if monsterAttackGaugeM >= monsterAttackDistanceM {
		monsterAttacked = true
		monsterDamage = formulas.CalculateDamage(monster.Attack, statContext.Stats.Defense)
		monsterDamage = adjustedMonsterDamage(monsterDamage, statContext.Effects)
		characterCurrentHP -= monsterDamage
		if characterCurrentHP < 0 {
			characterCurrentHP = 0
		}
		totalDamageTaken += monsterDamage
		monsterAttackGaugeM -= monsterAttackDistanceM
		if characterCurrentHP <= 0 {
			status = "lose"
		}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	battlePayload := map[string]any{
		"status":                 status,
		"distance_used_m":        round2(battle.DistanceUsedM + attackDistanceM),
		"attack_count_used":      battle.AttackCountUsed + 1,
		"total_damage_dealt":     battle.TotalDamageDealt + playerDamage,
		"total_damage_taken":     totalDamageTaken,
		"reward_coin":            rewardCoin,
		"monster_current_hp":     monsterCurrentHP,
		"character_current_hp":   characterCurrentHP,
		"monster_attack_gauge_m": round2(monsterAttackGaugeM),
		"last_attacked_at":       now,
	}
	if status == "win" || status == "lose" {
		battlePayload["ended_at"] = now
	}

	attackCountBalance := character.AttackCountBalance - 1
	coinBalance := character.CoinBalance
	level := character.Level
	expBalance := character.Exp
	statExpBalance := character.StatExp
	statExpReward := 0
	if status == "win" {
		coinBalance += rewardCoin
		level, expBalance, statExpBalance, statExpReward = applyCharacterExpReward(level, expBalance, rewardExp, statExpBalance)
	}
	characterPersistHP := characterCurrentHP
	if status == "win" || status == "lose" || characterPersistHP <= 0 {
		characterPersistHP = characterMaxHP
	}

	updatedCharacter, err := patchBattleCharacter(ctx, token, character.ID, map[string]any{
		"attack_count_balance": attackCountBalance,
		"level":                level,
		"coin_balance":         coinBalance,
		"exp":                  expBalance,
		"stat_exp":             statExpBalance,
		"current_hp":           characterPersistHP,
	})
	if err != nil {
		return NormalBattleResponse{}, err
	}

	updatedBattle, err := patchBattle(ctx, token, battle.ID, battlePayload)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	if status == "win" {
		if err := clearNormalStageAndUnlockNext(ctx, token, character.ID, battle.Stage, now); err != nil {
			return NormalBattleResponse{}, err
		}
		if err := syncUserBattleClearMissions(ctx, token, userID, now); err != nil {
			log.Printf("failed to sync normal stage clear missions: %v", err)
		}
	}

	recordNormalBattleLogs(ctx, token, character.ID, battle.ID, status, rewardCoin, rewardExp, statExpReward, attackCountBalance, coinBalance, expBalance, statExpBalance)

	return NormalBattleResponse{
		Battle:                 updatedBattle,
		Character:              updatedCharacter,
		CharacterMaxHP:         characterMaxHP,
		Monster:                monster,
		PlayerDamage:           playerDamage,
		MonsterDamage:          monsterDamage,
		MonsterAttacked:        monsterAttacked,
		RewardCoin:             rewardCoin,
		RewardExp:              rewardExp,
		StatExpReward:          statExpReward,
		AttackCountBalance:     attackCountBalance,
		MonsterAttackGaugeM:    round2(monsterAttackGaugeM),
		MonsterAttackDistanceM: round2(monsterAttackDistanceM),
	}, nil
}

func attackBossBattle(ctx context.Context, token string, userID string, req NormalBattleAttackRequest) (NormalBattleResponse, error) {
	if req.BattleID == "" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle_id is required"}
	}

	unlockBattle := lockNormalBattle(req.BattleID)
	defer unlockBattle()

	battle, err := getBattleByID(ctx, token, req.BattleID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if battle.BattleType != "boss" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle is not boss type"}
	}
	ticketConsumed := false

	character, err := getBattleCharacterByID(ctx, token, battle.Character)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.User != userID {
		return NormalBattleResponse{}, statusError{status: http.StatusForbidden, message: "battle does not belong to user"}
	}

	stats, err := getBattleCharacterStats(ctx, token, character.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	statContext, err := getBattleStatContext(ctx, token, character.ID, stats)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	characterMaxHP := statContext.Stats.HP
	monster, err := getMonsterByID(ctx, token, battle.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if battle.Status != "in_progress" {
		return buildStoredBattleResponse(character, characterMaxHP, battle, monster), nil
	}
	if character.AttackCountBalance < 1 {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "attack_count_balance is not enough"}
	}
	if battle.MonsterCurrentHP <= 0 || battle.CharacterCurrentHP <= 0 {
		if err := finishBrokenNormalBattle(ctx, token, battle); err != nil {
			return NormalBattleResponse{}, err
		}
		if _, err := recoverBattleCharacterHP(ctx, token, character, characterMaxHP); err != nil {
			return NormalBattleResponse{}, err
		}
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle is already finished"}
	}
	progress, progressFound, err := getStageProgress(ctx, token, character.ID, battle.Stage)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if bossClearRequiresTicket(progress, progressFound) {
		if err := ensureBossEntranceTicketAvailable(ctx, token, character.ID); err != nil {
			return NormalBattleResponse{}, err
		}
	}

	monsterDefense := adjustedMonsterDefenseForHit(monster.Defense, statContext.Effects, battle.AttackCountUsed+1)
	playerDamage := formulas.CalculateDamage(statContext.Stats.Attack, monsterDefense)
	playerDamage = adjustedPlayerDamage(playerDamage, battle.BattleType, statContext.Effects)
	monsterCurrentHP := battle.MonsterCurrentHP - playerDamage
	if monsterCurrentHP < 0 {
		monsterCurrentHP = 0
	}

	attackDistanceM := formulas.CalculateAttackDistance(statContext.Stats.Agility)
	attackDistanceM = adjustedAttackDistance(attackDistanceM, statContext.Effects)
	monsterAttackDistanceM := formulas.CalculateMonsterAttackDistance()
	monsterGaugeGainM := adjustedMonsterGaugeGain(attackDistanceM, statContext.Effects)
	monsterAttackGaugeM := battle.MonsterAttackGaugeM + monsterGaugeGainM

	monsterDamage := 0
	monsterAttacked := false
	characterCurrentHP := battle.CharacterCurrentHP
	if characterCurrentHP <= 0 {
		characterCurrentHP = character.CurrentHP
	}

	status := "in_progress"
	rewardCoin := 0
	rewardExp := 0
	totalDamageTaken := battle.TotalDamageTaken

	if monsterCurrentHP <= 0 {
		status = "win"
		rewardCoin = randomCoin(monster.RewardCoinMin, monster.RewardCoinMax)
		stage, err := getStageByID(ctx, token, battle.Stage)
		if err != nil {
			return NormalBattleResponse{}, err
		}
		rewardCoin = normalBattleCoinReward(rewardCoin, stage.StageNo, progress, progressFound, combatPower(statContext.Stats))
		rewardExp = normalBattleExpReward(stage.StageNo, true, progress, progressFound, combatPower(statContext.Stats))
		if bossClearRequiresTicket(progress, progressFound) {
			if err := consumeBossEntranceTicket(ctx, token, character.ID); err != nil {
				return NormalBattleResponse{}, err
			}
			ticketConsumed = true
		}
		monsterAttackGaugeM = 0
	} else if monsterAttackGaugeM >= monsterAttackDistanceM {
		monsterAttacked = true
		monsterDamage = formulas.CalculateDamage(monster.Attack, statContext.Stats.Defense)
		monsterDamage = adjustedMonsterDamage(monsterDamage, statContext.Effects)
		characterCurrentHP -= monsterDamage
		if characterCurrentHP < 0 {
			characterCurrentHP = 0
		}
		totalDamageTaken += monsterDamage
		monsterAttackGaugeM -= monsterAttackDistanceM
		if characterCurrentHP <= 0 {
			status = "lose"
		}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	battlePayload := map[string]any{
		"status":                 status,
		"distance_used_m":        round2(battle.DistanceUsedM + attackDistanceM),
		"attack_count_used":      battle.AttackCountUsed + 1,
		"total_damage_dealt":     battle.TotalDamageDealt + playerDamage,
		"total_damage_taken":     totalDamageTaken,
		"reward_coin":            rewardCoin,
		"monster_current_hp":     monsterCurrentHP,
		"character_current_hp":   characterCurrentHP,
		"monster_attack_gauge_m": round2(monsterAttackGaugeM),
		"last_attacked_at":       now,
	}
	if status == "win" || status == "lose" {
		battlePayload["ended_at"] = now
	}

	attackCountBalance := character.AttackCountBalance - 1
	coinBalance := character.CoinBalance
	level := character.Level
	expBalance := character.Exp
	statExpBalance := character.StatExp
	statExpReward := 0
	if status == "win" {
		coinBalance += rewardCoin
		level, expBalance, statExpBalance, statExpReward = applyCharacterExpReward(level, expBalance, rewardExp, statExpBalance)
	}
	characterPersistHP := characterCurrentHP
	if status == "win" || status == "lose" || characterPersistHP <= 0 {
		characterPersistHP = characterMaxHP
	}

	updatedCharacter, err := patchBattleCharacter(ctx, token, character.ID, map[string]any{
		"attack_count_balance": attackCountBalance,
		"level":                level,
		"coin_balance":         coinBalance,
		"exp":                  expBalance,
		"stat_exp":             statExpBalance,
		"current_hp":           characterPersistHP,
	})
	if err != nil {
		return NormalBattleResponse{}, err
	}

	updatedBattle, err := patchBattle(ctx, token, battle.ID, battlePayload)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	var rewardItem any
	if status == "win" {
		if err := clearBossStage(ctx, token, character.ID, battle.Stage, now); err != nil {
			return NormalBattleResponse{}, err
		}
		if _, err := unlockBossEquipmentShopItemsForStage(ctx, token, battle.Stage); err != nil {
			log.Printf("failed to unlock boss equipment shop items: character=%s battle=%s stage=%s err=%v", character.ID, battle.ID, battle.Stage, err)
		}
		if err := syncUserBattleClearMissions(ctx, token, userID, now); err != nil {
			log.Printf("failed to sync boss stage clear missions: %v", err)
		}
		rewardItem, err = grantRandomBossEquipmentReward(ctx, token, character.ID, battle.Stage)
		if err != nil {
			log.Printf(
				"failed to grant boss equipment reward: character=%s battle=%s stage=%s err=%v",
				character.ID,
				battle.ID,
				battle.Stage,
				err,
			)
			rewardItem = nil
		}
	}

	recordNormalBattleLogs(ctx, token, character.ID, battle.ID, status, rewardCoin, rewardExp, statExpReward, attackCountBalance, coinBalance, expBalance, statExpBalance)

	return NormalBattleResponse{
		Battle:                 updatedBattle,
		Character:              updatedCharacter,
		CharacterMaxHP:         characterMaxHP,
		Monster:                monster,
		PlayerDamage:           playerDamage,
		MonsterDamage:          monsterDamage,
		MonsterAttacked:        monsterAttacked,
		RewardCoin:             rewardCoin,
		RewardExp:              rewardExp,
		StatExpReward:          statExpReward,
		RewardItem:             rewardItem,
		TicketConsumed:         ticketConsumed,
		AttackCountBalance:     attackCountBalance,
		MonsterAttackGaugeM:    round2(monsterAttackGaugeM),
		MonsterAttackDistanceM: round2(monsterAttackDistanceM),
	}, nil
}

func leaveNormalBattle(ctx context.Context, token string, userID string, req NormalBattleLeaveRequest) (NormalBattleResponse, error) {
	if req.BattleID == "" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle_id is required"}
	}

	unlockBattle := lockNormalBattle(req.BattleID)
	defer unlockBattle()

	battle, err := getBattleByID(ctx, token, req.BattleID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if battle.BattleType != "normal" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle is not normal type"}
	}

	character, err := getBattleCharacterByID(ctx, token, battle.Character)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.User != userID {
		return NormalBattleResponse{}, statusError{status: http.StatusForbidden, message: "battle does not belong to user"}
	}

	monster, err := getMonsterByID(ctx, token, battle.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	stats, err := getBattleCharacterStats(ctx, token, character.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	characterMaxHP, err := getBattleCharacterMaxHP(ctx, token, character.ID, stats)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	updatedBattle := battle
	updatedCharacter := character
	if battle.Status == "in_progress" {
		now := time.Now().UTC().Format(time.RFC3339)
		updatedBattle, err = patchBattle(ctx, token, battle.ID, map[string]any{
			"status":      "flee",
			"ended_at":    now,
			"reward_coin": 0,
		})
		if err != nil {
			return NormalBattleResponse{}, err
		}

		updatedCharacter, err = patchBattleCharacter(ctx, token, character.ID, map[string]any{
			"current_hp": characterMaxHP,
		})
		if err != nil {
			return NormalBattleResponse{}, err
		}
	}

	return NormalBattleResponse{
		Battle:                 updatedBattle,
		Character:              updatedCharacter,
		CharacterMaxHP:         characterMaxHP,
		Monster:                monster,
		RewardCoin:             0,
		AttackCountBalance:     updatedCharacter.AttackCountBalance,
		MonsterAttackGaugeM:    round2(updatedBattle.MonsterAttackGaugeM),
		MonsterAttackDistanceM: round2(formulas.CalculateMonsterAttackDistance()),
	}, nil
}

func leaveBossBattle(ctx context.Context, token string, userID string, req NormalBattleLeaveRequest) (NormalBattleResponse, error) {
	if req.BattleID == "" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle_id is required"}
	}

	unlockBattle := lockNormalBattle(req.BattleID)
	defer unlockBattle()

	battle, err := getBattleByID(ctx, token, req.BattleID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if battle.BattleType != "boss" {
		return NormalBattleResponse{}, statusError{status: http.StatusBadRequest, message: "battle is not boss type"}
	}

	character, err := getBattleCharacterByID(ctx, token, battle.Character)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.User != userID {
		return NormalBattleResponse{}, statusError{status: http.StatusForbidden, message: "battle does not belong to user"}
	}

	monster, err := getMonsterByID(ctx, token, battle.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	stats, err := getBattleCharacterStats(ctx, token, character.ID)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	characterMaxHP, err := getBattleCharacterMaxHP(ctx, token, character.ID, stats)
	if err != nil {
		return NormalBattleResponse{}, err
	}

	updatedBattle := battle
	updatedCharacter := character
	if battle.Status == "in_progress" {
		now := time.Now().UTC().Format(time.RFC3339)
		updatedBattle, err = patchBattle(ctx, token, battle.ID, map[string]any{
			"status":      "flee",
			"ended_at":    now,
			"reward_coin": 0,
		})
		if err != nil {
			return NormalBattleResponse{}, err
		}

		updatedCharacter, err = patchBattleCharacter(ctx, token, character.ID, map[string]any{
			"current_hp": characterMaxHP,
		})
		if err != nil {
			return NormalBattleResponse{}, err
		}
	}

	return NormalBattleResponse{
		Battle:                 updatedBattle,
		Character:              updatedCharacter,
		CharacterMaxHP:         characterMaxHP,
		Monster:                monster,
		RewardCoin:             0,
		AttackCountBalance:     updatedCharacter.AttackCountBalance,
		MonsterAttackGaugeM:    round2(updatedBattle.MonsterAttackGaugeM),
		MonsterAttackDistanceM: round2(formulas.CalculateMonsterAttackDistance()),
	}, nil
}

func resolveNormalStage(ctx context.Context, token string, req NormalBattleStartRequest) (stageRecord, error) {
	if req.StageID == "" {
		if req.StageNo <= 0 {
			return stageRecord{}, statusError{status: http.StatusBadRequest, message: "stage_id or stage_no is required"}
		}
		return getNormalStageByNo(ctx, token, req.StageNo)
	}

	stage, err := getStageByID(ctx, token, req.StageID)
	if err != nil {
		return stageRecord{}, err
	}
	if stage.StageType != "normal" || !stage.IsActive {
		return stageRecord{}, statusError{status: http.StatusBadRequest, message: "stage is not an active normal stage"}
	}
	return stage, nil
}

func resolveBossStage(ctx context.Context, token string, req NormalBattleStartRequest) (stageRecord, error) {
	if req.StageID == "" {
		stageNo := req.StageNo
		if stageNo <= 0 {
			stageNo = 5
		}
		return getBossStageByNo(ctx, token, stageNo)
	}

	stage, err := getStageByID(ctx, token, req.StageID)
	if err != nil {
		return stageRecord{}, err
	}
	if stage.StageType != "boss" || !stage.IsActive {
		return stageRecord{}, statusError{status: http.StatusBadRequest, message: "stage is not an active boss stage"}
	}
	return stage, nil
}

func buildCurrentNormalBattleResponse(
	ctx context.Context,
	token string,
	character battleCharacterRecord,
	characterMaxHP int,
	current battleRecord,
	requestedStageID string,
) (NormalBattleResponse, error) {
	if current.Stage != requestedStageID {
		return NormalBattleResponse{}, statusError{
			status:  http.StatusConflict,
			message: "another normal battle is already in progress",
		}
	}

	monster, err := getMonsterByID(ctx, token, current.Monster)
	if err != nil {
		return NormalBattleResponse{}, err
	}
	if character.CurrentHP <= 0 && current.CharacterCurrentHP > 0 {
		character, err = recoverBattleCharacterHP(ctx, token, character, current.CharacterCurrentHP)
		if err != nil {
			return NormalBattleResponse{}, err
		}
	}

	return NormalBattleResponse{
		Battle:             current,
		Character:          character,
		CharacterMaxHP:     characterMaxHP,
		Monster:            monster,
		AttackCountBalance: character.AttackCountBalance,
	}, nil
}

func buildStoredBattleResponse(
	character battleCharacterRecord,
	characterMaxHP int,
	battle battleRecord,
	monster monsterRecord,
) NormalBattleResponse {
	return NormalBattleResponse{
		Battle:                 battle,
		Character:              character,
		CharacterMaxHP:         characterMaxHP,
		Monster:                monster,
		RewardCoin:             battle.RewardCoin,
		AttackCountBalance:     character.AttackCountBalance,
		MonsterAttackGaugeM:    round2(battle.MonsterAttackGaugeM),
		MonsterAttackDistanceM: round2(formulas.CalculateMonsterAttackDistance()),
	}
}

func getBattleCharacterMaxHP(ctx context.Context, token string, characterID string, stats battleCharacterStatsRecord) (int, error) {
	statContext, err := getBattleStatContext(ctx, token, characterID, stats)
	if err != nil {
		return 0, err
	}
	return statContext.Stats.HP, nil
}

func recoverBattleCharacterHP(ctx context.Context, token string, character battleCharacterRecord, hp int) (battleCharacterRecord, error) {
	if hp <= 0 || character.CurrentHP == hp {
		return character, nil
	}
	return patchBattleCharacter(ctx, token, character.ID, map[string]any{
		"current_hp": hp,
	})
}

func finishBrokenNormalBattle(ctx context.Context, token string, current battleRecord) error {
	status := "lose"
	if current.MonsterCurrentHP <= 0 && current.CharacterCurrentHP > 0 {
		status = "win"
	}
	stats, err := getBattleCharacterStats(ctx, token, current.Character)
	if err != nil {
		return err
	}
	characterMaxHP, err := getBattleCharacterMaxHP(ctx, token, current.Character, stats)
	if err != nil {
		return err
	}
	_, err = patchBattle(ctx, token, current.ID, map[string]any{
		"status":               status,
		"monster_current_hp":   maxInt(current.MonsterCurrentHP, 0),
		"character_current_hp": maxInt(current.CharacterCurrentHP, 0),
		"ended_at":             time.Now().UTC().Format(time.RFC3339),
	})
	if err != nil {
		return err
	}
	_, err = patchBattleCharacter(ctx, token, current.Character, map[string]any{
		"current_hp": characterMaxHP,
	})
	return err
}

func ensureBossStageUnlocked(ctx context.Context, token string, characterID string, stage stageRecord) error {
	if stage.StageNo <= 1 {
		return nil
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
	return nil
}

func consumeBossEntranceTicket(ctx context.Context, token string, characterID string) error {
	consumable, err := getAvailableBossEntranceTicket(ctx, token, characterID)
	if err != nil {
		return err
	}
	_, err = patchCharacterConsumableQuantity(ctx, token, consumable.ID, consumable.Quantity-1)
	return err
}

func ensureBossEntranceTicketAvailable(ctx context.Context, token string, characterID string) error {
	_, err := getAvailableBossEntranceTicket(ctx, token, characterID)
	return err
}

func getAvailableBossEntranceTicket(ctx context.Context, token string, characterID string) (characterConsumableRecord, error) {
	ticket, err := findItemTemplateByName(ctx, token, bossEntranceTicketName)
	if err != nil {
		return characterConsumableRecord{}, err
	}
	consumable, err := getCharacterConsumable(ctx, token, characterID, ticket.ID)
	if err != nil {
		return characterConsumableRecord{}, bossEntranceTicketRequiredError()
	}
	if consumable.Quantity < 1 {
		return characterConsumableRecord{}, bossEntranceTicketRequiredError()
	}
	return consumable, nil
}

func bossEntranceTicketRequiredError() error {
	return statusError{status: http.StatusForbidden, message: "boss entrance ticket is required"}
}

func bossClearRequiresTicket(progress stageProgressRecord, progressFound bool) bool {
	return progressFound && progress.ClearCount > 0
}

func clearBossStage(ctx context.Context, token string, characterID string, stageID string, clearedAt string) error {
	stage, err := getStageByID(ctx, token, stageID)
	if err != nil {
		return err
	}
	if err := clearNormalStage(ctx, token, characterID, stage, clearedAt); err != nil {
		return err
	}
	return unlockNextNormalStageAfterBoss(ctx, token, characterID, stage.StageNo)
}

func unlockNextNormalStageAfterBoss(ctx context.Context, token string, characterID string, bossStageNo int) error {
	nextStage, err := getNormalStageByNo(ctx, token, bossStageNo+1)
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

func grantRandomBossEquipmentReward(ctx context.Context, token string, characterID string, stageID string) (any, error) {
	stage, err := getStageByID(ctx, token, stageID)
	if err != nil {
		return nil, err
	}
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	rarity := randomBossRewardRarity(rng)
	if rarity == "" {
		return nil, nil
	}
	templates, err := listBossRewardTemplates(ctx, token, rarity, stage.StageNo)
	if err != nil {
		return nil, err
	}
	if len(templates) == 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "boss epic equipment rewards are not configured"}
	}
	template := templates[rng.Intn(len(templates))]
	return createOwnedEquipment(ctx, token, characterID, template)
}

func randomBossRewardRarity(rng *rand.Rand) string {
	return bossRewardRarityForRoll(rng.Intn(100))
}

func bossRewardRarityForRoll(roll int) string {
	switch {
	case roll < 40:
		return ""
	default:
		return "epic"
	}
}

func findItemTemplateByName(ctx context.Context, token string, name string) (itemTemplateRecord, error) {
	filter := url.QueryEscape(fmt.Sprintf("name=%q && is_active=true", name))
	endpoint := pocketBaseCollectionURL(itemTemplatesCollection) + "?filter=" + filter + "&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return itemTemplateRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return itemTemplateRecord{}, mapPocketBaseError(resp, "failed to find item template")
	}

	var list pocketBaseListResponse[itemTemplateRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return itemTemplateRecord{}, errors.New("failed to parse item template response")
	}
	if len(list.Items) == 0 {
		return itemTemplateRecord{}, statusError{status: http.StatusNotFound, message: "item template not found"}
	}
	return list.Items[0], nil
}

func listBossRewardTemplates(ctx context.Context, token string, rarity string, stageNo int) ([]itemTemplateRecord, error) {
	filterValue := fmt.Sprintf("item_type=%q && is_active=true", "equipment")
	if rarity != "" {
		filterValue += fmt.Sprintf(" && rarity=%q", rarity)
	} else {
		filterValue += " && (rarity=\"common\" || rarity=\"rare\" || rarity=\"epic\")"
	}
	filter := url.QueryEscape(filterValue)
	endpoint := pocketBaseCollectionURL(itemTemplatesCollection) + "?filter=" + filter + "&sort=rarity,equipment_slot,price_coin&perPage=200"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list boss equipment rewards")
	}

	var list pocketBaseListResponse[itemTemplateRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse boss equipment rewards response")
	}
	rewards := make([]itemTemplateRecord, 0, len(list.Items))
	for _, item := range list.Items {
		if !isBossRewardTemplateForStage(item, stageNo) {
			continue
		}
		switch item.EquipmentSlot {
		case "sword", "helmet", "armor", "shoes":
			rewards = append(rewards, item)
		}
	}
	return rewards, nil
}

func isBossRewardTemplateForStage(template itemTemplateRecord, stageNo int) bool {
	chapter := equipmentShopChapterForBossStageNo(stageNo)
	if chapter <= 0 {
		chapter = 1
	}
	return equipmentShopChapter(template) == chapter && isSupportedChapterEpicTemplate(template)
}

func lockNormalBattle(battleID string) func() {
	lockValue, _ := normalBattleLocks.LoadOrStore(battleID, &sync.Mutex{})
	lock := lockValue.(*sync.Mutex)
	lock.Lock()
	return lock.Unlock
}

func recordNormalBattleLogs(
	ctx context.Context,
	token string,
	characterID string,
	battleID string,
	status string,
	rewardCoin int,
	rewardExp int,
	statExpReward int,
	attackCountBalance int,
	coinBalance int,
	expBalance int,
	statExpBalance int,
) {
	if err := createBattleResourceTransaction(ctx, token, characterID, battleID, "attack_count", "use", -1, attackCountBalance, "normal battle attack"); err != nil {
		log.Printf("failed to create normal battle attack_count transaction: %v", err)
	}

	if status != "win" || rewardCoin <= 0 {
		return
	}

	if err := createRewardLog(ctx, token, characterID, battleID, rewardCoin); err != nil {
		log.Printf("failed to create normal battle reward log: %v", err)
	}
	if err := createBattleResourceTransaction(ctx, token, characterID, battleID, "coin", "reward", rewardCoin, coinBalance, "normal battle reward"); err != nil {
		log.Printf("failed to create normal battle coin transaction: %v", err)
	}
	if rewardExp > 0 {
		if err := createBattleResourceTransaction(ctx, token, characterID, battleID, "exp", "reward", rewardExp, expBalance, "normal battle exp reward"); err != nil {
			log.Printf("failed to create normal battle exp transaction: %v", err)
		}
	}
	if statExpReward > 0 {
		if err := createBattleResourceTransaction(ctx, token, characterID, battleID, "stat_exp", "reward", statExpReward, statExpBalance, "level up stat exp reward"); err != nil {
			log.Printf("failed to create level up stat_exp transaction: %v", err)
		}
	}
}

const (
	rewardPowerThresholdPercent = 40
	rewardPowerBracketPercent   = 20
)

var recommendedCombatPowerByStage = map[int]int{
	1:  150,
	2:  180,
	3:  230,
	4:  280,
	5:  360,
	6:  300,
	7:  420,
	8:  540,
	9:  680,
	10: 820,
	11: 900,
	12: 1050,
	13: 1220,
	14: 1400,
	15: 1650,
}

func normalBattleExpReward(stageNo int, isBoss bool, progress stageProgressRecord, progressFound bool, characterCombatPower int) int {
	if stageNo < 1 {
		stageNo = 1
	}
	base := ceilDiv(stageNo*100, 3)
	if isBoss {
		base = ceilDiv(stageNo*100, 2)
	}

	if !progressFound || progress.ClearCount <= 0 {
		return ceilDiv(base*3, 2)
	}

	repeatPercent := combatPowerAdjustedRepeatPercent(60, 20, 10, stageNo, characterCombatPower)
	return ceilDiv(base*repeatPercent, 100)
}

func normalBattleCoinReward(baseCoin int, stageNo int, progress stageProgressRecord, progressFound bool, characterCombatPower int) int {
	if baseCoin <= 0 {
		return 0
	}
	if stageNo < 1 {
		stageNo = 1
	}
	if !progressFound || progress.ClearCount <= 0 {
		return baseCoin
	}

	repeatPercent := combatPowerAdjustedRepeatPercent(50, 15, 5, stageNo, characterCombatPower)
	return ceilDiv(baseCoin*repeatPercent, 100)
}

func combatPowerAdjustedRepeatPercent(basePercent int, minPercent int, penaltyPerBracket int, stageNo int, characterCombatPower int) int {
	if characterCombatPower <= 0 {
		return basePercent
	}
	recommendedPower := recommendedCombatPowerForStage(stageNo)
	if recommendedPower <= 0 || characterCombatPower <= recommendedPower {
		return basePercent
	}

	overPercent := ((characterCombatPower - recommendedPower) * 100) / recommendedPower
	if overPercent <= rewardPowerThresholdPercent {
		return basePercent
	}

	brackets := ((overPercent - rewardPowerThresholdPercent - 1) / rewardPowerBracketPercent) + 1
	repeatPercent := basePercent - (brackets * penaltyPerBracket)
	if repeatPercent < minPercent {
		return minPercent
	}
	return repeatPercent
}

func recommendedCombatPowerForStage(stageNo int) int {
	if stageNo < 1 {
		stageNo = 1
	}
	if power, ok := recommendedCombatPowerByStage[stageNo]; ok {
		return power
	}

	chapter := ((stageNo - 1) / 5) + 1
	chapterStageNo := ((stageNo - 1) % 5) + 1
	power := 1100 + ((chapter - 2) * 550) + ((chapterStageNo - 1) * 140)
	if power < 150 {
		return 150
	}
	return power
}

func combatPower(stats statBlock) int {
	power := math.Round(float64(stats.HP)/3 + float64(stats.Attack*8+stats.Defense*5+stats.Agility*4))
	if power < 0 {
		return 0
	}
	return int(power)
}
func ceilDiv(numerator int, denominator int) int {
	if denominator <= 0 {
		return 0
	}
	if numerator <= 0 {
		return 0
	}
	return (numerator + denominator - 1) / denominator
}

func applyCharacterExpReward(level int, exp int, rewardExp int, statExp int) (int, int, int, int) {
	if level < 1 {
		level = 1
	}
	if rewardExp <= 0 {
		return level, exp, statExp, 0
	}
	exp += rewardExp
	statExpReward := 0
	for exp >= level*100 {
		exp -= level * 100
		level++
		statExpReward += statExpRewardForLevel(level)
	}
	return level, exp, statExp + statExpReward, statExpReward
}

func statExpRewardForLevel(level int) int {
	if level < 2 {
		return 0
	}
	return 40 + ((level - 1) / 5 * 10)
}

func randomCoin(min int, max int) int {
	if min <= 0 && max <= 0 {
		return 0
	}
	if max < min {
		max = min
	}
	return rand.New(rand.NewSource(time.Now().UnixNano())).Intn(max-min+1) + min
}
