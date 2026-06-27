class MonsterAssetService {
  static const greenGoblin = 'assets/images/monsters/green_goblin.png';
  static const redGoblin = 'assets/images/monsters/red_goblin.png';
  static const purpleGoblin = 'assets/images/monsters/purple_goblin.png';
  static const rainGoblin = 'assets/images/monsters/rain_goblin.png';
  static const bossGoblin = 'assets/images/monsters/boss_goblin.png';

  static String imageForMonster({required String name, int? stageNo}) {
    final normalizedName = name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalizedName.contains('보스') ||
        normalizedName.contains('boss') ||
        normalizedName.contains('수문장') ||
        normalizedName.contains('guardian')) {
      return bossGoblin;
    }

    if (normalizedName.contains('레인보우') ||
        normalizedName.contains('무지개') ||
        normalizedName.contains('rainbow') ||
        normalizedName.contains('rain')) {
      return rainGoblin;
    }

    if (normalizedName.contains('퍼플') ||
        normalizedName.contains('보라') ||
        normalizedName.contains('purple')) {
      return purpleGoblin;
    }

    if (normalizedName.contains('레드') ||
        normalizedName.contains('래드') ||
        normalizedName.contains('red')) {
      return redGoblin;
    }

    if (normalizedName.contains('그린') || normalizedName.contains('green')) {
      return greenGoblin;
    }

    return switch (stageNo) {
      2 => redGoblin,
      3 => purpleGoblin,
      4 => rainGoblin,
      5 => bossGoblin,
      _ => greenGoblin,
    };
  }
}
