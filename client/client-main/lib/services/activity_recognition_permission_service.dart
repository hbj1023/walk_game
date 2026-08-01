import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ActivityRecognitionPermissionService {
  static const _channel = MethodChannel('cap1/activity_permission');

  static bool? _granted;
  static Future<bool>? _pendingCheck;
  static Future<bool>? _pendingRequest;

  static bool get isGranted => _granted == true;

  /// Checks the current permission without opening a system permission dialog.
  static Future<bool> checkGranted({bool force = false}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return SynchronousFuture(true);
    }
    if (!force && _granted == true) return SynchronousFuture(true);
    return _pendingCheck ??= _checkGranted().whenComplete(() {
      _pendingCheck = null;
    });
  }

  /// Requests the permission only when the startup check found it missing.
  static Future<bool> ensureGranted() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return SynchronousFuture(true);
    }
    if (_granted == true) return SynchronousFuture(true);
    return _pendingRequest ??= _ensureGranted().whenComplete(() {
      _pendingRequest = null;
    });
  }

  static Future<bool> _checkGranted() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>(
            'checkActivityRecognitionPermission',
          ) ??
          false;
      _granted = granted;
      return granted;
    } on PlatformException {
      _granted = false;
      return false;
    }
  }

  static Future<bool> _ensureGranted() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>(
            'ensureActivityRecognitionPermission',
          ) ??
          false;
      _granted = granted;
      return granted;
    } on PlatformException {
      _granted = false;
      return false;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _granted = null;
    _pendingCheck = null;
    _pendingRequest = null;
  }
}
