import 'package:flutter/material.dart';

class GameLoadingScreen extends StatelessWidget {
  final String? backgroundAsset;
  final String characterAsset;
  final String title;
  final String message;
  final double? progress;
  final bool waitingServer;
  final bool characterOnly;

  const GameLoadingScreen({
    super.key,
    this.backgroundAsset,
    this.characterAsset = 'assets/images/character/idle.png',
    required this.title,
    required this.message,
    this.progress,
    this.waitingServer = false,
    this.characterOnly = true,
  });

  static const _gold = Color(0xFFF0C040);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            '로딩중...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
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
      ),
    );
  }
}

class GameLoadingOverlay extends StatelessWidget {
  final bool visible;

  const GameLoadingOverlay({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: visible
              ? const GameLoadingScreen(
                  key: ValueKey('game-loading-visible'),
                  title: '로딩중',
                  message: '로딩중',
                )
              : const SizedBox.shrink(key: ValueKey('game-loading-hidden')),
        ),
      ),
    );
  }
}
