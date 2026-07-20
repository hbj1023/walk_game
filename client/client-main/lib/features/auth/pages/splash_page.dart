import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/profile_icon_service.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/auth/pages/intro_page.dart';
import 'package:capstone_app/features/auth/pages/login_page.dart';
import 'package:capstone_app/widgets/game_loading_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () async {
      final prefs = await SharedPreferences.getInstance();
      await ProfileIconService.loadIntoGameState();
      final hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;
      var token = await AuthService.getSavedToken();
      if (token != null && token.isNotEmpty) {
        try {
          await AuthService.fetchMainMessage().timeout(
            const Duration(seconds: 3),
          );
          await ProfileIconService.loadIntoGameState();
          await BattleApiService.leaveStoredUnfinishedNormalBattle().timeout(
            const Duration(seconds: 3),
          );
        } catch (_) {
          await AuthService.logout();
          token = null;
          // 강제 종료된 전투 정리는 다음 실행 때 다시 시도합니다.
        }
      }

      if (!mounted) {
        return;
      }

      final page = !hasSeenIntro
          ? const IntroPage()
          : (token == null || token.isEmpty)
          ? const LoginPage()
          : const HomePage();
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
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GameLoadingScreen(
        title: '로딩중',
        message: '로딩중',
      ),
    );
  }
}
