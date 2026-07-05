String resolveEquipmentImagePath({
  required String imagePath,
  required String itemType,
  required String equipmentSlot,
  required String weaponType,
  required String setKey,
  required String setPieceType,
  required String name,
}) {
  final explicitImagePath = imagePath.trim();
  if (explicitImagePath.isNotEmpty) return explicitImagePath;
  if (itemType != 'equipment') return '';

  final chapter2ImagePath = _chapter2EquipmentImagePath(
    equipmentSlot: equipmentSlot,
    weaponType: weaponType,
    setKey: setKey,
    setPieceType: setPieceType,
    name: name,
  );
  if (chapter2ImagePath.isNotEmpty) return chapter2ImagePath;

  return _chapter1EquipmentImagePath(name);
}

String _chapter1EquipmentImagePath(String name) {
  final normalizedName = name.replaceAll(' ', '').trim();
  return switch (normalizedName) {
    '낡은모자' => 'assets/images/equipment/chapter1/tutorial_armor_helmet.png',
    '낡은갑옷' => 'assets/images/equipment/chapter1/tutorial_armor_chest.png',
    '낡은신발' => 'assets/images/equipment/chapter1/tutorial_armor_boots.png',
    '튼튼한모자' => 'assets/images/equipment/chapter1/stage1_armor_helmet.png',
    '튼튼한갑옷' => 'assets/images/equipment/chapter1/stage1_armor_chest.png',
    '튼튼한신발' => 'assets/images/equipment/chapter1/stage1_armor_boots.png',
    '초급검' =>
      'assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png',
    '레어검' => 'assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png',
    '에픽검' => 'assets/images/equipment/chapter1/epic_green_brass_sword.png',
    '에픽투구' => 'assets/images/equipment/chapter1/epic_green_brass_helmet.png',
    '에픽갑옷' => 'assets/images/equipment/chapter1/epic_green_brass_armor.png',
    '에픽신발' => 'assets/images/equipment/chapter1/epic_green_brass_boots.png',
    _ => '',
  };
}

String _chapter2EquipmentImagePath({
  required String equipmentSlot,
  required String weaponType,
  required String setKey,
  required String setPieceType,
  required String name,
}) {
  final inferredSetKey = _inferSetKey(setKey, name);
  if (inferredSetKey.isEmpty) return '';

  final inferredPieceType = _inferPieceType(
    equipmentSlot: equipmentSlot,
    setPieceType: setPieceType,
    name: name,
  );

  if (inferredPieceType == 'weapon') {
    final inferredWeaponType = weaponType.isNotEmpty
        ? weaponType
        : _weaponTypeForSet(inferredSetKey);
    return switch (inferredWeaponType) {
      'sword' => 'assets/images/equipment/chapter2/ch2_weapon_sword.png',
      'axe' => 'assets/images/equipment/chapter2/ch2_weapon_axe.png',
      'spear' => 'assets/images/equipment/chapter2/ch2_weapon_spear.png',
      'dagger' => 'assets/images/equipment/chapter2/ch2_weapon_dagger.png',
      'greatsword' =>
        'assets/images/equipment/chapter2/ch2_weapon_colossus.png',
      _ => '',
    };
  }

  final pieceSuffix = switch (inferredPieceType) {
    'helmet' => 'helmet',
    'armor' => 'armor',
    'shoes' => 'boots',
    _ => '',
  };
  if (pieceSuffix.isEmpty) return '';

  final assetSetKey = switch (inferredSetKey) {
    'vanguard' => 'berserker',
    'berserker' => 'shadow',
    'sentinel' => 'sentinel',
    'shadow' => 'vanguard',
    'colossus' => 'colossus',
    _ => '',
  };
  if (assetSetKey.isEmpty) return '';

  return 'assets/images/equipment/chapter2/ch2_armor_${assetSetKey}_$pieceSuffix.png';
}

String _inferSetKey(String setKey, String name) {
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

String _inferPieceType({
  required String equipmentSlot,
  required String setPieceType,
  required String name,
}) {
  if (setPieceType.isNotEmpty) return setPieceType;
  if (equipmentSlot == 'sword') return 'weapon';
  if (equipmentSlot.isNotEmpty) return equipmentSlot;

  final lowerName = name.toLowerCase();
  if (lowerName.contains('helm') || name.contains('투구') || name.contains('건')) {
    return 'helmet';
  }
  if (lowerName.contains('armor') || name.contains('갑옷')) return 'armor';
  if (lowerName.contains('boots') || name.contains('신발')) return 'shoes';
  return '';
}

String _weaponTypeForSet(String setKey) {
  return switch (setKey) {
    'vanguard' => 'sword',
    'berserker' => 'axe',
    'sentinel' => 'spear',
    'shadow' => 'dagger',
    'colossus' => 'greatsword',
    _ => '',
  };
}
