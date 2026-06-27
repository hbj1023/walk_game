import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';

import 'game_api_service.dart';

typedef StepSyncCallback =
    Future<StepSyncResult> Function(StepSyncRequest request);
typedef StepSyncSuccessCallback =
    FutureOr<void> Function(StepSyncResult result, StepSyncContext context);
typedef StepTrackingErrorCallback = void Function(Object error);
typedef StepTrackingStatusPartsBuilder = Iterable<String> Function();
typedef StepTrackingActiveGuard = bool Function();

class StepSyncRequest {
  final int stepCount;
  final double strideM;
  final int gpsDistanceM;
  final String abnormalReason;

  const StepSyncRequest({
    required this.stepCount,
    required this.strideM,
    required this.gpsDistanceM,
    required this.abnormalReason,
  });
}

class StepSyncContext {
  final bool allowPostSyncActions;
  final bool updateState;

  const StepSyncContext({
    required this.allowPostSyncActions,
    required this.updateState,
  });
}

class StepTrackingController extends ChangeNotifier {
  static const strideM = 0.75;

  static const _stepSyncThreshold = 20;
  static const _gpsSampleInterval = Duration(seconds: 15);
  static const _gpsPositionTimeout = Duration(seconds: 10);
  static const _gpsMinMovementM = 6.0;
  static const _gpsMaxAccuracyM = 60.0;
  static const _gpsMaxAcceptedSpeedMps = 8.0;
  static const _gpsAssistMismatchMinM = 80.0;
  static const _gpsAssistMismatchRatio = 0.6;
  static const _activityPermissionChannel = MethodChannel(
    'cap1/activity_permission',
  );

  final StepSyncCallback onSyncSteps;
  final StepSyncSuccessCallback? onSyncSuccess;
  final StepTrackingErrorCallback? onStartError;
  final StepTrackingErrorCallback? onSyncError;
  final StepTrackingStatusPartsBuilder? additionalStatusParts;
  final StepTrackingActiveGuard? canTrack;
  final String trackingStatusLabel;
  final String stoppedStatusLabel;
  final String permissionStatusLabel;
  final String sensorConnectingStatusLabel;
  final String syncingStatusNote;
  final String syncFailedStatusNote;
  final String gpsEnabledStatusNote;
  final String gpsDisabledStatusNote;
  final String gpsSampleFailedStatusNote;
  final String fastGpsMovementStatusNote;
  final String Function(int distanceM) gpsDistanceStatusBuilder;
  final String Function(Object error)? startErrorStatusBuilder;
  final String? Function(StepSyncResult result)? syncSuccessStatusNoteBuilder;

  bool isTracking = false;
  bool isStarting = false;
  bool isSyncing = false;
  int sessionStepCount = 0;
  int pendingStepCount = 0;
  double gpsSessionDistanceM = 0;
  String statusLabel;

  bool _isGpsSampling = false;
  int? _lastStepSensorCount;
  double _gpsAssistDistanceSinceLastSyncM = 0;
  String? _pedestrianStatusLabel;
  Timer? _gpsTimer;
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  Position? _lastGpsPosition;
  bool _isDisposed = false;

  StepTrackingController({
    required this.onSyncSteps,
    required String initialStatusLabel,
    required this.trackingStatusLabel,
    required this.stoppedStatusLabel,
    required this.permissionStatusLabel,
    required this.sensorConnectingStatusLabel,
    required this.syncingStatusNote,
    required this.syncFailedStatusNote,
    required this.gpsEnabledStatusNote,
    required this.gpsDisabledStatusNote,
    required this.gpsSampleFailedStatusNote,
    required this.fastGpsMovementStatusNote,
    required this.gpsDistanceStatusBuilder,
    this.onSyncSuccess,
    this.onStartError,
    this.onSyncError,
    this.additionalStatusParts,
    this.canTrack,
    this.startErrorStatusBuilder,
    this.syncSuccessStatusNoteBuilder,
  }) : statusLabel = initialStatusLabel;

  factory StepTrackingController.home({
    required StepSyncCallback onSyncSteps,
    StepSyncSuccessCallback? onSyncSuccess,
    StepTrackingErrorCallback? onStartError,
    StepTrackingErrorCallback? onSyncError,
  }) {
    return StepTrackingController(
      onSyncSteps: onSyncSteps,
      onSyncSuccess: onSyncSuccess,
      onStartError: onStartError,
      onSyncError: onSyncError,
      initialStatusLabel: '걸음 추적 대기',
      trackingStatusLabel: '걸음 추적 중',
      stoppedStatusLabel: '걸음 추적 중지',
      permissionStatusLabel: '걸음 권한 확인 중',
      sensorConnectingStatusLabel: '걸음 센서 연결 중',
      syncingStatusNote: '걸음 서버 반영 중',
      syncFailedStatusNote: '걸음 반영 실패',
      gpsEnabledStatusNote: 'GPS 보조 켜짐',
      gpsDisabledStatusNote: 'GPS 보조 꺼짐',
      gpsSampleFailedStatusNote: 'GPS 샘플 실패',
      fastGpsMovementStatusNote: '빠른 GPS 이동 제외',
      gpsDistanceStatusBuilder: (distanceM) => 'GPS 보조 ${distanceM}m',
      startErrorStatusBuilder: (_) => '걸음 추적 대기',
    );
  }

  factory StepTrackingController.battle({
    required StepSyncCallback onSyncSteps,
    StepSyncSuccessCallback? onSyncSuccess,
    StepTrackingStatusPartsBuilder? additionalStatusParts,
    StepTrackingActiveGuard? canTrack,
    String? Function(StepSyncResult result)? syncSuccessStatusNoteBuilder,
  }) {
    return StepTrackingController(
      onSyncSteps: onSyncSteps,
      onSyncSuccess: onSyncSuccess,
      additionalStatusParts: additionalStatusParts,
      canTrack: canTrack,
      syncSuccessStatusNoteBuilder: syncSuccessStatusNoteBuilder,
      initialStatusLabel: '걸음 추적 준비',
      trackingStatusLabel: '자동 걸음 전투',
      stoppedStatusLabel: '걸음 추적 중지',
      permissionStatusLabel: '걸음 권한 확인 중',
      sensorConnectingStatusLabel: '걸음 센서 연결 중',
      syncingStatusNote: '걸음 반영 중',
      syncFailedStatusNote: '걸음 반영 실패',
      gpsEnabledStatusNote: 'GPS 보조 켜짐',
      gpsDisabledStatusNote: 'GPS 보조 꺼짐',
      gpsSampleFailedStatusNote: 'GPS 샘플 실패',
      fastGpsMovementStatusNote: '빠른 GPS 이동 제외',
      gpsDistanceStatusBuilder: (distanceM) => 'GPS ${distanceM}m',
    );
  }

  double get pendingDistanceM => pendingStepCount * strideM;

  Future<void> toggle() {
    return isTracking ? stop() : start();
  }

  Future<void> start() async {
    if (isTracking || isStarting || isSyncing || !_canTrackNow) return;

    _change(() {
      isStarting = true;
      statusLabel = permissionStatusLabel;
    });

    try {
      await _ensureStepTrackingPermission();
      await _cancelTrackingStreams();
      if (_isDisposed || !_canTrackNow) return;

      _change(() {
        isTracking = true;
        sessionStepCount = 0;
        pendingStepCount = 0;
        _lastStepSensorCount = null;
        gpsSessionDistanceM = 0;
        _gpsAssistDistanceSinceLastSyncM = 0;
        _lastGpsPosition = null;
        _pedestrianStatusLabel = null;
        statusLabel = sensorConnectingStatusLabel;
      });

      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _handleStepCount,
        onError: _handleStepCountError,
      );

      try {
        _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
          _handlePedestrianStatus,
          onError: (_) {},
        );
      } catch (_) {
        // Step count is the reward source; pedestrian status is optional UI data.
      }

      unawaited(_startGpsAssist());
    } catch (error) {
      if (_isDisposed) return;
      _change(() {
        isTracking = false;
        statusLabel = startErrorStatusBuilder?.call(error) ?? error.toString();
      });
      onStartError?.call(error);
    } finally {
      if (!_isDisposed) {
        _change(() => isStarting = false);
      }
    }
  }

  Future<void> stop({bool syncPending = true, bool updateState = true}) async {
    final hadPendingSteps = pendingStepCount > 0;
    isTracking = false;
    isStarting = false;

    await _cancelTrackingStreams();

    if (updateState) {
      _change(() => statusLabel = _buildStatus(note: '추적 중지'));
    }

    if (syncPending && hadPendingSteps) {
      await syncPendingSteps(
        force: true,
        allowPostSyncActions: false,
        updateState: updateState,
      );
    }
  }

  Future<void> syncPendingSteps({
    bool force = false,
    bool allowPostSyncActions = true,
    bool updateState = true,
  }) async {
    if (isSyncing) return;
    if (!force && pendingStepCount < _stepSyncThreshold) return;

    final stepCount = pendingStepCount;
    if (stepCount <= 0) return;

    final gpsDistanceM = _gpsAssistDistanceSinceLastSyncM.round();
    final abnormalReason = _gpsAssistAbnormalReasonFor(
      stepCount: stepCount,
      gpsDistanceM: gpsDistanceM.toDouble(),
    );

    isSyncing = true;
    if (updateState) {
      _change(() => statusLabel = _buildStatus(note: syncingStatusNote));
    }

    try {
      final result = await onSyncSteps(
        StepSyncRequest(
          stepCount: stepCount,
          strideM: strideM,
          gpsDistanceM: gpsDistanceM,
          abnormalReason: abnormalReason,
        ),
      );

      pendingStepCount -= stepCount;
      if (pendingStepCount < 0) pendingStepCount = 0;
      _gpsAssistDistanceSinceLastSyncM -= gpsDistanceM;
      if (_gpsAssistDistanceSinceLastSyncM < 0) {
        _gpsAssistDistanceSinceLastSyncM = 0;
      }

      if (!_isDisposed) {
        await onSyncSuccess?.call(
          result,
          StepSyncContext(
            allowPostSyncActions: allowPostSyncActions,
            updateState: updateState,
          ),
        );
      }

      if (updateState) {
        _change(() {
          statusLabel = _buildStatus(
            note: syncSuccessStatusNoteBuilder?.call(result),
          );
        });
      }
    } catch (error) {
      if (updateState) {
        _change(() => statusLabel = _buildStatus(note: syncFailedStatusNote));
      }
      if (!_isDisposed) {
        onSyncError?.call(error);
      }
    } finally {
      isSyncing = false;
      if (updateState) {
        _change(() => statusLabel = _buildStatus());
      }
    }
  }

  void _handleStepCount(StepCount event) {
    if (!isTracking || !_canTrackNow) return;

    final currentSteps = event.steps;
    final previousSteps = _lastStepSensorCount;
    if (previousSteps == null) {
      _change(() {
        _lastStepSensorCount = currentSteps;
        statusLabel = _buildStatus(note: '기준값 설정 완료');
      });
      return;
    }

    if (currentSteps < previousSteps) {
      _change(() {
        _lastStepSensorCount = currentSteps;
        statusLabel = _buildStatus(note: '걸음 센서 재설정');
      });
      return;
    }

    final deltaSteps = currentSteps - previousSteps;
    if (deltaSteps == 0) return;

    _change(() {
      _lastStepSensorCount = currentSteps;
      sessionStepCount += deltaSteps;
      pendingStepCount += deltaSteps;
      statusLabel = _buildStatus();
    });

    if (pendingStepCount >= _stepSyncThreshold) {
      unawaited(syncPendingSteps());
    }
  }

  void _handleStepCountError(Object error) {
    final hadPendingSteps = pendingStepCount > 0;
    unawaited(_cancelTrackingStreams());
    _change(() {
      isTracking = false;
      statusLabel = '걸음 센서 오류: $error';
    });
    if (hadPendingSteps) {
      unawaited(syncPendingSteps(force: true));
    }
  }

  void _handlePedestrianStatus(PedestrianStatus event) {
    if (!isTracking || !_canTrackNow) return;
    _change(() {
      _pedestrianStatusLabel = switch (event.status) {
        'walking' => '걷는 중',
        'stopped' => '정지',
        _ => null,
      };
      statusLabel = _buildStatus();
    });
  }

  Future<void> _startGpsAssist() async {
    _gpsTimer?.cancel();
    try {
      await _ensureLocationPermission();
      final position = await _readGpsPosition();
      if (!isTracking || !_canTrackNow) return;
      _lastGpsPosition = position;
      _gpsTimer = Timer.periodic(
        _gpsSampleInterval,
        (_) => _sampleGpsAssistDistance(),
      );
      _change(() => statusLabel = _buildStatus(note: gpsEnabledStatusNote));
    } catch (_) {
      if (isTracking && _canTrackNow) {
        _change(() => statusLabel = _buildStatus(note: gpsDisabledStatusNote));
      }
    }
  }

  Future<void> _sampleGpsAssistDistance() async {
    if (!isTracking || _isGpsSampling || !_canTrackNow) return;

    _isGpsSampling = true;
    try {
      final current = await _readGpsPosition();
      if (!isTracking || !_canTrackNow) return;
      final previous = _lastGpsPosition;
      if (previous == null) {
        _lastGpsPosition = current;
        return;
      }

      if (current.accuracy > _gpsMaxAccuracyM) {
        _change(() {
          statusLabel = _buildStatus(
            note: 'GPS 오차 ${current.accuracy.round()}m',
          );
        });
        return;
      }

      final distanceM = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      final elapsedSeconds =
          current.timestamp
              .difference(previous.timestamp)
              .inMilliseconds
              .abs() /
          1000;
      final speedMps = elapsedSeconds <= 0 ? 0 : distanceM / elapsedSeconds;

      _lastGpsPosition = current;
      if (distanceM < _gpsMinMovementM) {
        _change(() => statusLabel = _buildStatus());
        return;
      }
      if (speedMps > _gpsMaxAcceptedSpeedMps) {
        _change(() {
          statusLabel = _buildStatus(note: fastGpsMovementStatusNote);
        });
        return;
      }

      gpsSessionDistanceM += distanceM;
      _gpsAssistDistanceSinceLastSyncM += distanceM;
      _change(() => statusLabel = _buildStatus());
    } catch (_) {
      _change(
        () => statusLabel = _buildStatus(note: gpsSampleFailedStatusNote),
      );
    } finally {
      _isGpsSampling = false;
    }
  }

  String _buildStatus({String? note}) {
    final parts = <String>[
      isTracking ? trackingStatusLabel : stoppedStatusLabel,
      '세션 $sessionStepCount보',
    ];
    if (pendingStepCount > 0) {
      parts.add('미반영 $pendingStepCount보');
    }
    parts.addAll(additionalStatusParts?.call() ?? const []);
    if (gpsSessionDistanceM > 0) {
      parts.add(gpsDistanceStatusBuilder(gpsSessionDistanceM.round()));
    }
    if (_pedestrianStatusLabel != null) {
      parts.add(_pedestrianStatusLabel!);
    }
    parts.add(note ?? _gpsAssistStatusNote() ?? '');
    parts.removeWhere((part) => part.isEmpty);
    return parts.join(' · ');
  }

  String? _gpsAssistStatusNote() {
    final stepDistanceM = sessionStepCount * strideM;
    final gpsDistanceM = gpsSessionDistanceM;
    if (stepDistanceM < 100 && gpsDistanceM < 100) return null;

    final differenceM = (stepDistanceM - gpsDistanceM).abs();
    final allowedM = math.max(
      _gpsAssistMismatchMinM,
      math.max(stepDistanceM, gpsDistanceM) * _gpsAssistMismatchRatio,
    );
    if (differenceM <= allowedM) return null;
    return gpsDistanceM > stepDistanceM ? 'GPS 이동 큼' : 'GPS 이동 작음';
  }

  String _gpsAssistAbnormalReasonFor({
    required int stepCount,
    required double gpsDistanceM,
  }) {
    final stepDistanceM = stepCount * strideM;
    if (stepDistanceM <= 0 || gpsDistanceM <= 0) return '';

    final differenceM = (stepDistanceM - gpsDistanceM).abs();
    final allowedM = math.max(
      _gpsAssistMismatchMinM,
      math.max(stepDistanceM, gpsDistanceM) * _gpsAssistMismatchRatio,
    );
    if (differenceM <= allowedM) return '';
    return gpsDistanceM > stepDistanceM
        ? 'gps_distance_exceeds_step_distance'
        : 'step_distance_exceeds_gps_distance';
  }

  Future<void> _ensureStepTrackingPermission() async {
    if (!_supportsStepTrackingPlatform) {
      throw const GameApiException('걸음 추적은 Android 또는 iOS 기기에서만 지원됩니다.');
    }
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final granted =
        await _activityPermissionChannel.invokeMethod<bool>(
          'ensureActivityRecognitionPermission',
        ) ??
        false;
    if (!granted) {
      throw const GameApiException('걸음 수 권한이 필요합니다. 앱 설정에서 신체 활동 권한을 허용해주세요.');
    }
  }

  bool get _supportsStepTrackingPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const GameApiException('기기 위치 서비스를 켜주세요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const GameApiException('위치 권한이 필요합니다.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GameApiException('위치 권한이 영구 거부되었습니다. 앱 설정에서 권한을 허용해주세요.');
    }
  }

  Future<Position> _readGpsPosition() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: _gpsPositionTimeout,
    );
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  Future<void> _cancelTrackingStreams() async {
    await _stepCountSubscription?.cancel();
    await _pedestrianStatusSubscription?.cancel();
    _stepCountSubscription = null;
    _pedestrianStatusSubscription = null;
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  bool get _canTrackNow => canTrack?.call() ?? true;

  void _change(VoidCallback change) {
    change();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _gpsTimer?.cancel();
    final stepCountSubscription = _stepCountSubscription;
    final pedestrianStatusSubscription = _pedestrianStatusSubscription;
    if (stepCountSubscription != null) {
      unawaited(stepCountSubscription.cancel());
    }
    if (pedestrianStatusSubscription != null) {
      unawaited(pedestrianStatusSubscription.cancel());
    }
    super.dispose();
  }
}
