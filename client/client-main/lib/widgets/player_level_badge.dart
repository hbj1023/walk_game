import 'package:flutter/material.dart';

class PlayerLevelBadge extends StatelessWidget {
  final int level;
  final int exp;
  final int expToNext;

  const PlayerLevelBadge({
    super.key,
    required this.level,
    required this.exp,
    required this.expToNext,
  });

  @override
  Widget build(BuildContext context) {
    final safeLevel = level < 1 ? 1 : level;
    final safeNext = expToNext <= 0 ? safeLevel * 100 : expToNext;
    final progress = safeNext <= 0 ? 0.0 : (exp / safeNext).clamp(0.0, 1.0);

    return Container(
      width: 66,
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xE6141519),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF6B3A1F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LV.$safeLevel',
            style: const TextStyle(
              color: Color(0xFFFFD966),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress,
              backgroundColor: const Color(0xFF242936),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF69D8FF),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$exp/$safeNext',
            style: const TextStyle(
              color: Color(0xFFBFF4FF),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerProfileWithLevel extends StatelessWidget {
  final int level;
  final int exp;
  final int expToNext;

  const PlayerProfileWithLevel({
    super.key,
    required this.level,
    required this.exp,
    required this.expToNext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Stack(
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
                  Icons.person,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          Positioned(
            top: 54,
            child: PlayerLevelBadge(
              level: level,
              exp: exp,
              expToNext: expToNext,
            ),
          ),
        ],
      ),
    );
  }
}
