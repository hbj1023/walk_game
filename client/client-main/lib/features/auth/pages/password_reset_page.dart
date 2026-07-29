import 'package:flutter/material.dart';

import 'package:capstone_app/features/auth/pages/login_page.dart';
import 'package:capstone_app/services/auth_service.dart';

const _kGold = Color(0xFFF2C94C);
const _kBrown = Color(0xFF7A3E1D);
const _kDark = Color(0xE610251B);
const _kField = Color(0xCC06120C);
const _kRed = Color(0xFF8F1D1D);

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({required this.token, super.key});

  final String token;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;
    if (password.length < 8) {
      setState(() => _errorMessage = '비밀번호는 8자 이상 입력해주세요.');
      return;
    }
    if (password != passwordConfirm) {
      setState(() => _errorMessage = '비밀번호가 서로 일치하지 않습니다.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final message = await AuthService.confirmPasswordReset(
        token: widget.token,
        password: password,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF10251B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _kBrown, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: _kGold),
              SizedBox(width: 10),
              Text(
                '변경 완료',
                style: TextStyle(color: _kGold, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, height: 1.45),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(backgroundColor: _kRed),
              child: const Text('로그인으로 이동'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = '비밀번호 변경 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F6B3D),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg/home_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0x5506120C))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
                  decoration: BoxDecoration(
                    color: _kDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBrown, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, offset: Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        color: _kGold,
                        size: 44,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '새 비밀번호 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kGold,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '새로 사용할 비밀번호를 입력해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      _PasswordField(
                        controller: _passwordController,
                        label: '새 비밀번호',
                        obscureText: _obscurePassword,
                        enabled: !_isSubmitting,
                        onToggleVisibility: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _PasswordField(
                        controller: _passwordConfirmController,
                        label: '새 비밀번호 확인',
                        obscureText: _obscurePasswordConfirm,
                        enabled: !_isSubmitting,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        onToggleVisibility: () {
                          setState(() {
                            _obscurePasswordConfirm = !_obscurePasswordConfirm;
                          });
                        },
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: _errorMessage == null
                            ? const SizedBox(height: 18)
                            : Padding(
                                key: ValueKey(_errorMessage),
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFF8B7C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.key_rounded),
                        label: Text(
                          _isSubmitting ? '변경 중...' : '비밀번호 변경',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF555555),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                              color: Color(0xFF4A0E0E),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                  (_) => false,
                                );
                              },
                        child: const Text(
                          '로그인으로 돌아가기',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.enabled,
    required this.onToggleVisibility,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final bool enabled;
  final VoidCallback onToggleVisibility;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: _kField,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          tooltip: obscureText ? '비밀번호 보이기' : '비밀번호 숨기기',
          onPressed: enabled ? onToggleVisibility : null,
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kBrown),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kBrown),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kGold, width: 2),
        ),
      ),
    );
  }
}
