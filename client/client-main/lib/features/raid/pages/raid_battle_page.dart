import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:pedometer/pedometer.dart';

import 'package:capstone_app/models/raid_boss.dart';
import 'package:capstone_app/services/game_api_service.dart';

// ─── 색상 상수 ────────────────────────────────────────────────────────────────

const _kPanelBg = Color(0xFF1A1008);
const _kBorderColor = Color(0xFF6B3A1F);
const _kGold = Color(0xFFF0C040);
const _kBlue = Color(0xFF71C6E4);

// ─── RaidBattlePage ───────────────────────────────────────────────────────────

class RaidBattlePage extends StatefulWidget {
  final RaidBoss boss;
  final String raidId;
  final RaidProgressSummary? initialProgress;
  final int partySize;

  const RaidBattlePage({
    super.key,
    required this.boss,
    required this.raidId,
    this.initialProgress,
    this.partySize = 1,
  });

  @override
  State<RaidBattlePage> createState() => _RaidBattlePageState();
}

class _RaidBattlePageState extends State<RaidBattlePage>
    with WidgetsBindingObserver {
  static const _activityPermissionChannel = MethodChannel(
    'cap1/activity_permission',
  );
  static const _strideM = 0.75;
  static const _maxPartySize = 4;
  static const _defaultGaugeDistanceM = 1000.0;
  static const _minAutoSyncDistanceM = 3.0;

  RaidProgressSummary? _summary;
  RaidProgressInfo? _progress;
  RaidMonsterInfo? _monster;
  List<RaidParticipantInfo> _participants = const [];
  String? _characterId;
  String? _error;
  bool _loadingProgress = false;
  bool _isStepTracking = false;
  bool _isStepStarting = false;
  bool _isDistanceSyncing = false;
  bool _isLeavingRaid = false;
  bool _routeExitAllowed = false;
  bool _resultDialogShown = false;
  int? _lastStepSensorCount;
  int _sessionSteps = 0;
  int _pendingSteps = 0;
  double _pendingDistanceM = 0;
  double _attackDistanceM = _defaultGaugeDistanceM;
  double _monsterAttackDistanceM = _defaultGaugeDistanceM;
  int _activeParticipantCount = 0;
  int _teamAgility = 0;
  int _lastAttackCycles = 0;
  int _lastDamageDealt = 0;
  int _lastMonsterAttackCycles = 0;
  int _lastMonsterDamage = 0;
  String _activityLabel = '걸음 추적 준비';
  Timer? _syncTimer;
  Timer? _refreshTimer;
  StreamSubscription<StepCount>? _stepCountSubscription;

  int get _activePartySize {
    final joinedCount = _activeParticipantCount > 0
        ? _activeParticipantCount
        : _participants
              .where((participant) => participant.joinStatus == 'joined')
              .length;
    final count = _participants.isEmpty ? widget.partySize : joinedCount;
    if (_participants.isEmpty && count < 1) return 1;
    if (count < 1) return 0;
    if (count > _maxPartySize) return _maxPartySize;
    return count;
  }

  bool get _canLeaveRoute => _raidFinished || _routeExitAllowed;

  int get _maxBossHp {
    final hp = _monster?.hp ?? widget.boss.hp;
    return hp > 0 ? hp : 1;
  }

  double get _currentBossHp {
    final current = _progress?.monsterCurrentHp ?? _maxBossHp.toDouble();
    if (current < 0) return 0;
    if (current > _maxBossHp) return _maxBossHp.toDouble();
    return current;
  }

  double get _liveTotalDistanceM {
    final syncedDistance = _progress?.totalDistanceAccumulatedM ?? 0;
    return syncedDistance + _pendingDistanceM;
  }

  bool get _raidFinished {
    final status = _progress?.status ?? '';
    return status == 'cleared' ||
        status == 'failed' ||
        status == 'canceled' ||
        _summary?.raid.status == 'ended';
  }

  double get _attackGaugeDistanceM {
    return (_progress?.distanceSinceLastAttackCycleM ?? 0) + _pendingDistanceM;
  }

  double get _counterGaugeDistanceM {
    return (_progress?.distanceSinceLastMonsterAttackM ?? 0) +
        _pendingDistanceM;
  }

  bool get _hasFullRaidGauge {
    return _attackGaugeDistanceM >= _attackDistanceM ||
        _counterGaugeDistanceM >= _monsterAttackDistanceM;
  }

  double get _attackGaugeRatio {
    return (_attackGaugeDistanceM / _attackDistanceM)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get _counterGaugeRatio {
    return (_counterGaugeDistanceM / _monsterAttackDistanceM)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySummary(widget.initialProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInitialData());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_syncPendingDistance(force: true));
    }
    if (state == AppLifecycleState.detached) {
      unawaited(_stopRaidTracking());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _refreshTimer?.cancel();
    _stepCountSubscription?.cancel();
    unawaited(_syncPendingDistance(force: true, updateUi: false));
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final characterId = await GameApiService.requireCharacterId();
      if (mounted) setState(() => _characterId = characterId);
    } catch (_) {
      // 진행도 조회와 화면 표시는 가능하므로 캐릭터 ID 오류는 거리 전송 시 표시한다.
    }
    await _loadProgress();
    if (!_raidFinished) {
      await _startRaidTracking();
    } else {
      _showResultDialogOnce();
    }
  }

  Future<void> _loadProgress({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loadingProgress = true;
        _error = null;
      });
    }
    try {
      final summary = await GameApiService.fetchRaidProgress(widget.raidId);
      if (!mounted) return;
      setState(() {
        _applySummary(summary, announceChanges: silent);
        _loadingProgress = false;
        _error = null;
      });
      if (_raidFinished) {
        _showResultDialogOnce();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProgress = false;
        _error = e.toString();
      });
    }
  }

  void _applySummary(
    RaidProgressSummary? summary, {
    bool announceChanges = false,
  }) {
    if (summary == null) return;
    if (_isStaleProgress(summary.progress)) return;
    if (announceChanges) {
      _announceRemoteProgress(summary, _progress, _participants);
    }
    _summary = summary;
    _progress = summary.progress;
    _monster = summary.monster ?? widget.initialProgress?.monster;
    _participants = summary.participants;
    _activeParticipantCount = summary.activeParticipants > 0
        ? summary.activeParticipants
        : summary.participants
              .where((participant) => participant.joinStatus == 'joined')
              .length;
    _teamAgility = summary.teamAgility;
    if (summary.attackDistanceM > 0) {
      _attackDistanceM = summary.attackDistanceM;
    }
    if (summary.monsterAttackDistanceM > 0) {
      _monsterAttackDistanceM = summary.monsterAttackDistanceM;
    }
  }

  bool _isStaleProgress(RaidProgressInfo incoming) {
    final current = _progress;
    if (current == null) return false;
    final distanceWentBack =
        incoming.totalDistanceAccumulatedM < current.totalDistanceAccumulatedM;
    final attacksWentBack =
        incoming.totalAttackCycles < current.totalAttackCycles ||
        incoming.totalMonsterAttackCycles < current.totalMonsterAttackCycles;
    return distanceWentBack || attacksWentBack;
  }

  void _announceRemoteProgress(
    RaidProgressSummary summary,
    RaidProgressInfo? previousProgress,
    List<RaidParticipantInfo> previousParticipants,
  ) {
    if (previousProgress == null) return;
    final attackDelta =
        summary.progress.totalAttackCycles - previousProgress.totalAttackCycles;
    final monsterDelta =
        summary.progress.totalMonsterAttackCycles -
        previousProgress.totalMonsterAttackCycles;
    if (attackDelta <= 0 && monsterDelta <= 0) return;

    var damageDelta =
        (previousProgress.monsterCurrentHp - summary.progress.monsterCurrentHp)
            .round();
    if (damageDelta < 0) damageDelta = 0;
    final monsterDamageDelta = _participantHpDamageDelta(
      previousParticipants,
      summary.participants,
    );

    _lastAttackCycles = attackDelta > 0 ? attackDelta : 0;
    _lastDamageDealt = damageDelta;
    _lastMonsterAttackCycles = monsterDelta > 0 ? monsterDelta : 0;
    _lastMonsterDamage = monsterDamageDelta;
    if (attackDelta > 0 && monsterDelta > 0) {
      _activityLabel =
          '파티 공격 ${_fmt(attackDelta)}회 · 보스 반격 ${_fmt(monsterDelta)}회 반영';
    } else if (attackDelta > 0) {
      _activityLabel =
          '파티 공격 ${_fmt(attackDelta)}회 · 피해 ${_fmt(damageDelta)} 반영';
    } else {
      _activityLabel =
          '보스 반격 ${_fmt(monsterDelta)}회 · 피해 ${_fmt(monsterDamageDelta)} 반영';
    }
  }

  int _participantHpDamageDelta(
    List<RaidParticipantInfo> previous,
    List<RaidParticipantInfo> current,
  ) {
    final previousHpById = <String, int>{
      for (final participant in previous)
        participant.id: participant.characterCurrentHp,
    };
    var damage = 0;
    for (final participant in current) {
      final previousHp = previousHpById[participant.id];
      if (previousHp == null) continue;
      final delta = previousHp - participant.characterCurrentHp;
      if (delta > 0) damage += delta;
    }
    return damage;
  }

  Future<void> _startRaidTracking() async {
    if (_isStepTracking || _isStepStarting || _raidFinished) return;
    setState(() {
      _isStepStarting = true;
      _activityLabel = '걸음 권한 확인 중';
    });
    try {
      final granted = await _ensureActivityPermission();
      if (!mounted || _raidFinished) return;
      if (!granted) {
        setState(() {
          _isStepStarting = false;
          _activityLabel = '걸음 권한이 필요합니다';
        });
        return;
      }

      await _stepCountSubscription?.cancel();
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          if (!mounted) return;
          setState(() => _activityLabel = '걸음 센서 오류: $error');
        },
        cancelOnError: false,
      );
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_syncPendingDistance()),
      );
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_loadProgress(silent: true)),
      );
      setState(() {
        _isStepTracking = true;
        _isStepStarting = false;
        _activityLabel = '걸음 추적 중';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStepStarting = false;
        _isStepTracking = false;
        _activityLabel = e.toString();
      });
    }
  }

  Future<void> _stopRaidTracking() async {
    _syncTimer?.cancel();
    _refreshTimer?.cancel();
    await _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    await _syncPendingDistance(force: true);
    if (!mounted) return;
    setState(() {
      _isStepTracking = false;
      _isStepStarting = false;
      _activityLabel = '걸음 추적 중지';
    });
  }

  Future<bool> _ensureActivityPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final granted = await _activityPermissionChannel.invokeMethod<bool>(
        'ensureActivityRecognitionPermission',
      );
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  void _onStepCount(StepCount event) {
    if (!_isStepTracking || _raidFinished) return;
    final current = event.steps;
    final last = _lastStepSensorCount;
    _lastStepSensorCount = current;
    if (last == null) {
      if (mounted) setState(() => _activityLabel = '걸음 기준점 설정 완료');
      return;
    }

    final delta = current - last;
    if (delta <= 0 || delta > 5000) return;
    setState(() {
      _sessionSteps += delta;
      _pendingSteps += delta;
      _pendingDistanceM += delta * _strideM;
      _activityLabel = '추적 중 · 이번 레이드 $_sessionSteps걸음 · 대기 $_pendingSteps걸음';
    });
    if (_hasFullRaidGauge) {
      unawaited(_syncPendingDistance(force: true));
    } else if (_pendingDistanceM >= 25) {
      unawaited(_syncPendingDistance());
    }
  }

  Future<void> _syncPendingDistance({
    bool force = false,
    bool updateUi = true,
  }) async {
    if (_isDistanceSyncing || _raidFinished) return;
    final distance = _pendingDistanceM;
    if (distance <= 0 || (!force && distance < _minAutoSyncDistanceM)) return;

    if (mounted && updateUi) {
      setState(() {
        _isDistanceSyncing = true;
        _activityLabel = '레이드 거리 반영 중';
      });
    } else {
      _isDistanceSyncing = true;
    }

    try {
      final result = await GameApiService.addRaidDistance(
        raidId: widget.raidId,
        distanceM: distance,
      );
      if (!mounted) return;
      setState(() {
        _progress = result.progress;
        _attackDistanceM = result.attackDistanceM > 0
            ? result.attackDistanceM
            : _attackDistanceM;
        _monsterAttackDistanceM = result.monsterAttackDistanceM > 0
            ? result.monsterAttackDistanceM
            : _monsterAttackDistanceM;
        _activeParticipantCount = result.activeParticipants;
        _teamAgility = result.teamAgility;
        _lastAttackCycles = result.attackCycles;
        _lastDamageDealt = result.damageDealt;
        _lastMonsterAttackCycles = result.monsterAttackCycles;
        _lastMonsterDamage = result.monsterDamageDealt;
        _pendingDistanceM -= distance;
        if (_pendingDistanceM < 0) _pendingDistanceM = 0;
        _pendingSteps = (_pendingDistanceM / _strideM).round();
        _isDistanceSyncing = false;
        if (result.attackCycles > 0 && result.monsterAttackCycles > 0) {
          _activityLabel =
              '파티 공격 ${result.attackCycles}회 · 보스 반격 ${result.monsterAttackCycles}회 발동';
        } else if (result.attackCycles > 0) {
          _activityLabel = '파티 공격 ${result.attackCycles}회 발동';
        } else if (result.monsterAttackCycles > 0) {
          _activityLabel = '보스 반격 ${result.monsterAttackCycles}회 발동';
        } else {
          _activityLabel = '걸음 추적 중';
        }
      });
      unawaited(_loadProgress(silent: true));
      if (_raidFinished) {
        _showResultDialogOnce();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDistanceSyncing = false;
        _activityLabel = e.toString();
      });
    }
  }

  void _showResultDialogOnce() {
    if (!mounted || _resultDialogShown) return;
    _resultDialogShown = true;
    unawaited(_stopRaidTracking());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cleared = _progress?.status == 'cleared';
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _kPanelBg,
          title: Text(
            cleared ? '레이드 클리어' : '레이드 종료',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            '총 거리 ${_fmtDouble(_progress?.totalDistanceAccumulatedM ?? 0)}m\n'
            '파티 공격 ${_fmt(_progress?.totalAttackCycles ?? 0)}회\n'
            '보스 반격 ${_fmt(_progress?.totalMonsterAttackCycles ?? 0)}회',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => _returnHomeFromResult(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    });
  }

  void _returnHomeFromResult(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    if (!mounted) return;
    _routeExitAllowed = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleBack() async {
    if (_isLeavingRaid) return;
    if (!_canLeaveRoute) {
      await _confirmLeaveRaid();
      return;
    }
    await _stopRaidTracking();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmLeaveRaid() async {
    if (_raidFinished || _isLeavingRaid) return;

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kPanelBg,
        title: const Text('레이드 나가기', style: TextStyle(color: Colors.white)),
        content: const Text(
          '레이드 전투가 아직 끝나지 않았습니다.\n나가면 전투 포기로 처리됩니다.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('포기하고 나가기'),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !mounted) return;

    setState(() => _isLeavingRaid = true);
    try {
      await _stopRaidTracking();
      final summary = await GameApiService.leaveRaid(raidId: widget.raidId);
      if (!mounted) return;
      setState(() {
        _applySummary(summary);
        _pendingDistanceM = 0;
        _pendingSteps = 0;
        _activityLabel = '레이드를 포기했습니다';
        _routeExitAllowed = true;
      });
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } on GameApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('레이드 나가기 처리에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
    } finally {
      if (mounted) setState(() => _isLeavingRaid = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canLeaveRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                widget.boss.bgPath ?? 'assets/images/bg/home_bg.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopArea(),
                  _buildBossHpBar(),
                  Expanded(child: _buildBattleScene()),
                  _buildBottomPanel(),
                ],
              ),
            ),
            if (_loadingProgress && _progress == null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: const Center(
                    child: CircularProgressIndicator(color: _kGold),
                  ),
                ),
              ),
            if (_isLeavingRaid)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.42),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _kGold),
                        SizedBox(height: 12),
                        Text(
                          '레이드 나가는 중',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopArea() {
    final statusText = switch (_progress?.status ?? 'waiting') {
      'cleared' => '클리어',
      'failed' => '실패',
      'canceled' => '취소됨',
      'in_progress' => '진행 중',
      _ => '대기 중',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isLeavingRaid ? null : _handleBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderColor, width: 2),
              ),
              child: _isLeavingRaid
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        color: _kGold,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderColor, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '레이드 전투 · $statusText',
                    style: const TextStyle(
                      color: Color(0xFFCC1111),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _monster?.name ?? widget.boss.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 6,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossHpBar() {
    final ratio = (_currentBossHp / _maxBossHp).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 24,
              backgroundColor: Colors.grey[900],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
            ),
          ),
          Text(
            '${_fmt(_currentBossHp.round())} / ${_fmt(_maxBossHp)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleScene() {
    return Row(
      children: [
        SizedBox(
          width: 180,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              const spriteH = 130.0;
              const spriteW = 130.0;
              final cx = w / 2 - spriteW / 2;
              final top = h * 0.25;
              final bottom = h * 0.55;
              final midY = h * 0.52;
              final mid = midY - spriteH / 2;
              final leftX = cx - spriteW * 0.4;
              final rightX = cx + spriteW * 0.4;
              final slots = [
                Offset(rightX, mid),
                Offset(cx, top),
                Offset(leftX, mid),
                Offset(cx, bottom),
              ];

              return Stack(
                children: List.generate(_activePartySize, (i) {
                  final slot = slots[i];
                  return Positioned(
                    left: slot.dx,
                    top: slot.dy,
                    child: _buildSceneCharacter(),
                  );
                }),
              );
            },
          ),
        ),
        Expanded(child: _buildSceneBoss()),
      ],
    );
  }

  Widget _buildSceneCharacter() {
    return AnimatedSpriteFrame(
      assetPath: 'assets/images/character/attack2_right.png',
      totalFrames: 8,
      fps: 8,
      displayHeight: 130,
    );
  }

  Widget _buildSceneBoss() {
    final path = widget.boss.imagePath ?? widget.boss.iconPath;
    if (path != null && path.contains('boss_golem')) {
      return const Align(
        alignment: Alignment(0.0, -0.1),
        child: GolemSpriteWidget(displayHeight: 220),
      );
    }
    return Align(
      alignment: Alignment.center,
      child: path != null
          ? Image.asset(
              path,
              height: 180,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            )
          : const Icon(Icons.help_outline, color: Colors.white24, size: 60),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _kPanelBg,
        border: Border(top: BorderSide(color: _kBorderColor, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRaidStats(),
          const SizedBox(height: 10),
          _buildGauge(
            label: '반격 게이지',
            ratio: _counterGaugeRatio,
            color: Colors.red[700]!,
            icon: Icons.warning_amber,
          ),
          const SizedBox(height: 8),
          _buildGauge(
            label: '공격 게이지',
            ratio: _attackGaugeRatio,
            color: Colors.green[600]!,
            icon: Icons.flash_on,
          ),
          const SizedBox(height: 12),
          _buildCharacterCards(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRaidStats() {
    final totalDistance = _liveTotalDistanceM;
    final partyCount = _activeParticipantCount > 0
        ? _activeParticipantCount
        : _participants
              .where((participant) => participant.joinStatus == 'joined')
              .length;
    final error = _error;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatChip(
                '누적 거리',
                '${_fmtDouble(totalDistance)}m',
                _kBlue,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildStatChip(
                '참여중',
                '$partyCount/$_maxPartySize',
                _kGold,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildStatChip('팀 민첩', _fmt(_teamAgility), Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildStatChip(
                '공격 거리',
                '${_fmtDouble(_attackDistanceM)}m',
                Colors.green,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildStatChip(
                '반격 거리',
                '${_fmtDouble(_monsterAttackDistanceM)}m',
                Colors.redAccent,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildStatChip('대기 걸음', _fmt(_pendingSteps), _kGold),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 10),
          ),
        ],
        if (_lastAttackCycles > 0 || _lastMonsterAttackCycles > 0) ...[
          const SizedBox(height: 6),
          Text(
            '최근 공격 $_lastAttackCycles회 · 피해 ${_fmt(_lastDamageDealt)}'
            ' / 반격 $_lastMonsterAttackCycles회 · 피해 ${_fmt(_lastMonsterDamage)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge({
    required String label,
    required double ratio,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const Spacer(),
            Text(
              '${(ratio * 100).round()}%',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 20,
                backgroundColor: Colors.grey[900],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  border: Border.all(color: _kGold, width: 1.3),
                ),
                child: Transform.rotate(
                  angle: -0.785398,
                  child: Icon(icon, color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterCards() {
    final participants = _participants.take(_maxPartySize).toList();
    final pendingSlots = ((_summary?.pendingInvitationCount ?? 0).clamp(
      0,
      _maxPartySize - participants.length,
    )).toInt();
    final occupiedSlots = participants.length + pendingSlots;
    return Row(
      children: List.generate(_maxPartySize, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 2,
              right: i == _maxPartySize - 1 ? 0 : 2,
            ),
            child: i < participants.length
                ? _buildParticipantCard(participants[i])
                : i < occupiedSlots
                ? _buildWaitingCharCard()
                : _buildEmptyCharCard(),
          ),
        );
      }),
    );
  }

  Widget _buildParticipantCard(RaidParticipantInfo participant) {
    final isMine =
        _characterId != null && participant.characterId == _characterId;
    final isLeft = participant.joinStatus == 'left';
    final statusText = isLeft ? '포기함' : '참여중';
    final statusColor = isLeft ? const Color(0xFFFF8A8A) : Colors.greenAccent;
    final participantName = participant.displayLabel;
    final nameText = isMine
        ? (participantName == '친구' ? '나' : '나 · $participantName')
        : participantName;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isLeft ? 0.62 : 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLeft
              ? const Color(0xFF8A3A3A)
              : isMine
              ? _kGold
              : _kBorderColor,
          width: isMine ? 2 : 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth;
              return Opacity(
                opacity: isLeft ? 0.35 : 1,
                child: SpriteFrame(
                  assetPath: 'assets/images/character/attack2_right.png',
                  frameIndex: 0,
                  frameWidth: 80,
                  frameHeight: 80,
                  displayHeight: size,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            nameText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLeft ? Colors.white38 : (isMine ? _kGold : Colors.white),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: statusColor, fontSize: 8),
          ),
          _buildParticipantHpBar(participant, isLeft),
          Text(
            '${_fmtDouble(participant.contributionDistanceM)}m',
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
          Text(
            '딜 ${_fmt(participant.contributionDamage.round())}',
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantHpBar(RaidParticipantInfo participant, bool isLeft) {
    final maxHp = participant.characterMaxHp;
    if (maxHp <= 0) {
      return const SizedBox(height: 8);
    }
    final currentHp = participant.characterCurrentHp.clamp(0, maxHp).toInt();
    final ratio = (currentHp / maxHp).clamp(0.0, 1.0).toDouble();
    final color = ratio <= 0.25
        ? const Color(0xFFE94B4B)
        : ratio <= 0.55
        ? const Color(0xFFF0A040)
        : const Color(0xFF54D878);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 1),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'HP',
                style: TextStyle(color: Colors.white38, fontSize: 7),
              ),
              const Spacer(),
              Text(
                '${_fmt(currentHp)}/${_fmt(maxHp)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isLeft ? 0.35 : 0.62),
                  fontSize: 7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation<Color>(
                color.withValues(alpha: isLeft ? 0.35 : 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCharCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxWidth + 39,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderColor.withValues(alpha: 0.6)),
          ),
          child: const Center(
            child: Text(
              '초대중',
              style: TextStyle(color: Colors.white30, fontSize: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCharCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxWidth + 39,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderColor.withValues(alpha: 0.45)),
          ),
          child: Icon(
            Icons.person_add_disabled,
            color: Colors.white.withValues(alpha: 0.16),
            size: 24,
          ),
        );
      },
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDouble(double value) {
    if (value >= 100) return _fmt(value.round());
    return value.toStringAsFixed(1);
  }
}

// ─── GolemSpriteWidget ───────────────────────────────────────────────────────

class GolemSpriteWidget extends StatefulWidget {
  final double displayHeight;
  final double stepTime;

  const GolemSpriteWidget({
    super.key,
    required this.displayHeight,
    this.stepTime = 0.07,
  });

  @override
  State<GolemSpriteWidget> createState() => _GolemSpriteWidgetState();
}

class _GolemSpriteWidgetState extends State<GolemSpriteWidget> {
  static const String _assetPath = 'assets/images/monsters/boss_golem.png';
  static const int _totalFrames = 49;
  static const double _frameW = 2048 / 7;
  static const double _frameH = 1152 / 7;

  ui.Image? _image;
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _timer = Timer.periodic(
      Duration(milliseconds: (widget.stepTime * 1000).round()),
      (_) => setState(() => _frame = (_frame + 1) % _totalFrames),
    );
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(_assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.displayHeight / _frameH;
    final frameDisplayW = _frameW * scale;
    // 클립 창은 프레임의 60% 너비만 보여줘 좌우 이동을 숨김
    final clipW = frameDisplayW * 0.6;

    if (_image == null) {
      return SizedBox(width: clipW, height: widget.displayHeight);
    }

    // 전체 프레임을 clipW 중앙에 고정 배치하고 양옆을 잘라냄
    return ClipRect(
      child: SizedBox(
        width: clipW,
        height: widget.displayHeight,
        child: OverflowBox(
          maxWidth: frameDisplayW,
          maxHeight: widget.displayHeight,
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size(frameDisplayW, widget.displayHeight),
            painter: _GolemPainter(image: _image!, frame: _frame),
          ),
        ),
      ),
    );
  }
}

class _GolemPainter extends CustomPainter {
  final ui.Image image;
  final int frame;

  static const int _cols = 7;
  static const double _frameW = 2048 / 7;
  static const double _frameH = 1152 / 7;

  const _GolemPainter({required this.image, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final r = frame ~/ _cols;
    final c = frame % _cols;
    final src = Rect.fromLTWH(c * _frameW, r * _frameH, _frameW, _frameH);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GolemPainter old) =>
      old.frame != frame || old.image != image;
}

// ─── BossAnimatedSprite ───────────────────────────────────────────────────────

class BossAnimatedSprite extends StatefulWidget {
  final String assetPath;
  final int cols;
  final int rows;
  final int fps;
  final double displayHeight;
  final int? startFrame;
  final int? endFrame;

  const BossAnimatedSprite({
    super.key,
    required this.assetPath,
    this.cols = 4,
    this.rows = 2,
    this.fps = 8,
    required this.displayHeight,
    this.startFrame,
    this.endFrame,
  });

  @override
  State<BossAnimatedSprite> createState() => _BossAnimatedSpriteState();
}

class _BossAnimatedSpriteState extends State<BossAnimatedSprite> {
  ui.Image? _image;
  int _frame = 0;
  Timer? _timer;

  int get _start => widget.startFrame ?? 0;
  int get _end => widget.endFrame ?? (widget.cols * widget.rows - 1);
  int get _rangeCount => _end - _start + 1;

  @override
  void initState() {
    super.initState();
    _frame = _start;
    _loadImage();
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / widget.fps).round()),
      (_) =>
          setState(() => _frame = _start + (_frame - _start + 1) % _rangeCount),
    );
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayHeight = widget.displayHeight;
    final displayWidth = displayHeight * widget.rows / widget.cols;

    if (_image == null) {
      return SizedBox(width: displayWidth, height: displayHeight);
    }

    return CustomPaint(
      size: Size(displayWidth, displayHeight),
      painter: _SpritePainter(
        image: _image!,
        frame: _frame,
        cols: widget.cols,
        rows: widget.rows,
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final int frame;
  final int cols;
  final int rows;

  const _SpritePainter({
    required this.image,
    required this.frame,
    required this.cols,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final col = frame % cols;
    final row = frame ~/ cols;
    final srcW = image.width / cols;
    final srcH = image.height / rows;
    final src = Rect.fromLTWH(col * srcW, row * srcH, srcW, srcH);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.frame != frame || old.image != image;
}

// ─── SpriteFrame ──────────────────────────────────────────────────────────────

class SpriteFrame extends StatelessWidget {
  final String assetPath;
  final int frameIndex;
  final int totalFrames;
  final double frameWidth;
  final double frameHeight;
  final double displayHeight;

  const SpriteFrame({
    super.key,
    required this.assetPath,
    this.frameIndex = 0,
    this.totalFrames = 8,
    this.frameWidth = 80,
    this.frameHeight = 80,
    required this.displayHeight,
  });

  @override
  Widget build(BuildContext context) {
    final scale = displayHeight / frameHeight;
    final displayFrameWidth = frameWidth * scale;

    return SizedBox(
      width: displayFrameWidth,
      height: displayHeight,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(-frameIndex * displayFrameWidth, 0),
          child: OverflowBox(
            maxWidth: displayFrameWidth * totalFrames,
            maxHeight: displayHeight,
            alignment: Alignment.topLeft,
            child: Image.asset(
              assetPath,
              width: displayFrameWidth * totalFrames,
              height: displayHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AnimatedSpriteFrame ──────────────────────────────────────────────────────

class AnimatedSpriteFrame extends StatefulWidget {
  final String assetPath;
  final int totalFrames;
  final int fps;
  final double frameWidth;
  final double frameHeight;
  final double displayHeight;

  const AnimatedSpriteFrame({
    super.key,
    required this.assetPath,
    this.totalFrames = 8,
    this.fps = 8,
    this.frameWidth = 80,
    this.frameHeight = 80,
    required this.displayHeight,
  });

  @override
  State<AnimatedSpriteFrame> createState() => _AnimatedSpriteFrameState();
}

class _AnimatedSpriteFrameState extends State<AnimatedSpriteFrame> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / widget.fps).round()),
      (_) => setState(() => _frame = (_frame + 1) % widget.totalFrames),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.displayHeight / widget.frameHeight;
    final displayFrameWidth = widget.frameWidth * scale;

    return SizedBox(
      width: displayFrameWidth,
      height: widget.displayHeight,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(-_frame * displayFrameWidth, 0),
          child: OverflowBox(
            maxWidth: displayFrameWidth * widget.totalFrames,
            maxHeight: widget.displayHeight,
            alignment: Alignment.topLeft,
            child: Image.asset(
              widget.assetPath,
              width: displayFrameWidth * widget.totalFrames,
              height: widget.displayHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }
}
