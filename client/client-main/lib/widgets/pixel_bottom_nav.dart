import 'dart:async';

import 'package:flutter/material.dart';

class MainNavSwipeController {
  MainNavSwipeController._();

  static final List<_MainNavSwipeRegistration> _registrations = [];
  static List<PixelBottomNavItem> _items = const [];
  static int _currentIndex = 0;
  static Future<void> Function(PixelBottomNavItem item)? _onSwipe;
  static int? _pointer;
  static Offset? _startPosition;
  static Offset? _latestPosition;
  static bool _animateNextRoute = false;

  static void activate({
    required Object owner,
    required List<PixelBottomNavItem> items,
    required int currentIndex,
    required Future<void> Function(PixelBottomNavItem item) onSwipe,
  }) {
    _registrations.removeWhere(
      (registration) => identical(registration.owner, owner),
    );
    _registrations.add(
      _MainNavSwipeRegistration(
        owner: owner,
        items: items,
        currentIndex: currentIndex,
        onSwipe: onSwipe,
      ),
    );
    _items = items;
    _currentIndex = currentIndex;
    _onSwipe = onSwipe;
  }

  static void deactivate(Object owner) {
    _registrations.removeWhere(
      (registration) => identical(registration.owner, owner),
    );
    if (_registrations.isEmpty) {
      _items = const [];
      _onSwipe = null;
    } else {
      final previous = _registrations.last;
      _items = previous.items;
      _currentIndex = previous.currentIndex;
      _onSwipe = previous.onSwipe;
    }
    cancelPointer();
  }

  static void pointerDown(PointerDownEvent event) {
    if (_onSwipe == null || _pointer != null) return;
    _pointer = event.pointer;
    _startPosition = event.position;
    _latestPosition = event.position;
  }

  static void pointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    _latestPosition = event.position;
  }

  static void pointerUp(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    _latestPosition = event.position;
    final start = _startPosition;
    final end = _latestPosition;
    cancelPointer();
    if (start == null || end == null) return;

    final delta = end - start;
    if (delta.dx.abs() < 72 || delta.dx.abs() < delta.dy.abs() * 1.45) {
      return;
    }

    final targetIndex = _currentIndex + (delta.dx < 0 ? 1 : -1);
    PixelBottomNavItem? target;
    for (final item in _items) {
      if (item.index == targetIndex) {
        target = item;
        break;
      }
    }
    final callback = _onSwipe;
    if (target == null || callback == null) return;

    _animateNextRoute = true;
    unawaited(
      callback(target).whenComplete(() {
        _animateNextRoute = false;
      }),
    );
  }

  static void cancelPointer() {
    _pointer = null;
    _startPosition = null;
    _latestPosition = null;
  }

  static bool takeAnimatedRouteRequest() {
    final animate = _animateNextRoute;
    _animateNextRoute = false;
    return animate;
  }
}

class _MainNavSwipeRegistration {
  const _MainNavSwipeRegistration({
    required this.owner,
    required this.items,
    required this.currentIndex,
    required this.onSwipe,
  });

  final Object owner;
  final List<PixelBottomNavItem> items;
  final int currentIndex;
  final Future<void> Function(PixelBottomNavItem item) onSwipe;
}

PageRouteBuilder<T> buildMainNavRoute<T>({
  required Widget page,
  required int fromIndex,
  required int toIndex,
}) {
  final animate = MainNavSwipeController.takeAnimatedRouteRequest();
  if (!animate) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  final enterFromRight = toIndex > fromIndex;
  final beginOffset = Offset(enterFromRight ? 1 : -1, 0);

  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final position = Tween<Offset>(begin: beginOffset, end: Offset.zero)
          .animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
          );
      return ClipRect(
        child: SlideTransition(
          position: position,
          child: ColoredBox(color: const Color(0xFF100B08), child: child),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
  );
}

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

class PixelBottomNav extends StatefulWidget {
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
  State<PixelBottomNav> createState() => _PixelBottomNavState();

  static bool isCompactFor(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return screenSize.height < 900 || screenSize.width < 430;
  }

  static double reservedHeightFor(BuildContext context) {
    return isCompactFor(context) ? 90 : 120;
  }
}

class _PixelBottomNavState extends State<PixelBottomNav> {
  @override
  void initState() {
    super.initState();
    _activateSwipe();
  }

  @override
  void didUpdateWidget(covariant PixelBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activateSwipe();
  }

  @override
  void dispose() {
    MainNavSwipeController.deactivate(this);
    super.dispose();
  }

  void _activateSwipe() {
    MainNavSwipeController.activate(
      owner: this,
      items: widget.items,
      currentIndex: widget.currentIndex,
      onSwipe: (item) async {
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        await widget.onTap(item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = PixelBottomNav.isCompactFor(context);
    final selectedHeight = compact ? 72.0 : 90.0;
    final itemHeight = compact ? 62.0 : 78.0;
    final topPadding = compact ? 12.0 : 22.0;
    final bottomPadding = compact ? 6.0 : 8.0;

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
        padding: EdgeInsets.fromLTRB(7, topPadding, 7, bottomPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: widget.items.map((item) {
            final isSelected = widget.currentIndex == item.index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 2,
                  right: 2,
                  top: isSelected ? 0 : 10,
                ),
                child: GestureDetector(
                  onTap: () => widget.onTap(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: isSelected ? selectedHeight : itemHeight,
                    padding: EdgeInsets.fromLTRB(3, compact ? 5 : 7, 3, 6),
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
                              SizedBox(height: compact ? 3 : 5),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFFDD73)
                                      : const Color(0xFF6F665F),
                                  fontSize: compact
                                      ? (isSelected ? 12 : 11)
                                      : (isSelected ? 13 : 12),
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
    final compact = PixelBottomNav.isCompactFor(context);
    if (isSelected) {
      return Image.asset(
        item.icon,
        width: compact ? 30 : 36,
        height: compact ? 30 : 36,
      );
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.52,
        0,
        0,
        0,
        0,
        0,
        0.52,
        0,
        0,
        0,
        0,
        0,
        0.52,
        0,
        0,
        0,
        0,
        0,
        0.95,
        0,
      ]),
      child: Image.asset(
        item.icon,
        width: compact ? 26 : 31,
        height: compact ? 26 : 31,
      ),
    );
  }
}
