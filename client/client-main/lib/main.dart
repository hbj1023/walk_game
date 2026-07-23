import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone_app/features/auth/pages/splash_page.dart';
import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/game_audio_service.dart';
import 'package:capstone_app/services/power_saving_route_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF070302),
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
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
      navigatorObservers: [powerSavingRouteObserver],
      builder: (context, child) =>
          _MobileFrame(child: _AutoPowerSavingGate(child: child)),
      home: const SplashPage(),
    );
  }
}

class _AutoPowerSavingGate extends StatefulWidget {
  const _AutoPowerSavingGate({required this.child});

  final Widget? child;

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

  Future<void> _disablePowerSavingMode() async {
    final settings = AppSettingsService.notifier.value;
    await AppSettingsService.save(settings.copyWith(powerSavingMode: false));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppSettingsService.notifier,
        AppSettingsService.customPowerSavingUiVisible,
      ]),
      builder: (context, _) {
        final showGlobalPowerSaving =
            AppSettingsService.notifier.value.powerSavingMode &&
            !AppSettingsService.customPowerSavingUiVisible.value;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _resetIdleTimer();
            GameAudioService.ensureBackgroundMusic();
          },
          onPointerMove: (_) => _resetIdleTimer(),
          onPointerSignal: (_) => _resetIdleTimer(),
          child: Stack(
            children: [
              widget.child ?? const SizedBox.shrink(),
              if (showGlobalPowerSaving)
                Positioned.fill(child: _buildGlobalPowerSavingView()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalPowerSavingView() {
    return Material(
      color: const Color(0xFF050705),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.battery_saver_rounded,
                    color: Color(0xFF79E28A),
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '절전 모드',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _disablePowerSavingMode,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF5D201B),
                      side: const BorderSide(color: Color(0xFFA94B3C)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '종료',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.shield_moon_rounded,
                color: Color(0xFF79E28A),
                size: 78,
              ),
              const SizedBox(height: 18),
              const Text(
                '화면 사용량을 줄이고 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '종료를 누르면 이전 화면으로 돌아갑니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
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
