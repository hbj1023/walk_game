import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import 'equipment_image_resolver.dart';
import 'game_state.dart';

class GameApiException implements Exception {
  final String message;
  const GameApiException(this.message);

  @override
  String toString() => message;
}

class ItemTemplate {
  final String id;
  final String name;
  final String itemType;
  final String equipmentSlot;
  final String weaponType;
  final String setKey;
  final String setPieceType;
  final String imagePath;
  final String rarity;
  final int recoverHp;
  final int baseHp;
  final int baseAttack;
  final int baseDefense;
  final int baseAgility;
  final int priceCoin;
  final bool isActive;

  const ItemTemplate({
    required this.id,
    required this.name,
    required this.itemType,
    required this.equipmentSlot,
    required this.weaponType,
    required this.setKey,
    required this.setPieceType,
    required this.imagePath,
    required this.rarity,
    required this.recoverHp,
    required this.baseHp,
    required this.baseAttack,
    required this.baseDefense,
    required this.baseAgility,
    required this.priceCoin,
    required this.isActive,
  });

  factory ItemTemplate.fromJson(Map<String, dynamic> json) {
    return ItemTemplate(
      id: _asString(json['id']),
      name: _asString(json['name']),
      itemType: _asString(json['item_type']),
      equipmentSlot: _asString(json['equipment_slot']),
      weaponType: _asString(json['weapon_type']),
      setKey: _asString(json['set_key']),
      setPieceType: _asString(json['set_piece_type']),
      imagePath: _asString(json['image_path']),
      rarity: _asString(json['rarity']),
      recoverHp: _asInt(json['recover_hp']),
      baseHp: _asInt(json['base_hp']),
      baseAttack: _asInt(json['base_attack']),
      baseDefense: _asInt(json['base_defense']),
      baseAgility: _asInt(json['base_agility']),
      priceCoin: _asInt(json['price_coin']),
      isActive: json['is_active'] == true,
    );
  }

  bool get isEquipment => itemType == 'equipment';
  bool get isConsumable => itemType == 'consumable';
  bool get isWeapon => equipmentSlot == 'sword';

  String get displayImagePath => resolveEquipmentImagePath(
    imagePath: imagePath,
    itemType: itemType,
    equipmentSlot: equipmentSlot,
    weaponType: weaponType,
    setKey: setKey,
    setPieceType: setPieceType,
    name: name,
  );

  String get inferredSetKey {
    if (setKey.isNotEmpty) return setKey;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('vanguard') || name.contains('모험가')) {
      return 'vanguard';
    }
    if (lowerName.contains('berserker') || name.contains('광전사')) {
      return 'berserker';
    }
    if (lowerName.contains('sentinel') || name.contains('창술사')) {
      return 'sentinel';
    }
    if (lowerName.contains('shadow') || name.contains('도적')) {
      return 'shadow';
    }
    if (lowerName.contains('colossus') || name.contains('견습기사')) {
      return 'colossus';
    }
    return '';
  }

  String get inferredPieceType {
    if (setPieceType.isNotEmpty) return setPieceType;
    if (isWeapon) return 'weapon';
    if (equipmentSlot.isNotEmpty) return equipmentSlot;

    final lowerName = name.toLowerCase();
    if (lowerName.contains('helm') ||
        name.contains('투구') ||
        name.contains('두건')) {
      return 'helmet';
    }
    if (lowerName.contains('armor') || name.contains('갑옷')) return 'armor';
    if (lowerName.contains('boots') || name.contains('장화')) return 'shoes';
    return '';
  }

  String get weaponTypeLabel {
    return switch (weaponType) {
      'sword' => '검',
      'axe' => '도끼',
      'spear' => '창',
      'dagger' => '단검',
      'greatsword' => '대검',
      _ => '',
    };
  }

  String get slotLabel {
    return switch (equipmentSlot) {
      'helmet' => '투구',
      'armor' => '갑옷',
      'sword' => '무기',
      'shoes' => '신발',
      _ => '기타',
    };
  }

  String get statSummary {
    final parts = <String>[];
    if (isWeapon && weaponTypeLabel.isNotEmpty) parts.add(weaponTypeLabel);
    if (baseHp > 0) parts.add('HP +$baseHp');
    if (baseAttack > 0) parts.add('공격 +$baseAttack');
    if (baseDefense > 0) parts.add('방어 +$baseDefense');
    if (baseAgility > 0) parts.add('민첩 +$baseAgility');
    if (recoverHp > 0) parts.add('회복 +$recoverHp');
    return parts.isEmpty ? '기본 아이템' : parts.join(' / ');
  }
}

class Shop {
  final String id;
  final String name;
  final String shopType;

  const Shop({required this.id, required this.name, required this.shopType});

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _asString(json['id']),
      name: _asString(json['name']),
      shopType: _asString(json['shop_type']),
    );
  }
}

class ShopItem {
  final String id;
  final String shopId;
  final int priceCoin;
  final int stockLimit;
  final int purchaseLimitPerUser;
  final bool isActive;
  final ItemTemplate itemTemplate;

  const ShopItem({
    required this.id,
    required this.shopId,
    required this.priceCoin,
    required this.stockLimit,
    required this.purchaseLimitPerUser,
    required this.isActive,
    required this.itemTemplate,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    final expand = _asMap(json['expand']);
    return ShopItem(
      id: _asString(json['id']),
      shopId: _asString(json['shop']),
      priceCoin: _asInt(json['price_coin']),
      stockLimit: _asInt(json['stock_limit']),
      purchaseLimitPerUser: _asInt(json['purchase_limit_per_user']),
      isActive: json['is_active'] == true,
      itemTemplate: ItemTemplate.fromJson(_asMap(expand['item_template'])),
    );
  }
}

class OwnedInventoryItem {
  final String id;
  final String status;
  final int quantity;
  final ItemTemplate itemTemplate;

  const OwnedInventoryItem({
    required this.id,
    required this.status,
    required this.quantity,
    required this.itemTemplate,
  });

  bool get isEquipped => status == 'equipped';
  bool get isRemoved => status == 'sold' || status == 'deleted';

  factory OwnedInventoryItem.equipment(Map<String, dynamic> json) {
    final expand = _asMap(json['expand']);
    return OwnedInventoryItem(
      id: _asString(json['id']),
      status: _asString(json['status']).isEmpty
          ? 'owned'
          : _asString(json['status']),
      quantity: 1,
      itemTemplate: ItemTemplate.fromJson(_asMap(expand['item_template'])),
    );
  }

  factory OwnedInventoryItem.consumable(Map<String, dynamic> json) {
    final expand = _asMap(json['expand']);
    return OwnedInventoryItem(
      id: _asString(json['id']),
      status: 'owned',
      quantity: _asInt(json['quantity']),
      itemTemplate: ItemTemplate.fromJson(_asMap(expand['item_template'])),
    );
  }
}

class ConsumableUseResult {
  final int remainingQuantity;
  final int recoveredHp;
  final int? characterCurrentHp;
  final int? battleCharacterCurrentHp;

  const ConsumableUseResult({
    required this.remainingQuantity,
    required this.recoveredHp,
    required this.characterCurrentHp,
    required this.battleCharacterCurrentHp,
  });

  factory ConsumableUseResult.fromJson(Map<String, dynamic> json) {
    final character = _asMap(json['character']);
    final battle = _asMap(json['battle']);
    return ConsumableUseResult(
      remainingQuantity: _asInt(json['remaining_quantity']),
      recoveredHp: _asInt(json['recovered_hp']),
      characterCurrentHp: character.isEmpty
          ? null
          : _asInt(character['current_hp']),
      battleCharacterCurrentHp: battle.isEmpty
          ? null
          : _asInt(battle['character_current_hp']),
    );
  }
}

class StatUpgradeSummary {
  final Map<String, int> currentStats;
  final Map<String, int> costs;
  final Map<String, int> upgradedStats;
  final int exp;
  final int statExp;
  final String resourceType;

  const StatUpgradeSummary({
    required this.currentStats,
    required this.costs,
    required this.upgradedStats,
    required this.exp,
    required this.statExp,
    required this.resourceType,
  });

  factory StatUpgradeSummary.fromJson(Map<String, dynamic> json) {
    return StatUpgradeSummary(
      currentStats: _intMap(_asMap(json['current_stats'])),
      costs: _intMap(_asMap(json['costs'])),
      upgradedStats: _intMap(_asMap(json['upgraded_stats'])),
      exp: _asInt(json['exp']),
      statExp: json.containsKey('stat_exp')
          ? _asInt(json['stat_exp'])
          : _asInt(json['exp']),
      resourceType: _asString(json['resource_type']).isEmpty
          ? 'stat_exp'
          : _asString(json['resource_type']),
    );
  }
}

class CharacterStatsSummary {
  final Map<String, int> baseStats;
  final Map<String, int> upgradeStats;
  final Map<String, int> equipmentStats;
  final Map<String, int> setBonusStats;
  final Map<String, int> finalStats;
  final int equippedItemCount;
  final int activeSetBonusCount;

  const CharacterStatsSummary({
    required this.baseStats,
    required this.upgradeStats,
    required this.equipmentStats,
    required this.setBonusStats,
    required this.finalStats,
    required this.equippedItemCount,
    required this.activeSetBonusCount,
  });

  factory CharacterStatsSummary.fromJson(Map<String, dynamic> json) {
    return CharacterStatsSummary(
      baseStats: _intMap(_asMap(json['base_stats'])),
      upgradeStats: _intMap(_asMap(json['upgrade_stats'])),
      equipmentStats: _intMap(_asMap(json['equipment_stats'])),
      setBonusStats: _intMap(_asMap(json['set_bonus_stats'])),
      finalStats: _intMap(_asMap(json['final_stats'])),
      equippedItemCount: _asListOfMaps(json['equipped_items']).length,
      activeSetBonusCount: _asListOfMaps(json['active_set_bonuses']).length,
    );
  }
}

class UserMission {
  final String id;
  final String title;
  final String missionType;
  final String targetType;
  final double targetValue;
  final double progressValue;
  final int rewardCoin;
  final String status;

  const UserMission({
    required this.id,
    required this.title,
    required this.missionType,
    required this.targetType,
    required this.targetValue,
    required this.progressValue,
    required this.rewardCoin,
    required this.status,
  });

  factory UserMission.fromJson(Map<String, dynamic> json) {
    final mission = _asMap(_asMap(json['expand'])['mission']);
    return UserMission(
      id: _asString(json['id']),
      title: _asString(mission['title']).isEmpty
          ? '미션'
          : _asString(mission['title']),
      missionType: _asString(mission['mission_type']),
      targetType: _asString(mission['target_type']),
      targetValue: _asDouble(mission['target_value']),
      progressValue: _asDouble(json['progress_value']),
      rewardCoin: _asInt(mission['reward_coin']),
      status: _asString(json['status']),
    );
  }

  double get progress {
    if (targetValue <= 0) return 0;
    return (progressValue / targetValue).clamp(0.0, 1.0);
  }

  bool get canClaim => status == 'completed';
  bool get isClaimed => status == 'claimed';
  bool get isWeekly => missionType == 'weekly';
  String get unit => targetType == 'distance' ? 'm' : '회';

  int get displayOrder {
    final target = targetValue.round();
    if (isWeekly) {
      return switch (targetType) {
        'boss_stage_clear' => target,
        'distance' => 100000 + target,
        'normal_stage_clear' => 200000 + target,
        _ => 300000 + target,
      };
    }
    return switch (targetType) {
      'distance' => target,
      'normal_stage_clear' => 100000 + target,
      'boss_stage_clear' => 200000 + target,
      _ => 300000 + target,
    };
  }
}

class StepSyncResult {
  final String recordDate;
  final int stepCount;
  final int distanceM;
  final int deltaStepCount;
  final int deltaDistanceM;
  final double attackDistanceM;
  final double attackDistanceRemainderM;
  final int attackCountEarned;
  final int attackCountBalance;
  final int offlineAttackCountCap;
  final int offlineAttackCountEarned;
  final int offlineAttackCountStored;
  final int offlineAttackCountLost;

  const StepSyncResult({
    required this.recordDate,
    required this.stepCount,
    required this.distanceM,
    required this.deltaStepCount,
    required this.deltaDistanceM,
    required this.attackDistanceM,
    required this.attackDistanceRemainderM,
    required this.attackCountEarned,
    required this.attackCountBalance,
    required this.offlineAttackCountCap,
    required this.offlineAttackCountEarned,
    required this.offlineAttackCountStored,
    required this.offlineAttackCountLost,
  });

  factory StepSyncResult.fromJson(Map<String, dynamic> json) {
    return StepSyncResult(
      recordDate: _asString(json['record_date']),
      stepCount: _asInt(json['step_count']),
      distanceM: _asInt(json['distance_m']),
      deltaStepCount: _asInt(json['delta_step_count']),
      deltaDistanceM: _asInt(json['delta_distance_m']),
      attackDistanceM: _asDouble(json['attack_distance_m']),
      attackDistanceRemainderM: _asDouble(json['attack_distance_remainder_m']),
      attackCountEarned: _asInt(json['attack_count_earned']),
      attackCountBalance: _asInt(json['attack_count_balance']),
      offlineAttackCountCap: _asInt(json['offline_attack_count_cap']),
      offlineAttackCountEarned: _asInt(json['offline_attack_count_earned']),
      offlineAttackCountStored: _asInt(json['offline_attack_count_stored']),
      offlineAttackCountLost: _asInt(json['offline_attack_count_lost']),
    );
  }
}

class ExplorationUpgradeSummary {
  final int coinBalance;
  final Map<String, ExplorationUpgradeInfo> upgrades;
  final bool serverAvailable;

  const ExplorationUpgradeSummary({
    required this.coinBalance,
    required this.upgrades,
    required this.serverAvailable,
  });

  factory ExplorationUpgradeSummary.fromJson(Map<String, dynamic> json) {
    final upgradeMap = _asMap(json['upgrades']);
    return ExplorationUpgradeSummary(
      coinBalance: _asInt(json['coin_balance']),
      serverAvailable: true,
      upgrades: upgradeMap.map(
        (key, value) =>
            MapEntry(key, ExplorationUpgradeInfo.fromJson(_asMap(value))),
      ),
    );
  }

  factory ExplorationUpgradeSummary.defaults({required int coinBalance}) {
    return ExplorationUpgradeSummary(
      coinBalance: coinBalance,
      serverAvailable: false,
      upgrades: const {
        'offline_storage': ExplorationUpgradeInfo(
          level: 0,
          maxLevel: 5,
          costCoin: 150,
          currentValue: 10,
          nextValue: 15,
          valueUnit: '회',
          title: '공격기회 보관함',
          description: '앱을 꺼둔 동안 쌓을 수 있는 공격기회 최대치를 늘립니다.',
        ),
        'offline_efficiency': ExplorationUpgradeInfo(
          level: 0,
          maxLevel: 5,
          costCoin: 250,
          currentValue: 30,
          nextValue: 26,
          valueUnit: '%',
          title: '탐험 효율',
          description: '오프라인 걷기에서 추가로 더 걸어야 하는 부담을 줄입니다.',
        ),
      },
    );
  }
}

class ExplorationUpgradeInfo {
  final int level;
  final int maxLevel;
  final int costCoin;
  final int currentValue;
  final int nextValue;
  final String valueUnit;
  final String title;
  final String description;

  const ExplorationUpgradeInfo({
    required this.level,
    required this.maxLevel,
    required this.costCoin,
    required this.currentValue,
    required this.nextValue,
    required this.valueUnit,
    required this.title,
    required this.description,
  });

  bool get isMaxed => level >= maxLevel;

  factory ExplorationUpgradeInfo.fromJson(Map<String, dynamic> json) {
    return ExplorationUpgradeInfo(
      level: _asInt(json['level']),
      maxLevel: _asInt(json['max_level']),
      costCoin: _asInt(json['cost_coin']),
      currentValue: _asInt(json['current_value']),
      nextValue: _asInt(json['next_value']),
      valueUnit: _asString(json['value_unit']),
      title: _asString(json['title']),
      description: _asString(json['description']),
    );
  }
}

class RaidMonsterInfo {
  final String id;
  final String name;
  final String monsterType;
  final int hp;
  final int attack;
  final int defense;
  final int agility;
  final int rewardCoinMin;
  final int rewardCoinMax;
  final bool isActive;

  const RaidMonsterInfo({
    required this.id,
    required this.name,
    required this.monsterType,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.agility,
    required this.rewardCoinMin,
    required this.rewardCoinMax,
    required this.isActive,
  });

  factory RaidMonsterInfo.fromJson(Map<String, dynamic> json) {
    return RaidMonsterInfo(
      id: _asString(json['id']),
      name: _asString(json['name']),
      monsterType: _asString(json['monster_type']),
      hp: _asInt(json['hp']),
      attack: _asInt(json['attack']),
      defense: _asInt(json['defense']),
      agility: _asInt(json['agility']),
      rewardCoinMin: _asInt(json['reward_coin_min']),
      rewardCoinMax: _asInt(json['reward_coin_max']),
      isActive: json['is_active'] != false,
    );
  }
}

class RaidRecordInfo {
  final String id;
  final String hostCharacterId;
  final String monsterId;
  final String title;
  final String description;
  final int maxParticipants;
  final String status;
  final int rewardCoin;
  final RaidMonsterInfo? monster;

  const RaidRecordInfo({
    required this.id,
    required this.hostCharacterId,
    required this.monsterId,
    required this.title,
    required this.description,
    required this.maxParticipants,
    required this.status,
    required this.rewardCoin,
    required this.monster,
  });

  factory RaidRecordInfo.fromJson(Map<String, dynamic> json) {
    final expand = _asMap(json['expand']);
    final monsterMap = _asMap(expand['monster']);
    return RaidRecordInfo(
      id: _asString(json['id']),
      hostCharacterId: _asString(json['host_character']),
      monsterId: _asString(json['monster']),
      title: _asString(json['title']),
      description: _asString(json['description']),
      maxParticipants: _asInt(json['max_participants']),
      status: _asString(json['status']),
      rewardCoin: _asInt(json['reward_coin']),
      monster: monsterMap.isEmpty ? null : RaidMonsterInfo.fromJson(monsterMap),
    );
  }
}

class RaidProgressInfo {
  final String id;
  final String raidId;
  final double monsterCurrentHp;
  final double totalDistanceAccumulatedM;
  final double distanceSinceLastAttackCycleM;
  final double distanceSinceLastMonsterAttackM;
  final int totalAttackCycles;
  final int totalMonsterAttackCycles;
  final String status;
  final String startedAt;
  final String endedAt;

  const RaidProgressInfo({
    required this.id,
    required this.raidId,
    required this.monsterCurrentHp,
    required this.totalDistanceAccumulatedM,
    required this.distanceSinceLastAttackCycleM,
    required this.distanceSinceLastMonsterAttackM,
    required this.totalAttackCycles,
    required this.totalMonsterAttackCycles,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  factory RaidProgressInfo.fromJson(Map<String, dynamic> json) {
    return RaidProgressInfo(
      id: _asString(json['id']),
      raidId: _asString(json['raid']),
      monsterCurrentHp: _asDouble(json['monster_current_hp']),
      totalDistanceAccumulatedM: _asDouble(
        json['total_distance_accumulated_m'],
      ),
      distanceSinceLastAttackCycleM: _asDouble(
        json['distance_since_last_attack_cycle_m'],
      ),
      distanceSinceLastMonsterAttackM: _asDouble(
        json['distance_since_last_monster_attack_m'],
      ),
      totalAttackCycles: _asInt(json['total_attack_cycles']),
      totalMonsterAttackCycles: _asInt(json['total_monster_attack_cycles']),
      status: _asString(json['status']),
      startedAt: _asString(json['started_at']),
      endedAt: _asString(json['ended_at']),
    );
  }

  bool get isFinished =>
      status == 'cleared' || status == 'failed' || status == 'canceled';
}

class RaidParticipantInfo {
  final String id;
  final String raidId;
  final String characterId;
  final double contributionDamage;
  final double contributionDistanceM;
  final int contributionAttackCount;
  final String joinStatus;
  final String characterName;
  final String userName;
  final String userNickname;
  final String userUsername;
  final String userEmail;
  final int characterCurrentHp;
  final int characterMaxHp;

  const RaidParticipantInfo({
    required this.id,
    required this.raidId,
    required this.characterId,
    required this.contributionDamage,
    required this.contributionDistanceM,
    required this.contributionAttackCount,
    required this.joinStatus,
    required this.characterName,
    required this.userName,
    required this.userNickname,
    required this.userUsername,
    required this.userEmail,
    required this.characterCurrentHp,
    required this.characterMaxHp,
  });

  factory RaidParticipantInfo.fromJson(Map<String, dynamic> json) {
    final expand = _asMap(json['expand']);
    final characterMap = _asMap(expand['character']);
    final characterExpand = _asMap(characterMap['expand']);
    final userMap = _asMap(characterExpand['user']);
    return RaidParticipantInfo(
      id: _asString(json['id']),
      raidId: _asString(json['raid']),
      characterId: _asString(json['character']),
      contributionDamage: _asDouble(json['contribution_damage']),
      contributionDistanceM: _asDouble(json['contribution_distance_m']),
      contributionAttackCount: _asInt(json['contribution_attack_count']),
      joinStatus: _asString(json['join_status']),
      characterName: _firstNonEmpty([
        _asString(json['character_name']),
        _asString(characterMap['name']),
      ]),
      userName: _firstNonEmpty([
        _asString(json['user_name']),
        _asString(userMap['name']),
      ]),
      userNickname: _firstNonEmpty([
        _asString(json['user_nickname']),
        _asString(userMap['nickname']),
      ]),
      userUsername: _firstNonEmpty([
        _asString(json['user_username']),
        _asString(userMap['username']),
      ]),
      userEmail: _firstNonEmpty([
        _asString(json['user_email']),
        _asString(userMap['email']),
      ]),
      characterCurrentHp: _asInt(json['character_current_hp']),
      characterMaxHp: _asInt(json['character_max_hp']),
    );
  }

  String get displayLabel {
    if (userNickname.isNotEmpty) return userNickname;
    if (userName.isNotEmpty) return userName;
    if (userUsername.isNotEmpty) return userUsername;
    if (characterName.isNotEmpty) return characterName;
    if (userEmail.isNotEmpty) return userEmail;
    return '친구';
  }
}

class RaidProgressSummary {
  final RaidRecordInfo raid;
  final RaidProgressInfo progress;
  final RaidMonsterInfo? monster;
  final List<RaidParticipantInfo> participants;
  final List<RaidInvitationInfo> invitations;
  final int pendingInvitationCount;
  final int participantCount;
  final int activeParticipants;
  final int teamAgility;
  final double attackDistanceM;
  final double monsterAttackDistanceM;
  final String lobbyPath;

  const RaidProgressSummary({
    required this.raid,
    required this.progress,
    required this.monster,
    required this.participants,
    required this.invitations,
    required this.pendingInvitationCount,
    required this.participantCount,
    required this.activeParticipants,
    required this.teamAgility,
    required this.attackDistanceM,
    required this.monsterAttackDistanceM,
    required this.lobbyPath,
  });

  factory RaidProgressSummary.fromJson(Map<String, dynamic> json) {
    final raid = RaidRecordInfo.fromJson(_asMap(json['raid']));
    final monsterMap = _asMap(json['monster']);
    final participants = _asListOfMaps(json['participants'])
        .map(RaidParticipantInfo.fromJson)
        .where((participant) => participant.id.isNotEmpty)
        .toList();
    final invitations = _asListOfMaps(json['invitations'])
        .map(RaidInvitationInfo.fromJson)
        .where((invitation) => invitation.id.isNotEmpty)
        .toList();
    return RaidProgressSummary(
      raid: raid,
      progress: RaidProgressInfo.fromJson(_asMap(json['progress'])),
      monster: monsterMap.isNotEmpty
          ? RaidMonsterInfo.fromJson(monsterMap)
          : raid.monster,
      participants: participants,
      invitations: invitations,
      pendingInvitationCount: _asInt(json['pending_invitation_count']) > 0
          ? _asInt(json['pending_invitation_count'])
          : invitations.where((invitation) => invitation.isPending).length,
      participantCount: _asInt(json['participant_count']) > 0
          ? _asInt(json['participant_count'])
          : participants.length,
      activeParticipants: _asInt(json['active_participants']) > 0
          ? _asInt(json['active_participants'])
          : participants
                .where((participant) => participant.joinStatus == 'joined')
                .length,
      teamAgility: _asInt(json['team_agility']),
      attackDistanceM: _asDouble(json['attack_distance_m']),
      monsterAttackDistanceM: _asDouble(json['monster_attack_distance_m']),
      lobbyPath: _asString(json['lobby_path']),
    );
  }
}

class RaidDistanceResult {
  final RaidRecordInfo raid;
  final RaidProgressInfo progress;
  final RaidParticipantInfo? participant;
  final int attackCycles;
  final int totalAttackCount;
  final int damageDealt;
  final int monsterAttackCycles;
  final int monsterDamageDealt;
  final List<String> defeatedParticipants;
  final int activeParticipants;
  final int teamAgility;
  final double attackDistanceM;
  final double monsterAttackDistanceM;

  const RaidDistanceResult({
    required this.raid,
    required this.progress,
    required this.participant,
    required this.attackCycles,
    required this.totalAttackCount,
    required this.damageDealt,
    required this.monsterAttackCycles,
    required this.monsterDamageDealt,
    required this.defeatedParticipants,
    required this.activeParticipants,
    required this.teamAgility,
    required this.attackDistanceM,
    required this.monsterAttackDistanceM,
  });

  factory RaidDistanceResult.fromJson(Map<String, dynamic> json) {
    final participantMap = _asMap(json['participant']);
    final defeated = json['defeated_participants'];
    return RaidDistanceResult(
      raid: RaidRecordInfo.fromJson(_asMap(json['raid'])),
      progress: RaidProgressInfo.fromJson(_asMap(json['progress'])),
      participant: participantMap.isEmpty
          ? null
          : RaidParticipantInfo.fromJson(participantMap),
      attackCycles: _asInt(json['attack_cycles']),
      totalAttackCount: _asInt(json['total_attack_count']),
      damageDealt: _asInt(json['damage_dealt']),
      monsterAttackCycles: _asInt(json['monster_attack_cycles']),
      monsterDamageDealt: _asInt(json['monster_damage_dealt']),
      defeatedParticipants: defeated is List
          ? defeated.map((value) => _asString(value)).toList()
          : const [],
      activeParticipants: _asInt(json['active_participants']),
      teamAgility: _asInt(json['team_agility']),
      attackDistanceM: _asDouble(json['attack_distance_m']),
      monsterAttackDistanceM: _asDouble(json['monster_attack_distance_m']),
    );
  }
}

class RaidInvitationInfo {
  final String id;
  final String raidId;
  final String inviterCharacterId;
  final String invitedUserId;
  final String status;
  final RaidRecordInfo? raid;
  final RaidMonsterInfo? monster;
  final String inviterName;
  final String inviterEmail;
  final String invitedUserName;
  final String invitedUserEmail;

  const RaidInvitationInfo({
    required this.id,
    required this.raidId,
    required this.inviterCharacterId,
    required this.invitedUserId,
    required this.status,
    required this.raid,
    required this.monster,
    required this.inviterName,
    required this.inviterEmail,
    required this.invitedUserName,
    required this.invitedUserEmail,
  });

  factory RaidInvitationInfo.fromJson(Map<String, dynamic> json) {
    final expand = _asMap(json['expand']);
    final raidMap = _asMap(expand['raid']);
    final raid = raidMap.isEmpty ? null : RaidRecordInfo.fromJson(raidMap);
    final raidExpand = _asMap(raidMap['expand']);
    final monsterMap = _asMap(raidExpand['monster']);
    final directMonsterMap = _asMap(expand['raid.monster']);
    final inviterCharacterMap = _asMap(expand['inviter_character']);
    final inviterCharacterExpand = _asMap(inviterCharacterMap['expand']);
    final inviterUserMap = _asMap(inviterCharacterExpand['user']);
    final directInviterUserMap = _asMap(expand['inviter_character.user']);
    final invitedUserMap = _asMap(expand['invited_user']);
    final monster = monsterMap.isNotEmpty
        ? RaidMonsterInfo.fromJson(monsterMap)
        : directMonsterMap.isNotEmpty
        ? RaidMonsterInfo.fromJson(directMonsterMap)
        : raid?.monster;
    return RaidInvitationInfo(
      id: _asString(json['id']),
      raidId: _asString(json['raid']),
      inviterCharacterId: _asString(json['inviter_character']),
      invitedUserId: _asString(json['invited_user']),
      status: _asString(json['status']),
      raid: raid,
      monster: monster,
      inviterName: _firstNonEmpty([
        _asString(inviterUserMap['nickname']),
        _asString(directInviterUserMap['nickname']),
        _asString(inviterUserMap['name']),
        _asString(directInviterUserMap['name']),
        _asString(inviterUserMap['username']),
        _asString(directInviterUserMap['username']),
        _asString(inviterCharacterMap['name']),
      ]),
      inviterEmail: _firstNonEmpty([
        _asString(inviterUserMap['email']),
        _asString(directInviterUserMap['email']),
      ]),
      invitedUserName: _firstNonEmpty([
        _asString(invitedUserMap['nickname']),
        _asString(invitedUserMap['name']),
        _asString(invitedUserMap['username']),
      ]),
      invitedUserEmail: _asString(invitedUserMap['email']),
    );
  }

  bool get isPending => status == 'pending';

  String get invitedUserLabel {
    if (invitedUserName.isNotEmpty) return invitedUserName;
    if (invitedUserEmail.isNotEmpty) return invitedUserEmail;
    return invitedUserId;
  }

  String get inviterLabel {
    if (inviterName.isNotEmpty) return inviterName;
    if (inviterEmail.isNotEmpty) return inviterEmail;
    return '친구';
  }
}

class GameApiService {
  static const _requestTimeout = Duration(seconds: 12);

  static Future<String> requireCharacterId() async {
    var characterId = (await AuthService.getSavedCharacterId())?.trim();
    if (characterId != null && characterId.isNotEmpty) return characterId;

    await AuthService.fetchMainMessage();
    characterId = (await AuthService.getSavedCharacterId())?.trim();
    if (characterId == null || characterId.isEmpty) {
      throw const GameApiException('캐릭터 정보를 불러오지 못했습니다.');
    }
    return characterId;
  }

  static Future<String> requireUserId() async {
    var userId = (await AuthService.getSavedUserId())?.trim();
    if (userId != null && userId.isNotEmpty) return userId;

    await AuthService.fetchMainMessage();
    userId = (await AuthService.getSavedUserId())?.trim();
    if (userId == null || userId.isEmpty) {
      throw const GameApiException('사용자 정보를 불러오지 못했습니다.');
    }
    return userId;
  }

  static Future<List<Shop>> fetchShops() async {
    final response = await _get('/api/shops');
    return _dataItems(
      response,
    ).map(Shop.fromJson).where((s) => s.id.isNotEmpty).toList();
  }

  static Future<List<ShopItem>> fetchShopItems(String shopId) async {
    final response = await _get('/api/shops/$shopId/items');
    return _dataItems(response)
        .map(ShopItem.fromJson)
        .where((item) => item.id.isNotEmpty && item.itemTemplate.id.isNotEmpty)
        .toList();
  }

  static Future<void> purchaseShopItem({
    required String shopId,
    required String shopItemId,
    int quantity = 1,
  }) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/shops/$shopId/purchase', {
      'characterId': characterId,
      'shopItemId': shopItemId,
      'quantity': quantity,
    });
    final character = _asMap(_asMap(response['data'])['character']);
    if (character.containsKey('coin_balance')) {
      GameState.instance.setCoins(_asInt(character['coin_balance']));
    }
  }

  static Future<List<OwnedInventoryItem>> fetchInventoryItems() async {
    final characterId = await requireCharacterId();
    final equipmentResponse = await _get(
      '/api/characters/$characterId/equipments',
    );
    final consumableResponse = await _get(
      '/api/characters/$characterId/consumables',
    );
    return [
      ..._dataItems(equipmentResponse)
          .map(OwnedInventoryItem.equipment)
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.itemTemplate.id.isNotEmpty &&
                !item.isRemoved,
          ),
      ..._dataItems(consumableResponse)
          .map(OwnedInventoryItem.consumable)
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.itemTemplate.id.isNotEmpty &&
                item.quantity > 0,
          ),
    ];
  }

  static Future<void> equipItem(String ownedEquipmentId) async {
    final characterId = await requireCharacterId();
    await _post('/api/characters/$characterId/equip', {
      'ownedEquipmentId': ownedEquipmentId,
    });
  }

  static Future<void> unequipItem(String ownedEquipmentId) async {
    final characterId = await requireCharacterId();
    await _post('/api/characters/$characterId/unequip', {
      'ownedEquipmentId': ownedEquipmentId,
    });
  }

  static Future<int> sellItem({
    required OwnedInventoryItem item,
    int quantity = 1,
  }) async {
    final characterId = await requireCharacterId();
    final response = item.itemTemplate.isEquipment
        ? await _post('/api/characters/$characterId/equipments/sell', {
            'ownedEquipmentId': item.id,
          })
        : await _post('/api/characters/$characterId/consumables/sell', {
            'itemTemplateId': item.itemTemplate.id,
            'useQuantity': quantity,
          });
    final data = _asMap(response['data']);
    final character = _asMap(data['character']);
    if (character.containsKey('coin_balance')) {
      GameState.instance.setCoins(_asInt(character['coin_balance']));
    }
    return _asInt(data['refund_coin']);
  }

  static Future<ConsumableUseResult> useConsumable(
    String itemTemplateId,
  ) async {
    final characterId = await requireCharacterId();
    final response = await _post(
      '/api/characters/$characterId/consumables/use',
      {'itemTemplateId': itemTemplateId, 'useQuantity': 1},
    );
    return ConsumableUseResult.fromJson(_asMap(response['data']));
  }

  static Future<StatUpgradeSummary> fetchStatUpgradeSummary() async {
    final characterId = await requireCharacterId();
    final response = await _get('/api/stat-upgrades/costs/$characterId');
    final summary = StatUpgradeSummary.fromJson(_asMap(response['data']));
    GameState.instance.setExp(summary.exp);
    GameState.instance.setStatExp(summary.statExp);
    return summary;
  }

  static Future<CharacterStatsSummary> fetchCharacterStatsSummary() async {
    final characterId = await requireCharacterId();
    final response = await _get('/api/characters/stats/$characterId');
    return CharacterStatsSummary.fromJson(_asMap(response['data']));
  }

  static Future<StatUpgradeSummary> upgradeStat(String statType) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/stat-upgrades', {
      'characterId': characterId,
      'statType': statType,
    });
    final data = _asMap(response['data']);
    if (data.containsKey('coin_balance')) {
      GameState.instance.setCoins(_asInt(data['coin_balance']));
    }
    if (data.containsKey('exp')) {
      GameState.instance.setExp(_asInt(data['exp']));
    }
    if (data.containsKey('stat_exp')) {
      GameState.instance.setStatExp(_asInt(data['stat_exp']));
    }
    return fetchStatUpgradeSummary();
  }

  static Future<ExplorationUpgradeSummary>
  fetchExplorationUpgradeSummary() async {
    final characterId = await requireCharacterId();
    try {
      final response = await _get(
        '/api/exploration-upgrades/costs/$characterId',
      );
      final summary = ExplorationUpgradeSummary.fromJson(
        _asMap(response['data']),
      );
      GameState.instance.setCoins(summary.coinBalance);
      return summary;
    } on GameApiException {
      return ExplorationUpgradeSummary.defaults(
        coinBalance: GameState.instance.coins,
      );
    }
  }

  static Future<ExplorationUpgradeSummary> upgradeExploration(
    String upgradeType,
  ) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/exploration-upgrades', {
      'characterId': characterId,
      'upgradeType': upgradeType,
    });
    final summary = ExplorationUpgradeSummary.fromJson(
      _asMap(response['data']),
    );
    GameState.instance.setCoins(summary.coinBalance);
    return summary;
  }

  static Future<List<UserMission>> fetchUserMissions() async {
    final userId = await requireUserId();
    final response = await _get('/api/users/$userId/missions');
    final missions = _dataItems(response)
        .map(UserMission.fromJson)
        .where((mission) => mission.id.isNotEmpty)
        .toList();
    missions.sort((a, b) {
      final typeCompare = a.missionType.compareTo(b.missionType);
      if (typeCompare != 0) return typeCompare;
      return a.displayOrder.compareTo(b.displayOrder);
    });
    return missions;
  }

  static Future<void> claimMission(String userMissionId) async {
    final response = await _post('/api/user-missions/$userMissionId/claim', {});
    final character = _asMap(_asMap(response['data'])['character']);
    if (character.containsKey('coin_balance')) {
      GameState.instance.setCoins(_asInt(character['coin_balance']));
    }
  }

  static Future<StepSyncResult> syncSteps({
    required int stepCount,
    int? distanceM,
  }) async {
    final response = await _post('/steps/sync', {
      'source_type': 'api',
      'sync_type': 'realtime',
      'step_count': stepCount,
      'distance_m': distanceM ?? (stepCount * 0.75).round(),
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    });
    final result = StepSyncResult.fromJson(response);
    GameState.instance.setAttackCountBalance(result.attackCountBalance);
    return result;
  }

  static Future<StepSyncResult> syncStepDelta({
    required int stepCount,
    double strideM = 0.75,
    int gpsDistanceM = 0,
    String abnormalReason = '',
    String syncType = 'periodic',
  }) async {
    final response = await _post('/steps/sync', {
      'source_type': 'sensor',
      'sync_type': syncType,
      'step_count': stepCount,
      'distance_m': 0,
      'stride_m': strideM,
      'is_delta': true,
      'gps_distance_m': gpsDistanceM,
      'abnormal_flag': abnormalReason.isNotEmpty,
      'abnormal_reason': abnormalReason,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    });
    final result = StepSyncResult.fromJson(response);
    GameState.instance.setAttackCountBalance(result.attackCountBalance);
    return result;
  }

  static Future<StepSyncResult> syncDistanceDelta({
    required int distanceM,
  }) async {
    final response = await _post('/steps/sync', {
      'source_type': 'sensor',
      'sync_type': 'periodic',
      'step_count': 0,
      'distance_m': distanceM,
      'is_delta': true,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    });
    final result = StepSyncResult.fromJson(response);
    GameState.instance.setAttackCountBalance(result.attackCountBalance);
    return result;
  }

  static Future<StepSyncResult> addDistanceDelta({
    required int distanceM,
  }) async {
    final response = await _post('/steps/sync', {
      'source_type': 'api',
      'sync_type': 'realtime',
      'step_count': 0,
      'distance_m': distanceM,
      'is_delta': true,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    });
    final result = StepSyncResult.fromJson(response);
    GameState.instance.setAttackCountBalance(result.attackCountBalance);
    return result;
  }

  static Future<List<RaidMonsterInfo>> fetchRaidMonsters() async {
    final response = await _get('/api/raid-monsters');
    return _dataItems(response)
        .map(RaidMonsterInfo.fromJson)
        .where((monster) => monster.id.isNotEmpty && monster.isActive)
        .toList();
  }

  static Future<List<RaidRecordInfo>> fetchRaids() async {
    final response = await _get('/api/raids');
    return _dataItems(
      response,
    ).map(RaidRecordInfo.fromJson).where((raid) => raid.id.isNotEmpty).toList();
  }

  static Future<RaidProgressSummary> createRaid({
    required String monsterId,
    required String title,
    String description = '',
  }) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raids', {
      'hostCharacterId': characterId,
      'monsterId': monsterId,
      'title': title,
      'description': description,
    });
    final raid = RaidRecordInfo.fromJson(
      _asMap(_asMap(response['data'])['raid']),
    );
    if (raid.id.isEmpty) {
      throw const GameApiException('레이드를 생성하지 못했습니다.');
    }
    return fetchRaidProgress(raid.id);
  }

  static Future<RaidProgressSummary> joinRaid({required String raidId}) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raids/$raidId/join', {
      'characterId': characterId,
    });
    final data = _asMap(response['data']);
    final lobby = _asMap(data['lobby']);
    if (lobby.isNotEmpty) {
      return RaidProgressSummary.fromJson(lobby);
    }
    return fetchRaidProgress(raidId);
  }

  static Future<RaidProgressSummary> leaveRaid({required String raidId}) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raids/$raidId/leave', {
      'characterId': characterId,
    });
    final data = _asMap(response['data']);
    final lobby = _asMap(data['lobby']);
    if (lobby.isNotEmpty) {
      return RaidProgressSummary.fromJson(lobby);
    }
    return fetchRaidProgress(raidId);
  }

  static Future<RaidProgressSummary> startRaid({required String raidId}) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raids/$raidId/start', {
      'characterId': characterId,
    });
    final data = _asMap(response['data']);
    final lobby = _asMap(data['lobby']);
    if (lobby.isNotEmpty) {
      return RaidProgressSummary.fromJson(lobby);
    }
    return fetchRaidProgress(raidId);
  }

  static Future<RaidProgressSummary> fetchRaidProgress(String raidId) async {
    final response = await _get('/api/raids/$raidId/progress');
    return RaidProgressSummary.fromJson(_asMap(response['data']));
  }

  static Future<List<RaidParticipantInfo>> fetchRaidParticipants(
    String raidId,
  ) async {
    final response = await _get('/api/raids/$raidId/participants');
    return _dataItems(response)
        .map(RaidParticipantInfo.fromJson)
        .where((participant) => participant.id.isNotEmpty)
        .toList();
  }

  static Future<void> inviteRaidFriend({
    required String raidId,
    required String invitedUserId,
  }) async {
    final characterId = await requireCharacterId();
    await _post('/api/raids/$raidId/invite', {
      'inviterCharacterId': characterId,
      'invitedUserId': invitedUserId,
    });
  }

  static Future<RaidDistanceResult> addRaidDistance({
    required String raidId,
    required double distanceM,
  }) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raids/$raidId/distance', {
      'characterId': characterId,
      'distanceM': distanceM,
    });
    return RaidDistanceResult.fromJson(_asMap(response['data']));
  }

  static Future<List<RaidInvitationInfo>> fetchRaidInvitations() async {
    final userId = await requireUserId();
    final response = await _get('/api/users/$userId/raid-invitations');
    return _dataItems(response)
        .map(RaidInvitationInfo.fromJson)
        .where((invitation) => invitation.id.isNotEmpty)
        .toList();
  }

  static Future<RaidProgressSummary> acceptRaidInvitation(
    String invitationId,
  ) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raid-invitations/$invitationId/accept', {
      'characterId': characterId,
    });
    final data = _asMap(response['data']);
    final lobby = _asMap(data['lobby']);
    if (lobby.isNotEmpty) {
      return RaidProgressSummary.fromJson(lobby);
    }
    final raid = RaidRecordInfo.fromJson(_asMap(data['raid']));
    if (raid.id.isEmpty) {
      throw const GameApiException('레이드 초대를 수락하지 못했습니다.');
    }
    return fetchRaidProgress(raid.id);
  }

  static Future<void> declineRaidInvitation(String invitationId) async {
    final characterId = await requireCharacterId();
    await _post('/api/raid-invitations/$invitationId/decline', {
      'characterId': characterId,
    });
  }

  static Future<RaidProgressSummary> cancelRaidInvitation(
    String invitationId,
  ) async {
    final characterId = await requireCharacterId();
    final response = await _post('/api/raid-invitations/$invitationId/cancel', {
      'characterId': characterId,
    });
    final data = _asMap(response['data']);
    final lobby = _asMap(data['lobby']);
    if (lobby.isNotEmpty) {
      return RaidProgressSummary.fromJson(lobby);
    }
    final raid = RaidRecordInfo.fromJson(_asMap(data['raid']));
    if (raid.id.isEmpty) {
      throw const GameApiException('레이드 초대를 취소하지 못했습니다.');
    }
    return fetchRaidProgress(raid.id);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const GameApiException('로그인이 필요합니다.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    late final http.Response response;
    try {
      response = await http
          .get(ApiConfig.uri(path), headers: await _headers())
          .timeout(_requestTimeout);
    } on SocketException {
      throw const GameApiException('네트워크 연결을 확인해주세요.');
    } on http.ClientException {
      throw const GameApiException('서버에 연결하지 못했습니다.');
    } on TimeoutException {
      throw const GameApiException('서버 응답이 지연되고 있습니다.');
    }
    return _decodeResponse(response, '요청에 실패했습니다.');
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            ApiConfig.uri(path),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on SocketException {
      throw const GameApiException('네트워크 연결을 확인해주세요.');
    } on http.ClientException {
      throw const GameApiException('서버에 연결하지 못했습니다.');
    } on TimeoutException {
      throw const GameApiException('서버 응답이 지연되고 있습니다.');
    }
    return _decodeResponse(response, '요청에 실패했습니다.');
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String fallback,
  ) {
    final Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : _asMap(jsonDecode(response.body));
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GameApiException(fallback);
      }
      throw const GameApiException('서버 응답을 읽을 수 없습니다.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _asString(decoded['error']).isNotEmpty
          ? _asString(decoded['error'])
          : _asString(decoded['message']);
      throw GameApiException(
        message.isEmpty ? fallback : _localizeApiMessage(message),
      );
    }
    return decoded;
  }

  static List<Map<String, dynamic>> _dataItems(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    final map = _asMap(data);
    final items = map['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}

String _localizeApiMessage(String message) {
  return switch (message) {
    'Invalid value equipment_sell.' => '판매 완료!',
    'equipment is not sellable' => '판매할 수 없는 장비입니다.',
    'equipment is already equipped' => '이미 장착 중인 장비입니다.',
    'equipment is not equipped' => '장착 중인 장비가 아닙니다.',
    'equipped equipment cannot be sold' => '착용 중인 장비는 판매할 수 없습니다.',
    'owned equipment not found' => '장비를 찾을 수 없습니다.',
    'owned equipment does not belong to character' => '내 장비가 아닙니다.',
    'not enough consumable quantity' => '소모품 수량이 부족합니다.',
    'item template is not consumable' => '사용할 수 없는 아이템입니다.',
    'not enough coin balance' => '코인이 부족합니다.',
    'stock limit exceeded' => '현재 구매할 수 있는 수량을 초과했습니다.',
    'purchase limit per user exceeded' => '구매 가능 횟수를 초과했습니다.',
    'not enough exp balance' => 'EXP가 부족합니다.',
    'not enough stat exp balance' => '스탯 포인트가 부족합니다.',
    'raid is not active' => '진행 중인 레이드가 아닙니다.',
    'raid progress is already finished' => '이미 종료된 레이드입니다.',
    'raid is not waiting for invitations' => '초대 가능한 레이드 상태가 아닙니다.',
    'raid is not waiting for participants' => '이미 시작되었거나 참가할 수 없는 레이드입니다.',
    'raid host left' => '파티장이 나가 레이드 방이 해체되었습니다.',
    'only raid host can invite users' => '레이드 방장만 초대할 수 있습니다.',
    'only raid host can start raids' => '파티장만 전투를 시작할 수 있습니다.',
    'raid participants are not ready' => '파티원이 모두 준비되어야 전투를 시작할 수 있습니다.',
    'invited user is already participating in raid' => '이미 참여 중인 사용자입니다.',
    'pending invitation already exists' => '이미 보낸 레이드 초대가 있습니다.',
    'character is not participating in raid' => '레이드 참여 캐릭터가 아닙니다.',
    'raid is full' => '레이드 파티가 가득 찼습니다.',
    'character already joined raid' => '이미 참여한 레이드입니다.',
    'raid requires level 5' => '레이드는 5레벨부터 입장할 수 있습니다.',
    'invitation is not pending' => '이미 처리된 초대입니다.',
    'only raid host can cancel invitations' => '레이드 방장만 초대를 취소할 수 있습니다.',
    'raid has pending invitations' => '수락 대기 중인 초대가 있어 전투를 시작할 수 없습니다.',
    _ => message,
  };
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, val) => MapEntry('$key', val));
  return {};
}

List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

String _asString(dynamic value) => value?.toString().trim() ?? '';

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
  }
  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

Map<String, int> _intMap(Map<String, dynamic> map) {
  return map.map((key, value) => MapEntry(key, _asInt(value)));
}
