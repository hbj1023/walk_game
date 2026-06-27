import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/auth/pages/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pw = _pwController.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.login(email: email, password: pw);

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, _) => const HomePage(),
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
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) =>
            SignupPage(initialEmail: _emailController.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF71C6E4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 40),

                Image.asset(
                  'assets/images/logo/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 28),

                const Text(
                  '환영합니다',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  '걷는 순간, 모험이 시작됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 36),

                _InputField(
                  controller: _emailController,
                  hintText: '이메일을 입력하세요',
                  icon: Icons.email_outlined,
                  obscureText: false,
                ),

                const SizedBox(height: 14),

                _InputField(
                  controller: _pwController,
                  hintText: '비밀번호를 입력하세요',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),

                const SizedBox(height: 18),

                _ActionButton(
                  text: _isLoading ? '로그인 중...' : '로그인',
                  backgroundColor: const Color(0xFF4F8FA8),
                  textColor: Colors.white,
                  icon: Icons.login,
                  onTap: _isLoading ? null : _login,
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: _goToSignUp,
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  '로그인 시 서비스 이용약관 및 개인정보처리방침에 동의한 것으로 간주됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white70,
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

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF202124),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xFF4F8FA8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
