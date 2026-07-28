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
}
