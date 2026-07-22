import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capstone_app/features/auth/pages/signup_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/profile_icon_service.dart';

const _kAuthGold = Color(0xFFF2C94C);
const _kAuthBrown = Color(0xFF7A3E1D);
const _kAuthDark = Color(0xCC10251B);
const _kAuthField = Color(0xAA06120C);
const _kAuthRed = Color(0xFF8F1D1D);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailNotice;
  String? _passwordNotice;

  static final RegExp _hangulRegex = RegExp(r'[가-힣]');
  static final RegExp _upperAlphaRegex = RegExp(r'[A-Z]');
  static final RegExp _lowerAlphaRegex = RegExp(r'[a-z]');

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refreshInputNotices);
    _pwController.addListener(_refreshInputNotices);
    _emailFocusNode.addListener(_refreshInputNotices);
    _passwordFocusNode.addListener(_refreshInputNotices);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refreshInputNotices);
    _pwController.removeListener(_refreshInputNotices);
    _emailFocusNode.removeListener(_refreshInputNotices);
    _passwordFocusNode.removeListener(_refreshInputNotices);
    _emailController.dispose();
    _pwController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _refreshInputNotices() {
    final nextEmailNotice = _buildEmailNotice();
    final nextPasswordNotice = _buildPasswordNotice();
    if (_emailNotice == nextEmailNotice &&
        _passwordNotice == nextPasswordNotice) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _emailNotice = nextEmailNotice;
      _passwordNotice = nextPasswordNotice;
    });
  }

  String? _buildEmailNotice() {
    final text = _emailController.text;
    if (text.isEmpty || !_emailFocusNode.hasFocus) return null;
    if (_hangulRegex.hasMatch(text)) {
      return '한글 입력 상태입니다. 영문 이메일로 입력해주세요.';
    }
    if (_isCapsLockEnabled()) {
      return 'Caps Lock이 켜져 있습니다. 이메일을 소문자로 확인해주세요.';
    }
    return null;
  }

  String? _buildPasswordNotice() {
    final text = _pwController.text;
    if (text.isEmpty || !_passwordFocusNode.hasFocus) return null;
    if (_hangulRegex.hasMatch(text)) {
      return '한글 입력 상태입니다. 비밀번호 입력 언어를 확인해주세요.';
    }
    if (_isCapsLockEnabled() || _looksLikeCapsLock(text)) {
      return 'Caps Lock이 켜져 있을 수 있습니다.';
    }
    return null;
  }

  bool _isCapsLockEnabled() {
    return HardwareKeyboard.instance.lockModesEnabled.contains(
      KeyboardLockMode.capsLock,
    );
  }

  bool _looksLikeCapsLock(String text) {
    final lettersOnly = text.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (lettersOnly.length < 2) return false;
    return _upperAlphaRegex.hasMatch(lettersOnly) &&
        !_lowerAlphaRegex.hasMatch(lettersOnly);
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _pwController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('이메일과 비밀번호를 모두 입력해주세요.');
      return;
    }
    if (!email.contains('@')) {
      _showSnackBar('이메일 형식을 확인해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.login(email: email, password: password);
      AppSettingsService.resetPowerSavingAfterLogin();
      ProfileIconService.resetGameStateToDefault();
      await ProfileIconService.loadIntoGameState();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, _) => const HomePage(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('로그인 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _goToSignUp() async {
    if (_isLoading) return;

    final signedUpEmail = await Navigator.push<String>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) =>
            SignupPage(initialEmail: _emailController.text.trim()),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );

    if (!mounted) return;
    if (signedUpEmail != null && signedUpEmail.isNotEmpty) {
      _emailController.text = signedUpEmail;
      _pwController.clear();
      _showSnackBar('회원가입이 완료되었습니다. 방금 만든 계정으로 로그인해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F6B3D),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 22),
                    _LoginPanel(
                      isLoading: _isLoading,
                      emailController: _emailController,
                      passwordController: _pwController,
                      emailFocusNode: _emailFocusNode,
                      passwordFocusNode: _passwordFocusNode,
                      obscurePassword: _obscurePassword,
                      emailNotice: _emailNotice,
                      passwordNotice: _passwordNotice,
                      onTogglePassword: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      onLogin: _login,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _isLoading ? null : _goToSignUp,
                      child: const Text(
                        '처음 오셨나요? 모험가 등록',
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
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final String? emailNotice;
  final String? passwordNotice;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  const _LoginPanel({
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.emailNotice,
    required this.passwordNotice,
    required this.onTogglePassword,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
      decoration: BoxDecoration(
        color: _kAuthDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAuthBrown, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A120D).withValues(alpha: 0.34),
            blurRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'assets/images/logo/logo.png',
            width: 94,
            height: 94,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 14),
          const Text(
            '모험가 로그인',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Galmuri',
              color: _kAuthGold,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '걸음으로 성장하는 모험을 이어가세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          _PixelTextField(
            controller: emailController,
            focusNode: emailFocusNode,
            label: '이메일',
            hintText: '이메일을 입력하세요',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            inputFormatters: const [_EmailLowerCaseFormatter()],
            noticeText: emailNotice,
            onChanged: (_) {},
            onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: 14),
          _PixelTextField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            label: '비밀번호',
            hintText: '비밀번호를 입력하세요',
            icon: Icons.lock_outline,
            obscureText: obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            noticeText: passwordNotice,
            onChanged: (_) {},
            onFieldSubmitted: (_) => isLoading ? null : onLogin(),
            suffixIcon: _VisibilityButton(
              visible: !obscurePassword,
              onTap: isLoading ? null : onTogglePassword,
            ),
          ),
          const SizedBox(height: 22),
          _PixelActionButton(
            label: isLoading ? '로그인 중...' : '로그인',
            onTap: isLoading ? null : onLogin,
          ),
        ],
      ),
    );
  }
}

class _PixelTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? noticeText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  const _PixelTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.noticeText,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
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
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          onChanged: onChanged,
          onSubmitted: onFieldSubmitted,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kAuthField,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.34),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: Icon(icon, color: Colors.white70, size: 21),
            suffixIcon: suffixIcon,
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
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: noticeText == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(noticeText),
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    noticeText!,
                    style: const TextStyle(
                      color: Color(0xFFFFD86E),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/bg/home_bg.png', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x330A120D), Color(0x221C4E2F), Color(0x112F6B3D)],
            ),
          ),
        ),
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

class _EmailLowerCaseFormatter extends TextInputFormatter {
  const _EmailLowerCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lower = newValue.text.toLowerCase();
    if (lower == newValue.text) return newValue;
    return newValue.copyWith(
      text: lower,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, lower.length),
      ),
      composing: TextRange.empty,
    );
  }
}
