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
}
