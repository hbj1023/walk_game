import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';

import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/widgets/game_feedback.dart';

class GoldMineEventPage extends StatefulWidget {
  const GoldMineEventPage({super.key});

  @override
  State<GoldMineEventPage> createState() => _GoldMineEventPageState();
}

class _GoldMineEventPageState extends State<GoldMineEventPage> {
  static const _gold = Color(0xFFFFD45A);
  static const _panelColor = Color(0xFF24170B);
  GoldMineEventStatus? _status;
  GoldMineEventResult? _result;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<StepCount>? _stepSub;
  Timer? _timer;
  Position? _lastPosition;
  DateTime? _lastPositionAt;
  int? _startSteps;
  int _steps = 0;
  int _remainingSeconds = 180;
  double _distanceM = 0;
  double _maxSpeedKmh = 0;
  bool _loading = true;
  bool _starting = false;
  bool _running = false;
  bool _finishing = false;
  String? _runId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _stepSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await GameApiService.fetchGoldMineEventStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _remainingSeconds = status.durationSeconds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    if (_starting || _running || _status?.attemptedToday == true) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await _ensureLocationPermission();
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (initial.accuracy > 60) {
        throw const GameApiException('GPS 정확도가 낮습니다. 야외에서 다시 시도해주세요.');
      }
      final start = await GameApiService.startGoldMineEvent();
      _runId = start.runId;
      _lastPosition = initial;
      _lastPositionAt = DateTime.now();
      _remainingSeconds = start.durationSeconds;
      _listenToSteps();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(_onPosition, onError: _onTrackingError);
      if (!mounted) return;
      setState(() {
        _running = true;
        _starting = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_running) return;
        if (_remainingSeconds <= 1) {
          setState(() => _remainingSeconds = 0);
          _finish();
        } else {
          setState(() => _remainingSeconds--);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString();
      });
      showGameToast(context, e.toString(), type: GameToastType.error);
    }
  }

  void _listenToSteps() {
    try {
      _stepSub = Pedometer.stepCountStream.listen((event) {
        _startSteps ??= event.steps;
        final next = math.max(0, event.steps - (_startSteps ?? event.steps));
        if (mounted) setState(() => _steps = next);
      }, onError: (_) {});
    } catch (_) {}
  }

  void _onPosition(Position current) {
    if (!_running || current.accuracy > 60) return;
    final previous = _lastPosition;
    final previousAt = _lastPositionAt;
    _lastPosition = current;
    _lastPositionAt = DateTime.now();
    if (previous == null || previousAt == null) return;
    final segment = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final elapsed = math.max(
      0.2,
      DateTime.now().difference(previousAt).inMilliseconds / 1000,
    );
    final speedKmh = (segment / elapsed) * 3.6;
    if (segment < 1 || speedKmh > 30) return;
    setState(() {
      _distanceM += segment;
      _maxSpeedKmh = math.max(_maxSpeedKmh, speedKmh);
    });
  }

  void _onTrackingError(Object _) {
    if (mounted) setState(() => _error = 'GPS 신호가 불안정합니다. 야외에서 계속 이동해주세요.');
  }

  Future<void> _finish() async {
    if (_finishing || !_running || _runId == null) return;
    setState(() => _finishing = true);
    _timer?.cancel();
    await _positionSub?.cancel();
    await _stepSub?.cancel();
    try {
      final result = await GameApiService.finishGoldMineEvent(
        runId: _runId!,
        distanceM: _distanceM,
        stepCount: _steps,
        maxSpeedKmh: _maxSpeedKmh,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
        _finishing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
        _finishing = false;
      });
    }
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GameApiException('GPS를 켜야 황금 광맥에 입장할 수 있습니다.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const GameApiException('황금 광맥에는 위치 권한이 필요합니다.');
    }
  }

  int get _nextMilestone {
    for (final value in const [100, 200, 300, 400, 500, 600]) {
      if (_distanceM < value) return value;
    }
    return 600;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        backgroundColor: const Color(0xFF120D07),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171007),
          foregroundColor: Colors.white,
          title: const Text('황금 광맥 발견'),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _gold))
              : Padding(
                  padding: const EdgeInsets.all(14),
                  child: _result != null
                      ? _buildResult()
                      : (_running || _finishing
                            ? _buildRun()
                            : _buildBriefing()),
                ),
        ),
      ),
    );
  }

  Widget _buildBriefing() {
    final locked = _status == null || !_status!.unlocked;
    final attempted = _status?.attemptedToday == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: const Column(
            children: [
              Icon(Icons.diamond_outlined, color: _gold, size: 58),
              SizedBox(height: 10),
              Text(
                '3분 동안 광맥을 향해 달리세요',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'GPS 거리로 측정하고 만보기로 움직임을 확인합니다.\n600m 이후에는 기록만 계속 올라갑니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: const Column(
            children: [
              _RewardLine('400m', '520골드 · 찢어진 입장권 1개'),
              _RewardLine('500m', '누적 700골드 · 스탯 포인트 1개'),
              _RewardLine('600m', '누적 900골드 · 찢어진 입장권 총 4개'),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const Spacer(),
        FilledButton.icon(
          onPressed: locked || attempted || _starting ? null : _start,
          icon: Icon(_starting ? Icons.hourglass_top : Icons.directions_run),
          label: Text(
            locked
                ? '3-3 클리어 필요'
                : attempted
                ? '오늘 도전 완료'
                : _starting
                ? 'GPS 확인 중'
                : '이벤트 시작',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA76A13),
            padding: const EdgeInsets.symmetric(vertical: 17),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRun() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return Column(
      children: [
        Text(
          '$minutes:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: _gold,
            fontSize: 58,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text('남은 시간', style: TextStyle(color: Colors.white60)),
        const Spacer(),
        Text(
          '${_distanceM.floor()}m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: (_distanceM / 600).clamp(0, 1),
          minHeight: 14,
          color: _gold,
          backgroundColor: Colors.white12,
        ),
        const SizedBox(height: 14),
        Text(
          _distanceM >= 600
              ? '최고 보상 달성 · 기록 측정 중'
              : '다음 보상까지 ${math.max(0, _nextMilestone - _distanceM.floor())}m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '걸음 $_steps · 최고 속도 ${_maxSpeedKmh.toStringAsFixed(1)}km/h',
          style: const TextStyle(color: Colors.white60),
        ),
        const Spacer(),
        if (_finishing) const CircularProgressIndicator(color: _gold),
      ],
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.emoji_events, color: _gold, size: 72),
        Text(
          result.cleared ? '광맥 발견 성공' : '도전 종료',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _panel(
          child: Column(
            children: [
              _resultLine('실제 이동 거리', '${result.distanceM.floor()}m'),
              _resultLine('보상 인정 거리', '${result.rewardDistanceM}m'),
              _resultLine('골드', '+${result.rewardCoin}'),
              _resultLine('스탯 포인트', '+${result.rewardStatExp}'),
              _resultLine('찢어진 입장권', '+${result.rewardTicketFragments}'),
            ],
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA76A13),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            '확인',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panelColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF8D6328), width: 2),
    ),
    child: child,
  );
  Widget _resultLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: _gold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _RewardLine extends StatelessWidget {
  final String distance;
  final String reward;
  const _RewardLine(this.distance, this.reward);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            distance,
            style: const TextStyle(
              color: _GoldMineColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(reward, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}

abstract final class _GoldMineColors {
  static const gold = Color(0xFFFFD45A);
}
