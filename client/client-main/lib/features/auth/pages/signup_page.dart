import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';

const _kAuthGold = Color(0xFFF2C94C);
const _kAuthBrown = Color(0xFF7A3E1D);
const _kAuthDark = Color(0xE610130F);
const _kAuthRed = Color(0xFF8F1D1D);

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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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
    } catch (_) {
      _showSnackBar('회원가입 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BackButton(onTap: () => Navigator.pop(context)),
                      ),
                      const SizedBox(height: 12),
                      _SignupPanel(
                        isLoading: _isLoading,
                        nicknameController: _nicknameController,
                        emailController: _emailController,
                        pwController: _pwController,
                        pwConfirmController: _pwConfirmController,
                        obscurePw: _obscurePw,
                        obscurePwConfirm: _obscurePwConfirm,
                        onTogglePw: () {
                          setState(() => _obscurePw = !_obscurePw);
                        },
                        onTogglePwConfirm: () {
                          setState(
                            () => _obscurePwConfirm = !_obscurePwConfirm,
                          );
                        },
                        onSubmit: _signup,
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text(
                          '이미 계정이 있나요? 로그인',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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

class _SignupPanel extends StatelessWidget {
  final bool isLoading;
  final TextEditingController nicknameController;
  final TextEditingController emailController;
  final TextEditingController pwController;
  final TextEditingController pwConfirmController;
  final bool obscurePw;
  final bool obscurePwConfirm;
  final VoidCallback onTogglePw;
  final VoidCallback onTogglePwConfirm;
  final VoidCallback onSubmit;

  const _SignupPanel({
    required this.isLoading,
    required this.nicknameController,
    required this.emailController,
    required this.pwController,
    required this.pwConfirmController,
    required this.obscurePw,
    required this.obscurePwConfirm,
    required this.onTogglePw,
    required this.onTogglePwConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      decoration: BoxDecoration(
        color: _kAuthDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAuthBrown, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            color: _kAuthGold,
            size: 42,
          ),
          const SizedBox(height: 10),
          const Text(
            '모험가 등록',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Galmuri',
              color: _kAuthGold,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
            ),
          ),
          const SizedBox(height: 22),
          _PixelTextField(
            controller: nicknameController,
            label: '닉네임',
            hintText: '닉네임을 입력하세요',
            icon: Icons.person_outline,
            validator: (value) {
              final nickname = value?.trim() ?? '';
              if (nickname.isEmpty) return '닉네임을 입력해주세요.';
              if (nickname.length < 2) return '닉네임은 2자 이상 입력해주세요.';
              if (nickname.length > 12) return '닉네임은 12자 이하로 입력해주세요.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _PixelTextField(
            controller: emailController,
            label: '이메일',
            hintText: '이메일을 입력하세요',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return '이메일을 입력해주세요.';
              if (email.contains(' ')) return '이메일에는 공백을 넣을 수 없습니다.';
              final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(email)) {
                return '올바른 이메일 형식을 입력해주세요.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _PixelTextField(
            controller: pwController,
            label: '비밀번호',
            hintText: '비밀번호를 입력하세요',
            icon: Icons.lock_outline,
            obscureText: obscurePw,
            suffixIcon: _VisibilityButton(
              visible: !obscurePw,
              onTap: isLoading ? null : onTogglePw,
            ),
            validator: (value) {
              final password = value?.trim() ?? '';
              if (password.isEmpty) return '비밀번호를 입력해주세요.';
              if (password.length < 6) return '비밀번호는 6자 이상 입력해주세요.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _PixelTextField(
            controller: pwConfirmController,
            label: '비밀번호 확인',
            hintText: '비밀번호를 다시 입력하세요',
            icon: Icons.lock_reset_outlined,
            obscureText: obscurePwConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => isLoading ? null : onSubmit(),
            suffixIcon: _VisibilityButton(
              visible: !obscurePwConfirm,
              onTap: isLoading ? null : onTogglePwConfirm,
            ),
            validator: (value) {
              final confirm = value?.trim() ?? '';
              if (confirm.isEmpty) return '비밀번호 확인을 입력해주세요.';
              if (confirm != pwController.text.trim()) {
                return '비밀번호가 일치하지 않습니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          _PixelActionButton(
            label: isLoading ? '등록 중...' : '모험 시작',
            onTap: isLoading ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _PixelTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _PixelTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: _kAuthGold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.42),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.34),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: Icon(icon, color: Colors.white70, size: 21),
            suffixIcon: suffixIcon,
            errorMaxLines: 2,
            errorStyle: const TextStyle(
              color: Color(0xFFFFB9A8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kAuthBrown, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kAuthBrown, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kAuthGold, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD24A32), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFFF775F), width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  final bool visible;
  final VoidCallback? onTap;

  const _VisibilityButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: visible ? '비밀번호 숨기기' : '비밀번호 보이기',
      onPressed: onTap,
      icon: Icon(
        visible ? Icons.visibility : Icons.visibility_off,
        color: Colors.white70,
        size: 20,
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kAuthBrown, width: 2),
        ),
        child: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
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
        Container(color: Colors.black.withValues(alpha: 0.5)),
      ],
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
        height: 56,
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
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
