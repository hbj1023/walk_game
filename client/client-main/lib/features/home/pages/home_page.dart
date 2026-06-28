import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/step_tracking_controller.dart';
import 'package:capstone_app/features/social/widgets/friend_sheet.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/auth/pages/login_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String _userName = '...';
  int _currentNavIndex = 2;
  final _gs = GameState.instance;
  late final StepTrackingController _stepTracker;
  bool _isLoggingOut = false;

  late AnimationController _bgController;
  double _bgAspectRatio = 2.0; // 이미지 로드 전 기본값

  bool _isDistanceAdding = false;
  bool _profileLoading = true;
  String? _profileError;
  bool _missionLoading = true;
  String? _missionError;
  List<UserMission> _missions = const [];

  @override
  void initState() {
    super.initState();
    _gs.addListener(_onGameStateChanged);
    _stepTracker = StepTrackingController.home(
      onSyncSteps: (request) => GameApiService.syncStepDelta(
        stepCount: request.stepCount,
        strideM: request.strideM,
        gpsDistanceM: request.gpsDistanceM,
        abnormalReason: request.abnormalReason,
      ),
      onSyncSuccess: (_, _) => _loadMissions(),
      onStartError: (error) => _showSnackBar(error.toString()),
      onSyncError: (error) => _showSnackBar(error.toString()),
    )..addListener(_onStepTrackerChanged);
    _loadUserName();
    _loadMissions();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _loadBgAspectRatio();
  }

  void _loadBgAspectRatio() {
    const image = AssetImage('assets/images/bg/home_bg.png');
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

  @override
  void dispose() {
    _stepTracker.removeListener(_onStepTrackerChanged);
    _stepTracker.dispose();
    _bgController.dispose();
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

  Future<void> _claimMission(String userMissionId) async {
    try {
      await GameApiService.claimMission(userMissionId);
      await AuthService.fetchMainMessage();
      await _loadMissions();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('미션 보상을 수령했습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openDistanceAddDialog() async {
    final controller = TextEditingController(text: '100');
    final distanceM = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이동거리 추가'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '이동 거리(m)',
            helperText: '입력한 이동거리를 서버에 누적 반영합니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(dialogContext, value);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (distanceM == null || distanceM <= 0) return;

    setState(() => _isDistanceAdding = true);
    try {
      final result = await GameApiService.addDistanceDelta(
        distanceM: distanceM,
      );
      await _loadMissions();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '이동거리 ${result.deltaDistanceM}m가 추가되었습니다. 공격 횟수 ${result.attackCountBalance}회',
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isDistanceAdding = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
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
              'assets/images/bg/home_bg.png',
              fit: BoxFit.fill,
            ),
          ),
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
          const Positioned(
            bottom: 88,
            left: 0,
            right: 0,
            child: Center(child: WalkingCharacter()),
          ),
        ],
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileFrame(),
              const SizedBox(width: 8),
              _buildFloatingName(),
            ],
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
                  _buildFriendButton(),
                  const SizedBox(width: 6),
                  _buildSettingsButton(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildFloatingName() {
    return Text(
      _userName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 1)),
        ],
      ),
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

  Widget _buildFriendButton() {
    return GestureDetector(
      onTap: _openFriendSheet,
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
          'assets/images/icon/friend_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: _isLoggingOut ? null : _openSettingsDialog,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
        ),
        child: Icon(
          Icons.settings,
          size: 22,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  void _openFriendSheet() {
    showDialog(context: context, builder: (context) => const FriendSheet());
  }

  void _openSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.pop(dialogContext);
                  _confirmLogout();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4A0E0E),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '로그아웃',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await _logout();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);
    try {
      await AuthService.logout();
      _gs.setCoins(0);
      _gs.setAttackCountBalance(0);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
      setState(() => _isLoggingOut = false);
    }
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_profileLoading || _profileError != null) ...[
              _buildConnectionBanner(),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '일일 퀘스트',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade800,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4DA6FF),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _dailyQuestSummaryText(
                dailyMissions: dailyMissions,
                completedCount: completedCount,
                nextMission: nextMission,
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '공격 횟수: ${_gs.attackCountBalance}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _stepTracker.statusLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                _buildProgressActionButton(
                  label: _stepTracker.isTracking
                      ? '걸음 추적 중지'
                      : (_stepTracker.isStarting ? '준비 중...' : '걸음 추적 시작'),
                  onTap: (_stepTracker.isStarting || _stepTracker.isSyncing)
                      ? null
                      : _stepTracker.toggle,
                  color: _stepTracker.isTracking
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF4DA6FF),
                ),
                _buildProgressActionButton(
                  label: _isDistanceAdding ? '추가 중...' : '이동거리 추가',
                  onTap: _isDistanceAdding ? null : _openDistanceAddDialog,
                  color: const Color(0xFF8F6BFF),
                ),
              ],
            ),
          ],
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

  Widget _buildProgressActionButton({
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? color : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white38,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildPageFadeTransition(Animation<double> opacity, Widget child) {
    return ColoredBox(
      color: const Color(0xFF100B08),
      child: FadeTransition(opacity: opacity, child: child),
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
          final isSelected = _currentNavIndex == item.index;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
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
                  ).then((_) => setState(() => _currentNavIndex = 2));
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
                  ).then((_) => setState(() => _currentNavIndex = 2));
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
                  ).then((_) => setState(() => _currentNavIndex = 2));
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
                  ).then((_) => setState(() => _currentNavIndex = 2));
                } else {
                  setState(() => _currentNavIndex = item.index);
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
                        color: isSelected
                            ? const Color(0xFFF0C040)
                            : Colors.white38,
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
}

class _QuestDetailDialog extends StatefulWidget {
  final List<UserMission> missions;
  final bool isLoading;
  final String? error;
  final Future<void> Function(String userMissionId) onClaim;
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
    setState(() => _isClaiming = true);
    await widget.onClaim(mission.id);
    if (mounted) Navigator.pop(context);
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

class WalkingCharacter extends StatefulWidget {
  const WalkingCharacter({super.key});

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
              'assets/images/character/run_right.png',
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
