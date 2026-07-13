import 'package:flutter/foundation.dart';

// 앱 전역 게임 상태 싱글톤 — 백엔드 연동 전까지 임시로 사용
// 추후 서버에서 fetch/update로 교체 예정
// TODO: ChangeNotifierProvider로 위젯 트리에 등록해야 notifyListeners()가 동작함
//       현재는 리스너가 없어 coins 변경이 UI에 자동 반영되지 않음 (각 페이지에서 setState로 수동 갱신 중)
class GameState extends ChangeNotifier {
  GameState._();
  static final GameState instance = GameState._();

  int _coins = 9999;
  int _level = 1;
  int _exp = 0;
  int _statExp = 0;
  int _attackCountBalance = 0;
  int _bossTicketFragments = 0;
  String _profileIconKey = 'vanguard';
  String? _profileImageDataUrl;

  int get coins => _coins;
  int get level => _level;
  int get exp => _exp;
  int get statExp => _statExp;
  int get expToNextLevel => (_level < 1 ? 1 : _level) * 100;
  int get attackCountBalance => _attackCountBalance;
  int get bossTicketFragments => _bossTicketFragments;
  String get profileIconKey => _profileIconKey;
  String? get profileImageDataUrl => _profileImageDataUrl;

  void setCoins(int value) {
    if (_coins == value) return;
    _coins = value;
    notifyListeners();
  }

  void setAttackCountBalance(int value) {
    if (_attackCountBalance == value) return;
    _attackCountBalance = value;
    notifyListeners();
  }

  void setBossTicketFragments(int value) {
    final next = value < 0 ? 0 : value;
    if (_bossTicketFragments == next) return;
    _bossTicketFragments = next;
    notifyListeners();
  }

  void setLevel(int value) {
    final next = value < 1 ? 1 : value;
    if (_level == next) return;
    _level = next;
    notifyListeners();
  }

  void setExp(int value) {
    final next = value < 0 ? 0 : value;
    if (_exp == next) return;
    _exp = next;
    notifyListeners();
  }

  void setStatExp(int value) {
    final next = value < 0 ? 0 : value;
    if (_statExp == next) return;
    _statExp = next;
    notifyListeners();
  }

  void setProfileIconKey(String value) {
    final next = value.trim().isEmpty ? 'vanguard' : value.trim();
    if (_profileIconKey == next) return;
    _profileIconKey = next;
    notifyListeners();
  }

  void setProfileImageDataUrl(String? value) {
    final next = value?.trim();
    final normalized = next == null || next.isEmpty ? null : next;
    if (_profileImageDataUrl == normalized) return;
    _profileImageDataUrl = normalized;
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

  bool spendExp(int amount) {
    if (_exp < amount) return false;
    _exp -= amount;
    notifyListeners();
    return true;
  }

  void addExp(int amount) {
    _exp += amount;
    notifyListeners();
  }

  bool spendStatExp(int amount) {
    if (_statExp < amount) return false;
    _statExp -= amount;
    notifyListeners();
    return true;
  }

  void addStatExp(int amount) {
    _statExp += amount;
    notifyListeners();
  }
}
