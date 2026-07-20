import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';

import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
import 'package:capstone_app/widgets/game_loading_screen.dart';
import 'package:capstone_app/widgets/game_top_actions.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';

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
  Timer? _spriteTimer;
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
  int _runFrame = 0;
  String? _runId;
  String? _error;
  final GameState _gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spriteTimer?.cancel();
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
      _spriteTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (mounted && _running)
          setState(() => _runFrame = (_runFrame + 1) % 8);
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
    _spriteTimer?.cancel();
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
        extendBody: true,
        backgroundColor: const Color(0xFF120D07),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg/stage3_battle_ancient_quarry_entrance_941x1672.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                reverseDuration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _loading
                    ? const GameLoadingScreen(
                        key: ValueKey('gold-mine-loading'),
                        title: '로딩중',
                        message: '로딩중',
                      )
                    : _result != null
                    ? Stack(
                        key: const ValueKey('gold-mine-result'),
                        children: [
                          Positioned.fill(
                            child: _buildRun(showTracking: false),
                          ),
                          Positioned.fill(child: _buildResult()),
                        ],
                      )
                    : KeyedSubtree(
                        key: const ValueKey('gold-mine-run'),
                        child: _buildRun(showTracking: _running || _finishing),
                      ),
              ),
            ),
          ],
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

  Widget _buildRun({bool showTracking = true}) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final rewardRatio = (_distanceM / 600).clamp(0.0, 1.0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              PlayerProfileWithLevel(
                level: _gs.level,
                exp: _gs.exp,
                expToNext: _gs.expToNextLevel,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '모험가',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8D6328),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/icon/coin_icon.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_gs.coins}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: _running ? null : () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A1A1A).withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFB84535),
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        '이벤트 나가기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const GameTopActions(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '3-6 황금 광맥',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          showTracking
              ? '남은 시간 $minutes:${seconds.toString().padLeft(2, '0')} · 진행 중'
              : '탐사 종료',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black, blurRadius: 5)],
          ),
        ),
        const SizedBox(height: 10),
        _buildDistanceBar(rewardRatio),
        Expanded(
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(0, -0.72),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/monsters/monster_1-1_basic_goblin.png',
                      width: 138,
                      height: 138,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '황금 광맥 도둑 고블린',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                    Text(
                      _distanceM >= 600
                          ? '추적 성공'
                          : '추격 거리 ${math.max(0, 600 - _distanceM.floor())}m',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.64),
                child: _buildRunnerSprite(),
              ),
              Positioned(
                left: 12,
                bottom: 18,
                child: _buildEventRewardPreview(),
              ),
              Positioned(right: 12, bottom: 92, child: _buildMilestoneRail()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: _running || _finishing
                      ? _buildDistancePanel()
                      : _buildEventStartButton(),
                ),
              ),
              GameLoadingOverlay(visible: _finishing),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.86),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 54, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.diamond, color: _gold, size: 68),
            const SizedBox(height: 8),
            Text(
              result.cleared ? '황금 광맥 탐사 성공' : '탐사 종료',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _gold,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${result.distanceM.floor()}m',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '보상 인정 거리 ${result.rewardDistanceM}m',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            _panel(
              child: Column(
                children: [
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
                backgroundColor: const Color(0xFF7A1A1A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceBar(double ratio) => SizedBox(
    width: 280,
    height: 40,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A120E), width: 2),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 4,
          bottom: 4,
          width: 272 * ratio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFB8841F),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        Text(
          '${_distanceM.floor()} / 600m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    ),
  );

  Widget _buildRunnerSprite() {
    const frameWidth = 96.0;
    const frameHeight = 90.0;
    const scale = 1.55;
    return SizedBox(
      width: frameWidth * scale,
      height: frameHeight * scale,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-_runFrame * frameWidth * scale, 0),
            child: Image.asset(
              'assets/images/character/run_up.png',
              width: frameWidth * 8 * scale,
              height: frameHeight * scale,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              alignment: Alignment.topLeft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingStatus() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFF8D6328), width: 2),
    ),
    child: Text(
      '걸음 $_steps\n${_maxSpeedKmh.toStringAsFixed(1)}km/h',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );

  Widget _buildEventRewardPreview() {
    final earnedCoin = _distanceM >= 600
        ? 900
        : _distanceM >= 500
        ? 700
        : _distanceM >= 400
        ? 520
        : 0;
    final earnedTickets = _distanceM >= 600
        ? 4
        : _distanceM >= 400
        ? 1
        : 0;
    final earnedStat = _distanceM >= 500 ? 1 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF8D6328), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _eventRewardIcon(
            image: 'assets/images/icon/coin_icon.png',
            value: '$earnedCoin',
          ),
          const SizedBox(height: 4),
          _eventRewardIcon(
            image: 'assets/images/icon/ticket.png',
            value: '$earnedTickets',
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF9EE7FF),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '$earnedStat',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventRewardIcon({required String image, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(image, width: 18, height: 18, fit: BoxFit.contain),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneRail() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _milestoneBadge(600, '최고'),
      const SizedBox(height: 5),
      _milestoneBadge(500, '스탯'),
      const SizedBox(height: 5),
      _milestoneBadge(400, '입장권'),
    ],
  );

  Widget _milestoneBadge(int distance, String label) {
    final reached = _distanceM >= distance;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: reached ? _gold : const Color(0xFF6E5530),
          width: 2,
        ),
      ),
      child: Text(
        reached ? '$distance ✓\n$label' : '$distance\n$label',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: reached ? _gold : Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildDistancePanel() => Container(
    width: 220,
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF7A1A1A),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFB84535), width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '실시간 탐사 거리',
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
        Text(
          '${_distanceM.floor()}m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _buildEventStartButton() {
    final locked = _status == null || !_status!.unlocked;
    final attempted = _status?.attemptedToday == true;
    final disabled = locked || attempted || _starting;
    return GestureDetector(
      onTap: disabled ? null : _start,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF555555) : const Color(0xFF9B261E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled ? const Color(0xFF6D6D6D) : const Color(0xFFD05A42),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/icon/battle.png',
                width: 22,
                height: 22,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  locked
                      ? '3-3 클리어 필요'
                      : attempted
                      ? '오늘 도전 완료'
                      : _starting
                      ? '이벤트 준비 중...'
                      : '전투 시작',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
