import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_audio_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/monster_asset_service.dart';
import 'package:capstone_app/features/battle/pages/battle_page.dart';
import 'package:capstone_app/features/battle/pages/gold_mine_event_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
import 'package:capstone_app/widgets/character_stats_panel.dart';
import 'package:capstone_app/widgets/game_top_actions.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';
import 'package:capstone_app/widgets/pixel_bottom_nav.dart';

const _kPanelBg = Color(0xCC0B0B0B);
const _kPanelBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFF0C040);
const _kLabelBg = Color(0xE6111111);
const _kStartBtn = Color(0xFF7A1A1A);
const _kStartBtnBorder = Color(0xFF4A0E0E);
const _kStageMapContentOffsetY = -25.0;
const _kPowerDanger = Color(0xFFFF5A52);
const _kPowerEasy = Color(0xFF5AB7FF);
const _kRewardReductionPowerPercent = 140;
const _kChapter1HomeBg = 'assets/images/bg/home_bg.png';
const _kChapter2HomeBg = 'assets/images/bg/home_bg_chapter2_shadow_forest.png';
const _kChapter3StageWaitBg =
    'assets/images/bg/stage_wait_chapter3_ancient_quarry.png';

class _StageData {
  final int stageNo;
  final String id;
  final String title;
  final Offset point;
  final bool isBoss;
  final bool unlocked;
  final bool cleared;
  final String status;
  final int clearCount;
  final int monsterCount;
  final String monsterName;
  final int monsterHp;

  const _StageData({
    required this.stageNo,
    required this.id,
    required this.title,
    required this.point,
    required this.isBoss,
    required this.unlocked,
    required this.cleared,
    required this.status,
    required this.clearCount,
    required this.monsterCount,
    required this.monsterName,
    required this.monsterHp,
  });
}

const _kChapterStagePoints = <int, List<Offset>>{
  1: [
    Offset(0.118, 0.64),
    Offset(0.3, 0.62),
    Offset(0.5, 0.37),
    Offset(0.7, 0.48),
    Offset(0.89, 0.33),
  ],
  2: [
    Offset(0.12, 0.64),
    Offset(0.31, 0.7),
    Offset(0.49, 0.54),
    Offset(0.668, 0.52),
    Offset(0.841, 0.46),
  ],
  3: [
    Offset(0.19, 0.7),
    Offset(0.34, 0.73),
    Offset(0.51, 0.52),
    Offset(0.72, 0.45),
    Offset(0.875, 0.33),
  ],
};

const _kChapterTitles = <int, String>{
  1: '1장 숲의 길',
  2: '2장 그늘버섯 숲',
  3: '3장 고대 채석장',
};

const _kMonsterNameFallbacks = <int, String>{
  1: '기본 고블린',
  2: '창 고블린',
  3: '궁수 고블린',
  4: '폭탄 고블린',
  5: '흉폭한 고블린',
  6: '포자 버섯병사',
  7: '가시 버섯병사',
  8: '독버섯 주술사',
  9: '서리 버섯병사',
  10: '장로 포자왕',
  11: '금이 간 석상병',
  12: '광맥 굴착 골렘',
  13: '룬 각인 수호자',
  14: '고대 파쇄 거인',
  15: '거석왕 탈로스',
};

const _kMonsterHpFallbacks = <int, int>{
  1: 75,
  2: 115,
  3: 145,
  4: 185,
  5: 320,
  6: 760,
  7: 880,
  8: 1020,
  9: 1180,
  10: 1700,
  11: 250,
  12: 300,
  13: 360,
  14: 450,
  15: 760,
};

const _kRecommendedCombatPowerByStage = <int, int>{
  1: 150,
  2: 180,
  3: 230,
  4: 280,
  5: 360,
  6: 460,
  7: 540,
  8: 620,
  9: 720,
  10: 830,
  11: 850,
  12: 950,
  13: 1050,
  14: 1200,
  15: 1350,
};

const _kBattlePreloadAssets = <String>[
  'assets/images/bg/stage1_battle_BG.png',
  'assets/images/bg/stage2_battle_shadow_mushroom_forest.png',
  'assets/images/bg/stage3_battle_ancient_quarry_entrance_941x1672.png',
  'assets/images/bg/stage3_ancient_quarry_entrance_map_1672x941.png',
  _kChapter3StageWaitBg,
  'assets/images/profile_frame.png',
  'assets/images/icon/coin_icon.png',
  'assets/images/icon/friend_icon.png',
  MonsterAssetService.basicGoblin,
  MonsterAssetService.spearGoblin,
  MonsterAssetService.archerGoblin,
  MonsterAssetService.bomberGoblin,
  MonsterAssetService.fierceGoblin,
  MonsterAssetService.sporeShroom,
  MonsterAssetService.thornShroom,
  MonsterAssetService.toxicShroom,
  MonsterAssetService.frostShroom,
  MonsterAssetService.elderSporeKing,
  MonsterAssetService.pebbleGolem,
  MonsterAssetService.crackedGolem,
  MonsterAssetService.mossyGolem,
  MonsterAssetService.oreGolem,
  MonsterAssetService.quarryGuardianGolem,
  'assets/images/character/battle_back.png',
  'assets/images/nav/nav_shop.png',
  'assets/images/nav/nav_character.png',
  'assets/images/nav/nav_home.png',
  'assets/images/nav/nav_battle.png',
  'assets/images/nav/nav_raid.png',
];

double _stageNodeVisualOffsetY(int stageNo) {
  final chapterStageNo = stageNo <= 0 ? 1 : ((stageNo - 1) % 5) + 1;
  return chapterStageNo == 2 ? -30.0 : 0.0;
}

class BattleStagePage extends StatefulWidget {
  const BattleStagePage({super.key});

  @override
  State<BattleStagePage> createState() => _BattleStagePageState();
}

class _BattleStagePageState extends State<BattleStagePage> {
  final _gs = GameState.instance;
  int _selectedIndex = 0;
  int _currentChapter = 1;
  bool _goldMineEventSelected = false;
  String _userName = '...';
  bool _isStarting = false;
  bool _isStageLoading = true;
  double _loadingProgress = 0;
  bool _isWaitingServer = false;
  String? _stageError;
  List<_StageData> _allStages = const [];
  int? _currentCombatPower;
  AppSettingsData _appSettings = const AppSettingsData.defaults();

  List<_StageData> get _visibleStages => _allStages
      .where((stage) => _chapterForStage(stage.stageNo) == _currentChapter)
      .toList(growable: false);

  int get _maxChapter {
    final maxStage = _allStages.fold<int>(
      0,
      (maxStage, stage) => math.max(maxStage, stage.stageNo),
    );
    return math.max(2, _chapterForStage(maxStage));
  }

  int get _safeSelectedIndex {
    final stages = _visibleStages;
    if (stages.isEmpty) return 0;
    if (_selectedIndex < 0) return 0;
    if (_selectedIndex >= stages.length) return stages.length - 1;
    return _selectedIndex;
  }

  _StageData? get _selectedStage {
    final stages = _visibleStages;
    if (stages.isEmpty) return null;
    return stages[_safeSelectedIndex];
  }

  bool get _chapter2HomeBgUnlocked =>
      _allStages.any((stage) => stage.stageNo >= 6 && stage.unlocked) ||
      _allStages.any((stage) => stage.stageNo == 5 && stage.cleared);

  bool get _chapter3HomeBgUnlocked =>
      _allStages.any((stage) => stage.stageNo >= 11 && stage.unlocked) ||
      _allStages.any((stage) => stage.stageNo == 10 && stage.cleared);

  String get _stagePageBackgroundAsset {
    final selected = _appSettings.homeBackgroundChapter;
    final effectiveChapter = selected == AppSettingsData.homeBackgroundAuto
        ? (_chapter3HomeBgUnlocked
              ? AppSettingsData.homeBackgroundChapter3
              : (_chapter2HomeBgUnlocked
                    ? AppSettingsData.homeBackgroundChapter2
                    : AppSettingsData.homeBackgroundChapter1))
        : selected;

    if (effectiveChapter == AppSettingsData.homeBackgroundChapter3 &&
        _chapter3HomeBgUnlocked) {
      return _kChapter3StageWaitBg;
    }
    if (effectiveChapter == AppSettingsData.homeBackgroundChapter2 &&
        _chapter2HomeBgUnlocked) {
      return _kChapter2HomeBg;
    }
    return _kChapter1HomeBg;
  }

  Widget _buildStagePageBackground() {
    return Image.asset(
      _stagePageBackgroundAsset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.none,
    );
  }

  @override
  void initState() {
    super.initState();
    AppSettingsService.notifier.addListener(_onAppSettingsChanged);
    _loadUserName();
    _loadStages();
    _loadCurrentCombatPower();
    _loadAppSettings();
  }

  @override
  void dispose() {
    AppSettingsService.notifier.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  Future<void> _loadAppSettings() async {
    final settings = await AppSettingsService.load();
    if (mounted) setState(() => _appSettings = settings);
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() => _appSettings = AppSettingsService.notifier.value);
  }

  Future<void> _loadUserName() async {
    try {
      await AuthService.fetchMainMessage();
    } catch (_) {
      // 세션 갱신 실패 시 저장된 값으로 폴백
    }

    final name = await AuthService.getSavedName();
    if (mounted) setState(() => _userName = name ?? '모험가');
  }

  Future<void> _loadStages() async {
    setState(() {
      _isStageLoading = true;
      _stageError = null;
    });

    try {
      final stages = await BattleApiService.fetchNormalStages();
      final mapped = _withBossStages(stages.map(_stageFromServer).toList())
        ..sort((a, b) => a.stageNo.compareTo(b.stageNo));
      final initialChapter = _initialChapterForStages(mapped);
      final initialVisibleStages = mapped
          .where((stage) => _chapterForStage(stage.stageNo) == initialChapter)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _allStages = mapped;
        _currentChapter = initialChapter;
        _selectedIndex = _initialSelectedIndex(initialVisibleStages);
        _isStageLoading = false;
      });
    } on BattleApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _allStages = const [];
        _selectedIndex = 0;
        _stageError = e.message;
        _isStageLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allStages = const [];
        _selectedIndex = 0;
        _stageError = '스테이지 정보를 불러오지 못했습니다.';
        _isStageLoading = false;
      });
    }
  }

  Future<void> _loadCurrentCombatPower() async {
    try {
      final summary = await GameApiService.fetchCharacterStatsSummary();
      final power = _combatPower(summary.finalStats);
      if (!mounted) return;
      setState(() => _currentCombatPower = power);
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentCombatPower = null);
    }
  }

  int _initialSelectedIndex(List<_StageData> stages) {
    if (stages.isEmpty) return 0;
    if (_selectedIndex >= 0 &&
        _selectedIndex < stages.length &&
        stages[_selectedIndex].unlocked) {
      return _selectedIndex;
    }
    final firstUnlocked = stages.indexWhere((stage) => stage.unlocked);
    return firstUnlocked >= 0 ? firstUnlocked : 0;
  }

  int _initialChapterForStages(List<_StageData> stages) {
    var highestChapter = 1;
    for (final stage in stages) {
      if (!stage.unlocked && !stage.cleared) continue;
      highestChapter = math.max(
        highestChapter,
        _chapterForStage(stage.stageNo),
      );
    }
    return highestChapter;
  }

  _StageData _stageFromServer(NormalStageInfo stage) {
    final title = stage.title.trim().isNotEmpty
        ? stage.title.trim()
        : '스테이지 ${stage.stageNo}';
    return _StageData(
      stageNo: stage.stageNo,
      id: _stageDisplayId(stage.stageNo),
      title: title,
      point: _stagePoint(stage.stageNo),
      isBoss: stage.stageType == 'boss',
      unlocked: stage.isUnlocked,
      cleared: stage.isCleared,
      status: stage.status,
      clearCount: stage.clearCount,
      monsterCount: stage.monsterCount <= 0 ? 1 : stage.monsterCount,
      monsterName: MonsterAssetService.nameForStage(
        stage.stageNo,
        fallback: stage.monsterName.trim().isNotEmpty
            ? stage.monsterName.trim()
            : (_kMonsterNameFallbacks[stage.stageNo] ?? '몬스터'),
      ),
      monsterHp: stage.monsterHp > 0
          ? stage.monsterHp
          : (_kMonsterHpFallbacks[stage.stageNo] ?? 1),
    );
  }

  List<_StageData> _withBossStages(List<_StageData> normalStages) {
    return [
      ...normalStages,
      if (!normalStages.any((stage) => stage.stageNo == 5))
        _bossStage(
          stageNo: 5,
          title: '고대 수문장 - 1-5',
          previousStage: normalStages.where((stage) => stage.stageNo == 4),
        ),
      if (normalStages.any((stage) => stage.stageNo >= 6) &&
          !normalStages.any((stage) => stage.stageNo == 10))
        _bossStage(
          stageNo: 10,
          title: '그늘버섯 숲 - 2-5',
          previousStage: normalStages.where((stage) => stage.stageNo == 9),
        ),
      if (normalStages.any((stage) => stage.stageNo >= 11) &&
          !normalStages.any((stage) => stage.stageNo == 15))
        _bossStage(
          stageNo: 15,
          title: '고대 채석장 - 3-5',
          previousStage: normalStages.where((stage) => stage.stageNo == 14),
        ),
    ];
  }

  _StageData _bossStage({
    required int stageNo,
    required String title,
    required Iterable<_StageData> previousStage,
  }) {
    final previous = previousStage.isEmpty ? null : previousStage.first;
    final unlocked = previous?.cleared ?? false;
    return _StageData(
      stageNo: stageNo,
      id: _stageDisplayId(stageNo),
      title: title,
      point: _stagePoint(stageNo),
      isBoss: true,
      unlocked: unlocked,
      cleared: false,
      status: unlocked ? 'unlocked' : 'locked',
      clearCount: 0,
      monsterCount: 1,
      monsterName: _kMonsterNameFallbacks[stageNo] ?? '보스 몬스터',
      monsterHp: _kMonsterHpFallbacks[stageNo] ?? 1,
    );
  }

  Offset _stagePoint(int stageNo) {
    final chapter = _chapterForStage(stageNo);
    final chapterStageNo = _stageNoInChapter(stageNo);
    final chapterPoints = _kChapterStagePoints[chapter];
    if (chapterPoints != null &&
        chapterStageNo >= 1 &&
        chapterStageNo <= chapterPoints.length) {
      return chapterPoints[chapterStageNo - 1];
    }

    final index = chapterStageNo - 1;
    final x = 0.12 + ((index % 5) * 0.19);
    final y = index.isEven ? 0.72 : 0.58;
    return Offset(x.clamp(0.10, 0.90).toDouble(), y);
  }

  int _chapterForStage(int stageNo) {
    if (stageNo <= 0) return 1;
    return ((stageNo - 1) ~/ 5) + 1;
  }

  int _stageNoInChapter(int stageNo) {
    if (stageNo <= 0) return 1;
    return ((stageNo - 1) % 5) + 1;
  }

  String _stageDisplayId(int stageNo) {
    return '${_chapterForStage(stageNo)}-${_stageNoInChapter(stageNo)}';
  }

  int get _clearedCount => _visibleStages.where((s) => s.cleared).length;

  void _changeChapter(int delta) {
    final nextChapter = (_currentChapter + delta).clamp(1, _maxChapter);
    if (nextChapter == _currentChapter) return;
    setState(() {
      _currentChapter = nextChapter;
      _selectedIndex = _initialSelectedIndex(_visibleStages);
      _goldMineEventSelected = false;
    });
    GameAudioService.playChapterTurn();
  }

  void _selectStage(int index) {
    final stages = _visibleStages;
    if (index < 0 || index >= stages.length) return;
    final stage = stages[index];
    if (!stage.unlocked) {
      showGameToast(
        context,
        '이전 스테이지를 먼저 클리어하세요.',
        type: GameToastType.warning,
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
      _goldMineEventSelected = false;
    });
  }

  Future<void> _startBattle() async {
    final selectedStage = _selectedStage;
    if (selectedStage == null ||
        !selectedStage.unlocked ||
        _isStageLoading ||
        _isStarting) {
      return;
    }

    String? errorMessage;
    setState(() {
      _isStarting = true;
      _loadingProgress = 0;
      _isWaitingServer = false;
    });
    try {
      await AuthService.fetchMainMessage();
      if (!mounted) return;
      await _precacheBattleAssets();
      if (!mounted) return;

      setState(() => _isWaitingServer = true);
      final result = selectedStage.isBoss
          ? await BattleApiService.startBossBattle(
              stageNo: selectedStage.stageNo,
            )
          : await BattleApiService.startNormalBattle(
              stageNo: selectedStage.stageNo,
            );
      _gs.setCoins(result.character.coinBalance);
      _gs.setLevel(result.character.level);
      _gs.setExp(result.character.exp);
      _gs.setStatExp(result.character.statExp);

      if (!mounted) return;
      GameAudioService.playStageEnter();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, _) => BattlePage(
            stageId: selectedStage.id,
            stageNo: selectedStage.stageNo,
            stageName: selectedStage.title,
            totalWaves: selectedStage.monsterCount,
            initialResult: result,
          ),
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
    } on BattleApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = '전투 시작에 실패했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
          _loadingProgress = 0;
          _isWaitingServer = false;
        });
      }
    }

    if (!mounted || errorMessage == null) return;
    showGameToast(context, errorMessage, type: GameToastType.error);
  }

  Future<void> _precacheBattleAssets() async {
    final total = _kBattlePreloadAssets.length;
    if (total == 0) {
      setState(() => _loadingProgress = 1);
      return;
    }

    for (int i = 0; i < total; i++) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(_kBattlePreloadAssets[i]), context);
      } catch (_) {
        // 프리캐시 실패는 무시하고 진행
      }
      if (!mounted) return;
      setState(() => _loadingProgress = (i + 1) / total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isShortWide = screenSize.height < 760 && screenSize.width > 700;
    final isCompactLayout = screenSize.height < 900 || screenSize.width < 430;
    final mapHeight = isShortWide
        ? math.min(86.0, math.max(76.0, screenSize.height * 0.12))
        : (isCompactLayout
              ? math.min(160.0, math.max(128.0, screenSize.height * 0.18))
              : math.min(300.0, math.max(205.0, screenSize.height * 0.31)));
    final bottomNavReservedHeight = PixelBottomNav.reservedHeightFor(context);

    return PopScope(
      canPop: !_isStarting,
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: _buildBottomNav(),
        body: Stack(
          children: [
            Positioned.fill(child: _buildStagePageBackground()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomNavReservedHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _buildTopHud(),
                    _buildTitle(compact: isCompactLayout),
                    _buildStagePanel(mapHeight, compact: isCompactLayout),
                    _buildMonsterPanel(compact: isCompactLayout),
                    _buildStartButton(compact: isCompactLayout),
                  ],
                ),
              ),
            ),
            if (_isStarting) Positioned.fill(child: _buildLoadingOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final percent = (_loadingProgress * 100).round().clamp(0, 100);
    return Stack(
      children: [
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.72),
        ),
        Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPanelBorder, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '전투 준비 중...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isWaitingServer
                      ? '로컬 준비 완료. 서버 응답을 기다리는 중입니다.'
                      : '전투 화면 리소스를 불러오는 중입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    minHeight: 10,
                    backgroundColor: Colors.black,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$percent%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isWaitingServer) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_kGold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '서버에서 전투 생성 중...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _openCharacterStatsDialog,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPlayerProfileBlock(),
                const SizedBox(width: 8),
                Text(
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
              ],
            ),
          ),
          const Spacer(),
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
              const GameTopActions(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerProfileBlock() {
    return PlayerProfileWithLevel(
      level: _gs.level,
      exp: _gs.exp,
      expToNext: _gs.expToNextLevel,
    );
  }

  void _openCharacterStatsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) =>
          CharacterStatsDialog(userName: _userName, level: _gs.level),
    );
  }

  Widget _buildTitle({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, compact ? 0 : 4, 8, compact ? 2 : 5),
      child: Column(
        children: [
          Text(
            '✦ 전투 ✦',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 20 : 25,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 8,
                  offset: Offset(1, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '모험을 떠나 몬스터를 물리치고 보상을 획득하세요!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: compact ? 8 : 10,
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

  Widget _buildStagePanel(double mapHeight, {bool compact = false}) {
    final stages = _visibleStages;
    final canGoPrevious = _currentChapter > 1;
    final canGoNext = _currentChapter < _maxChapter;
    final chapterTitle =
        _kChapterTitles[_currentChapter] ?? '$_currentChapter장 모험 지역';

    return Padding(
      padding: EdgeInsets.fromLTRB(6, 0, 6, compact ? 3 : 6),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 10,
          compact ? 6 : 8,
          compact ? 8 : 10,
          compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kPanelBorder, width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildChapterArrow(
                  icon: Icons.chevron_left,
                  enabled: canGoPrevious,
                  onTap: () => _changeChapter(-1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A2A1D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF51160F),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      chapterTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildChapterArrow(
                  icon: Icons.chevron_right,
                  enabled: canGoNext,
                  onTap: () => _changeChapter(1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kPanelBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: _kGold, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '$_clearedCount/${stages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: mapHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mapRatio = constraints.maxWidth / mapHeight;
                    final mapAsset = _currentChapter == 3
                        ? 'assets/images/bg/stage3_ancient_quarry_entrance_map_1672x941.png'
                        : (_currentChapter == 2
                              ? 'assets/images/bg/stage2_shadow_mushroom_forest_map.png'
                              : (mapRatio > 6
                                    ? 'assets/images/bg/stage1_forest_path_ui_strip.png'
                                    : (mapRatio > 2.15
                                          ? 'assets/images/bg/stage1_forest_path_strip_map.png'
                                          : 'assets/images/bg/stage1_forest_path_map.png')));
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            mapAsset,
                            fit: BoxFit.fill,
                            alignment: const Alignment(0, 1.4),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isStageLoading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(color: _kGold),
                            ),
                          )
                        else if (_stageError != null)
                          Positioned.fill(child: _buildStageError())
                        else if (stages.isEmpty)
                          Positioned.fill(
                            child: _buildStageEmpty('표시할 스테이지가 없습니다.'),
                          )
                        else ...[
                          Positioned.fill(
                            child: Transform.translate(
                              offset: const Offset(0, _kStageMapContentOffsetY),
                              child: CustomPaint(
                                painter: _StagePathPainter(stages: stages),
                              ),
                            ),
                          ),
                          if (_currentChapter == 3)
                            _buildGoldMineEventNode(constraints),
                          for (int i = 0; i < stages.length; i++)
                            _buildStageNode(
                              i,
                              constraints,
                              compact: compact,
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: enabled ? 0.56 : 0.32),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? _kPanelBorder : Colors.black45,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white30,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildStageNode(
    int index,
    BoxConstraints constraints, {
    bool compact = false,
  }) {
    final iconSize = compact ? 68.0 : 78.0;
    final glowSizeLarge = compact ? 96.0 : 112.0;
    final glowSizeSmall = compact ? 92.0 : 108.0;
    final stages = _visibleStages;
    final stage = stages[index];
    final isSelected = _safeSelectedIndex == index;
    final left = (stage.point.dx * constraints.maxWidth) - (iconSize / 2);
    final extraOffsetY = _stageNodeVisualOffsetY(stage.stageNo);
    final top =
        (stage.point.dy * constraints.maxHeight) -
        (iconSize / 2) +
        _kStageMapContentOffsetY +
        extraOffsetY;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _selectStage(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: compact ? 11 : 13,
              child: stage.cleared
                  ? Padding(
                      padding: EdgeInsets.only(bottom: compact ? 1 : 2),
                      child: Text(
                        'CLEAR',
                        style: TextStyle(
                          color: _kGold,
                          fontSize: compact ? 8 : 9,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSelected && stage.unlocked)
                    IgnorePointer(
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 20,
                          sigmaY: 20,
                        ),
                        child: Opacity(
                          opacity: 1,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _kGold,
                              BlendMode.srcATop,
                            ),
                            child: Image.asset(
                              'assets/images/battle/unlocked_battle.png',
                              width: glowSizeLarge,
                              height: glowSizeLarge,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (isSelected && stage.unlocked)
                    IgnorePointer(
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 15,
                          sigmaY: 15,
                        ),
                        child: Opacity(
                          opacity: 1,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _kGold,
                              BlendMode.srcATop,
                            ),
                            child: Image.asset(
                              'assets/images/battle/unlocked_battle.png',
                              width: glowSizeSmall,
                              height: glowSizeSmall,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Image.asset(
                    stage.unlocked
                        ? 'assets/images/battle/unlocked_battle.png'
                        : 'assets/images/battle/locked_battle.png',
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kPanelBorder, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 1 : 2),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: _kLabelBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? _kGold : const Color(0xFF3C3C3C),
                  width: isSelected ? 1.8 : 1.2,
                ),
              ),
              child: Text(
                stage.id,
                style: TextStyle(
                  color: stage.unlocked ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldMineEventNode(BoxConstraints constraints) {
    const markerSize = 54.0;
    const point = Offset(0.31, 0.31);
    final left = (point.dx * constraints.maxWidth) - (markerSize / 2);
    final top = (point.dy * constraints.maxHeight) - (markerSize / 2);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          if (!_goldMineEventUnlocked) {
            showGameToast(
              context,
              '3-3 스테이지를 먼저 클리어하세요.',
              type: GameToastType.warning,
            );
            return;
          }
          setState(() => _goldMineEventSelected = true);
        },
        child: SizedBox(
          width: markerSize,
          height: markerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_goldMineEventSelected)
                Icon(
                  Icons.star_rounded,
                  color: _kGold.withValues(alpha: 0.36),
                  size: 52,
                  shadows: const [
                    Shadow(color: _kGold, blurRadius: 16),
                    Shadow(color: Colors.black, blurRadius: 5),
                  ],
                ),
              Icon(
                Icons.star_rounded,
                color: _goldMineEventUnlocked
                    ? _kGold
                    : _kGold.withValues(alpha: 0.48),
                size: 31,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 5),
                  Shadow(color: Colors.black, offset: Offset(1, 1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageError() {
    return _buildStageEmpty(
      _stageError ?? '스테이지 정보를 불러오지 못했습니다.',
      actionLabel: '다시 불러오기',
      onAction: _loadStages,
    );
  }

  Widget _buildStageEmpty(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kStartBtn,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kStartBtnBorder, width: 1.5),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonsterPanel({bool compact = false}) {
    if (_goldMineEventSelected) {
      return _buildGoldMineEventPanel();
    }
    final selectedStage = _selectedStage;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 0, 6, compact ? 3 : 6),
      child: Container(
        padding: EdgeInsets.all(compact ? 6 : 8),
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kPanelBorder, width: 2),
        ),
        child: Column(
          children: [
            if (selectedStage == null)
              const Text(
                '✦ 스테이지 정보 ✦',
                style: TextStyle(
                  color: _kGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 5 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A2A1D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF51160F),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      selectedStage.id,
                      style: TextStyle(
                        color: _kGold,
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              selectedStage.title,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 14 : 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          selectedStage.unlocked ? '도전 가능한 스테이지' : '잠긴 스테이지',
                          style: TextStyle(
                            color: selectedStage.unlocked
                                ? const Color(0xFF64E66D)
                                : Colors.white60,
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  _buildRecommendedPowerBadge(
                    selectedStage,
                    compact: compact,
                  ),
                ],
              ),
            SizedBox(height: compact ? 4 : 7),
            if (selectedStage == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _isStageLoading ? '스테이지 정보를 불러오는 중입니다.' : '선택된 스테이지가 없습니다.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Container(
                    width: compact ? 46 : 64,
                    height: compact ? 46 : 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kPanelBorder, width: 1.5),
                    ),
                    padding: EdgeInsets.all(compact ? 5 : 8),
                    child: Image.asset(
                      MonsterAssetService.imageForMonster(
                        name: selectedStage.monsterName,
                        stageNo: selectedStage.stageNo,
                      ),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.pets,
                        color: Colors.white54,
                        size: compact ? 32 : 44,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Column(
                      children: [
                        _buildMonsterInfoRow(
                          label: '몬스터 이름',
                          value: selectedStage.monsterName,
                          unlocked: selectedStage.unlocked,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 3 : 5),
                        _buildMonsterInfoRow(
                          label: '체력',
                          value: _formatNumber(selectedStage.monsterHp),
                          iconPath: 'assets/images/icon/hp.png',
                          unlocked: selectedStage.unlocked,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 3 : 5),
                        _buildMonsterInfoRow(
                          label: '상태',
                          value: _stageStatusLabel(selectedStage),
                          unlocked: selectedStage.unlocked,
                          compact: compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldMineEventPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kPanelBorder, width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A2A1D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF51160F),
                      width: 1.5,
                    ),
                  ),
                  child: const Text(
                    '3-6',
                    style: TextStyle(
                      color: _kGold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '황금 광맥 발견',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '3-3 클리어로 열린 이벤트 스테이지',
                        style: TextStyle(
                          color: Color(0xFF64E66D),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kPanelBorder, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/monsters/monster_1-1_basic_goblin.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.pets, color: Colors.white54, size: 44),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _buildMonsterInfoRow(
                        label: '몬스터',
                        value: '황금 광맥 도둑 고블린',
                        unlocked: true,
                      ),
                      const SizedBox(height: 5),
                      _buildMonsterInfoRow(
                        label: '제한 시간',
                        value: '3분',
                        unlocked: true,
                      ),
                      const SizedBox(height: 5),
                      _buildMonsterInfoRow(
                        label: '최고 보상',
                        value: '600m',
                        unlocked: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonsterInfoRow({
    required String label,
    required String value,
    required bool unlocked,
    String? iconPath,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPanelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          if (iconPath != null) ...[
            Image.asset(
              iconPath,
              width: compact ? 13 : 16,
              height: compact ? 13 : 16,
            ),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white60,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  int _recommendedCombatPowerForStage(int stageNo) {
    final knownPower = _kRecommendedCombatPowerByStage[stageNo];
    if (knownPower != null) return knownPower;

    final chapter = _chapterForStage(stageNo);
    final chapterStageNo = _stageNoInChapter(stageNo);
    return math.max(
      150,
      1100 + ((chapter - 2) * 550) + ((chapterStageNo - 1) * 140),
    );
  }

  String _stageStatusLabel(_StageData stage) {
    if (stage.cleared) return '클리어';
    if (stage.unlocked) return '도전 가능';
    return '잠김';
  }

  Widget _buildRecommendedPowerBadge(_StageData stage, {bool compact = false}) {
    final recommendedPower = _recommendedCombatPowerForStage(stage.stageNo);
    final value = _formatNumber(recommendedPower);
    final valueColor = _recommendedPowerColor(stage, recommendedPower);
    final borderColor = stage.unlocked
        ? valueColor.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.16);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/icon/atk.png',
            width: compact ? 12 : 14,
            height: compact ? 12 : 14,
          ),
          SizedBox(width: compact ? 3 : 5),
          Text(
            '전투력',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Color _recommendedPowerColor(_StageData stage, int recommendedPower) {
    if (!stage.unlocked) return Colors.white60;
    final currentPower = _currentCombatPower;
    if (currentPower == null || recommendedPower <= 0) return _kGold;
    if (currentPower < recommendedPower) return _kPowerDanger;
    if (currentPower * 100 > recommendedPower * _kRewardReductionPowerPercent) {
      return _kPowerEasy;
    }
    return _kGold;
  }

  int _combatPower(Map<String, int> stats) {
    if (stats.isEmpty) return 0;
    final hp = stats['hp'] ?? 0;
    final attack = stats['attack'] ?? 0;
    final defense = stats['defense'] ?? 0;
    final agility = stats['agility'] ?? 0;
    return (hp / 3 + attack * 8 + defense * 5 + agility * 4).round();
  }

  bool get _goldMineEventUnlocked =>
      _allStages.any((stage) => stage.stageNo == 13 && stage.cleared);

  Future<void> _openGoldMineEvent() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GoldMineEventPage()),
    );
  }

  Widget _buildStartButton({bool compact = false}) {
    final selectedStage = _selectedStage;
    final isEvent = _goldMineEventSelected;
    final locked = isEvent
        ? !_goldMineEventUnlocked
        : _isStageLoading || selectedStage == null || !selectedStage.unlocked;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 0, 6, compact ? 3 : 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (false && _currentChapter == 3 && _goldMineEventUnlocked) ...[
            GestureDetector(
              onTap: _isStarting ? null : _openGoldMineEvent,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A6515),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGold, width: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.diamond_outlined, color: _kGold, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '황금 광맥 발견',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          GestureDetector(
            onTap: (locked || _isStarting)
                ? null
                : (isEvent ? _openGoldMineEvent : _startBattle),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                8,
                compact ? 6 : 8,
                8,
                compact ? 7 : 9,
              ),
              decoration: BoxDecoration(
                color: (locked || _isStarting)
                    ? const Color(0xFF555555)
                    : _kStartBtn,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (locked || _isStarting)
                      ? const Color(0xFF6D6D6D)
                      : _kStartBtnBorder,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 26 : 30,
                    height: compact ? 26 : 30,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/icon/battle.png',
                      width: compact ? 17 : 20,
                      height: compact ? 17 : 20,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEvent
                            ? '이벤트 시작'
                            : _isStageLoading
                            ? '스테이지 불러오는 중...'
                            : (_stageError != null
                                  ? '스테이지 불러오기 실패'
                                  : (locked
                                        ? '잠금 해제 필요'
                                        : (_isStarting
                                              ? '전투 준비 중...'
                                              : '전투 시작'))),
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_shop.png',
        label: '상점',
        index: 0,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_character.png',
        label: '캐릭터',
        index: 1,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_home.png',
        label: '홈',
        index: 2,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_battle.png',
        label: '전투',
        index: 3,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_raid.png',
        label: '레이드',
        index: 4,
      ),
    ];

    return PixelBottomNav(
      items: items,
      currentIndex: 3,
      onTap: (item) async {
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

  String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

class _StagePathPainter extends CustomPainter {
  final List<_StageData> stages;
  const _StagePathPainter({required this.stages});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < stages.length - 1; i++) {
      final start = Offset(
        stages[i].point.dx * size.width,
        (stages[i].point.dy * size.height) +
            _stageNodeVisualOffsetY(stages[i].stageNo),
      );
      final end = Offset(
        stages[i + 1].point.dx * size.width,
        (stages[i + 1].point.dy * size.height) +
            _stageNodeVisualOffsetY(stages[i + 1].stageNo),
      );
      final paint = Paint()
        ..color = stages[i + 1].unlocked
            ? const Color(0xFFE7D5A3)
            : Colors.black54
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      _drawDashedLine(canvas, start, end, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 10.0;
    const gap = 7.0;
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    double drawn = 0;

    while (drawn < distance) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * math.min(drawn + dash, distance);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StagePathPainter oldDelegate) {
    return oldDelegate.stages != stages;
  }
}
