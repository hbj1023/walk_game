import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/widgets/app_settings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_email': 'player@example.com',
      'auth_name': '테스터',
    });
  });

  testWidgets('고객센터를 닫으면 입력 포커스와 키보드가 함께 해제된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSettingsLauncher(tester);

    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    final messageField = find.widgetWithText(
      TextField,
      '무엇을 하다가 어떤 문제가 생겼는지 짧게 적어주세요.',
    );
    await tester.ensureVisible(messageField);
    await tester.tap(messageField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('안드로이드 뒤로가기로 고객센터를 닫아도 키보드가 해제된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSettingsLauncher(tester);

    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    final messageField = find.widgetWithText(
      TextField,
      '무엇을 하다가 어떤 문제가 생겼는지 짧게 적어주세요.',
    );
    await tester.ensureVisible(messageField);
    await tester.tap(messageField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('고객센터에서 계정 삭제로 이동하면 새 입력창이 키보드를 받는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSettingsLauncher(tester);

    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    final messageField = find.widgetWithText(
      TextField,
      '무엇을 하다가 어떤 문제가 생겼는지 짧게 적어주세요.',
    );
    await tester.ensureVisible(messageField);
    await tester.tap(messageField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    final deleteButton = find.text('계정 삭제');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('이메일 확인'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    final passwordField = find.widgetWithText(TextField, '현재 비밀번호');
    await tester.ensureVisible(passwordField);
    await tester.tap(passwordField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    expect(find.text('버그 제보'), findsOneWidget);
    expect(find.text('이메일 확인'), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}

Future<void> _pumpSettingsLauncher(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppSettingsDialog(
                  onLogout: () async {},
                  onAccountDeleted: () async {},
                ),
              ),
              child: const Text('설정 열기'),
            ),
          ),
        ),
      ),
    ),
  );
}
