import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class OfflineAttackNotificationService {
  static const _channel = MethodChannel('cap1/offline_attack_notification');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> requestPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'ensureNotificationPermission',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> configure({
    required int currentBalance,
    required int capacity,
    required double offlineAttackDistanceM,
    required double attackDistanceRemainderM,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('configure', {
        'currentBalance': currentBalance,
        'capacity': capacity,
        'offlineAttackDistanceM': offlineAttackDistanceM,
        'attackDistanceRemainderM': attackDistanceRemainderM,
      });
    } on PlatformException {
      // Notification support must never block step synchronization.
    }
  }

  static Future<void> updateBalance(int currentBalance) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('updateBalance', {
        'currentBalance': currentBalance,
      });
    } on PlatformException {
      // Battle state remains authoritative when the native bridge is absent.
    }
  }
}
