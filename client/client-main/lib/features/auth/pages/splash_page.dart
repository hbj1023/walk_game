import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/profile_icon_service.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/auth/pages/intro_page.dart';
import 'package:capstone_app/features/auth/pages/initial_permission_page.dart';
import 'package:capstone_app/features/auth/pages/login_page.dart';
import 'package:capstone_app/services/initial_permission_service.dart';
import 'package:capstone_app/widgets/game_loading_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final Completer<void> _minimumSplashCompleter = Completer<void>();
  Timer? _minimumSplashTimer;

  @override
  void initState() {
    super.initState();
    _minimumSplashTimer = Timer(const Duration(milliseconds: 650), () {
      if (!_minimumSplashCompleter.isCompleted) {
        _minimumSplashCompleter.complete();
      }
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final prefsFuture = SharedPreferences.getInstance();
    final permissionFuture = InitialPermissionService.shouldShow();

    final prefs = await prefsFuture;
    final hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;
    var token = await AuthService.getSavedToken();
    if (token != null && token.isNotEmpty) {
      try {
        await AuthService.fetchMainMessage().timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {
        await AuthService.logout();
        token = null;
      }
    }

    if (token != null && token.isNotEmpty) {
      await Future.wait<void>([
        ProfileIconService.loadIntoGameState(),
        _cleanupUnfinishedBattle(),
      ]);
    } else {
      ProfileIconService.resetGameStateToDefault();
    }

    final destination = !hasSeenIntro
        ? const IntroPage()
        : (token == null || token.isEmpty)
        ? const LoginPage()
        : const HomePage();
    final page = await permissionFuture
        ? InitialPermissionPage(nextPage: destination)
        : destination;
    await _minimumSplashCompleter.future;
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => page,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _cleanupUnfinishedBattle() async {
    try {
      await BattleApiService.leaveStoredUnfinishedNormalBattle().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      // 전투 정리 실패는 로그인 세션을 만료시키지 않고 다음 실행에 재시도합니다.
    }
  }

  @override
  void dispose() {
    _minimumSplashTimer?.cancel();
    if (!_minimumSplashCompleter.isCompleted) {
      _minimumSplashCompleter.complete();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GameLoadingScreen(title: '로딩중', message: '로딩중'),
    );
  }
}
