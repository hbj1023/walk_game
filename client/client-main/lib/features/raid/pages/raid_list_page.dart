import 'dart:async';

import 'package:flutter/material.dart';

import 'package:capstone_app/models/raid_boss.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/friendship_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/profile_icon_service.dart';
import 'package:capstone_app/features/social/widgets/friend_sheet.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_lobby_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';
import 'package:capstone_app/widgets/character_stats_panel.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';
import 'package:capstone_app/widgets/pixel_bottom_nav.dart';

// ─── 색상 상수 ────────────────────────────────────────────────────────────────

const _kCardBg = Color(0xFF1A1A1A);
const _kCardBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFF0C040);
const _kRedStar = Color(0xFFE03030);
const _kRaidMinimumLevel = 5;

// ─── RaidListPage ─────────────────────────────────────────────────────────────

class RaidListPage extends StatefulWidget {
  const RaidListPage({super.key});

  @override
  State<RaidListPage> createState() => _RaidListPageState();
}

class _RaidListPageState extends State<RaidListPage> {
  int _selectedIndex = 0;
  String _userName = '...';
  List<RaidBoss> _bosses = const [];
  bool _loadingBosses = true;
  bool _startingRaid = false;
  bool _loadingInvitations = true;
  List<RaidInvitationInfo> _invitations = const [];
  String? _bossError;
  String? _invitationError;
  final _gs = GameState.instance;

  RaidBoss? get _selectedBoss {
    if (_bosses.isEmpty) return null;
    final index = _selectedIndex.clamp(0, _bosses.length - 1).toInt();
    return _bosses[index];
  }

  @override
  void initState() {
    super.initState();
    _gs.addListener(_onGameStateChanged);
    unawaited(ProfileIconService.loadIntoGameState());
    _loadUserName();
    _loadRaidBosses();
    _loadRaidInvitations();
  }

  @override
  void dispose() {
    _gs.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getSavedName();
    if (mounted) setState(() => _userName = name ?? '모험가');
  }

  Future<void> _loadRaidBosses() async {
    setState(() {
      _loadingBosses = true;
      _bossError = null;
    });
    try {
      final monsters = await GameApiService.fetchRaidMonsters();
      if (!mounted) return;
      setState(() {
        _bosses = monsters.map(RaidBoss.fromMonster).toList()
          ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
        _selectedIndex = _bosses.isEmpty
            ? 0
            : _selectedIndex.clamp(0, _bosses.length - 1).toInt();
        _loadingBosses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bosses = const [];
        _bossError = e.toString();
        _loadingBosses = false;
      });
    }
  }

  Future<void> _loadRaidInvitations() async {
    setState(() {
      _loadingInvitations = true;
      _invitationError = null;
    });
    try {
      final invitations = await GameApiService.fetchRaidInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = invitations.where((invite) => invite.isPending).toList();
        _loadingInvitations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invitationError = e.toString();
        _loadingInvitations = false;
      });
    }
  }

  Future<void> _startRaid(List<FriendUser> party) async {
    final boss = _selectedBoss;
    if (boss == null || boss.id.isEmpty) {
      _showMessage('레이드 보스 정보를 불러온 뒤 다시 시도해주세요.');
      return;
    }
    if (_startingRaid) return;

    setState(() => _startingRaid = true);
    try {
      final created = await GameApiService.createRaid(
        monsterId: boss.id,
        title: '${boss.name} 레이드',
        description: party.isEmpty ? '솔로 레이드' : '친구 초대 레이드',
      );

      final failedInvites = <String>[];
      for (final friend in party) {
        try {
          await GameApiService.inviteRaidFriend(
            raidId: created.raid.id,
            invitedUserId: friend.id,
          );
        } catch (_) {
          failedInvites.add(friend.displayName);
        }
      }

      final lobby = await GameApiService.fetchRaidProgress(created.raid.id);
      if (!mounted) return;
      Navigator.pop(context);
      if (failedInvites.isNotEmpty) {
        _showMessage('초대 실패: ${failedInvites.join(', ')}');
      }
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, _) => RaidLobbyPage(
            boss: boss,
            raidId: lobby.raid.id,
            initialSummary: lobby,
            invitedPartySize: party.length + 1,
          ),
          transitionsBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            return FadeTransition(opacity: curved, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      if (mounted) {
        _loadRaidInvitations();
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _startingRaid = false);
    }
  }

  Future<void> _acceptInvitation(RaidInvitationInfo invitation) async {
    if (_gs.level < _kRaidMinimumLevel) {
      _showMessage('레이드는 $_kRaidMinimumLevel레벨부터 입장할 수 있습니다.');
      return;
    }
    try {
      final summary = await GameApiService.acceptRaidInvitation(invitation.id);
      if (!mounted) return;
      final monster = summary.monster ?? invitation.monster;
      final boss = monster != null
          ? RaidBoss.fromMonster(monster)
          : RaidBoss(
              id: summary.raid.monsterId,
              name: summary.raid.title.isEmpty ? '레이드 보스' : summary.raid.title,
              recommendedLevel: _kRaidMinimumLevel,
              difficulty: 1,
              isLocked: false,
              bgPath: 'assets/images/bg/raid_forest.png',
              iconPath: 'assets/images/raid/ic_boss_goblin.png',
            );
      _loadRaidInvitations();
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, _) => RaidLobbyPage(
            boss: boss,
            raidId: summary.raid.id,
            initialSummary: summary,
            invitedPartySize: summary.participantCount,
          ),
          transitionsBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            return FadeTransition(opacity: curved, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString());
        _loadRaidInvitations();
      }
    }
  }

  Future<void> _declineInvitation(RaidInvitationInfo invitation) async {
    try {
      await GameApiService.declineRaidInvitation(invitation.id);
      if (!mounted) return;
      _showMessage('레이드 초대를 거절했습니다.');
      _loadRaidInvitations();
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openFriendDialog() {
    showDialog(context: context, builder: (_) => const FriendSheet());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg/home_bg.png',
              fit: BoxFit.cover,
              alignment: const Alignment(
                -0.9,
                0.0,
              ), // x: -1.0(좌)~1.0(우), y: -1.0(상)~1.0(하)
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildTitle(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Column(
                      children: [
                        _buildInvitationPanel(),
                        if (_loadingBosses)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(color: _kGold),
                          )
                        else if (_bossError != null)
                          _buildErrorPanel(
                            message: _bossError!,
                            onRetry: _loadRaidBosses,
                          )
                        else if (_bosses.isEmpty)
                          _buildEmptyPanel('도전 가능한 레이드 보스가 없습니다.')
                        else
                          ...List.generate(
                            _bosses.length,
                            (i) => _buildBossCard(i),
                          ),
                        _buildPartyButton(),
                        const SizedBox(height: 88),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 상단 HUD ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              // 코인
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
              ),
              const SizedBox(height: 6),
              // 친구 버튼
              GestureDetector(
                onTap: _openFriendDialog,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF6B3A1F),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/icon/friend_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 타이틀 ───────────────────────────────────────────────────────────────

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

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        children: [
          const Text(
            '✦ 레이드 ✦',
            style: TextStyle(
              color: Color(0xFFCC1111),
              fontSize: 28,
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
          const SizedBox(height: 4),
          Text(
            '강력한 레이드 몬스터에 도전하고 특별한 보상을 획득하세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
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

  Widget _buildInvitationPanel() {
    if (_loadingInvitations) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kGold),
            ),
            SizedBox(width: 10),
            Text(
              '레이드 초대 확인 중',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_invitationError != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7A1A1A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mail_outline, color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '초대장을 불러오지 못했습니다.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: _loadRaidInvitations,
              child: const Text(
                '재시도',
                style: TextStyle(color: _kGold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    if (_invitations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF142238).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A5AA0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail, color: Color(0xFF4DA6FF), size: 18),
              const SizedBox(width: 8),
              Text(
                '레이드 초대 ${_invitations.length}개',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadRaidInvitations,
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._invitations.take(3).map(_buildInvitationTile),
        ],
      ),
    );
  }

  Widget _buildInvitationTile(RaidInvitationInfo invitation) {
    final raidTitle = invitation.raid?.title ?? '';
    final monsterName = invitation.monster?.name ?? raidTitle;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monsterName.isEmpty ? '레이드 초대' : monsterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  '${invitation.inviterLabel}님의 초대',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _declineInvitation(invitation),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '거절',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _acceptInvitation(invitation),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A7A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2A5AA0)),
              ),
              child: const Text(
                '입장',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7A1A1A), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              '다시 불러오기',
              style: TextStyle(color: _kGold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPanel(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }

  // ─── 보스 카드 ────────────────────────────────────────────────────────────

  Widget _buildBossCard(int index) {
    final boss = _bosses[index];
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (!boss.isLocked) setState(() => _selectedIndex = index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _kGold : _kCardBorder,
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBossImage(boss),
              Expanded(child: _buildBossInfo(boss)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBossImage(RaidBoss boss) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
      child: SizedBox(
        width: 110,
        height: 120,
        child: boss.iconPath != null
            ? Image.asset(
                boss.iconPath!,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Container(
                  color: const Color(0xFF2A2A3A),
                  child: const Icon(
                    Icons.help_outline,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              )
            : Container(
                color: const Color(0xFF2A2A3A),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
      ),
    );
  }

  Widget _buildBossInfo(RaidBoss boss) {
    final isRed = boss.isLocked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            boss.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          _buildDifficultyRow(boss.difficulty, isRed),
          const SizedBox(height: 5),
          Text(
            '입장 기준 LV.${boss.recommendedLevel}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusRow(boss),
        ],
      ),
    );
  }

  Widget _buildDifficultyRow(int difficulty, bool redStar) {
    return Row(
      children: [
        Image.asset('assets/images/icon/battle.png', width: 13, height: 13),
        const SizedBox(width: 4),
        const Text(
          '난이도',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(3, (i) {
            final filled = i < difficulty;
            return Icon(
              filled ? Icons.star : Icons.star_border,
              size: 16,
              color: filled ? (redStar ? _kRedStar : _kGold) : Colors.white30,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatusRow(RaidBoss boss) {
    if (_gs.level < boss.recommendedLevel) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, color: Colors.red, size: 13),
            const SizedBox(width: 4),
            Text(
              'LV.${boss.recommendedLevel}부터 입장 가능',
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ],
        ),
      );
    }
    if (boss.isLocked) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, color: Colors.red, size: 13),
            SizedBox(width: 4),
            Text(
              '잠금 — 이전 레이드를 클리어하세요.',
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A1A),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: const Row(
        children: [
          Icon(Icons.circle, color: Colors.green, size: 10),
          SizedBox(width: 6),
          Text('도전 가능', style: TextStyle(color: Colors.white, fontSize: 12)),
          Spacer(),
          Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        ],
      ),
    );
  }

  // ─── 파티 구성 버튼 ──────────────────────────────────────────────────────

  void _openPartySheet() {
    final boss = _selectedBoss;
    if (boss == null) {
      _showMessage('레이드 보스 정보를 불러오는 중입니다.');
      return;
    }
    if (_gs.level < _kRaidMinimumLevel) {
      _showMessage('레이드는 $_kRaidMinimumLevel레벨부터 입장할 수 있습니다.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartySheet(boss: boss, onEnter: _startRaid),
    );
  }

  Widget _buildPartyButton() {
    final boss = _selectedBoss;
    final levelLocked = _gs.level < _kRaidMinimumLevel;
    final locked =
        boss == null ||
        boss.isLocked ||
        levelLocked ||
        _loadingBosses ||
        _startingRaid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: GestureDetector(
        onTap: locked ? null : _openPartySheet,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: locked ? Colors.grey[700] : const Color(0xFF1A3A7A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: locked ? Colors.grey[600]! : const Color(0xFF2A5AA0),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _startingRaid
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.group, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Text(
                _startingRaid
                    ? '레이드 생성 중'
                    : levelLocked
                    ? '입장 Lv.$_kRaidMinimumLevel 필요'
                    : '파티 구성',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 하단 네비게이션바 ────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
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
      currentIndex: 4,
      onTap: (item) async => _navigateBottom(item.index),
    );
  }

  void _navigateBottom(int index) {
    Widget? page;
    switch (index) {
      case 0:
        page = const ShopPage();
        break;
      case 1:
        page = const InventoryPage();
        break;
      case 2:
        page = const HomePage();
        break;
      case 3:
        page = const BattleStagePage();
        break;
      case 4:
        return;
    }
    if (page == null) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => page!,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _PartySheet extends StatefulWidget {
  final RaidBoss boss;
  final Future<void> Function(List<FriendUser> party) onEnter;

  const _PartySheet({required this.boss, required this.onEnter});

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
  List<FriendshipRecord> _friends = const [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _entering = false;
  String? _error;
  String? _currentUserId;

  static const int _maxPartySize = 3; // 본인 포함 최대 4인

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUserId = await FriendshipService.currentUserId();
      final friends = await FriendshipService.fetchFriends();
      if (!mounted) return;
      setState(() {
        _currentUserId = currentUserId;
        _friends = friends;
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

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < _maxPartySize) {
        _selectedIds.add(id);
      }
    });
  }

  List<MapEntry<String, FriendUser>> _availableFriends() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const [];

    return _friends
        .where((record) => !_selectedIds.contains(record.id))
        .map((record) => MapEntry(record.id, record.otherUser(currentUserId)))
        .toList();
  }

  void _openFriendPicker() {
    if (_loading) {
      _showPartyMessage('친구 목록을 불러오는 중입니다.');
      return;
    }
    if (_error != null) {
      _showPartyMessage('친구 목록을 불러오지 못했습니다. 다시 시도해주세요.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerContext) => _buildFriendPickerSheet(pickerContext),
    );
  }

  void _addFriendFromPicker(BuildContext pickerContext, String friendshipId) {
    if (_selectedIds.length >= _maxPartySize) {
      Navigator.pop(pickerContext);
      _showPartyMessage('파티가 이미 가득 찼습니다.');
      return;
    }

    setState(() => _selectedIds.add(friendshipId));
    Navigator.pop(pickerContext);
  }

  void _showPartyMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enterRaid(List<MapEntry<String, FriendUser>> selected) async {
    if (_entering) return;
    setState(() => _entering = true);
    try {
      await widget.onEnter(selected.map((entry) => entry.value).toList());
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;
    final selectedFriends = currentUserId == null
        ? <MapEntry<String, FriendUser>>[]
        : _friends
              .where((record) => _selectedIds.contains(record.id))
              .map(
                (record) =>
                    MapEntry(record.id, record.otherUser(currentUserId)),
              )
              .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF2A5AA0), width: 2),
          left: BorderSide(color: Color(0xFF2A5AA0), width: 2),
          right: BorderSide(color: Color(0xFF2A5AA0), width: 2),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.group, color: Color(0xFF4DA6FF), size: 22),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '파티 구성',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.boss.name} · 최대 ${_maxPartySize + 1}인 (본인 포함)',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _entering ? null : () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A3A4A), height: 1),
            _buildPartySlots(selectedFriends),
            const Divider(color: Color(0xFF2A3A4A), height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4DA6FF),
                        ),
                      ),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _loadFriends,
                            child: const Text(
                              '다시 시도',
                              style: TextStyle(
                                color: Color(0xFF4DA6FF),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _friends.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '친구 목록이 비어있어요',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '혼자서도 레이드에 입장할 수 있어요!',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _friends.length,
                      itemBuilder: (_, i) => _buildFriendTile(_friends[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: GestureDetector(
                onTap: _entering ? null : () => _enterRaid(selectedFriends),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4A0E0E),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _entering
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Image.asset(
                              'assets/images/icon/battle.png',
                              width: 24,
                              height: 24,
                            ),
                      const SizedBox(width: 8),
                      Text(
                        _entering
                            ? '레이드 생성 중'
                            : selectedFriends.isEmpty
                            ? '혼자 레이드 입장'
                            : '파티원 ${selectedFriends.length}명과 레이드 입장',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildPartySlots(List<MapEntry<String, FriendUser>> selected) {
    final totalSlots = _maxPartySize + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSlots, (i) {
          if (i == 0) {
            return _buildSlot(
              label: '나',
              icon: Icons.person,
              color: const Color(0xFF4DA6FF),
              isMe: true,
            );
          }
          final friendIndex = i - 1;
          if (friendIndex < selected.length) {
            final entry = selected[friendIndex];
            return _buildSlot(
              label: entry.value.displayName,
              icon: Icons.person,
              color: const Color(0xFFF0C040),
              onRemove: () => _toggle(entry.key),
            );
          }
          return _buildSlot(
            label: '대기중',
            icon: Icons.add,
            color: Colors.white24,
            isEmpty: true,
            onTap: _openFriendPicker,
          );
        }),
      ),
    );
  }

  Widget _buildSlot({
    required String label,
    required IconData icon,
    required Color color,
    bool isMe = false,
    bool isEmpty = false,
    VoidCallback? onTap,
    VoidCallback? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEmpty
                        ? Colors.white.withValues(alpha: 0.05)
                        : color.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isEmpty && onTap != null
                          ? const Color(0xFF4DA6FF).withValues(alpha: 0.55)
                          : (isEmpty ? Colors.white12 : color),
                      width: isEmpty ? 1 : 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isEmpty && onTap != null
                        ? const Color(0xFF4DA6FF).withValues(alpha: 0.7)
                        : (isEmpty ? Colors.white24 : color),
                    size: 26,
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF4D4D),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 60,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isEmpty
                      ? Colors.white24
                      : (isMe ? const Color(0xFF4DA6FF) : Colors.white70),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendPickerSheet(BuildContext pickerContext) {
    final availableFriends = _availableFriends();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(
          top: BorderSide(color: Color(0xFF2A5AA0), width: 2),
          left: BorderSide(color: Color(0xFF2A5AA0), width: 2),
          right: BorderSide(color: Color(0xFF2A5AA0), width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add,
                    color: Color(0xFF4DA6FF),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '친구 목록',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(pickerContext),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A3A4A), height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: _friends.isEmpty
                  ? _buildFriendPickerEmpty(
                      icon: Icons.people_outline,
                      title: '친구 목록이 비어있어요',
                      subtitle: '친구를 추가한 뒤 파티에 초대할 수 있어요.',
                    )
                  : availableFriends.isEmpty
                  ? _buildFriendPickerEmpty(
                      icon: Icons.check_circle_outline,
                      title: '추가할 친구가 없어요',
                      subtitle: '이미 모든 친구가 파티에 들어와 있습니다.',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: availableFriends.length,
                      itemBuilder: (_, i) {
                        final entry = availableFriends[i];
                        return _buildFriendPickerTile(
                          pickerContext,
                          friendshipId: entry.key,
                          friend: entry.value,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendPickerEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendPickerTile(
    BuildContext pickerContext, {
    required String friendshipId,
    required FriendUser friend,
  }) {
    return GestureDetector(
      onTap: () => _addFriendFromPicker(pickerContext, friendshipId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFFF0C040), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (friend.subtitle.isNotEmpty &&
                      friend.subtitle != friend.displayName)
                    Text(
                      friend.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF4DA6FF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(FriendshipRecord record) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return const SizedBox.shrink();

    final friend = record.otherUser(currentUserId);
    final selected = _selectedIds.contains(record.id);
    final atMax = _selectedIds.length >= _maxPartySize && !selected;
    return GestureDetector(
      onTap: atMax ? null : () => _toggle(record.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0C040).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: atMax ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFF0C040) : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: selected
                  ? const Color(0xFFF0C040)
                  : (atMax ? Colors.white24 : Colors.white54),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFF0C040)
                          : (atMax ? Colors.white24 : Colors.white),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (friend.subtitle.isNotEmpty &&
                      friend.subtitle != friend.displayName)
                    Text(
                      friend.subtitle,
                      style: TextStyle(
                        color: atMax ? Colors.white12 : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFFF0C040), size: 20)
            else if (atMax)
              const Text(
                '파티 가득참',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              )
            else
              const Icon(
                Icons.add_circle_outline,
                color: Colors.white38,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
