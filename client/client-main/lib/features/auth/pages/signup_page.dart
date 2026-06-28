import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';

class SignupPage extends StatefulWidget {
  final String initialEmail;

  const SignupPage({super.key, this.initialEmail = ''});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();

  bool _obscurePw = true;
  bool _obscurePwConfirm = true;
  bool _isLoading = false;

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _pwController.text.trim();
      final nickname = _nicknameController.text.trim();

      await AuthService.register(
        email: email,
        password: password,
        name: nickname,
      );

      if (!mounted) return;

      Navigator.pop(context, email);
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('회원가입 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입'), centerTitle: true),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Image.asset(
                    'assets/images/logo/logo.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '새 계정을 만들어보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '회원정보를 입력하고 가입을 진행하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      label: '이메일',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일을 입력해주세요.';
                      }
                      if (value.trim().contains(' ')) {
                        return '이메일에는 공백을 넣을 수 없습니다.';
                      }
                      final emailRegex = RegExp(
                        r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return '올바른 이메일 형식을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nicknameController,
                    decoration: _inputDecoration(
                      label: '닉네임',
                      icon: Icons.person_outline,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '닉네임을 입력해주세요.';
                      }
                      final nickname = value.trim();
                      if (nickname.length < 2) {
                        return '닉네임은 2자 이상 입력해주세요.';
                      }
                      if (nickname.length > 12) {
                        return '닉네임은 12자 이하로 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _pwController,
                    obscureText: _obscurePw,
                    decoration: _inputDecoration(
                      label: '비밀번호',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePw ? Icons.visibility_off : Icons.visibility,
                        ),
                        tooltip: _obscurePw ? '비밀번호 보이기' : '비밀번호 숨기기',
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePw = !_obscurePw;
                                });
                              },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }
                      if (value.trim().length < 6) {
                        return '비밀번호는 6자 이상 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _pwConfirmController,
                    obscureText: _obscurePwConfirm,
                    decoration: _inputDecoration(
                      label: '비밀번호 확인',
                      icon: Icons.lock_reset_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePwConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        tooltip: _obscurePwConfirm ? '비밀번호 보이기' : '비밀번호 숨기기',
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePwConfirm = !_obscurePwConfirm;
                                });
                              },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '비밀번호 확인을 입력해주세요.';
                      }
                      if (value.trim() != _pwController.text.trim()) {
                        return '비밀번호가 일치하지 않습니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: const Text('이미 계정이 있나요? 로그인으로 돌아가기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
