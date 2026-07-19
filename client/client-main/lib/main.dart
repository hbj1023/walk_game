import 'dart:async';

import 'package:flutter/material.dart';
import 'package:capstone_app/features/auth/pages/splash_page.dart';
import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/game_audio_service.dart';

void main() {
  GameAudioService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Walk Master', //앱 이름
      theme: ThemeData(
        fontFamily: 'Galmuri',
        scaffoldBackgroundColor: const Color(0xFF71C6E4),
      ),
      builder: (context, child) =>
          _AutoPowerSavingGate(child: _MobileFrame(child: child)),
      home: const SplashPage(),
    );
  }
}

class _AutoPowerSavingGate extends StatefulWidget {
  const _AutoPowerSavingGate({required this.child});

  final Widget child;

  @override
  State<_AutoPowerSavingGate> createState() => _AutoPowerSavingGateState();
}

class _AutoPowerSavingGateState extends State<_AutoPowerSavingGate>
    with WidgetsBindingObserver {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettingsService.notifier.addListener(_resetIdleTimer);
    AppSettingsService.load().then((_) => _resetIdleTimer());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    AppSettingsService.notifier.removeListener(_resetIdleTimer);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetIdleTimer();
    } else {
      _idleTimer?.cancel();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final settings = AppSettingsService.notifier.value;
    if (settings.powerSavingMode || settings.autoPowerSavingMinutes <= 0) {
      return;
    }
    _idleTimer = Timer(
      Duration(minutes: settings.autoPowerSavingMinutes),
      _enablePowerSavingMode,
    );
  }

  Future<void> _enablePowerSavingMode() async {
    final settings = AppSettingsService.notifier.value;
    if (settings.powerSavingMode || settings.autoPowerSavingMinutes <= 0) {
      return;
    }
    await AppSettingsService.save(settings.copyWith(powerSavingMode: true));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _resetIdleTimer();
        GameAudioService.ensureBackgroundMusic();
      },
      onPointerMove: (_) => _resetIdleTimer(),
      onPointerSignal: (_) => _resetIdleTimer(),
      child: widget.child,
    );
  }
}

class _MobileFrame extends StatelessWidget {
  const _MobileFrame({required this.child});

  static const double _maxWidth = 430;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < _maxWidth
            ? constraints.maxWidth
            : _maxWidth;
        final height = constraints.maxHeight;
        final mediaQuery = MediaQuery.of(context);

        return ColoredBox(
          color: const Color(0xFF10141A),
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: MediaQuery(
                data: mediaQuery.copyWith(size: Size(width, height)),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
