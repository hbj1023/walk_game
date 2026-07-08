import 'dart:async';

import 'package:flutter/material.dart';

import 'package:capstone_app/models/raid_boss.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/features/raid/pages/raid_battle_page.dart';
import 'package:capstone_app/widgets/profile_icon_catalog.dart';
import 'package:capstone_app/widgets/user_profile_avatar.dart';

const _kLobbyBg = Color(0xFF1A1008);
const _kLobbyBorder = Color(0xFF6B3A1F);
const _kLobbyGold = Color(0xFFF0C040);
const _kLobbyBlue = Color(0xFF4DA6FF);

class RaidLobbyPage extends StatefulWidget {
  final RaidBoss boss;
  final String raidId;
  final RaidProgressSummary initialSummary;
  final int invitedPartySize;

  const RaidLobbyPage({
    super.key,
    required this.boss,
    required this.raidId,
    required this.initialSummary,
    required this.invitedPartySize,
  });

  @override
  State<RaidLobbyPage> createState() => _RaidLobbyPageState();
}

class _RaidLobbyPageState extends State<RaidLobbyPage> {
  late RaidProgressSummary _summary = widget.initialSummary;
  String? _characterId;
  String? _error;
  bool _loading = false;
  bool _starting = false;
  bool _canceling = false;
  bool _leavingLobby = false;
  bool _routeExitAllowed = false;
  bool _raidCanceledDialogShown = false;
  bool _navigatingToBattle = false;
  Timer? _refreshTimer;

  List<RaidInvitationInfo> get _pendingInvitations =>
      _summary.invitations.where((invitation) => invitation.isPending).toList();

  bool get _hasPendingInvitations => _pendingInvitations.isNotEmpty;
  bool get _isHost => _characterId == _summary.raid.hostCharacterId;
  bool get _raidCanceled =>
      _summary.progress.status == 'canceled' ||
      _summary.raid.status == 'canceled';
  bool get _raidEnded =>
      _summary.progress.isFinished ||
      _summary.raid.status == 'ended' ||
      _summary.raid.status == 'canceled';
  int get _joinedParticipantCount => _summary.participants
      .where((participant) => participant.joinStatus == 'joined')
      .length;
  bool get _allPartyReady =>
      !_hasPendingInvitations &&
      _joinedParticipantCount > 0 &&
      _joinedParticipantCount == _summary.participants.length;

  @override
  void initState() {
    super.initState();
    _loadCharacterId();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refresh(silent: true)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterBattleIfStarted(_summary);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCharacterId() async {
    try {
      final characterId = await GameApiService.requireCharacterId();
      if (mounted) setState(() => _characterId = characterId);
    } catch (_) {}
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await GameApiService.fetchRaidProgress(widget.raidId);
      if (!mounted) return;
      final wasCanceled = _raidCanceled;
      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
      });
      if (!wasCanceled && _raidCanceled && !_leavingLobby) {
        _showRaidCanceledDialog();
        return;
      }
      _enterBattleIfStarted(summary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _enterBattleIfStarted(RaidProgressSummary summary) {
    if (!mounted || _navigatingToBattle || _leavingLobby || _raidCanceled) {
      return;
    }
    final started =
        summary.progress.status == 'in_progress' ||
        summary.raid.status == 'in_progress';
    if (!started) return;
    _openBattle(summary);
  }

  void _openBattle(RaidProgressSummary summary) {
    if (!mounted || _navigatingToBattle) return;
    _navigatingToBattle = true;
    _refreshTimer?.cancel();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => RaidBattlePage(
          boss: widget.boss,
          raidId: widget.raidId,
          initialProgress: summary,
          partySize: summary.participantCount,
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
  }

  Future<void> _leaveLobby() async {
    if (_leavingLobby) return;
    if (_raidEnded) {
      _popLobby();
      return;
    }

    setState(() => _leavingLobby = true);
    try {
      await GameApiService.leaveRaid(raidId: widget.raidId);
      if (!mounted) return;
      _popLobby();
    } on GameApiException catch (e) {
      if (!mounted) return;
      if (e.message == '파티장이 나가 레이드 방이 해체되었습니다.' ||
          e.message == '진행 중인 레이드가 아닙니다.' ||
          e.message == '레이드 참여 캐릭터가 아닙니다.') {
        _popLobby();
        return;
      }
      _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _leavingLobby = false);
    }
  }

  void _popLobby() {
    if (!mounted) return;
    setState(() => _routeExitAllowed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  void _showRaidCanceledDialog() {
    if (!mounted || _raidCanceledDialogShown) return;
    _raidCanceledDialogShown = true;
    _refreshTimer?.cancel();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kLobbyBg,
        title: const Text('레이드 방 해체', style: TextStyle(color: Colors.white)),
        content: const Text(
          '파티장이 나가 레이드 방이 해체되었습니다.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    ).then((_) {
      _popLobby();
    });
  }

  Future<void> _cancelInvitation(RaidInvitationInfo invitation) async {
    if (_canceling) return;
    setState(() => _canceling = true);
    try {
      final summary = await GameApiService.cancelRaidInvitation(invitation.id);
      if (!mounted) return;
      setState(() => _summary = summary);
      _showMessage('초대를 취소했습니다.');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  Future<void> _enterBattle() async {
    if (_starting) return;
    if (_raidEnded) {
      _showMessage('이미 종료된 레이드입니다.');
      return;
    }
    if (!_isHost) {
      _showMessage('파티장이 전투를 시작할 때까지 기다려주세요.');
      return;
    }
    if (!_allPartyReady) {
      _showMessage('파티원이 모두 준비될 때까지 기다려주세요.');
      return;
    }

    setState(() => _starting = true);
    try {
      final summary = await GameApiService.startRaid(raidId: widget.raidId);
      if (!mounted) return;
      if (summary.pendingInvitationCount > 0) {
        setState(() {
          _summary = summary;
          _starting = false;
        });
        _showMessage('수락 대기 중인 초대가 있어 전투를 시작할 수 없습니다.');
        return;
      }
      _openBattle(summary);
    } on GameApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _routeExitAllowed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_leaveLobby());
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
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _refresh(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                        children: [
                          _buildBossPanel(),
                          const SizedBox(height: 10),
                          _buildParticipantPanel(),
                          const SizedBox(height: 10),
                          _buildInvitationPanel(),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            _buildErrorPanel(_error!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
              child: _buildStartButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: _leavingLobby ? null : _leaveLobby,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kLobbyBorder, width: 2),
              ),
              child: _leavingLobby
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kLobbyGold,
                      ),
                    )
                  : const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kLobbyBorder, width: 2),
              ),
              child: const Column(
                children: [
                  Text(
                    '레이드 로비',
                    style: TextStyle(
                      color: Color(0xFFCC1111),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '초대 상태를 확인한 뒤 전투를 시작합니다.',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loading ? null : () => _refresh(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kLobbyBorder, width: 2),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kLobbyGold,
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossPanel() {
    final monster = _summary.monster;
    final hp = monster?.hp ?? widget.boss.hp;
    return _panel(
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: widget.boss.iconPath == null
                ? const Icon(Icons.shield, color: Colors.white24, size: 40)
                : Image.asset(
                    widget.boss.iconPath!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monster?.name ?? widget.boss.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _miniStat('HP', hp <= 0 ? '-' : _fmt(hp)),
                    const SizedBox(width: 6),
                    _miniStat('상태', _statusLabel(_summary.progress.status)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantPanel() {
    final participants = _summary.participants;
    return _panel(
      title: '참가자 ${participants.length}/4',
      child: Column(
        children: [
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '참가자 정보를 불러오는 중입니다.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            ...participants.map((participant) {
              final isMine = participant.characterId == _characterId;
              final name = participant.displayLabel;
              final status = switch (participant.joinStatus) {
                'left' => '나감',
                'kicked' => '퇴장',
                _ => '참가 완료',
              };
              return _statusRow(
                icon: Icons.person,
                title: isMine && name != '친구'
                    ? '나 · $name'
                    : (isMine ? '나' : name),
                subtitle:
                    '기여 거리 ${_fmtDouble(participant.contributionDistanceM)}m',
                trailing: status,
                color: participant.joinStatus == 'joined'
                    ? (isMine ? _kLobbyGold : _kLobbyBlue)
                    : Colors.white38,
                leading: isMine
                    ? AnimatedBuilder(
                        animation: GameState.instance,
                        builder: (context, _) => ProfileIconPreview(
                          iconKey: GameState.instance.profileIconKey,
                          customImageDataUrl:
                              GameState.instance.profileImageDataUrl,
                          size: 32,
                        ),
                      )
                    : UserProfileAvatar(
                        profileImage: participant.profileImage,
                        size: 32,
                        showFrame: false,
                      ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInvitationPanel() {
    return _panel(
      title: '초대 대기 ${_pendingInvitations.length}명',
      child: Column(
        children: [
          if (_pendingInvitations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '수락 대기 중인 초대가 없습니다.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            ..._pendingInvitations.map(
              (invitation) => _statusRow(
                icon: Icons.mail_outline,
                title: invitation.invitedUserLabel,
                subtitle: '초대 수락 대기중',
                trailing: _isHost ? '취소' : '대기중',
                color: _kLobbyGold,
                leading: UserProfileAvatar(
                  profileImage: invitation.invitedUserProfileImage,
                  size: 32,
                  showFrame: false,
                ),
                onTap: _isHost ? () => _cancelInvitation(invitation) : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel(String message) {
    return _panel(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12),
      ),
    );
  }

  Widget _buildStartButton() {
    final waitingForHost = !_isHost;
    final waitingForPartyReady = _isHost && !_allPartyReady && !_raidEnded;
    final disabled =
        _starting || _raidEnded || waitingForHost || waitingForPartyReady;
    final label = _raidEnded
        ? '종료된 레이드'
        : waitingForHost
        ? '파티장 전투 시작 대기'
        : waitingForPartyReady
        ? '파티원 준비 대기'
        : _starting
        ? '전투 시작 중'
        : '전투 시작';
    return GestureDetector(
      onTap: disabled ? null : _enterBattle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey[700] : const Color(0xFF7A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled ? Colors.grey[600]! : const Color(0xFF4A0E0E),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_starting)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.sports_martial_arts, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _kLobbyBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLobbyBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required Color color,
    Widget? leading,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            leading ?? Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: onTap == null
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFF7A1A1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: onTap == null
                      ? Colors.white12
                      : const Color(0xFF4A0E0E),
                ),
              ),
              child: Text(
                trailing,
                style: TextStyle(
                  color: onTap == null ? Colors.white38 : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'cleared' => '클리어',
      'failed' => '실패',
      'in_progress' => '진행 중',
      _ => '대기',
    };
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
