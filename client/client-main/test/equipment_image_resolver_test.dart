import 'package:capstone_app/services/equipment_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String armorPath(String setKey, String rarity) {
    return resolveEquipmentImagePath(
      imagePath: '',
      rarity: rarity,
      itemType: 'equipment',
      equipmentSlot: 'armor',
      weaponType: '',
      setKey: setKey,
      setPieceType: 'armor',
      name: '',
    );
  }

  test('2장 일반 갑옷은 직업별 색상 에셋을 사용한다', () {
    expect(armorPath('vanguard', 'common'), contains('armor_berserker_'));
    expect(armorPath('berserker', 'common'), contains('armor_shadow_'));
    expect(armorPath('shadow', 'common'), contains('armor_vanguard_'));
  });

  test('2장 희귀 갑옷도 일반과 같은 직업별 색상 에셋을 사용한다', () {
    expect(armorPath('vanguard', 'rare'), contains('armor_rare_berserker_'));
    expect(armorPath('berserker', 'rare'), contains('armor_rare_shadow_'));
    expect(armorPath('shadow', 'rare'), contains('armor_rare_vanguard_'));
  });

  test('서버 세트 키에 공백이나 대문자가 섞여도 같은 에셋을 사용한다', () {
    expect(armorPath(' VANGUARD ', 'common'), contains('armor_berserker_'));
    expect(armorPath(' BERSERKER ', 'rare'), contains('armor_rare_shadow_'));
    expect(armorPath(' SHADOW ', 'common'), contains('armor_vanguard_'));
  });

  test('3장 명시 이미지 경로는 그대로 사용한다', () {
    final path = resolveEquipmentImagePath(
      imagePath: 'assets/images/equipment/chapter3/ch3_weapon_rare_sword.png',
      rarity: 'rare',
      itemType: 'equipment',
      equipmentSlot: 'sword',
      weaponType: 'sword',
      setKey: 'vanguard',
      setPieceType: 'weapon',
      name: '',
    );

    expect(path, 'assets/images/equipment/chapter3/ch3_weapon_rare_sword.png');
  });

  test('파쇄자 무기는 3장 무기 에셋을 사용한다', () {
    final path = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'rare',
      itemType: 'equipment',
      equipmentSlot: 'sword',
      weaponType: 'greatsword',
      setKey: 'crusher',
      setPieceType: 'weapon',
      name: '파쇄자 대검',
    );

    expect(
      path,
      'assets/images/equipment/chapter3/ch3_weapon_rare_greatsword.png',
    );
  });

  test('3장 채석단 방어구는 세트와 등급별 전용 에셋을 사용한다', () {
    expect(
      armorPath('quarry_swordsman', 'common'),
      'assets/images/equipment/chapter3/ch3_common_vanguard_armor.png',
    );
    expect(
      armorPath('quarry_rogue', 'rare'),
      'assets/images/equipment/chapter3/ch3_rare_shadow_armor.png',
    );
    expect(
      armorPath('quarry_knight', 'rare'),
      'assets/images/equipment/chapter3/ch3_rare_colossus_armor.png',
    );
  });

  test('3장 채석단 무기는 세트 키만으로 3장 에셋을 사용한다', () {
    final path = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'rare',
      itemType: 'equipment',
      equipmentSlot: 'sword',
      weaponType: 'axe',
      setKey: 'quarry_berserker',
      setPieceType: 'weapon',
      name: '+채석단 광전사 도끼',
    );

    expect(path, 'assets/images/equipment/chapter3/ch3_weapon_rare_axe.png');
  });

  test('세트 키가 없어도 채석단 무기 이름으로 3장 에셋을 사용한다', () {
    final commonPath = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'common',
      itemType: 'equipment',
      equipmentSlot: 'sword',
      weaponType: 'spear',
      setKey: '',
      setPieceType: 'weapon',
      name: '채석단 창술사 창',
    );
    final rarePath = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'rare',
      itemType: 'equipment',
      equipmentSlot: 'sword',
      weaponType: 'dagger',
      setKey: '',
      setPieceType: 'weapon',
      name: '+채석단 도적 단검',
    );

    expect(commonPath, 'assets/images/equipment/chapter3/ch3_weapon_spear.png');
    expect(
      rarePath,
      'assets/images/equipment/chapter3/ch3_weapon_rare_dagger.png',
    );
  });

  test('세트 키가 없어도 채석단 방어구 이름으로 세트 이미지를 찾는다', () {
    final commonPath = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'common',
      itemType: 'equipment',
      equipmentSlot: 'helmet',
      weaponType: '',
      setKey: '',
      setPieceType: 'helmet',
      name: '채석단 검사 투구',
    );
    final rarePath = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'rare',
      itemType: 'equipment',
      equipmentSlot: 'shoes',
      weaponType: '',
      setKey: '',
      setPieceType: 'shoes',
      name: '+채석단 기사 장화',
    );

    expect(
      commonPath,
      'assets/images/equipment/chapter3/ch3_common_vanguard_helmet.png',
    );
    expect(
      rarePath,
      'assets/images/equipment/chapter3/ch3_rare_colossus_boots.png',
    );
  });

  test('균열자 세트는 이미지 경로가 없어도 에픽 전용 에셋을 사용한다', () {
    final weaponPath = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'epic',
      itemType: 'equipment',
      equipmentSlot: 'sword',
      weaponType: 'greatsword',
      setKey: 'riftbreaker',
      setPieceType: 'weapon',
      name: '균열자 대검',
    );
    final armorPath = resolveEquipmentImagePath(
      imagePath: '',
      rarity: 'epic',
      itemType: 'equipment',
      equipmentSlot: 'armor',
      weaponType: '',
      setKey: 'riftbreaker',
      setPieceType: 'armor',
      name: '균열자 갑옷',
    );

    expect(
      weaponPath,
      'assets/images/equipment/chapter3/ch3_epic_riftstone_greatsword.png',
    );
    expect(
      armorPath,
      'assets/images/equipment/chapter3/ch3_epic_riftstone_armor.png',
    );
  });
}
