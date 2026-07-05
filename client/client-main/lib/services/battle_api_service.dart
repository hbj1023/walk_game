import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'auth_service.dart';
import 'equipment_image_resolver.dart';

class BattleApiException implements Exception {
  final String message;
  const BattleApiException(this.message);

  @override
  String toString() => message;
}

class NormalBattleCharacter {
  final String id;
  final int currentHp;
  final int level;
  final int exp;
  final int statExp;
  final int coinBalance;
  final int attackCountBalance;

  const NormalBattleCharacter({
    required this.id,
    required this.currentHp,
    required this.level,
    required this.exp,
    required this.statExp,
    required this.coinBalance,
    required this.attackCountBalance,
  });

  factory NormalBattleCharacter.fromJson(Map<String, dynamic> json) {
    return NormalBattleCharacter(
      id: (json['id'] ?? '') as String,
      currentHp: _asInt(json['current_hp']),
      level: _asInt(json['level']),
      exp: _asInt(json['exp']),
      statExp: _asInt(json['stat_exp']),
      coinBalance: _asInt(json['coin_balance']),
      attackCountBalance: _asInt(json['attack_count_balance']),
    );
  }
}

class NormalBattleMonster {
  final String id;
  final String name;
  final int hp;
  final int agility;

  const NormalBattleMonster({
    required this.id,
    required this.name,
    required this.hp,
    required this.agility,
  });

  factory NormalBattleMonster.fromJson(Map<String, dynamic> json) {
    return NormalBattleMonster(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      hp: _asInt(json['hp']),
      agility: _asInt(json['agility']),
    );
  }
}

class NormalBattleRecord {
  final String id;
  final String battleType;
  final String status;
  final int attackCountUsed;
  final int totalDamageDealt;
  final int totalDamageTaken;
  final int monsterCurrentHp;
  final int characterCurrentHp;
  final int rewardCoin;
  final int currentSpawnOrder;
  final double monsterAttackGaugeM;

  const NormalBattleRecord({
    required this.id,
    required this.battleType,
    required this.status,
    required this.attackCountUsed,
    required this.totalDamageDealt,
    required this.totalDamageTaken,
    required this.monsterCurrentHp,
    required this.characterCurrentHp,
    required this.rewardCoin,
    required this.currentSpawnOrder,
    required this.monsterAttackGaugeM,
  });

  factory NormalBattleRecord.fromJson(Map<String, dynamic> json) {
    return NormalBattleRecord(
      id: (json['id'] ?? '') as String,
      battleType: (json['battle_type'] ?? 'normal') as String,
      status: (json['status'] ?? '') as String,
      attackCountUsed: _asInt(json['attack_count_used']),
      totalDamageDealt: _asInt(json['total_damage_dealt']),
      totalDamageTaken: _asInt(json['total_damage_taken']),
      monsterCurrentHp: _asInt(json['monster_current_hp']),
      characterCurrentHp: _asInt(json['character_current_hp']),
      rewardCoin: _asInt(json['reward_coin']),
      currentSpawnOrder: _asInt(json['current_spawn_order']),
      monsterAttackGaugeM: _asDouble(json['monster_attack_gauge_m']),
    );
  }
}

class NormalBattleResult {
  final NormalBattleRecord battle;
  final NormalBattleCharacter character;
  final int characterMaxHp;
  final NormalBattleMonster monster;
  final int playerDamage;
  final int monsterDamage;
  final bool monsterAttacked;
  final int rewardCoin;
  final int rewardExp;
  final int statExpReward;
  final int attackCountBalance;
  final double monsterAttackGaugeM;
  final double monsterAttackDistanceM;
  final BattleRewardEquipment? rewardEquipment;

  const NormalBattleResult({
    required this.battle,
    required this.character,
    required this.characterMaxHp,
    required this.monster,
    required this.playerDamage,
    required this.monsterDamage,
    required this.monsterAttacked,
    required this.rewardCoin,
    required this.rewardExp,
    required this.statExpReward,
    required this.attackCountBalance,
    required this.monsterAttackGaugeM,
    required this.monsterAttackDistanceM,
    required this.rewardEquipment,
  });

  factory NormalBattleResult.fromJson(Map<String, dynamic> json) {
    return NormalBattleResult(
      battle: NormalBattleRecord.fromJson(_asMap(json['battle'])),
      character: NormalBattleCharacter.fromJson(_asMap(json['character'])),
      characterMaxHp: _asInt(json['character_max_hp']),
      monster: NormalBattleMonster.fromJson(_asMap(json['monster'])),
      playerDamage: _asInt(json['player_damage']),
      monsterDamage: _asInt(json['monster_damage']),
      monsterAttacked: (json['monster_attacked'] ?? false) as bool,
      rewardCoin: _asInt(json['reward_coin']),
      rewardExp: _asInt(json['reward_exp']),
      statExpReward: _asInt(json['stat_exp_reward']),
      attackCountBalance: _asInt(json['attack_count_balance']),
      monsterAttackGaugeM: _asDouble(json['monster_attack_gauge_m']),
      monsterAttackDistanceM: _asDouble(json['monster_attack_distance_m']),
      rewardEquipment: BattleRewardEquipment.fromJsonOrNull(
        _asMap(json['reward_item']),
      ),
    );
  }
}

class BattleRewardEquipment {
  final String id;
  final BattleRewardItemTemplate itemTemplate;

  const BattleRewardEquipment({required this.id, required this.itemTemplate});

  static BattleRewardEquipment? fromJsonOrNull(Map<String, dynamic> json) {
    if (json.isEmpty) return null;
    final expand = _asMap(json['expand']);
    final template = BattleRewardItemTemplate.fromJson(
      _asMap(expand['item_template']),
    );
    if (template.id.isEmpty) return null;
    return BattleRewardEquipment(
      id: _asString(json['id']),
      itemTemplate: template,
    );
  }
}

class BattleRewardItemTemplate {
  final String id;
  final String name;
  final String itemType;
  final String equipmentSlot;
  final String weaponType;
  final String setKey;
  final String setPieceType;
  final String imagePath;
  final String rarity;
  final int baseHp;
  final int baseAttack;
  final int baseDefense;
  final int baseAgility;

  const BattleRewardItemTemplate({
    required this.id,
    required this.name,
    required this.itemType,
    required this.equipmentSlot,
    required this.weaponType,
    required this.setKey,
    required this.setPieceType,
    required this.imagePath,
    required this.rarity,
    required this.baseHp,
    required this.baseAttack,
    required this.baseDefense,
    required this.baseAgility,
  });

  factory BattleRewardItemTemplate.fromJson(Map<String, dynamic> json) {
    return BattleRewardItemTemplate(
      id: _asString(json['id']),
      name: _asString(json['name']),
      itemType: _asString(json['item_type']),
      equipmentSlot: _asString(json['equipment_slot']),
      weaponType: _asString(json['weapon_type']),
      setKey: _asString(json['set_key']),
      setPieceType: _asString(json['set_piece_type']),
      imagePath: _asString(json['image_path']),
      rarity: _asString(json['rarity']),
      baseHp: _asInt(json['base_hp']),
      baseAttack: _asInt(json['base_attack']),
      baseDefense: _asInt(json['base_defense']),
      baseAgility: _asInt(json['base_agility']),
    );
  }

  String get displayImagePath => resolveEquipmentImagePath(
    imagePath: imagePath,
    itemType: itemType,
    equipmentSlot: equipmentSlot,
    weaponType: weaponType,
    setKey: setKey,
    setPieceType: setPieceType,
    name: name,
  );

  String get slotLabel {
    return switch (equipmentSlot) {
      'helmet' => '투구',
      'armor' => '갑옷',
      'sword' => '무기',
      'shoes' => '신발',
      _ => '장비',
    };
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

  String get statSummary {
    final parts = <String>[];
    if (equipmentSlot == 'sword' && weaponTypeLabel.isNotEmpty) {
      parts.add(weaponTypeLabel);
    }
    if (baseHp > 0) parts.add('HP +$baseHp');
    if (baseAttack > 0) parts.add('공격 +$baseAttack');
    if (baseDefense > 0) parts.add('방어 +$baseDefense');
    if (baseAgility > 0) parts.add('민첩 +$baseAgility');
    return parts.isEmpty ? slotLabel : parts.join(' / ');
  }
}

class NormalStageInfo {
  final String id;
  final int stageNo;
  final String title;
  final String stageType;
  final String status;
  final bool isUnlocked;
  final bool isCleared;
  final int clearCount;
  final int monsterCount;
  final String monsterId;
  final String monsterName;
  final int monsterHp;

  const NormalStageInfo({
    required this.id,
    required this.stageNo,
    required this.title,
    required this.stageType,
    required this.status,
    required this.isUnlocked,
    required this.isCleared,
    required this.clearCount,
    required this.monsterCount,
    required this.monsterId,
    required this.monsterName,
    required this.monsterHp,
  });

  factory NormalStageInfo.fromJson(Map<String, dynamic> json) {
    return NormalStageInfo(
      id: (json['id'] ?? '') as String,
      stageNo: _asInt(json['stage_no']),
      title: (json['title'] ?? '') as String,
      stageType: (json['stage_type'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      isUnlocked: (json['is_unlocked'] ?? false) as bool,
      isCleared: (json['is_cleared'] ?? false) as bool,
      clearCount: _asInt(json['clear_count']),
      monsterCount: _asInt(json['monster_count']),
      monsterId: (json['monster_id'] ?? '') as String,
      monsterName: (json['monster_name'] ?? '') as String,
      monsterHp: _asInt(json['monster_hp']),
    );
  }
}

class BattleApiService {
  static const _requestTimeout = Duration(seconds: 12);
  static const _activeNormalBattleIdKey = 'active_normal_battle_id';

  static Uri _uri(String path) => ApiConfig.uri(path);

  static Future<List<NormalStageInfo>> fetchNormalStages() async {
    final response = await _get('/stages/normal');
    final stages = response['stages'];
    if (stages is! List) return const [];
    return stages
        .whereType<Map<String, dynamic>>()
        .map(NormalStageInfo.fromJson)
        .where((stage) => stage.stageNo > 0)
        .toList();
  }

  static Future<NormalBattleResult> startNormalBattle({
    required int stageNo,
  }) async {
    final response = await _post('/battle/normal/start', {'stage_no': stageNo});
    return NormalBattleResult.fromJson(response);
  }

  static Future<NormalBattleResult> attackNormalBattle({
    required String battleId,
  }) async {
    final response = await _post('/battle/normal/attack', {
      'battle_id': battleId,
    });
    return NormalBattleResult.fromJson(response);
  }

  static Future<NormalBattleResult> leaveNormalBattle({
    required String battleId,
  }) async {
    final response = await _post('/battle/normal/leave', {
      'battle_id': battleId,
    });
    return NormalBattleResult.fromJson(response);
  }

  static Future<NormalBattleResult> startBossBattle({
    required int stageNo,
  }) async {
    final response = await _post('/battle/boss/start', {'stage_no': stageNo});
    return NormalBattleResult.fromJson(response);
  }

  static Future<NormalBattleResult> attackBossBattle({
    required String battleId,
  }) async {
    final response = await _post('/battle/boss/attack', {
      'battle_id': battleId,
    });
    return NormalBattleResult.fromJson(response);
  }

  static Future<NormalBattleResult> leaveBossBattle({
    required String battleId,
  }) async {
    final response = await _post('/battle/boss/leave', {'battle_id': battleId});
    return NormalBattleResult.fromJson(response);
  }

  static Future<void> markActiveNormalBattle(String battleId) async {
    if (battleId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeNormalBattleIdKey, battleId.trim());
  }

  static Future<void> clearActiveNormalBattle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeNormalBattleIdKey);
  }

  static Future<void> leaveStoredUnfinishedNormalBattle() async {
    final prefs = await SharedPreferences.getInstance();
    final battleId = prefs.getString(_activeNormalBattleIdKey)?.trim();
    if (battleId == null || battleId.isEmpty) return;

    await leaveNormalBattle(battleId: battleId);
    await prefs.remove(_activeNormalBattleIdKey);
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const BattleApiException('로그인 정보가 없습니다. 다시 로그인해주세요.');
    }

    late final http.Response response;
    try {
      response = await http
          .get(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout);
    } on SocketException {
      throw const BattleApiException('네트워크 연결을 확인해주세요.');
    } on http.ClientException {
      throw const BattleApiException('서버에 연결하지 못했습니다.');
    } on TimeoutException {
      throw const BattleApiException('서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.');
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BattleApiException(
        _errorMessage(decoded, fallback: '전투 요청에 실패했습니다.'),
      );
    }

    return decoded;
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const BattleApiException('로그인 정보가 없습니다. 다시 로그인해주세요.');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on SocketException {
      throw const BattleApiException('네트워크 연결을 확인해주세요.');
    } on http.ClientException {
      throw const BattleApiException('서버에 연결하지 못했습니다.');
    } on TimeoutException {
      throw const BattleApiException('서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.');
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BattleApiException(
        _errorMessage(decoded, fallback: '전투 요청에 실패했습니다.'),
      );
    }

    return decoded;
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  static String _errorMessage(
    Map<String, dynamic> body, {
    required String fallback,
  }) {
    final message = (body['error'] as String?)?.trim();
    if (message == null || message.isEmpty) return fallback;
    if (message == 'Something went wrong while processing your request.') {
      return '서버에서 전투 요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
    }
    return message;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return {};
}

String _asString(dynamic value) {
  if (value is String) return value;
  return value?.toString() ?? '';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
