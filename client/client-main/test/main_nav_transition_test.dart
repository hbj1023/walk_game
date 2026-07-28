import 'package:capstone_app/widgets/pixel_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('하단 버튼을 누르면 화면이 즉시 교체된다', (tester) async {
    await _pumpNavigationHarness(tester);

    await tester.tap(find.byKey(const Key('open-target')));
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(const Key('target-page'))).dx, 0);
  });

  testWidgets('왼쪽으로 밀면 오른쪽 인접 화면이 슬라이드된다', (tester) async {
    await _pumpNavigationHarness(tester, enableSwipe: true);

    await tester.drag(
      find.byKey(const Key('swipe-surface')),
      const Offset(-140, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    expect(
      tester.getTopLeft(find.byKey(const Key('target-page'))).dx,
      greaterThan(0),
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('target-page'))).dx, 0);
  });

  testWidgets('짧거나 세로 방향인 드래그는 화면을 바꾸지 않는다', (tester) async {
    await _pumpNavigationHarness(tester, enableSwipe: true);

    await tester.drag(
      find.byKey(const Key('swipe-surface')),
      const Offset(-30, 120),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('target-page')), findsNothing);
  });
}

Future<void> _pumpNavigationHarness(
  WidgetTester tester, {
  bool enableSwipe = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          Future<void> openTarget() async {
            await Navigator.push(
              context,
              buildMainNavRoute(
                page: const ColoredBox(
                  key: Key('target-page'),
                  color: Colors.black,
                ),
                fromIndex: 2,
                toIndex: 3,
              ),
            );
          }

          final page = Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-target'),
                onPressed: openTarget,
                child: const Text('열기'),
              ),
            ),
            bottomNavigationBar: PixelBottomNav(
              items: const [
                PixelBottomNavItem(
                  icon: 'assets/images/nav/nav_home.png',
                  label: '홈',
                  index: 2,
                ),
                PixelBottomNavItem(
                  icon: 'assets/images/nav/nav_battle.png',
                  label: '전투',
                  index: 3,
                ),
              ],
              currentIndex: 2,
              onTap: (item) => item.index == 3 ? openTarget() : Future.value(),
            ),
          );

          if (!enableSwipe) return page;
          return Listener(
            key: const Key('swipe-surface'),
            behavior: HitTestBehavior.translucent,
            onPointerDown: MainNavSwipeController.pointerDown,
            onPointerMove: MainNavSwipeController.pointerMove,
            onPointerUp: MainNavSwipeController.pointerUp,
            onPointerCancel: (_) => MainNavSwipeController.cancelPointer(),
            child: page,
          );
        },
      ),
    ),
  );
}
