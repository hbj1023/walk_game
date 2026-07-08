import 'dart:math' as math;

import 'package:capstone_app/services/game_api_service.dart';

class RaidBoss {
  final String id;
  final String name;
  final int recommendedLevel;
  final int recommendedCombatPower;
  final int difficulty;
  final bool isLocked;
  final int hp;
  final int attack;
  final int defense;
  final int agility;
  final int rewardCoinMin;
  final int rewardCoinMax;
  final String? imagePath;
  final String? iconPath;
  final String? bgPath;
  final bool isComingSoon;

  const RaidBoss({
    this.id = '',
    required this.name,
    required this.recommendedLevel,
    this.recommendedCombatPower = _kMinimumRaidRecommendedCombatPower,
    required this.difficulty,
    required this.isLocked,
    this.hp = 0,
    this.attack = 0,
    this.defense = 0,
    this.agility = 0,
    this.rewardCoinMin = 0,
    this.rewardCoinMax = 0,
    this.imagePath,
    this.iconPath,
    this.bgPath,
    this.isComingSoon = false,
  });

  factory RaidBoss.fromMonster(RaidMonsterInfo monster) {
    final normalizedName = monster.name.trim();
    final asset = _raidBossAsset(normalizedName);
    final comingSoon = _raidBossComingSoon(normalizedName);
    return RaidBoss(
      id: monster.id,
      name: normalizedName.isEmpty ? '레이드 보스' : normalizedName,
      recommendedLevel: _raidRecommendedLevel(monster),
      recommendedCombatPower: _raidRecommendedCombatPower(monster),
      difficulty: _raidDifficulty(monster),
      isLocked: comingSoon,
      hp: monster.hp,
      attack: monster.attack,
      defense: monster.defense,
      agility: monster.agility,
      rewardCoinMin: monster.rewardCoinMin,
      rewardCoinMax: monster.rewardCoinMax,
      iconPath: asset.iconPath,
      bgPath: asset.bgPath,
      isComingSoon: comingSoon,
    );
  }
}

class _RaidBossAsset {
  final String iconPath;
  final String bgPath;

  const _RaidBossAsset({required this.iconPath, required this.bgPath});
}

_RaidBossAsset _raidBossAsset(String name) {
  if (name.contains('와이번')) {
    return const _RaidBossAsset(
      iconPath: 'assets/images/raid/ic_boss_wyvern.png',
      bgPath: 'assets/images/bg/raid_volcano.png',
    );
  }
  if (name.contains('고블린')) {
    return const _RaidBossAsset(
      iconPath: 'assets/images/raid/ic_boss_goblin.png',
      bgPath: 'assets/images/bg/raid_forest.png',
    );
  }
  return const _RaidBossAsset(
    iconPath: 'assets/images/raid/ic_boss_golem.png',
    bgPath: 'assets/images/bg/raid_cave.png',
  );
}

int _raidDifficulty(RaidMonsterInfo monster) {
  final score = monster.hp + monster.attack * 8 + monster.agility * 3;
  if (score >= 260) return 3;
  if (score >= 140) return 2;
  return 1;
}

int _raidRecommendedLevel(RaidMonsterInfo _) => 5;

const _kMinimumRaidRecommendedCombatPower = 980;
const _kGolemRaidRecommendedCombatPower = 1100;

int _raidRecommendedCombatPower(RaidMonsterInfo monster) {
  final name = monster.name.trim();
  if (name.contains('와이번')) return 0;
  if (name.contains('골렘')) return _kGolemRaidRecommendedCombatPower;

  final monsterPower =
      (monster.hp / 3 +
              monster.attack * 8 +
              monster.defense * 5 +
              monster.agility * 4)
          .round();

  // Raid is party-facing, so expose a team-oriented target while keeping
  // the first raid from reading weaker than the chapter 1 boss gate.
  return math.max(_kMinimumRaidRecommendedCombatPower, monsterPower * 2);
}

bool _raidBossComingSoon(String name) => name.contains('와이번');
