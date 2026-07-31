import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'game_api_service.dart';

const offlineStepBaselinePrefix = 'offline_steps.baseline.';
const legacyStepSensorBaselineKey = 'step_tracking.last_sensor_count';

String offlineStepBaselineKey(String userId) =>
    '$offlineStepBaselinePrefix${userId.trim()}';

int calculateOfflineStepDelta({required int? baseline, required int current}) {
  if (baseline == null || current <= baseline) return 0;
  return current - baseline;
}

/// 화면이 꺼진 동안 누적된 기기 걸음을 앱 복귀 시 서버에 정산한다.
class OfflineStepReconciliationService {
  OfflineStepReconciliationService._();

  static final OfflineStepReconciliationService instance =
      OfflineStepReconciliationService._();
  static const _foregroundPersistenceStepInterval = 25;

  StreamSubscription<StepCount>? _stepSubscription;
  Future<void> _lifecycleQueue = Future<void>.value();
  Future<void> _stepEventQueue = Future<void>.value();
  bool _isForeground = false;
  bool _sessionReconciled = false;
  String? _activeUserId;
  int? _latestSensorSteps;
  int? _lastPersistedSensorSteps;

  Future<void> setAppInForeground(bool isForeground) {
    _isForeground = isForeground;
    return _queueLifecycle(
      isForeground ? _startForegroundSession : _stopForegroundSession,
    );
  }

  Future<void> refreshAccount() {
    if (!_isForeground) return Future<void>.value();
    return _queueLifecycle(_startForegroundSession);
  }

  Future<void> _queueLifecycle(Future<void> Function() operation) {
    _lifecycleQueue = _lifecycleQueue
        .catchError((Object error) {
          debugPrint('Offline step lifecycle failed: $error');
        })
        .then((_) => operation());
    return _lifecycleQueue;
  }

  Future<void> _startForegroundSession() async {
    if (!_supportsStepCounter || !_isForeground) return;

    final userId = (await AuthService.getSavedUserId())?.trim() ?? '';
    if (userId.isEmpty) {
      await _cancelStepSubscription();
      _activeUserId = null;
      _sessionReconciled = false;
      _latestSensorSteps = null;
      _lastPersistedSensorSteps = null;
      return;
    }

    if (_stepSubscription != null && _activeUserId == userId) return;

    await _cancelStepSubscription();
    _activeUserId = userId;
    _sessionReconciled = false;
    _latestSensorSteps = null;
    _lastPersistedSensorSteps = null;
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (Object error) {
          debugPrint('Offline step sensor failed: $error');
        },
      );
    } catch (error) {
      debugPrint('Offline step sensor connection failed: $error');
    }
  }

  Future<void> _stopForegroundSession() async {
    await _cancelStepSubscription();
    try {
      await _stepEventQueue;
    } catch (error) {
      debugPrint('Offline step event drain failed: $error');
    }
    final userId = _activeUserId;
    final latestSteps = _latestSensorSteps;
    if (_sessionReconciled &&
        userId != null &&
        userId.isNotEmpty &&
        latestSteps != null) {
      await _saveBaseline(userId, latestSteps);
    }
    _sessionReconciled = false;
    _latestSensorSteps = null;
    _lastPersistedSensorSteps = null;
  }

  void _onStepCount(StepCount event) {
    _latestSensorSteps = event.steps;
    _stepEventQueue = _stepEventQueue
        .catchError((Object error) {
          debugPrint('Offline step event failed: $error');
        })
        .then((_) => _processStepCount(event.steps));
  }

  Future<void> _processStepCount(int currentSteps) async {
    if (!_isForeground) return;

    final savedUserId = (await AuthService.getSavedUserId())?.trim() ?? '';
    if (savedUserId.isEmpty) {
      _activeUserId = null;
      _sessionReconciled = false;
      return;
    }
    if (_activeUserId != savedUserId) {
      _activeUserId = savedUserId;
      _sessionReconciled = false;
    }

    if (_sessionReconciled) {
      final persistedSteps = _lastPersistedSensorSteps;
      if (persistedSteps == null ||
          currentSteps < persistedSteps ||
          currentSteps - persistedSteps >= _foregroundPersistenceStepInterval) {
        await _saveBaseline(savedUserId, currentSteps);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = offlineStepBaselineKey(savedUserId);
    final baseline = prefs.getInt(key);
    _lastPersistedSensorSteps = baseline;
    if (baseline == null || currentSteps < baseline) {
      await _saveBaseline(savedUserId, currentSteps);
      _sessionReconciled = true;
      return;
    }

    final offlineSteps = calculateOfflineStepDelta(
      baseline: baseline,
      current: currentSteps,
    );
    if (offlineSteps > 0) {
      try {
        final result = await GameApiService.syncStepDelta(
          stepCount: offlineSteps,
          syncType: 'offline',
        );
        debugPrint(
          'Offline steps reconciled: $offlineSteps steps, '
          '${result.offlineAttackCountStored} attacks stored',
        );
      } catch (error) {
        debugPrint('Offline step sync failed; baseline retained: $error');
        return;
      }
    }

    await _saveBaseline(savedUserId, currentSteps);
    _sessionReconciled = true;
  }

  Future<void> _saveBaseline(String userId, int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(offlineStepBaselineKey(userId), steps),
      prefs.setInt(legacyStepSensorBaselineKey, steps),
    ]);
    _lastPersistedSensorSteps = steps;
  }

  Future<void> _cancelStepSubscription() async {
    final subscription = _stepSubscription;
    _stepSubscription = null;
    await subscription?.cancel();
  }

  bool get _supportsStepCounter =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
