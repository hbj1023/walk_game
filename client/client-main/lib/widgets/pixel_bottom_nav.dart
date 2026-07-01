import 'package:flutter/material.dart';

class PixelBottomNavItem {
  final String icon;
  final String label;
  final int index;

  const PixelBottomNavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class PixelBottomNav extends StatelessWidget {
  final List<PixelBottomNavItem> items;
  final int currentIndex;
  final Future<void> Function(PixelBottomNavItem item) onTap;

  const PixelBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF070302).withValues(alpha: 0),
            const Color(0xFF070302).withValues(alpha: 0.78),
            const Color(0xFF070302),
          ],
          stops: const [0, 0.36, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 18, 7, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: items.map((item) {
            final isSelected = currentIndex == item.index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 2,
                  right: 2,
                  top: isSelected ? 0 : 10,
                ),
                child: GestureDetector(
                  onTap: () => onTap(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: isSelected ? 70 : 60,
                    padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF24130A)
                          : const Color(0xFF100906),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE2B24A)
                            : const Color(0xFF392316),
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Container(
                            height: 3,
                            color: isSelected
                                ? const Color(0xFFFFD46A)
                                : const Color(0xFF25160E),
                          ),
                        ),
                        Positioned(
                          left: 1,
                          top: 1,
                          child: Container(
                            width: 4,
                            height: 4,
                            color: isSelected
                                ? const Color(0xFFFFE49A)
                                : const Color(0xFF4C2F1D),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PixelNavIcon(item: item, isSelected: isSelected),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFFDD73)
                                      : const Color(0xFF6F665F),
                                  fontSize: 9,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      color: Color(0xFF000000),
                                    ),
                                  ],
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
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PixelNavIcon extends StatelessWidget {
  final PixelBottomNavItem item;
  final bool isSelected;

  const _PixelNavIcon({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Image.asset(item.icon, width: 19, height: 19);
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.28,
        0,
        0,
        0,
        0,
        0,
        0.28,
        0,
        0,
        0,
        0,
        0,
        0.28,
        0,
        0,
        0,
        0,
        0,
        0.9,
        0,
      ]),
      child: Image.asset(item.icon, width: 15, height: 15),
    );
  }
}
