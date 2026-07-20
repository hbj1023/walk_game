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
    return const ColoredBox(
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
    );
  }
}
