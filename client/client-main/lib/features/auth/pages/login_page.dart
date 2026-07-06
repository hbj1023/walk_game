import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/profile_icon_service.dart';
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
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailNotice;
  String? _passwordNotice;

  static final RegExp _hangulRegex = RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]');
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
      return '한글 입력 상태예요. 영문 이메일로 입력해주세요.';
    }
    if (_isCapsLockEnabled()) {
      return 'Caps Lock이 켜져 있어도 이메일은 소문자로 정리돼요.';
    }
    return null;
  }

  String? _buildPasswordNotice() {
    final text = _pwController.text;
    if (text.isEmpty || !_passwordFocusNode.hasFocus) return null;
    if (_hangulRegex.hasMatch(text)) {
      return '한글 입력 상태예요. 비밀번호 입력 언어를 확인해주세요.';
    }
    if (_isCapsLockEnabled() || _looksLikeCapsLock(text)) {
      return 'Caps Lock이 켜졌을 수 있어요. 대소문자를 확인해주세요.';
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
    final pw = _pwController.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      _showSnackBar('이메일과 비밀번호를 모두 입력해주세요.');
      return;
    }

    if (!email.contains('@')) {
      _showSnackBar('이메일 형식을 확인해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.login(email: email, password: pw);
      ProfileIconService.resetGameStateToDefault();
      await ProfileIconService.loadIntoGameState();

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
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('로그인 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
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
                  focusNode: _emailFocusNode,
                  hintText: '이메일을 입력하세요',
                  icon: Icons.email_outlined,
                  obscureText: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  inputFormatters: const [_EmailLowerCaseFormatter()],
                  noticeText: _emailNotice,
                  onChanged: (_) => _refreshInputNotices(),
                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),

                const SizedBox(height: 14),

                _InputField(
                  controller: _pwController,
                  focusNode: _passwordFocusNode,
                  hintText: '비밀번호를 입력하세요',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  noticeText: _passwordNotice,
                  onChanged: (_) => _refreshInputNotices(),
                  onSubmitted: (_) => _login(),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? '비밀번호 보이기' : '비밀번호 숨기기',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF4F8FA8),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                  ),
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
                  onPressed: _isLoading ? null : _goToSignUp,
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
  final FocusNode? focusNode;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? noticeText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.icon,
    required this.obscureText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.noticeText,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 58,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
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
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: noticeText == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(noticeText),
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3C4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2B852)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFF7A5314),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              noticeText!,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B4710),
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
    final lowered = newValue.text.toLowerCase();
    if (lowered == newValue.text) return newValue;
    return newValue.copyWith(text: lowered, composing: TextRange.empty);
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
