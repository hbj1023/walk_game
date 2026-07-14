import 'package:flutter/material.dart';

import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/step_tracking_controller.dart';
import 'package:capstone_app/features/auth/pages/login_page.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';
import 'package:capstone_app/widgets/character_stats_panel.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
import 'package:capstone_app/widgets/game_top_actions.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';
import 'package:capstone_app/widgets/pixel_bottom_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const _supportedWeaponTypes = <String>{
    'sword',
    'dagger',
    'axe',
    'spear',
    'greatsword',
  };
  static const _chapter1HomeBg = 'assets/images/bg/home_bg.png';
  static const _chapter2HomeBg =
      'assets/images/bg/home_bg_chapter2_shadow_forest.png';

  String _userName = '...';
  String _equippedWeaponType = '';
  int _currentNavIndex = 2;
  final _gs = GameState.instance;
  late final StepTrackingController _stepTracker;

  late AnimationController _bgController;
  double _bgAspectRatio = 2.0; // 이미지 로드 전 기본값

  bool _chapter2HomeBgUnlocked = false;
  AppSettingsData _appSettings = const AppSettingsData.defaults();
  bool _profileLoading = true;
  String? _profileError;
  bool _missionLoading = true;
  String? _missionError;
  List<UserMission> _missions = const [];

  @override
  void initState() {
    super.initState();
    _gs.addListener(_onGameStateChanged);
    AppSettingsService.notifier.addListener(_onAppSettingsChanged);
    _stepTracker = StepTrackingController.home(
      onSyncSteps: (request) => GameApiService.syncStepDelta(
        stepCount: request.stepCount,
        strideM: request.strideM,
        gpsDistanceM: request.gpsDistanceM,
        abnormalReason: request.abnormalReason,
        syncType: request.syncType,
      ),
      onSyncSuccess: (result, context) async {
        if (context.allowPostSyncActions &&
            result.bossTicketFragmentEarned > 0 &&
            mounted) {
          showGameToast(
            this.context,
            '보스 입장권 조각 +${result.bossTicketFragmentEarned}개',
            type: GameToastType.success,
          );
        }
        await _loadMissions();
      },
      onStartError: (error) => _showSnackBar(error.toString()),
      onSyncError: (error) => _showSnackBar(error.toString()),
    )..addListener(_onStepTrackerChanged);
    _loadUserName();
    _loadEquippedWeapon();
    _loadMissions();
    _loadAppSettings();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _loadBgAspectRatio();
    _loadHomeBackgroundState();
  }

  String get _homeBgAsset {
    final selected = _appSettings.homeBackgroundChapter;
    final effectiveChapter = selected == AppSettingsData.homeBackgroundAuto
        ? (_chapter2HomeBgUnlocked
              ? AppSettingsData.homeBackgroundChapter2
              : AppSettingsData.homeBackgroundChapter1)
        : selected;

    if (effectiveChapter == AppSettingsData.homeBackgroundChapter2 &&
        _chapter2HomeBgUnlocked) {
      return _chapter2HomeBg;
    }
    return _chapter1HomeBg;
  }

  String get _homeRunSprite =>
      _supportedWeaponTypes.contains(_equippedWeaponType)
      ? 'assets/images/character/weapon_attacks/run_right_$_equippedWeaponType.png'
      : 'assets/images/character/run_right.png';

  Future<void> _loadEquippedWeapon() async {
    try {
      final items = await GameApiService.fetchInventoryItems();
      final equippedWeapons = items.where(
        (item) => item.isEquipped && item.itemTemplate.isWeapon,
      );
      if (!mounted) return;
      setState(() {
        _equippedWeaponType = equippedWeapons.isEmpty
            ? ''
            : equippedWeapons.first.itemTemplate.weaponType;
      });
    } catch (_) {
      // Keep the default character sprite if equipment cannot be loaded.
    }
  }

  Future<void> _loadAppSettings() async {
    final settings = await AppSettingsService.load();
    if (!mounted) return;
    _applyAppSettings(settings);
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    _applyAppSettings(AppSettingsService.notifier.value);
  }

  void _applyAppSettings(AppSettingsData settings) {
    final previousAsset = _homeBgAsset;
    setState(() {
      _appSettings = settings;
    });
    if (settings.powerSavingMode) {
      if (_bgController.isAnimating) _bgController.stop();
    } else if (!_bgController.isAnimating) {
      _bgController.repeat();
    }
    final nextAsset = _homeBgAsset;
    if (nextAsset != previousAsset) {
      _loadBgAspectRatio(nextAsset);
    }
  }

  void _loadBgAspectRatio([String? assetPath]) {
    final image = AssetImage(assetPath ?? _homeBgAsset);
    image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (mounted) {
              setState(() {
                _bgAspectRatio = info.image.width / info.image.height;
              });
            }
          }),
        );
  }

  Future<void> _loadHomeBackgroundState() async {
    try {
      final stages = await BattleApiService.fetchNormalStages();
      final chapter2Unlocked =
          stages.any((stage) => stage.stageNo >= 6 && stage.isUnlocked) ||
          stages.any((stage) => stage.stageNo == 5 && stage.isCleared);
      if (!mounted || chapter2Unlocked == _chapter2HomeBgUnlocked) return;
      final previousAsset = _homeBgAsset;
      setState(() {
        _chapter2HomeBgUnlocked = chapter2Unlocked;
      });
      final nextAsset = _homeBgAsset;
      if (nextAsset != previousAsset) {
        _loadBgAspectRatio(nextAsset);
      }
    } catch (_) {
      // Keep the current background if stage state cannot be refreshed.
    }
  }

  void _returnHomeFromRoute() {
    if (!mounted) return;
    setState(() => _currentNavIndex = 2);
    _loadHomeBackgroundState();
    _loadEquippedWeapon();
  }

  @override
  void dispose() {
    _stepTracker.removeListener(_onStepTrackerChanged);
    _stepTracker.dispose();
    _bgController.dispose();
    AppSettingsService.notifier.removeListener(_onAppSettingsChanged);
    _gs.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onStepTrackerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadUserName() async {
    if (mounted) {
      setState(() {
        _profileLoading = true;
        _profileError = null;
      });
    }
    try {
      await AuthService.fetchMainMessage(); // 토큰 갱신 + name sync
      final name = await AuthService.getSavedName();
      if (mounted) {
        setState(() {
          _userName = name ?? '모험가';
          _profileLoading = false;
        });
      }
    } catch (e) {
      final token = await AuthService.getSavedToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      final name = await AuthService.getSavedName();
      if (mounted) {
        setState(() {
          _userName = name ?? '모험가';
          _profileError = e.toString();
          _profileLoading = false;
        });
      }
    }
  }

  Future<List<UserMission>> _loadMissions() async {
    setState(() {
      _missionLoading = true;
      _missionError = null;
    });
    try {
      final missions = await GameApiService.fetchUserMissions();
      if (!mounted) return missions;
      setState(() {
        _missions = missions;
        _missionLoading = false;
      });
      return missions;
    } catch (e) {
      if (!mounted) return const [];
      setState(() {
        _missionError = e.toString();
        _missionLoading = false;
      });
      return const [];
    }
  }

  Future<MissionClaimResult> _claimMission(String userMissionId) async {
    final result = await GameApiService.claimMission(userMissionId);
    try {
      await AuthService.fetchMainMessage();
    } catch (_) {
      // 보상 수령은 이미 성공했으므로 홈 메시지 갱신 실패는 수령 실패로 취급하지 않는다.
    }
    return result;
  }

  void _showSnackBar(String message) {
    showGameToast(context, message, type: GameToastType.error);
  }

  Future<void> _setPowerSavingMode(bool enabled) async {
    await AppSettingsService.save(
      _appSettings.copyWith(powerSavingMode: enabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final powerSaving = _appSettings.powerSavingMode;
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: powerSaving ? null : _buildBottomNav(),
      body: Stack(
        children: [
          if (powerSaving)
            const Positioned.fill(child: ColoredBox(color: Color(0xFF050505)))
          else
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final h = MediaQuery.of(context).size.height;
                final tileW = h * _bgAspectRatio;
                final offset = _bgController.value * tileW;
                return Stack(
                  children: [
                    Positioned(
                      left: -offset,
                      top: 0,
                      bottom: 0,
                      width: tileW,
                      child: child!,
                    ),
                    Positioned(
                      left: tileW - offset,
                      top: 0,
                      bottom: 0,
                      width: tileW,
                      child: child,
                    ),
                  ],
                );
              },
              child: Image.asset(
                _homeBgAsset,
                key: ValueKey(_homeBgAsset),
                fit: BoxFit.fill,
              ),
            ),
          if (powerSaving)
            SafeArea(child: _buildHomePowerSavingView())
          else
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(),
                  SizedBox(height: _currentNavIndex == 0 ? 10 : 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildMainContent(),
                    ),
                  ),
                ],
              ),
            ),
          if (!powerSaving)
            Positioned(
              bottom: 88,
              left: 0,
              right: 0,
              child: Center(
                child: WalkingCharacter(spritePath: _homeRunSprite),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomePowerSavingView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.battery_saver,
                color: Color(0xFFFFD15C),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '절전 모드',
                  style: TextStyle(
                    color: Color(0xFFFFD15C),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _powerSavingTextButton('종료', () => _setPowerSavingMode(false)),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF5C3A1E), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '걸음 추적 유지 중',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _powerSavingStatusRow(
                      '상태',
                      _stepTracker.statusLabel,
                      maxLines: 2,
                    ),
                    _powerSavingStatusRow('공격권', '${_gs.attackCountBalance}회'),
                    _powerSavingStatusRow(
                      '보스 조각',
                      '${_gs.bossTicketFragments}개',
                    ),
                    _powerSavingStatusRow('레벨', 'LV.${_gs.level}'),
                  ],
                ),
              ),
            ),
          ),
          const Text(
            '화면 효과와 배경 애니메이션을 줄이고 걷기 보상만 유지합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _powerSavingStatusRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _powerSavingTextButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1B10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD15C), width: 1.4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFD15C),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 프레임 + 닉네임 (각각 독립)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _openCharacterStatsDialog,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPlayerProfileBlock(),
                const SizedBox(width: 8),
                _buildFloatingName(),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCoinCard(),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildQuestButton(),
                  const SizedBox(width: 6),
                  const GameTopActions(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProfileFrame() {
    return Stack(
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
            Icons.person, // 임시 아이콘
            size: 24,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerProfileBlock() {
    return PlayerProfileWithLevel(
      level: _gs.level,
      exp: _gs.exp,
      expToNext: _gs.expToNextLevel,
    );
  }

  Widget _buildFloatingName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF6B3A1F), width: 1),
          ),
          child: Text(
            'LV.${_gs.level}  XP ${_gs.exp}/${_gs.expToNextLevel}',
            style: const TextStyle(
              color: Color(0xFFBFF4FF),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
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
      ],
    );
  }

  Widget _buildCoinCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
      ),
      child: Row(
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
    );
  }

  Widget _buildQuestButton() {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (_) => _QuestDetailDialog(
          missions: _missions,
          isLoading: _missionLoading,
          error: _missionError,
          onClaim: _claimMission,
          onRefresh: _loadMissions,
        ),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
        ),
        padding: const EdgeInsets.all(6),
        child: Image.asset(
          'assets/images/icon/quest_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  void _openCharacterStatsDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) =>
          CharacterStatsDialog(userName: _userName, level: _gs.level),
    );
  }

  Widget _buildMainContent() {
    switch (_currentNavIndex) {
      // case 0·1: 탭 누르면 push 이동이라 _currentNavIndex가 0·1로 바뀌지 않음 — 실제로 도달 불가
      case 0:
        return const SizedBox.shrink();
      case 2:
        return Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _buildChapterProgress(),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        );
      case 3:
        return const _SimpleTabMessage(message: '전투 화면 준비중');
      case 4:
        return const RaidListPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChapterProgress() {
    final dailyMissions = _dailyMissions();
    final progress = _dailyQuestProgress(dailyMissions);
    final completedCount = dailyMissions
        .where((mission) => mission.isClaimed || mission.progress >= 1.0)
        .length;
    final nextMission = _nextDailyMission(dailyMissions);

    return FractionallySizedBox(
      widthFactor: 0.86,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF080403).withValues(alpha: 0.94),
          border: Border.all(color: const Color(0xFF000000), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF202638).withValues(alpha: 0.96),
            border: Border.all(color: const Color(0xFFE2B24A), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_profileLoading || _profileError != null) ...[
                _buildConnectionBanner(),
                const SizedBox(height: 8),
              ],
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF111521),
                  border: Border.all(color: const Color(0xFF090A0F), width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      color: const Color(0xFFFFD15B),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '일일 퀘스트',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFFFE19A),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              color: Color(0xFF000000),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              _PixelProgressBar(value: progress),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _dailyQuestSummaryText(
                    dailyMissions: dailyMissions,
                    completedCount: completedCount,
                    nextMission: nextMission,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE4DEC7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 23,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111521),
                        border: Border.all(
                          color: const Color(0xFF3A4962),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '공격 횟수 ${_gs.attackCountBalance}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFC7D6E6),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 23,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07090E),
                      border: Border.all(
                        color: const Color(0xFF6B5130),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _missionLoading ? 'LOAD' : 'READY',
                      style: const TextStyle(
                        color: Color(0xFFFFD15B),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final isError = _profileError != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFF7A1A1A).withValues(alpha: 0.82)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFF9A9A) : Colors.white24,
        ),
      ),
      child: Row(
        children: [
          if (_profileLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _profileLoading
                  ? '서버에서 캐릭터 정보를 불러오는 중입니다.'
                  : '서버 정보를 새로 불러오지 못했습니다. 저장된 정보로 표시 중입니다.',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          if (isError)
            TextButton(
              onPressed: _loadUserName,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('다시 시도'),
            ),
        ],
      ),
    );
  }

  List<UserMission> _dailyMissions() {
    return _missions
        .where((mission) => mission.missionType != 'weekly')
        .toList(growable: false);
  }

  double _dailyQuestProgress(List<UserMission> dailyMissions) {
    if (dailyMissions.isEmpty) return 0;
    final totalProgress = dailyMissions.fold<double>(
      0,
      (sum, mission) => sum + mission.progress,
    );
    return (totalProgress / dailyMissions.length).clamp(0.0, 1.0).toDouble();
  }

  UserMission? _nextDailyMission(List<UserMission> dailyMissions) {
    for (final mission in dailyMissions) {
      if (!mission.isClaimed && mission.progress < 1.0) {
        return mission;
      }
    }
    return null;
  }

  String _dailyQuestSummaryText({
    required List<UserMission> dailyMissions,
    required int completedCount,
    required UserMission? nextMission,
  }) {
    if (_missionLoading) return '퀘스트 불러오는 중';
    if (_missionError != null) return '퀘스트 불러오기 실패';
    if (dailyMissions.isEmpty) return '일일 퀘스트 없음';
    if (nextMission == null) {
      return '완료 $completedCount/${dailyMissions.length} · 모두 달성';
    }
    return '완료 $completedCount/${dailyMissions.length} · ${nextMission.title} ${nextMission.progressValue.toInt()}/${nextMission.targetValue.toInt()}${nextMission.unit}';
  }

  Widget _buildPageFadeTransition(Animation<double> opacity, Widget child) {
    return ColoredBox(
      color: const Color(0xFF100B08),
      child: FadeTransition(opacity: opacity, child: child),
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
      currentIndex: _currentNavIndex,
      onTap: (item) async {
        if (item.index == 0) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, _, _) => const ShopPage(),
              transitionsBuilder: (context, animation, _, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                );
                return _buildPageFadeTransition(curved, child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).then((_) => _returnHomeFromRoute());
        } else if (item.index == 1) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, _, _) => const InventoryPage(),
              transitionsBuilder: (context, animation, _, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                );
                return _buildPageFadeTransition(curved, child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).then((_) => _returnHomeFromRoute());
        } else if (item.index == 4) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, _, _) => const RaidListPage(),
              transitionsBuilder: (context, animation, _, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                );
                return _buildPageFadeTransition(curved, child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).then((_) => _returnHomeFromRoute());
        } else if (item.index == 3) {
          if (_stepTracker.isTracking) {
            await _stepTracker.stop();
            if (!mounted) return;
          }
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, _, _) => const BattleStagePage(),
              transitionsBuilder: (context, animation, _, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                );
                return _buildPageFadeTransition(curved, child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).then((_) => _returnHomeFromRoute());
        } else {
          setState(() => _currentNavIndex = item.index);
        }
      },
    );
  }
}

class _PixelProgressBar extends StatelessWidget {
  final double value;

  const _PixelProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final activeSegments = (value.clamp(0.0, 1.0) * 12).round();

    return Container(
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF05070B),
        border: Border.all(color: const Color(0xFF000000), width: 2),
      ),
      child: Row(
        children: List.generate(12, (index) {
          final isActive = index < activeSegments;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 11 ? 0 : 2),
              child: Container(
                color: isActive
                    ? const Color(0xFF4DA6FF)
                    : const Color(0xFF202634),
                child: isActive
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: 3,
                          color: const Color(0xFF9AD7FF),
                        ),
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _QuestDetailDialog extends StatefulWidget {
  final List<UserMission> missions;
  final bool isLoading;
  final String? error;
  final Future<MissionClaimResult> Function(String userMissionId) onClaim;
  final Future<List<UserMission>> Function() onRefresh;

  const _QuestDetailDialog({
    required this.missions,
    required this.isLoading,
    required this.error,
    required this.onClaim,
    required this.onRefresh,
  });

  @override
  State<_QuestDetailDialog> createState() => _QuestDetailDialogState();
}

class _QuestDetailDialogState extends State<_QuestDetailDialog> {
  bool _isClaiming = false;
  int _selectedQuestTab = 0;
  late List<UserMission> _missions;
  late bool _isLoading;
  String? _error;
  String? _claimMessage;
  bool _claimMessageSuccess = true;

  @override
  void initState() {
    super.initState();
    _missions = widget.missions;
    _isLoading = widget.isLoading;
    _error = widget.error;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
              child: Row(
                children: [
                  const Text(
                    '퀘스트',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isClaiming ? null : _refresh,
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF6B3A1F), height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: Color(0xFFF0C040)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refresh, child: const Text('다시 불러오기')),
          ],
        ),
      );
    }
    if (_missions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('진행 중인 미션이 없습니다.', style: TextStyle(color: Colors.white54)),
      );
    }
    final dailyMissions = _missions
        .where((mission) => mission.missionType != 'weekly')
        .toList();
    final weeklyMissions = _missions
        .where((mission) => mission.missionType == 'weekly')
        .toList();
    final selectedMissions = _selectedQuestTab == 0
        ? dailyMissions
        : weeklyMissions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuestTabBar(),
        if (_claimMessage != null) _buildClaimNotice(),
        Flexible(
          child: selectedMissions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    _selectedQuestTab == 0 ? '일일 퀘스트가 없습니다.' : '주간 퀘스트가 없습니다.',
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: selectedMissions.map(_buildQuestItem).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildClaimNotice() {
    final color = _claimMessageSuccess
        ? const Color(0xFFF0C040)
        : const Color(0xFFFF6B5A);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Icon(
            _claimMessageSuccess ? Icons.payments : Icons.error_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _claimMessage!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          _buildQuestTabButton('일일', 0),
          const SizedBox(width: 6),
          _buildQuestTabButton('주간', 1),
        ],
      ),
    );
  }

  Widget _buildQuestTabButton(String label, int index) {
    final isActive = _selectedQuestTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedQuestTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6B2F12) : const Color(0xFF221512),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF6B3A1F), width: 1.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF8A735A),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final missions = await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        _missions = missions;
        _isLoading = false;
        _claimMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _claim(UserMission mission) async {
    if (_isClaiming || !mission.canClaim) return;
    setState(() {
      _isClaiming = true;
      _claimMessage = null;
    });
    try {
      final result = await widget.onClaim(mission.id);
      final missions = await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        _missions = missions;
        _isClaiming = false;
        _claimMessageSuccess = true;
        _claimMessage = result.rewardCoin > 0
            ? '${mission.title} 보상 +${result.rewardCoin} 골드 획득'
            : '${mission.title} 보상을 수령했습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isClaiming = false;
        _claimMessageSuccess = false;
        _claimMessage = e.toString();
      });
    }
  }

  Widget _buildQuestItem(UserMission mission) {
    final isDone = mission.progress >= 1.0;
    final isClaimed = mission.isClaimed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone
              ? const Color(0xFFF0C040).withValues(alpha: 0.5)
              : Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  style: TextStyle(
                    color: isDone ? const Color(0xFFF0C040) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (mission.canClaim)
                GestureDetector(
                  onTap: () => _claim(mission),
                  child: _QuestBadge(
                    label: _isClaiming ? '처리 중' : '수령하기',
                    active: true,
                  ),
                )
              else if (isClaimed)
                const _QuestBadge(label: '수령 완료', active: false)
              else
                Row(
                  children: [
                    Image.asset(
                      'assets/images/icon/coin_icon.png',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${mission.rewardCoin}',
                      style: const TextStyle(
                        color: Color(0xFFF0C040),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: mission.progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDone
                          ? const Color(0xFFF0C040)
                          : const Color(0xFF4DA6FF),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${mission.progressValue.toInt()}/${mission.targetValue.toInt()}${mission.unit}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _QuestBadge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFF0C040).withValues(alpha: 0.2)
            : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFFF0C040) : Colors.white24,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFFF0C040) : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SimpleTabMessage extends StatelessWidget {
  const _SimpleTabMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}

class WalkingCharacter extends StatefulWidget {
  final String spritePath;

  const WalkingCharacter({super.key, required this.spritePath});

  @override
  State<WalkingCharacter> createState() => _WalkingCharacterState();
}

class _WalkingCharacterState extends State<WalkingCharacter>
    with SingleTickerProviderStateMixin {
  static const double _scale = 4.0;
  static const double _frameWidth = 80.0 * _scale;
  static const double _frameHeight = 80.0 * _scale;
  static const int _totalFrames = 8;

  late AnimationController _controller;
  int _currentFrame = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 800),
          )
          ..addListener(() {
            final frame =
                (_controller.value * _totalFrames).floor() % _totalFrames;
            if (frame != _currentFrame) {
              setState(() => _currentFrame = frame);
            }
          })
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _frameWidth,
      height: _frameHeight,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(-_currentFrame * _frameWidth, 0),
          child: OverflowBox(
            maxWidth: _frameWidth * _totalFrames,
            maxHeight: _frameHeight,
            alignment: Alignment.topLeft,
            child: Image.asset(
              widget.spritePath,
              width: _frameWidth * _totalFrames,
              height: _frameHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }
}
