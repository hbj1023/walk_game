import 'package:capstone_app/widgets/pixel_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('오른쪽 메뉴는 오른쪽에서 들어온다', (tester) async {
    await _pumpTransitionHarness(tester, fromIndex: 2, toIndex: 3);

    await tester.tap(find.byKey(const Key('open-target')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      tester.getTopLeft(find.byKey(const Key('target-page'))).dx,
      greaterThan(0),
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('target-page'))).dx, 0);
  });

  testWidgets('왼쪽 메뉴는 왼쪽에서 들어온다', (tester) async {
    await _pumpTransitionHarness(tester, fromIndex: 2, toIndex: 1);

    await tester.tap(find.byKey(const Key('open-target')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      tester.getTopLeft(find.byKey(const Key('target-page'))).dx,
      lessThan(0),
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('target-page'))).dx, 0);
  });

  testWidgets('화면 교체 방식에서도 전체 페이지가 슬라이드된다', (
    tester,
  ) async {
    await _pumpTransitionHarness(
      tester,
      fromIndex: 1,
      toIndex: 3,
      replace: true,
    );

    await tester.tap(find.byKey(const Key('open-target')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      tester.getTopLeft(find.byKey(const Key('target-page'))).dx,
      greaterThan(0),
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('target-page'))).dx, 0);
  });
}

Future<void> _pumpTransitionHarness(
  WidgetTester tester, {
  required int fromIndex,
  required int toIndex,
  bool replace = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-target'),
              onPressed: () {
                final route = buildMainNavRoute(
                  page: const ColoredBox(
                    key: Key('target-page'),
                    color: Colors.black,
                  ),
                  fromIndex: fromIndex,
                  toIndex: toIndex,
                );
                if (replace) {
                  Navigator.pushReplacement(context, route);
                } else {
                  Navigator.push(context, route);
                }
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
}
