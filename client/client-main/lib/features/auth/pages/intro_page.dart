import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/features/auth/pages/login_page.dart';

const _kAuthGold = Color(0xFFF2C94C);
const _kAuthBrown = Color(0xFF7A3E1D);
const _kAuthDark = Color(0xDD10130F);
const _kAuthRed = Color(0xFF8F1D1D);

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _IntroData(
      title: '걷는 만큼 성장',
      description: '걸음 수가 경험치와 보상으로 쌓여요.',
      icon: Icons.directions_walk_rounded,
    ),
    _IntroData(
      title: '스테이지 전투',
      description: '장을 넘어가며 몬스터를 물리치고 보상을 얻습니다.',
      icon: Icons.sports_martial_arts_rounded,
    ),
    _IntroData(
      title: '장비와 레이드',
      description: '장비를 모아 전투력을 올리고 보스에 도전합니다.',
      icon: Icons.inventory_2_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntro', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => const LoginPage(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  void _goNext() {
    if (_currentPage == _pages.length - 1) {
      _goToLogin();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 18 + bottomInset * 0.2),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _goToLogin,
                      child: const Text(
                        '건너뛰기',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        return _IntroSlide(data: _pages[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PageDots(count: _pages.length, selected: _currentPage),
                  const SizedBox(height: 18),
                  _PixelActionButton(
                    label: _currentPage == _pages.length - 1 ? '시작하기' : '다음',
                    onTap: _goNext,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroData {
  final String title;
  final String description;
  final IconData icon;

  const _IntroData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _IntroSlide extends StatelessWidget {
  final _IntroData data;

  const _IntroSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _PixelPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Galmuri',
                color: _kAuthGold,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.1,
                shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                border: Border.all(color: _kAuthBrown, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(data.icon, color: _kAuthGold, size: 58),
            ),
            const SizedBox(height: 24),
            Text(
              data.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/bg/home_bg.png', fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.48)),
      ],
    );
  }
}

class _PixelPanel extends StatelessWidget {
  final Widget child;

  const _PixelPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      decoration: BoxDecoration(
        color: _kAuthDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAuthBrown, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int selected;

  const _PageDots({required this.count, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: index == selected
                ? _kAuthGold
                : Colors.white.withValues(alpha: 0.25),
            border: Border.all(color: Colors.black, width: 1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PixelActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PixelActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFF555555) : _kAuthRed,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A0E0E), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Galmuri',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
