import 'package:flutter/material.dart';

class GameLoadingScreen extends StatelessWidget {
  final String backgroundAsset;
  final String title;
  final String message;
  final double? progress;
  final bool waitingServer;

  const GameLoadingScreen({
    super.key,
    required this.backgroundAsset,
    required this.title,
    required this.message,
    this.progress,
    this.waitingServer = false,
  });

  static const _gold = Color(0xFFF0C040);
  static const _border = Color(0xFF6B3A1F);

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress?.clamp(0.0, 1.0);
    final percent = safeProgress == null
        ? null
        : (safeProgress * 100).round().clamp(0, 100);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.none,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.48),
                  Colors.black.withValues(alpha: 0.70),
                  Colors.black.withValues(alpha: 0.86),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: const Color(0xDD12100D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      offset: const Offset(0, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PixelProgress(value: safeProgress),
                    const SizedBox(height: 8),
                    Text(
                      percent == null
                          ? (waitingServer ? '서버 응답 대기 중' : '준비 중')
                          : '$percent%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (waitingServer) ...[
                      const SizedBox(height: 8),
                      Text(
                        '전투 정보를 확인하고 있습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PixelProgress extends StatelessWidget {
  final double? value;

  const _PixelProgress({this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.70),
        border: Border.all(color: const Color(0xFF403224), width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final progressWidth = value == null
              ? width * 0.34
              : width * value!.clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: progressWidth.clamp(8.0, width),
              color: const Color(0xFFF0C040),
            ),
          );
        },
      ),
    );
  }
}
