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
  static const _border = Color(0xFF6B3A1F);

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress?.clamp(0.0, 1.0);
    final percent = safeProgress == null
        ? null
        : (safeProgress * 100).round().clamp(0, 100);

    return Stack(
      children: [
        if (backgroundAsset != null && !characterOnly)
          Positioned.fill(
            child: Image.asset(
              backgroundAsset!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.none,
            ),
          )
        else
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: characterOnly ? 0.10 : 0.48),
                  Colors.black.withValues(alpha: characterOnly ? 0.38 : 0.70),
                  Colors.black.withValues(alpha: characterOnly ? 0.72 : 0.86),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      characterAsset,
                      width: 118,
                      height: 118,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xE612100D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            offset: const Offset(0, 5),
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
                              fontSize: 19,
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
                          const SizedBox(height: 9),
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
                          const SizedBox(height: 13),
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
                        ],
                      ),
                    ),
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
