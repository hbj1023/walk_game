import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/power_saving_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppSettingsService.customPowerSavingUiVisible.value = false;
  });

  testWidgets('initial route immediately enables its custom power-saving UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [powerSavingRouteObserver],
        home: const _PowerSavingAwarePage(),
      ),
    );
    await tester.pump();

    expect(AppSettingsService.customPowerSavingUiVisible.value, isTrue);
  });

  testWidgets('covered route disables and restored route reenables custom UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [powerSavingRouteObserver],
        home: const _PowerSavingAwarePage(),
      ),
    );
    await tester.pump();

    final context = tester.element(find.text('절전 화면'));
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(AppSettingsService.customPowerSavingUiVisible.value, isFalse);

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(AppSettingsService.customPowerSavingUiVisible.value, isTrue);
  });
}

class _PowerSavingAwarePage extends StatefulWidget {
  const _PowerSavingAwarePage();

  @override
  State<_PowerSavingAwarePage> createState() => _PowerSavingAwarePageState();
}

class _PowerSavingAwarePageState extends State<_PowerSavingAwarePage>
    with CustomPowerSavingRouteAware<_PowerSavingAwarePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('절전 화면'));
  }
}
