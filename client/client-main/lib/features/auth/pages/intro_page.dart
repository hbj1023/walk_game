import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:capstone_app/features/auth/pages/login_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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

  void _goNext() {
    if (_currentPage == 2) {
      _goToLogin();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const skyBlue = Color(0xFF71C6E4);
    const deepBlue = Color(0xFF4F8FA8);

    const pages = [
      _IntroSlide(
        badge: 'WALK MASTER',
        title: '귀엽게 걷고\n가볍게 즐기는\n2D 모험',
        description: '현실에서 걸은 만큼 캐릭터가 앞으로 이동하는\n캐주얼 워킹 RPG예요.',
        content: _WalkContent(),
      ),
      _IntroSlide(
        badge: 'AUTO BATTLE',
        title: '이동 거리가 쌓이면\n몬스터와 보스를\n자동으로 공격',
        description: '앱이 측정한 거리 수치에 맞춰 전투가 진행되고\n적을 쓰러뜨릴 수 있어요.',
        content: _BattleContent(),
      ),
      _IntroSlide(
        badge: 'REWARD',
        title: '코인을 모아\n장비를 구매하고\n스탯을 강화하세요',
        description: '코인으로 상점에서 무기를 사거나 스탯을 올리고,\n보스를 처치하면 고등급 장비가 랜덤으로 드랍돼요.',
        content: _RewardContent(),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF91DCF5), skyBlue, Color(0xFF5A9DB5)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) => pages[index],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Row(
                      children: List.generate(
                        pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: _currentPage == index ? 28 : 10,
                          height: 10,
                          margin: EdgeInsets.only(
                            right: index == pages.length - 1 ? 0 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _goToLogin,
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: deepBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      _currentPage == pages.length - 1 ? '모험 시작하기' : '다음',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  final String badge;
  final String title;
  final String description;
  final Widget content;

  const _IntroSlide({
    required this.badge,
    required this.title,
    required this.description,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          description,
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: content),
      ],
    );
  }
}

class _WalkContent extends StatelessWidget {
  const _WalkContent();

  @override
  Widget build(BuildContext context) {
    return const _SoftCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.directions_walk_rounded,
                  title: '오늘 걸음',
                  value: '4,230',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.route_rounded,
                  title: '이동 거리',
                  value: '2.4 km',
                ),
              ),
            ],
          ),
          _MessageCard(
            icon: Icons.map_rounded,
            title: '걸을수록 필드 전진',
            description: '현실에서 이동한 거리만큼 2D 맵 위 캐릭터가 앞으로 이동해요.',
          ),
          _TagRow(tags: ['2D 캐주얼', '걷기 기반', '귀여운 모험']),
        ],
      ),
    );
  }
}

class _BattleContent extends StatelessWidget {
  const _BattleContent();

  @override
  Widget build(BuildContext context) {
    return const _SoftCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _BadgeCard(
                  imagePath: 'assets/images/monsters/green_goblin.png',
                  label: '고블린',
                  accent: Color(0xFFFFD86E),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _BadgeCard(
                  icon: Icons.flash_on_rounded,
                  label: '자동 전투',
                  accent: Color(0xFFAEE6FF),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '보스 체력',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C4054),
                ),
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(999)),
                child: LinearProgressIndicator(
                  value: 0.68,
                  minHeight: 16,
                  backgroundColor: Color(0xFFD9EFF8),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F8FA8)),
                ),
              ),
            ],
          ),
          _MessageCard(
            icon: Icons.sports_martial_arts_rounded,
            title: '전투는 자동으로 진행',
            description: '거리 데이터가 공격량으로 누적되어 몬스터와 보스를 때립니다.',
          ),
        ],
      ),
    );
  }
}

class _RewardContent extends StatelessWidget {
  const _RewardContent();

  @override
  Widget build(BuildContext context) {
    return const _SoftCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.monetization_on_rounded,
                  title: '획득 코인',
                  value: '120 C',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.diamond_rounded,
                  title: '보스 드랍',
                  value: '희귀 장비',
                ),
              ),
            ],
          ),
          _MessageCard(
            icon: Icons.store_rounded,
            title: '코인으로 장비 구매 &\n스탯 강화',
          ),
          _TagRow(tags: ['코인 보상', '장비 드랍', '상점 강화']),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;

  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8FF),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4F8FA8), size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6C8C9A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C4054),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String label;
  final Color accent;

  const _BadgeCard({
    this.icon,
    this.imagePath,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(imagePath!, fit: BoxFit.contain),
                  )
                : Icon(icon, color: const Color(0xFF1C4054), size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C4054),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;

  const _MessageCard({
    required this.icon,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE2F5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF4F8FA8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C4054),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF597A88),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final List<String> tags;

  const _TagRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F8FA8),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
