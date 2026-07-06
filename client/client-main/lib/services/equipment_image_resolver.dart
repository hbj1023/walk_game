String resolveEquipmentImagePath({
  required String imagePath,
  required String rarity,
  required String itemType,
  required String equipmentSlot,
  required String weaponType,
  required String setKey,
  required String setPieceType,
  required String name,
}) {
  if (itemType != 'equipment') return '';

  final chapter1ImagePath = _chapter1EquipmentImagePath(name);
  if (chapter1ImagePath.isNotEmpty) return chapter1ImagePath;

  final weaponImagePath = _weaponImagePath(
    equipmentSlot: equipmentSlot,
    setPieceType: setPieceType,
    weaponType: weaponType,
    name: name,
    rarity: rarity,
  );
  if (weaponImagePath.isNotEmpty) return weaponImagePath;

  final chapter2ImagePath = _chapter2EquipmentImagePath(
    equipmentSlot: equipmentSlot,
    weaponType: weaponType,
    setKey: setKey,
    setPieceType: setPieceType,
    name: name,
    rarity: rarity,
  );
  if (chapter2ImagePath.isNotEmpty) return chapter2ImagePath;

  final explicitImagePath = imagePath.trim();
  if (explicitImagePath.isNotEmpty) return explicitImagePath;

  return '';
}

String _chapter1EquipmentImagePath(String name) {
  final normalizedName = name.replaceAll(' ', '').trim();
  return switch (normalizedName) {
    '부서진검' =>
      'assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png',
    '낡은모자' => 'assets/images/equipment/chapter1/tutorial_armor_helmet.png',
    '낡은갑옷' => 'assets/images/equipment/chapter1/tutorial_armor_chest.png',
    '낡은신발' => 'assets/images/equipment/chapter1/tutorial_armor_boots.png',
    '튼튼한모자' => 'assets/images/equipment/chapter1/stage1_armor_helmet.png',
    '튼튼한갑옷' => 'assets/images/equipment/chapter1/stage1_armor_chest.png',
    '튼튼한신발' => 'assets/images/equipment/chapter1/stage1_armor_boots.png',
    '낡은검' =>
      'assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png',
    '초급검' =>
      'assets/images/equipment/chapter1/tutorial_weapon_beginner_sword.png',
    '일반검' => 'assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png',
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
  required String rarity,
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
    return _chapter2WeaponImagePath(inferredWeaponType, rarity: rarity);
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

String _weaponImagePath({
  required String equipmentSlot,
  required String setPieceType,
  required String weaponType,
  required String name,
  required String rarity,
}) {
  if (equipmentSlot != 'sword' && setPieceType != 'weapon') return '';

  final inferredWeaponType = weaponType.isNotEmpty
      ? weaponType
      : _inferWeaponTypeFromName(name);
  return _chapter2WeaponImagePath(inferredWeaponType, rarity: rarity);
}

String _inferWeaponTypeFromName(String name) {
  if (name.contains('대검')) return 'greatsword';
  if (name.contains('도끼')) return 'axe';
  if (name.contains('창')) return 'spear';
  if (name.contains('단검')) return 'dagger';
  if (name.contains('검')) return 'sword';

  final lowerName = name.toLowerCase();
  if (lowerName.contains('greatsword') || lowerName.contains('colossus')) {
    return 'greatsword';
  }
  if (lowerName.contains('axe') || lowerName.contains('berserker')) {
    return 'axe';
  }
  if (lowerName.contains('spear') || lowerName.contains('sentinel')) {
    return 'spear';
  }
  if (lowerName.contains('dagger') || lowerName.contains('shadow')) {
    return 'dagger';
  }
  if (lowerName.contains('sword') || lowerName.contains('vanguard')) {
    return 'sword';
  }
  return '';
}

String _chapter2WeaponImagePath(String weaponType, {String rarity = ''}) {
  final isRare = rarity.trim().toLowerCase() == 'rare';
  return switch (weaponType) {
    'sword' =>
      isRare
          ? 'assets/images/equipment/chapter2/ch2_weapon_rare_sword.png'
          : 'assets/images/equipment/chapter2/ch2_weapon_sword.png',
    'axe' =>
      isRare
          ? 'assets/images/equipment/chapter2/ch2_weapon_rare_axe.png'
          : 'assets/images/equipment/chapter2/ch2_weapon_axe.png',
    'spear' =>
      isRare
          ? 'assets/images/equipment/chapter2/ch2_weapon_rare_spear.png'
          : 'assets/images/equipment/chapter2/ch2_weapon_spear.png',
    'dagger' =>
      isRare
          ? 'assets/images/equipment/chapter2/ch2_weapon_rare_dagger.png'
          : 'assets/images/equipment/chapter2/ch2_weapon_dagger.png',
    'greatsword' =>
      isRare
          ? 'assets/images/equipment/chapter2/ch2_weapon_rare_greatsword.png'
          : 'assets/images/equipment/chapter2/ch2_weapon_colossus.png',
    _ => '',
  };
}
