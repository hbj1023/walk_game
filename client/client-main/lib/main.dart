import 'package:flutter/material.dart';
import 'package:capstone_app/features/auth/pages/splash_page.dart';

void main() {
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
      builder: (context, child) => _MobileFrame(child: child),
      home: const SplashPage(),
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
