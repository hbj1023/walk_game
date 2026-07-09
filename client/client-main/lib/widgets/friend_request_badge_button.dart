import 'dart:async';

import 'package:flutter/material.dart';

import 'package:capstone_app/services/friendship_service.dart';

class FriendRequestBadgeButton extends StatefulWidget {
  final Future<void> Function() onTap;
  final double size;

  const FriendRequestBadgeButton({
    super.key,
    required this.onTap,
    this.size = 40,
  });

  @override
  State<FriendRequestBadgeButton> createState() =>
      _FriendRequestBadgeButtonState();
}

class _FriendRequestBadgeButtonState extends State<FriendRequestBadgeButton> {
  static const _refreshInterval = Duration(seconds: 30);

  int _requestCount = 0;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshRequestCount();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _refreshRequestCount(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await widget.onTap();
    await _refreshRequestCount();
  }

  Future<void> _refreshRequestCount() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final requests = await FriendshipService.fetchReceivedRequests();
      if (!mounted) return;
      setState(() => _requestCount = requests.length);
    } catch (_) {
      // Keep the last known count; badge failure should not block the screen.
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
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
          if (_requestCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE03030),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFFFD15C), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _requestCount > 99 ? '99+' : '$_requestCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
