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
      home: const SplashPage(),
    );
  }
}
