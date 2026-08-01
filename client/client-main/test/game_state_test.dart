import 'package:flutter_test/flutter_test.dart';

import 'package:capstone_app/services/game_state.dart';

void main() {
  test('캐릭터 진행 정보를 한 번의 알림으로 갱신한다', () {
    final state = GameState.instance;
    var notificationCount = 0;
    void listener() => notificationCount++;
    state.addListener(listener);
    addTearDown(() => state.removeListener(listener));

    final nextCoins = state.coins + 17;
    final nextLevel = state.level + 1;
    final nextExp = state.exp + 23;
    final nextStatExp = state.statExp + 1;

    state.setCharacterProgress(
      coins: nextCoins,
      level: nextLevel,
      exp: nextExp,
      statExp: nextStatExp,
    );

    expect(state.coins, nextCoins);
    expect(state.level, nextLevel);
    expect(state.exp, nextExp);
    expect(state.statExp, nextStatExp);
    expect(notificationCount, 1);

    state.setCharacterProgress(
      coins: nextCoins,
      level: nextLevel,
      exp: nextExp,
      statExp: nextStatExp,
    );
    expect(notificationCount, 1);
  });
}
