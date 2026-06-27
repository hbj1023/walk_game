import 'package:flutter/foundation.dart';

// 앱 전역 게임 상태 싱글톤 — 백엔드 연동 전까지 임시로 사용
// 추후 서버에서 fetch/update로 교체 예정
// TODO: ChangeNotifierProvider로 위젯 트리에 등록해야 notifyListeners()가 동작함
//       현재는 리스너가 없어 coins 변경이 UI에 자동 반영되지 않음 (각 페이지에서 setState로 수동 갱신 중)
class GameState extends ChangeNotifier {
  GameState._();
  static final GameState instance = GameState._();

  int _coins = 9999;
  int _attackCountBalance = 0;

  int get coins => _coins;
  int get attackCountBalance => _attackCountBalance;

  void setCoins(int value) {
    _coins = value;
    notifyListeners();
  }

  void setAttackCountBalance(int value) {
    _attackCountBalance = value;
    notifyListeners();
  }

  // 코인 차감 — 잔액 부족 시 false 반환
  bool spendCoins(int amount) {
    if (_coins < amount) return false;
    _coins -= amount;
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    _coins += amount;
    notifyListeners();
  }
}
