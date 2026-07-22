import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_attack_notification_service.dart';

class InitialPermissionResult {
  const InitialPermissionResult({
    required this.activityGranted,
    required this.locationGranted,
    required this.notificationGranted,
  });

  final bool activityGranted;
  final bool locationGranted;
  final bool notificationGranted;

  bool get allGranted =>
      activityGranted && locationGranted && notificationGranted;
}

class InitialPermissionService {
  static const _completedKey = 'permissions:initial_request_completed';
  static const _notificationRequestedKey =
      'permissions:offline_notification_requested_v1';
  static const _activityPermissionChannel = MethodChannel(
    'cap1/activity_permission',
  );

  static Future<bool> shouldShow() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    final initialCompleted = prefs.getBool(_completedKey) ?? false;
    final needsAndroidNotification =
        defaultTargetPlatform == TargetPlatform.android &&
        !(prefs.getBool(_notificationRequestedKey) ?? false);
    return !initialCompleted || needsAndroidNotification;
  }

  static Future<InitialPermissionResult> requestAll() async {
    final activityGranted = await _requestActivityPermission();
    final locationGranted = await _requestLocationPermission();
    final notificationGranted =
        await OfflineAttackNotificationService.requestPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await prefs.setBool(_notificationRequestedKey, true);
    }
    return InitialPermissionResult(
      activityGranted: activityGranted,
      locationGranted: locationGranted,
      notificationGranted: notificationGranted,
    );
  }

  static Future<bool> _requestActivityPermission() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await _activityPermissionChannel.invokeMethod<bool>(
              'ensureActivityRecognitionPermission',
            ) ??
            false;
      } on PlatformException {
        return false;
      }
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      StreamSubscription<StepCount>? subscription;
      try {
        subscription = Pedometer.stepCountStream.listen(
          (_) {},
          onError: (_) {},
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return true;
      } catch (_) {
        return false;
      } finally {
        await subscription?.cancel();
      }
    }
    return true;
  }

  static Future<bool> _requestLocationPermission() async {
    if (kIsWeb) return true;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();
}
