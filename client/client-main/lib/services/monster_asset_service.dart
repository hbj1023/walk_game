class MonsterAssetService {
  static const basicGoblin =
      'assets/images/monsters/monster_1-1_basic_goblin.png';
  static const spearGoblin =
      'assets/images/monsters/monster_1-2_spear_goblin.png';
  static const archerGoblin =
      'assets/images/monsters/monster_1-3_archer_goblin.png';
  static const bomberGoblin =
      'assets/images/monsters/monster_1-4_bomber_goblin.png';
  static const fierceGoblin =
      'assets/images/monsters/monster_1-5_club_goblin.png';

  static const sporeShroom = 'assets/images/monsters/spore_shroom.png';
  static const thornShroom = 'assets/images/monsters/thorn_shroom.png';
  static const toxicShroom = 'assets/images/monsters/toxic_shroom.png';
  static const frostShroom = 'assets/images/monsters/frost_shroom.png';
  static const elderSporeKing = 'assets/images/monsters/elder_spore_king.png';
  static const pebbleGolem =
      'assets/images/monsters/monster_3-1_pebble_golem.png';
  static const crackedGolem =
      'assets/images/monsters/monster_3-2_cracked_golem.png';
  static const mossyGolem =
      'assets/images/monsters/monster_3-3_mossy_golem.png';
  static const oreGolem = 'assets/images/monsters/monster_3-4_ore_golem.png';
  static const quarryGuardianGolem =
      'assets/images/monsters/monster_3-5_quarry_guardian_golem.png';
  static const ancientQuarryGolem = quarryGuardianGolem;

  static const greenGoblin = 'assets/images/monsters/green_goblin.png';

  static String nameForStage(int stageNo, {String fallback = '몬스터'}) {
    return switch (stageNo) {
      1 => '기본 고블린',
      2 => '창 고블린',
      3 => '궁수 고블린',
      4 => '폭탄 고블린',
      5 => '흉폭한 고블린',
      6 => '포자 버섯병사',
      7 => '가시 버섯병사',
      8 => '독버섯 주술사',
      9 => '서리 버섯병사',
      10 => '장로 포자왕',
      11 => '금이 간 석상병',
      12 => '광맥 굴착 골렘',
      13 => '룬 각인 수호자',
      14 => '고대 파쇄 거인',
      15 => '거석왕 탈로스',
      _ => fallback,
    };
  }

  static String imageForMonster({required String name, int? stageNo}) {
    final stageAsset = switch (stageNo) {
      1 => basicGoblin,
      2 => spearGoblin,
      3 => archerGoblin,
      4 => bomberGoblin,
      5 => fierceGoblin,
      6 => sporeShroom,
      7 => thornShroom,
      8 => toxicShroom,
      9 => frostShroom,
      10 => elderSporeKing,
      11 => pebbleGolem,
      12 => crackedGolem,
      13 => mossyGolem,
      14 => oreGolem,
      15 => quarryGuardianGolem,
      _ => null,
    };
    if (stageAsset != null) return stageAsset;

    final normalizedName = name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalizedName.contains('장로') ||
        normalizedName.contains('포자왕') ||
        normalizedName.contains('elder') ||
        normalizedName.contains('king')) {
      return elderSporeKing;
    }
    if (normalizedName.contains('석상') ||
        normalizedName.contains('골렘') ||
        normalizedName.contains('수호자') ||
        normalizedName.contains('거인') ||
        normalizedName.contains('탈로스') ||
        normalizedName.contains('golem')) {
      return ancientQuarryGolem;
    }
    if (normalizedName.contains('서리') ||
        normalizedName.contains('얼음') ||
        normalizedName.contains('frost')) {
      return frostShroom;
    }
    if (normalizedName.contains('독') ||
        normalizedName.contains('toxic') ||
        normalizedName.contains('poison')) {
      return toxicShroom;
    }
    if (normalizedName.contains('가시') || normalizedName.contains('thorn')) {
      return thornShroom;
    }
    if (normalizedName.contains('버섯') ||
        normalizedName.contains('포자') ||
        normalizedName.contains('shroom') ||
        normalizedName.contains('mushroom') ||
        normalizedName.contains('spore')) {
      return sporeShroom;
    }
    if (normalizedName.contains('흉폭') ||
        normalizedName.contains('club') ||
        normalizedName.contains('bruiser') ||
        normalizedName.contains('boss')) {
      return fierceGoblin;
    }
    if (normalizedName.contains('폭탄') || normalizedName.contains('bomb')) {
      return bomberGoblin;
    }
    if (normalizedName.contains('궁수') || normalizedName.contains('archer')) {
      return archerGoblin;
    }
    if (normalizedName.contains('창') || normalizedName.contains('spear')) {
      return spearGoblin;
    }
    if (normalizedName.contains('고블린') || normalizedName.contains('goblin')) {
      return basicGoblin;
    }

    return greenGoblin;
  }
}
