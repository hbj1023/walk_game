import 'package:capstone_app/services/game_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weapon_type values are normalized for sprite selection', () {
    final template = ItemTemplate.fromJson({
      'id': 'weapon-1',
      'name': 'Test sword',
      'item_type': 'equipment',
      'equipment_slot': 'sword',
      'weapon_type': ' Sword ',
    });

    expect(template.weaponType, 'sword');
  });

  test('weapon type is inferred from the equipment set when omitted', () {
    final template = ItemTemplate.fromJson({
      'id': 'weapon-2',
      'name': '균열자 대검',
      'item_type': 'equipment',
      'equipment_slot': '',
      'weapon_type': '',
      'set_key': 'riftbreaker',
      'set_piece_type': 'weapon',
    });

    expect(template.isWeapon, isTrue);
    expect(template.effectiveWeaponType, 'greatsword');
  });

  test('weapon type is inferred from a localized item name', () {
    final template = ItemTemplate.fromJson({
      'id': 'weapon-3',
      'name': '채석단 창술사 창',
      'item_type': 'equipment',
      'equipment_slot': 'sword',
      'weapon_type': '',
      'set_key': '',
      'set_piece_type': 'weapon',
    });

    expect(template.effectiveWeaponType, 'spear');
  });
}
