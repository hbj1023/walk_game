import 'dart:async';

import 'package:flutter/material.dart';

import 'package:capstone_app/features/auth/pages/login_page.dart';
import 'package:capstone_app/features/social/widgets/friend_sheet.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/widgets/app_settings_dialog.dart';
import 'package:capstone_app/widgets/friend_request_badge_button.dart';

class GameTopActions extends StatefulWidget {
  final double size;

  const GameTopActions({super.key, this.size = 40});

  @override
  State<GameTopActions> createState() => _GameTopActionsState();
}

class _GameTopActionsState extends State<GameTopActions> {
  static const _raidInvitationRefreshInterval = Duration(seconds: 2);

  bool _isLoggingOut = false;
  bool _isRefreshingRaidInvitations = false;
  bool _hasLoadedRaidInvitations = false;
  Set<String> _raidInvitationIds = const <String>{};
  Timer? _raidInvitationRefreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshRaidInvitations(announce: false));
    _raidInvitationRefreshTimer = Timer.periodic(
      _raidInvitationRefreshInterval,
      (_) => unawaited(_refreshRaidInvitations()),
    );
  }

  @override
  void dispose() {
    _raidInvitationRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _openFriendSheet() {
    return showDialog<void>(
      context: context,
      builder: (context) => const FriendSheet(),
    );
  }

  Future<void> _openSettingsDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppSettingsDialog(
        onLogout: _confirmLogout,
        onAccountDeleted: _logout,
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
        content: const Text(
          '정말 로그아웃하시겠습니까?',
          style: TextStyle(color: Color(0xFFD9C9A8)),
        ),
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
      GameState.instance.setCoins(0);
      GameState.instance.setAttackCountBalance(0);

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

  Future<void> _refreshRaidInvitations({bool announce = true}) async {
    if (_isRefreshingRaidInvitations) return;
    _isRefreshingRaidInvitations = true;
    try {
      final invitations = await GameApiService.fetchRaidInvitations();
      if (!mounted) return;
      final nextIds = invitations
          .where((invitation) => invitation.isPending)
          .map((invitation) => invitation.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      final hasNewInvitation = nextIds.any(
        (id) => !_raidInvitationIds.contains(id),
      );
      final shouldAnnounce =
          announce && _hasLoadedRaidInvitations && hasNewInvitation;
      _raidInvitationIds = nextIds;
      _hasLoadedRaidInvitations = true;
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (shouldAnnounce && isCurrentRoute) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('새 레이드 초대가 도착했습니다.')));
      }
    } catch (_) {
      // 초대 알림 갱신 실패는 현재 화면 이용을 막지 않는다.
    } finally {
      _isRefreshingRaidInvitations = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FriendRequestBadgeButton(onTap: _openFriendSheet, size: widget.size),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _isLoggingOut ? null : _openSettingsDialog,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
            ),
            child: Icon(
              Icons.settings,
              size: widget.size * 0.55,
              color: Colors.white.withValues(alpha: _isLoggingOut ? 0.35 : 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
