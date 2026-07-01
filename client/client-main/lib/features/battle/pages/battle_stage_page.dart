import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/monster_asset_service.dart';
import 'package:capstone_app/features/battle/pages/battle_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';
import 'package:capstone_app/widgets/pixel_bottom_nav.dart';

const _kPanelBg = Color(0xCC0B0B0B);
const _kPanelBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFF0C040);
const _kLabelBg = Color(0xE6111111);
const _kStartBtn = Color(0xFF7A1A1A);
const _kStartBtnBorder = Color(0xFF4A0E0E);
const _kStageMapContentOffsetY = -25.0;

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

const _kStagePoints = <Offset>[
  Offset(0.12, 0.74),
  Offset(0.34, 0.79),
  Offset(0.53, 0.57),
  Offset(0.72, 0.76),
  Offset(0.87, 0.63),
];

const _kChapterTitles = <int, String>{1: '1장 숲의 길', 2: '2장 그늘버섯 숲'};

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
};

const _kBattlePreloadAssets = <String>[
  'assets/images/bg/stage1_battle_BG.png',
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
  'assets/images/character/battle_back.png',
  'assets/images/nav/nav_shop.png',
  'assets/images/nav/nav_character.png',
  'assets/images/nav/nav_home.png',
  'assets/images/nav/nav_battle.png',
  'assets/images/nav/nav_raid.png',
];

class BattleStagePage extends StatefulWidget {
  const BattleStagePage({super.key});

  @override
  State<BattleStagePage> createState() => _BattleStagePageState();
}

class _BattleStagePageState extends State<BattleStagePage> {
  final _gs = GameState.instance;
  int _selectedIndex = 0;
  int _currentChapter = 1;
  String _userName = '...';
  bool _isStarting = false;
  bool _isStageLoading = true;
  double _loadingProgress = 0;
  bool _isWaitingServer = false;
  String? _stageError;
  List<_StageData> _allStages = const [];

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

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadStages();
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
      if (!mounted) return;
      setState(() {
        _allStages = mapped;
        _selectedIndex = _initialSelectedIndex(_visibleStages);
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
    final chapterStageNo = _stageNoInChapter(stageNo);
    if (chapterStageNo >= 1 && chapterStageNo <= _kStagePoints.length) {
      return _kStagePoints[chapterStageNo - 1];
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
    });
  }

  void _selectStage(int index) {
    final stages = _visibleStages;
    if (index < 0 || index >= stages.length) return;
    final stage = stages[index];
    if (!stage.unlocked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이전 스테이지를 먼저 클리어하세요.')));
      return;
    }
    setState(() => _selectedIndex = index);
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
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(errorMessage)));
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
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = math.min(330.0, math.max(220.0, screenHeight * 0.34));

    return PopScope(
      canPop: !_isStarting,
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: _buildBottomNav(),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg/home_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 132),
                child: Column(
                  children: [
                    _buildTopHud(),
                    _buildTitle(),
                    _buildStagePanel(mapHeight),
                    _buildMonsterPanel(),
                    _buildStartButton(),
                    const SizedBox(height: 28),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          const Text(
            '✦ 전투 ✦',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
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
              fontSize: 11,
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

  Widget _buildStagePanel(double mapHeight) {
    final stages = _visibleStages;
    final canGoPrevious = _currentChapter > 1;
    final canGoNext = _currentChapter < _maxChapter;
    final chapterTitle =
        _kChapterTitles[_currentChapter] ?? '$_currentChapter장 모험 지역';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
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
                      vertical: 9,
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
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/bg/battle_satge_BG.jpg',
                            fit: BoxFit.cover,
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
                          for (int i = 0; i < stages.length; i++)
                            _buildStageNode(i, constraints),
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

  Widget _buildStageNode(int index, BoxConstraints constraints) {
    const iconSize = 78.0;
    final stages = _visibleStages;
    final stage = stages[index];
    final isSelected = _safeSelectedIndex == index;
    final left = (stage.point.dx * constraints.maxWidth) - (iconSize / 2);
    final extraOffsetY = _stageNoInChapter(stage.stageNo) == 2 ? -30.0 : 0.0;
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
            if (stage.cleared)
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  'CLEAR',
                  style: TextStyle(
                    color: _kGold,
                    fontSize: 9,
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
                              width: 112,
                              height: 112,
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
                              width: 108,
                              height: 108,
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
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  fontSize: 13,
                ),
              ),
            ),
          ],
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

  Widget _buildMonsterPanel() {
    final selectedStage = _selectedStage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(10),
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
                    child: Text(
                      selectedStage.id,
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedStage.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          selectedStage.unlocked ? '도전 가능한 스테이지' : '잠긴 스테이지',
                          style: TextStyle(
                            color: selectedStage.unlocked
                                ? const Color(0xFF64E66D)
                                : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
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
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kPanelBorder, width: 1.5),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      MonsterAssetService.imageForMonster(
                        name: selectedStage.monsterName,
                        stageNo: selectedStage.stageNo,
                      ),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.pets,
                        color: Colors.white54,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        _buildMonsterInfoRow(
                          label: '몬스터 이름',
                          value: selectedStage.monsterName,
                          unlocked: selectedStage.unlocked,
                        ),
                        const SizedBox(height: 7),
                        _buildMonsterInfoRow(
                          label: '체력',
                          value: _formatNumber(selectedStage.monsterHp),
                          iconPath: 'assets/images/icon/hp.png',
                          unlocked: selectedStage.unlocked,
                        ),
                        const SizedBox(height: 7),
                        _buildMonsterInfoRow(
                          label: '상태',
                          value: _stageStatusLabel(selectedStage),
                          unlocked: selectedStage.unlocked,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPanelBorder, width: 1.2),
      ),
      child: Row(
        children: [
          if (iconPath != null) ...[
            Image.asset(iconPath, width: 16, height: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _stageStatusLabel(_StageData stage) {
    if (stage.cleared) return '클리어';
    if (stage.unlocked) return '도전 가능';
    return '잠김';
  }

  Widget _buildStartButton() {
    final selectedStage = _selectedStage;
    final locked =
        _isStageLoading || selectedStage == null || !selectedStage.unlocked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: GestureDetector(
        onTap: (locked || _isStarting) ? null : _startBattle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
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
            children: [
              Image.asset(
                'assets/images/icon/battle.png',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isStageLoading
                        ? '스테이지 불러오는 중...'
                        : (_stageError != null
                              ? '스테이지 불러오기 실패'
                              : (locked
                                    ? '잠금 해제 필요'
                                    : (_isStarting ? '전투 준비 중...' : '전투 시작'))),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        stages[i].point.dy * size.height,
      );
      final end = Offset(
        stages[i + 1].point.dx * size.width,
        stages[i + 1].point.dy * size.height,
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
