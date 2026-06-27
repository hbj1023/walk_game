import 'dart:async';

import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/monster_asset_service.dart';
import 'package:capstone_app/services/step_tracking_controller.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';

const _kPanelBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFF0C040);
const _kRedBar = Color(0xFFE02D24);
const _kBlueBar = Color(0xFF1E73FF);
const _kPlayerAttackFrameCount = 8;
const _kPlayerAttackFrameWidth = 96.0;
const _kPlayerAttackFrameHeight = 80.0;
const _kPlayerIdleSprite = 'assets/images/character/idle_up.png';
const _kPlayerRunSprite = 'assets/images/character/run_up.png';
const _kPlayerAttackSprites = [
  'assets/images/character/attack1_up.png',
  'assets/images/character/attack2_up.png',
];

class BattlePage extends StatefulWidget {
  final String stageId;
  final int stageNo;
  final String stageName;
  final int totalWaves;
  final NormalBattleResult initialResult;

  const BattlePage({
    super.key,
    required this.stageId,
    required this.stageNo,
    required this.stageName,
    required this.totalWaves,
    required this.initialResult,
  });

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> with WidgetsBindingObserver {
  final _gs = GameState.instance;
  late final StepTrackingController _stepTracker;
  String _userName = '...';

  late String _battleId;
  late String _battleStatus;
  late String _monsterName;
  late int _monsterMaxHp;
  late int _monsterCurrentHp;
  late int _playerCurrentHp;
  late int _attackCountBalance;

  double _monsterAttackGaugeM = 0;
  double _monsterAttackDistanceM = 0;
  double _characterAttackDistanceM = 100;
  double _characterAttackRemainderM = 0;
  int _lastPlayerDamage = 0;
  int _lastMonsterDamage = 0;
  int _rewardCoin = 0;
  int _attackCountUsed = 0;
  int _totalDamageDealt = 0;
  int _totalDamageTaken = 0;
  BattleRewardEquipment? _rewardEquipment;
  List<OwnedInventoryItem> _consumables = const [];
  String? _selectedConsumableTemplateId;
  bool _isConsumableSelectorExpanded = false;
  String _currentPlayerSpritePath = _kPlayerIdleSprite;
  int _playerAttackSpriteIndex = 0;
  int _playerAnimationFrame = 0;
  double _playerSpriteOffsetY = 0;
  bool _isAttacking = false;
  bool _isLeavingBattle = false;
  bool _isUsingConsumable = false;
  bool _routeExitAllowed = false;
  bool _isRunningAutoAttacks = false;
  int _pendingAutoAttacks = 0;

  late final int _playerMaxHp = widget.initialResult.characterMaxHp > 0
      ? widget.initialResult.characterMaxHp
      : widget.initialResult.battle.characterCurrentHp > 0
      ? widget.initialResult.battle.characterCurrentHp
      : 500;

  int get _currentWave {
    final wave = widget.initialResult.battle.currentSpawnOrder > 0
        ? widget.initialResult.battle.currentSpawnOrder
        : 1;
    return wave > widget.totalWaves ? widget.totalWaves : wave;
  }

  bool get _battleEnded =>
      _battleStatus == 'win' ||
      _battleStatus == 'lose' ||
      _battleStatus == 'flee';

  bool get _canLeaveRoute => _battleEnded || _routeExitAllowed;
  bool get _isBossBattle => widget.initialResult.battle.battleType == 'boss';

  OwnedInventoryItem? get _selectedConsumable {
    for (final item in _consumables) {
      if (item.itemTemplate.id == _selectedConsumableTemplateId) return item;
    }
    return _consumables.isEmpty ? null : _consumables.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stepTracker = StepTrackingController.battle(
      onSyncSteps: (request) => GameApiService.syncStepDelta(
        stepCount: request.stepCount,
        strideM: request.strideM,
        gpsDistanceM: request.gpsDistanceM,
        abnormalReason: request.abnormalReason,
      ),
      onSyncSuccess: _handleBattleStepSyncSuccess,
      additionalStatusParts: () =>
          _pendingAutoAttacks > 0 ? ['자동공격 $_pendingAutoAttacks회'] : const [],
      canTrack: () => !_battleEnded,
      syncSuccessStatusNoteBuilder: (result) => result.attackCountEarned > 0
          ? '공격 +${result.attackCountEarned}'
          : null,
    )..addListener(_onStepTrackerChanged);
    _applyResult(widget.initialResult, clearDamageText: true);
    _syncActiveBattleMarker();
    _loadUserName();
    _loadConsumables();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_battleEnded) {
        _showBattleResultDialog();
      } else {
        unawaited(_stepTracker.start());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_stepTracker.stop(syncPending: true, updateState: false));
    _stepTracker.removeListener(_onStepTrackerChanged);
    _stepTracker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && !_battleEnded) {
      unawaited(_stepTracker.stop(syncPending: true, updateState: false));
      unawaited(
        (_isBossBattle
                ? BattleApiService.leaveBossBattle(battleId: _battleId)
                : BattleApiService.leaveNormalBattle(battleId: _battleId))
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
  }

  void _onStepTrackerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _applyResult(NormalBattleResult result, {bool clearDamageText = false}) {
    _battleId = result.battle.id;
    _battleStatus = result.battle.status;
    _monsterName = result.monster.name.isEmpty ? '몬스터' : result.monster.name;
    _monsterMaxHp = result.monster.hp > 0 ? result.monster.hp : 1;
    _monsterCurrentHp = result.battle.monsterCurrentHp;
    _playerCurrentHp = result.battle.characterCurrentHp;
    _attackCountBalance = result.attackCountBalance;
    _monsterAttackGaugeM = result.monsterAttackGaugeM;
    _monsterAttackDistanceM = result.monsterAttackDistanceM;
    _rewardCoin = result.rewardCoin;
    _rewardEquipment = result.rewardEquipment;
    _attackCountUsed = result.battle.attackCountUsed;
    _totalDamageDealt = result.battle.totalDamageDealt;
    _totalDamageTaken = result.battle.totalDamageTaken;
    _lastPlayerDamage = clearDamageText ? 0 : result.playerDamage;
    _lastMonsterDamage = clearDamageText ? 0 : result.monsterDamage;
    _gs.setCoins(result.character.coinBalance);
  }

  void _syncActiveBattleMarker() {
    if (_battleEnded) {
      unawaited(BattleApiService.clearActiveNormalBattle());
    } else {
      unawaited(BattleApiService.markActiveNormalBattle(_battleId));
    }
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getSavedName();
    if (mounted) {
      setState(() => _userName = name ?? '모험가');
    }
  }

  Future<void> _loadConsumables() async {
    try {
      final items = await GameApiService.fetchInventoryItems();
      final consumables = items
          .where(
            (item) =>
                item.itemTemplate.isConsumable &&
                item.itemTemplate.recoverHp > 0 &&
                item.quantity > 0,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _consumables = consumables;
        final selectedId = _selectedConsumableTemplateId;
        final hasSelected =
            selectedId != null &&
            consumables.any((item) => item.itemTemplate.id == selectedId);
        _selectedConsumableTemplateId = hasSelected
            ? selectedId
            : (consumables.isEmpty ? null : consumables.first.itemTemplate.id);
        if (consumables.isEmpty) {
          _isConsumableSelectorExpanded = false;
        }
      });
    } catch (_) {
      // 전투 화면에서는 물약 로딩 실패를 치명 오류로 보지 않는다.
    }
  }

  Future<void> _attack() async {
    await _performAttack(showMissingSnack: true);
  }

  Future<bool> _performAttack({required bool showMissingSnack}) async {
    if (_isAttacking || _isUsingConsumable || _battleEnded) return false;
    if (_attackCountBalance < 1) {
      if (showMissingSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공격권이 부족합니다. 걸음 수를 동기화해주세요.')),
        );
      }
      return false;
    }

    unawaited(_playPlayerAttackSequence());
    setState(() => _isAttacking = true);
    try {
      final result = _isBossBattle
          ? await BattleApiService.attackBossBattle(battleId: _battleId)
          : await BattleApiService.attackNormalBattle(battleId: _battleId);
      if (!mounted) return false;

      setState(() {
        _applyResult(result);
      });
      _syncActiveBattleMarker();

      if (_battleEnded) {
        _pendingAutoAttacks = 0;
        unawaited(_stepTracker.stop(syncPending: true));
        _showBattleResultDialog();
      }
      _loadConsumables();
      return true;
    } on BattleApiException catch (e) {
      if (!mounted) return false;
      if (showMissingSnack) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (!mounted) return false;
      if (showMissingSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공격 요청에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAttacking = false);
    }
    return false;
  }

  void _handleBattleStepSyncSuccess(
    StepSyncResult result,
    StepSyncContext context,
  ) {
    _attackCountBalance = result.attackCountBalance;
    if (result.attackDistanceM > 0) {
      _characterAttackDistanceM = result.attackDistanceM;
    }
    _characterAttackRemainderM = result.attackDistanceRemainderM;

    if (context.allowPostSyncActions &&
        _stepTracker.isTracking &&
        !_battleEnded &&
        result.attackCountEarned > 0) {
      _pendingAutoAttacks += result.attackCountEarned;
      unawaited(_runQueuedAutoAttacks());
    }
  }

  Future<void> _runQueuedAutoAttacks() async {
    if (_isRunningAutoAttacks || _battleEnded) return;

    _isRunningAutoAttacks = true;
    try {
      while (mounted && !_battleEnded && _pendingAutoAttacks > 0) {
        if (_isAttacking || _isUsingConsumable || _isLeavingBattle) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          continue;
        }
        if (_attackCountBalance < 1) break;

        final attacked = await _performAttack(showMissingSnack: false);
        if (!attacked) break;

        _pendingAutoAttacks--;
        if (!_battleEnded) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
      }
    } finally {
      _isRunningAutoAttacks = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _playPlayerAttackSequence() async {
    final nextSpriteIndex =
        (_playerAttackSpriteIndex + 1) % _kPlayerAttackSprites.length;
    _playerAttackSpriteIndex = nextSpriteIndex;

    await Future.wait([
      _animatePlayerFrames(
        _kPlayerRunSprite,
        frameCount: 4,
        frameDuration: const Duration(milliseconds: 45),
      ),
      _animatePlayerOffset(-0.52),
    ]);

    await _animatePlayerFrames(
      _kPlayerAttackSprites[_playerAttackSpriteIndex],
      frameCount: _kPlayerAttackFrameCount,
      frameDuration: const Duration(milliseconds: 70),
    );

    await Future.wait([
      _animatePlayerFrames(
        _kPlayerRunSprite,
        frameCount: 4,
        frameDuration: const Duration(milliseconds: 45),
      ),
      _animatePlayerOffset(0),
    ]);

    if (!mounted) return;
    setState(() {
      _currentPlayerSpritePath = _kPlayerIdleSprite;
      _playerAnimationFrame = 0;
    });
  }

  Future<void> _animatePlayerFrames(
    String spritePath, {
    required int frameCount,
    required Duration frameDuration,
  }) async {
    if (!mounted) return;
    setState(() {
      _currentPlayerSpritePath = spritePath;
      _playerAnimationFrame = 0;
    });

    for (int i = 1; i < frameCount; i++) {
      await Future.delayed(frameDuration);
      if (!mounted) return;
      setState(() => _playerAnimationFrame = i);
    }
  }

  Future<void> _animatePlayerOffset(double offsetY) async {
    if (!mounted) return;
    setState(() => _playerSpriteOffsetY = offsetY);
    await Future.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _useSelectedConsumable() async {
    final selected = _selectedConsumable;
    if (_battleEnded || _isAttacking || _isUsingConsumable) return;
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용할 물약이 없습니다.')));
      return;
    }

    setState(() => _isUsingConsumable = true);
    try {
      final result = await GameApiService.useConsumable(
        selected.itemTemplate.id,
      );
      final items = await GameApiService.fetchInventoryItems();
      final consumables = items
          .where(
            (item) =>
                item.itemTemplate.isConsumable &&
                item.itemTemplate.recoverHp > 0 &&
                item.quantity > 0,
          )
          .toList();
      if (!mounted) return;

      setState(() {
        _playerCurrentHp =
            result.battleCharacterCurrentHp ??
            result.characterCurrentHp ??
            _playerCurrentHp;
        _consumables = consumables;
        final currentSelectedId = selected.itemTemplate.id;
        final stillExists = consumables.any(
          (item) => item.itemTemplate.id == currentSelectedId,
        );
        _selectedConsumableTemplateId = stillExists
            ? currentSelectedId
            : (consumables.isEmpty ? null : consumables.first.itemTemplate.id);
        if (consumables.isEmpty) {
          _isConsumableSelectorExpanded = false;
        }
      });

      final healText = result.recoveredHp > 0
          ? 'HP +${result.recoveredHp}'
          : '${selected.itemTemplate.name} 사용';
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(healText)));
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
          const SnackBar(content: Text('물약 사용에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
    } finally {
      if (mounted) setState(() => _isUsingConsumable = false);
    }
  }

  Future<void> _confirmLeaveBattle() async {
    if (_battleEnded || _isLeavingBattle) return;

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('전투 나가기', style: TextStyle(color: Colors.white)),
        content: const Text(
          '전투가 아직 끝나지 않았습니다.\n나가면 전투 포기로 처리됩니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !mounted) return;

    setState(() => _isLeavingBattle = true);
    try {
      _pendingAutoAttacks = 0;
      await _stepTracker.stop(syncPending: true);
      final result = _isBossBattle
          ? await BattleApiService.leaveBossBattle(battleId: _battleId)
          : await BattleApiService.leaveNormalBattle(battleId: _battleId);
      await BattleApiService.clearActiveNormalBattle();
      if (!mounted) return;
      setState(() {
        _applyResult(result);
        _routeExitAllowed = true;
      });

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        _pushReplacement(const HomePage());
      }
    } on BattleApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전투 나가기 처리에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isLeavingBattle = false);
    }
  }

  void _showBattleLockedMessage() {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('전투 중에는 다른 화면으로 이동할 수 없습니다.')),
      );
  }

  void _showBattleResultDialog() {
    final isWin = _battleStatus == 'win';
    final accent = isWin ? _kGold : const Color(0xFFE84C3D);
    final title = isWin ? '승리!' : '패배';
    final subtitle = isWin ? '스테이지 클리어' : '도전 실패';
    final rewardCoin = isWin ? _rewardCoin : 0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF131313),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.48),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                              offset: Offset(1, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildResultRewardPanel(
                  isWin: isWin,
                  accent: accent,
                  rewardCoin: rewardCoin,
                  rewardEquipment: _isBossBattle ? _rewardEquipment : null,
                ),
                const SizedBox(height: 12),
                _buildResultStatsPanel(accent),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWin
                          ? const Color(0xFF7A4A10)
                          : const Color(0xFF7A1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _pushReplacement(const HomePage());
                    },
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRewardPanel({
    required bool isWin,
    required Color accent,
    required int rewardCoin,
    BattleRewardEquipment? rewardEquipment,
  }) {
    final hasEquipment = isWin && rewardEquipment != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPanelBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            isWin ? '획득 보상' : '획득 보상 없음',
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (hasEquipment) ...[
            _buildBossRewardEquipment(rewardEquipment.itemTemplate, accent),
            const SizedBox(height: 10),
          ],
          _buildCoinRewardRow(isWin: isWin, rewardCoin: rewardCoin),
          const SizedBox(height: 6),
          Text(
            isWin
                ? (hasEquipment ? '장비가 인벤토리에 지급되었습니다.' : '코인이 보유량에 반영되었습니다.')
                : '패배 시 보상은 지급되지 않습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossRewardEquipment(
    BattleRewardItemTemplate template,
    Color accent,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent, width: 1.5),
            ),
            child: Image.asset(
              _rewardEquipmentImage(template),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name.isEmpty ? '보상 장비' : template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${template.slotLabel} · ${_rewardRarityLabel(template.rarity)}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  template.statSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinRewardRow({required bool isWin, required int rewardCoin}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/icon/coin_icon.png', width: 30, height: 30),
        const SizedBox(width: 8),
        Text(
          isWin ? '+${_fmt(rewardCoin)}' : '0',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 5, offset: Offset(1, 1)),
            ],
          ),
        ),
      ],
    );
  }

  String _rewardEquipmentImage(BattleRewardItemTemplate template) {
    final normalizedName = template.name.replaceAll(' ', '').trim();
    return switch (normalizedName) {
      '초급검' => 'assets/images/icon/sword1.png',
      '레어검' => 'assets/images/icon/sword2.png',
      '에픽투구' => 'assets/images/icon/cap3.png',
      '에픽갑옷' => 'assets/images/icon/armor3.png',
      '에픽신발' => 'assets/images/icon/shoes3.png',
      '에픽검' => 'assets/images/icon/sword3.png',
      '낡은모자' => 'assets/images/icon/cap1.png',
      '낡은갑옷' => 'assets/images/icon/armor1.png',
      '낡은신발' => 'assets/images/icon/shoes1.png',
      '튼튼한모자' => 'assets/images/icon/cap2.png',
      '튼튼한갑옷' => 'assets/images/icon/armor2.png',
      '튼튼한신발' => 'assets/images/icon/shoes2.png',
      _ => switch (template.equipmentSlot) {
        'helmet' => 'assets/images/icon/helmet.png',
        'armor' => 'assets/images/icon/armor.png',
        'sword' => 'assets/images/icon/weapon.png',
        'shoes' => 'assets/images/icon/boots.png',
        _ => 'assets/images/icon/weapon.png',
      },
    };
  }

  String _rewardRarityLabel(String rarity) {
    return switch (rarity) {
      'common' => '일반',
      'rare' => '레어',
      'epic' => '에픽',
      _ => rarity.toUpperCase(),
    };
  }

  Widget _buildResultStatsPanel(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        children: [
          _buildResultStatRow('스테이지', '${widget.stageId} ${widget.stageName}'),
          _buildResultStatRow('공격 횟수', '${_fmt(_attackCountUsed)}회'),
          _buildResultStatRow('입힌 피해', _fmt(_totalDamageDealt)),
          _buildResultStatRow('받은 피해', _fmt(_totalDamageTaken)),
          _buildResultStatRow(
            '남은 HP',
            '${_fmt(_playerCurrentHp.clamp(0, _playerMaxHp).toInt())} / ${_fmt(_playerMaxHp)}',
          ),
        ],
      ),
    );
  }

  Widget _buildResultStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canLeaveRoute,
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: _buildBottomNav(),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg/stage1_battle_BG.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopHud(),
                  _buildStageTitle(),
                  Expanded(child: _buildBattleField()),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/profile_frame.png',
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.person,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPanelBorder, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/icon/coin_icon.png',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_gs.coins}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _buildLeaveBattleButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBattleButton() {
    final disabled = _battleEnded || _isLeavingBattle;
    return GestureDetector(
      onTap: disabled ? null : _confirmLeaveBattle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (disabled ? Colors.grey.shade800 : const Color(0xFF7A1A1A))
              .withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled ? Colors.white24 : const Color(0xFFB84535),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(
              _isLeavingBattle ? '처리 중' : '전투 나가기',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTitle() {
    final statusText = switch (_battleStatus) {
      'win' => '승리',
      'lose' => '패배',
      'flee' => '나감',
      _ => '진행 중',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        children: [
          Text(
            '${widget.stageId} ${widget.stageName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 5,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '웨이브 $_currentWave/${widget.totalWaves}  ·  $statusText',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 5,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _stepTracker.statusLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleField() {
    return Stack(
      children: [
        Align(
          alignment: const Alignment(0, -0.98),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHpBar(
                current: _monsterCurrentHp,
                max: _monsterMaxHp,
                width: 280,
                fillColor: _kRedBar,
              ),
              const SizedBox(height: 6),
              Text(
                _monsterName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 5,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.35),
          child: GestureDetector(
            onTap: _attack,
            child: Image.asset(
              MonsterAssetService.imageForMonster(
                name: _monsterName,
                stageNo: widget.stageNo,
              ),
              width: 138,
              height: 138,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
        Align(alignment: const Alignment(0, 0.78), child: _buildPlayerSprite()),
        Positioned(left: 12, bottom: 8, child: _buildPotionControls()),
        Positioned(right: 12, bottom: 74, child: _buildGaugeTracker()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Center(child: _buildAttackPanel()),
        ),
      ],
    );
  }

  Widget _buildHpBar({
    required int current,
    required int max,
    required double width,
    required Color fillColor,
    double height = 42,
    double fontSize = 18,
  }) {
    final safeMax = max <= 0 ? 1 : max;
    final clampedCurrent = current.clamp(0, safeMax);
    final ratio = clampedCurrent / safeMax;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A120E), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * ratio,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                fillColor.withValues(alpha: 0.78),
                                fillColor,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  '${_fmt(clampedCurrent)} / ${_fmt(safeMax)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ).copyWith(fontSize: fontSize),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPotionCard() {
    final selected = _selectedConsumable;
    final disabled = _battleEnded || _isUsingConsumable || selected == null;
    return Container(
      width: 80,
      height: 104,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : _useSelectedConsumable,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected != null)
                Image.asset(
                  _consumableImage(selected.itemTemplate),
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                )
              else
                const Icon(
                  Icons.local_drink,
                  color: Color(0xFFFF5C5C),
                  size: 30,
                ),
              const SizedBox(height: 6),
              Text(
                'x ${selected?.quantity ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isUsingConsumable ? '사용 중' : '사용',
                style: TextStyle(
                  color: disabled ? Colors.white54 : _kGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSprite() {
    const displayHeight = 200.0;
    const displayWidth =
        displayHeight * (_kPlayerAttackFrameWidth / _kPlayerAttackFrameHeight);
    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      offset: Offset(0, _playerSpriteOffsetY),
      child: SizedBox(
        width: displayWidth,
        height: displayHeight,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(-_playerAnimationFrame * displayWidth, 0),
              child: Image.asset(
                _currentPlayerSpritePath,
                width: displayWidth * _kPlayerAttackFrameCount,
                height: displayHeight,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                alignment: Alignment.topLeft,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPotionControls() {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPotionSelectorDrawer(),
          const SizedBox(height: 8),
          _buildPotionCard(),
        ],
      ),
    );
  }

  Widget _buildPotionSelectorButton() {
    final hasConsumables = _consumables.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasConsumables && !_isUsingConsumable
            ? () => setState(
                () => _isConsumableSelectorExpanded =
                    !_isConsumableSelectorExpanded,
              )
            : null,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          scale: _isConsumableSelectorExpanded ? 0.94 : 1,
          child: Container(
            width: 64,
            height: 48,
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/icon/item.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPotionSelectorDrawer() {
    final visible = _isConsumableSelectorExpanded && _consumables.isNotEmpty;
    final itemCount = _consumables.length;
    final contentHeight = visible
        ? (itemCount * 40.0) + ((itemCount - 1).clamp(0, 99) * 4.0) + 12.0
        : 0.0;
    final drawerHeight = 48.0 + contentHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 64,
      height: drawerHeight,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder, width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                border: visible
                    ? Border(top: BorderSide(color: _kPanelBorder, width: 1.5))
                    : null,
              ),
              child: _buildPotionSelectorButton(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            height: contentHeight,
            child: ClipRect(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: visible ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (
                        int index = _consumables.length - 1;
                        index >= 0;
                        index--
                      ) ...[
                        _buildPotionSelectorItem(_consumables[index], visible),
                        if (index > 0) const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPotionSelectorItem(OwnedInventoryItem item, bool visible) {
    final isSelected = item.itemTemplate.id == _selectedConsumableTemplateId;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: GestureDetector(
        onTap: _isUsingConsumable
            ? null
            : () => setState(() {
                _selectedConsumableTemplateId = item.itemTemplate.id;
                _isConsumableSelectorExpanded = false;
              }),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          scale: isSelected ? 1.04 : 1,
          child: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0x664C2A12) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  _consumableImage(item.itemTemplate),
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _consumableImage(ItemTemplate template) {
    final normalizedName = template.name.replaceAll(' ', '').trim();
    return switch (normalizedName) {
      '초급회복물약' => 'assets/images/icon/potion1.png',
      '중급회복물약' => 'assets/images/icon/potion2.png',
      '고급회복물약' => 'assets/images/icon/potion3.png',
      '5스테이지보스입장권' => 'assets/images/icon/ticket.png',
      _ => 'assets/images/icon/hp.png',
    };
  }

  Widget _buildGaugeTracker() {
    final pendingDistanceM = _stepTracker.pendingDistanceM;
    final characterGaugeDistanceM = _characterAttackDistanceM <= 0
        ? 0.0
        : (_characterAttackRemainderM + pendingDistanceM).clamp(
            0.0,
            _characterAttackDistanceM,
          );
    final characterRatio = _characterAttackDistanceM <= 0
        ? 0.0
        : (characterGaugeDistanceM / _characterAttackDistanceM).clamp(0.0, 1.0);
    final counterTargetGaugeM = _monsterAttackDistanceM <= 0
        ? 0.0
        : (_monsterAttackGaugeM + _characterAttackDistanceM).clamp(
            0.0,
            _monsterAttackDistanceM,
          );
    final liveCounterGaugeM =
        _monsterAttackGaugeM +
        ((counterTargetGaugeM - _monsterAttackGaugeM) * characterRatio);
    final counterRatio = _monsterAttackDistanceM <= 0
        ? 0.0
        : (liveCounterGaugeM / _monsterAttackDistanceM).clamp(0.0, 1.0);

    return Container(
      width: 58,
      height: 232,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPanelBorder, width: 2),
      ),
      child: Column(
        children: [
          Expanded(
            child: _buildVerticalBattleGauge(
              label: '반격',
              ratio: counterRatio,
              color: const Color(0xFFE02D24),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 8),
          Expanded(
            child: _buildVerticalBattleGauge(
              label: '공격',
              ratio: characterRatio,
              color: const Color(0xFF7AC943),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalBattleGauge({
    required String label,
    required double ratio,
    required Color color,
  }) {
    final safeRatio = ratio.clamp(0.0, 1.0);
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: safeRatio,
              child: Container(
                width: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(safeRatio * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAttackPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAttackButton(),
        const SizedBox(height: 5),
        _buildHpBar(
          current: _playerCurrentHp,
          max: _playerMaxHp,
          width: 200,
          height: 30,
          fontSize: 14,
          fillColor: _kBlueBar,
        ),
      ],
    );
  }

  Widget _buildAttackButton() {
    final disabled = _isAttacking || _battleEnded || _attackCountBalance <= 0;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade700 : const Color(0xFF7A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: disabled ? Colors.grey.shade600 : const Color(0xFF4A0E0E),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: disabled ? null : _attack,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _battleEnded
                      ? '전투 종료'
                      : (_isAttacking
                            ? '공격 중...'
                            : '공격 ($_attackCountBalance)'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_battleEnded &&
                    (_lastPlayerDamage > 0 || _lastMonsterDamage > 0))
                  Text(
                    '내 피해 $_lastPlayerDamage / 적 피해 $_lastMonsterDamage',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: 'assets/images/nav/nav_shop.png', label: '상점', index: 0),
      _NavItem(
        icon: 'assets/images/nav/nav_character.png',
        label: '캐릭터',
        index: 1,
      ),
      _NavItem(icon: 'assets/images/nav/nav_home.png', label: '홈', index: 2),
      _NavItem(icon: 'assets/images/nav/nav_battle.png', label: '전투', index: 3),
      _NavItem(icon: 'assets/images/nav/nav_raid.png', label: '레이드', index: 4),
    ];

    return Container(
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          const currentIndex = 3;
          final isSelected = currentIndex == item.index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_battleEnded && item.index != 3) {
                  _showBattleLockedMessage();
                  return;
                }
                switch (item.index) {
                  case 0:
                    _pushReplacement(const ShopPage());
                    break;
                  case 1:
                    _pushReplacement(const InventoryPage());
                    break;
                  case 2:
                    _pushReplacement(const HomePage());
                    break;
                  case 3:
                    break;
                  case 4:
                    _pushReplacement(const RaidListPage());
                    break;
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2E2E2E)
                      : const Color(0xFF232323),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isSelected
                        ? Image.asset(item.icon, width: 36, height: 36)
                        : ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.3,
                              0,
                              0,
                              0,
                              0,
                              0,
                              0.3,
                              0,
                              0,
                              0,
                              0,
                              0,
                              0.3,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                            child: Image.asset(
                              item.icon,
                              width: 36,
                              height: 36,
                            ),
                          ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? _kGold : Colors.white38,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _pushReplacement(Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => page,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _NavItem {
  final String icon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
