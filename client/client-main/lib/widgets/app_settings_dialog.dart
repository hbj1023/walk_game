import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/support_service.dart';

const _kPanelBg = Color(0xFF1A1A1A);
const _kInnerBg = Color(0xFF140C08);
const _kBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFFFD15C);
const _kRed = Color(0xFF7A1A1A);
const _kBlue = Color(0xFF245A8F);

class AppSettingsDialog extends StatefulWidget {
  final Future<void> Function() onLogout;
  final Future<void> Function() onAccountDeleted;

  const AppSettingsDialog({
    super.key,
    required this.onLogout,
    required this.onAccountDeleted,
  });

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  AppSettingsData _settings = const AppSettingsData.defaults();
  bool _isLoading = true;
  String _email = '';
  String _name = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      AppSettingsService.load(),
      AuthService.getSavedEmail(),
      AuthService.getSavedName(),
    ]);
    if (!mounted) return;
    setState(() {
      _settings = results[0] as AppSettingsData;
      _email = (results[1] as String?)?.trim() ?? '';
      _name = (results[2] as String?)?.trim() ?? '';
      _isLoading = false;
    });
  }

  Future<void> _save(AppSettingsData settings) async {
    setState(() => _settings = settings);
    await AppSettingsService.save(settings);
  }

  Future<void> _openSoundSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _SoundSettingsDialog(settings: _settings, onChanged: _save),
    );
  }

  Future<void> _openCustomerCenter() async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerCenterDialog(email: _email, name: _name),
    );
    if (deleted != true || !mounted) return;
    Navigator.pop(context);
    await widget.onAccountDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      title: '설정',
      icon: Icons.settings,
      maxWidth: 420,
      child: _isLoading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator(color: _kGold)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuTile(
                  icon: Icons.volume_up,
                  title: '사운드 설정',
                  subtitle: _settings.soundEnabled
                      ? '볼륨 ${(_settings.masterVolume * 100).round()}%'
                      : '전체 사운드 꺼짐',
                  onTap: _openSoundSettings,
                ),
                const SizedBox(height: 8),
                _powerTile(),
                const SizedBox(height: 8),
                _menuTile(
                  icon: Icons.support_agent,
                  title: '고객센터',
                  subtitle: '버그 제보, 계정 삭제',
                  onTap: _openCustomerCenter,
                ),
                const SizedBox(height: 12),
                _fullWidthButton(
                  icon: Icons.logout,
                  label: '로그아웃',
                  color: _kRed,
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.onLogout();
                  },
                ),
              ],
            ),
    );
  }

  Widget _powerTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Icon(Icons.battery_saver, color: _kGold, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '절전 모드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '이동 중 배터리 사용을 줄입니다.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _settings.powerSavingMode,
            activeThumbColor: _kGold,
            onChanged: (value) =>
                _save(_settings.copyWith(powerSavingMode: value)),
          ),
        ],
      ),
    );
  }
}

class _SoundSettingsDialog extends StatefulWidget {
  final AppSettingsData settings;
  final Future<void> Function(AppSettingsData settings) onChanged;

  const _SoundSettingsDialog({required this.settings, required this.onChanged});

  @override
  State<_SoundSettingsDialog> createState() => _SoundSettingsDialogState();
}

class _SoundSettingsDialogState extends State<_SoundSettingsDialog> {
  late AppSettingsData _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  Future<void> _save(AppSettingsData settings) async {
    setState(() => _settings = settings);
    await widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      title: '사운드 설정',
      icon: Icons.volume_up,
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _switchRow(
            label: '전체 사운드',
            value: _settings.soundEnabled,
            onChanged: (value) =>
                _save(_settings.copyWith(soundEnabled: value)),
          ),
          _switchRow(
            label: '배경음',
            value: _settings.bgmEnabled,
            enabled: _settings.soundEnabled,
            onChanged: (value) => _save(_settings.copyWith(bgmEnabled: value)),
          ),
          _switchRow(
            label: '효과음',
            value: _settings.sfxEnabled,
            enabled: _settings.soundEnabled,
            onChanged: (value) => _save(_settings.copyWith(sfxEnabled: value)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '볼륨',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: _settings.masterVolume,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  activeColor: _kGold,
                  inactiveColor: Colors.white.withValues(alpha: 0.16),
                  onChanged: _settings.soundEnabled
                      ? (value) =>
                            _save(_settings.copyWith(masterVolume: value))
                      : null,
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '${(_settings.masterVolume * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerCenterDialog extends StatefulWidget {
  final String email;
  final String name;

  const _CustomerCenterDialog({required this.email, required this.name});

  @override
  State<_CustomerCenterDialog> createState() => _CustomerCenterDialogState();
}

class _CustomerCenterDialogState extends State<_CustomerCenterDialog> {
  final _screenController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _notice;
  bool _noticeSuccess = true;

  @override
  void dispose() {
    _screenController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (_isSubmitting) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        _noticeSuccess = false;
        _notice = '제보 내용을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _notice = null;
    });
    try {
      await SupportService.submitBugReport(
        screen: _screenController.text,
        message: message,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _isSubmitting = false;
        _noticeSuccess = true;
        _notice = '버그 제보를 보냈습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _noticeSuccess = false;
        _notice = e.toString();
      });
    }
  }

  Future<void> _openDeleteDialog() async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountDeleteDialog(email: widget.email),
    );
    if (deleted == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _copyEmail() async {
    if (widget.email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.email));
    if (!mounted) return;
    setState(() {
      _noticeSuccess = true;
      _notice = '이메일을 복사했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayEmail = widget.email.isEmpty ? '로그인 정보 없음' : widget.email;
    return _SettingsShell(
      title: '고객센터',
      icon: Icons.support_agent,
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBox(
            label: '내 이메일',
            value: displayEmail,
            actionLabel: widget.email.isEmpty ? null : '복사',
            onTap: widget.email.isEmpty ? null : _copyEmail,
          ),
          if (widget.name.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoBox(label: '닉네임', value: widget.name),
          ],
          const SizedBox(height: 12),
          _subTitle('버그 제보'),
          const SizedBox(height: 8),
          _darkTextField(
            controller: _screenController,
            label: '발생 화면',
            hint: '예: 상점, 레이드, 전투',
            maxLength: 80,
          ),
          const SizedBox(height: 8),
          _darkTextField(
            controller: _messageController,
            label: '내용',
            hint: '무엇을 하다가 어떤 문제가 생겼는지 짧게 적어주세요.',
            minLines: 4,
            maxLines: 5,
            maxLength: 1000,
          ),
          if (_notice != null) ...[
            const SizedBox(height: 8),
            _noticeBox(_notice!, _noticeSuccess),
          ],
          const SizedBox(height: 10),
          _fullWidthButton(
            icon: Icons.send,
            label: _isSubmitting ? '전송 중' : '제보 보내기',
            color: _kBlue,
            onTap: _isSubmitting ? null : _submitBugReport,
          ),
          const SizedBox(height: 12),
          _fullWidthButton(
            icon: Icons.person_remove,
            label: '계정 삭제',
            color: _kRed,
            onTap: _openDeleteDialog,
          ),
        ],
      ),
    );
  }
}

class _AccountDeleteDialog extends StatefulWidget {
  final String email;

  const _AccountDeleteDialog({required this.email});

  @override
  State<_AccountDeleteDialog> createState() => _AccountDeleteDialogState();
}

class _AccountDeleteDialogState extends State<_AccountDeleteDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canDelete {
    final passwordOk = _passwordController.text.trim().isNotEmpty;
    if (widget.email.isEmpty) return passwordOk;
    return passwordOk &&
        _emailController.text.trim().toLowerCase() ==
            widget.email.trim().toLowerCase();
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete || _isDeleting) return;
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await AuthService.deleteAccount(
        email: widget.email.isEmpty ? null : _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      title: '계정 삭제',
      icon: Icons.person_remove,
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '계정을 삭제하면 캐릭터와 진행 정보를 복구하기 어렵습니다. 계속하려면 현재 계정 정보를 확인해주세요.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          if (widget.email.isNotEmpty) ...[
            const SizedBox(height: 12),
            _darkTextField(
              controller: _emailController,
              label: '이메일 확인',
              hint: widget.email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 8),
          _darkTextField(
            controller: _passwordController,
            label: '비밀번호',
            hint: '현재 비밀번호',
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _noticeBox(_error!, false),
          ],
          const SizedBox(height: 12),
          _fullWidthButton(
            icon: Icons.delete_forever,
            label: _isDeleting ? '삭제 중' : '삭제하기',
            color: _kRed,
            onTap: _canDelete && !_isDeleting ? _deleteAccount : null,
          ),
        ],
      ),
    );
  }
}

class _SettingsShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final double maxWidth;
  final Widget child;

  const _SettingsShell({
    required this.title,
    required this.icon,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 680),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, color: _kGold, size: 19),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _menuTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Icon(icon, color: _kGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
        ],
      ),
    ),
  );
}

Widget _switchRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
  bool enabled = true,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: _panelDecoration(),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white70 : Colors.white30,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: _kGold,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    ),
  );
}

Widget _fullWidthButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback? onTap,
}) {
  final enabled = onTap != null;
  return GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoBox({
  required String label,
  required String value,
  String? actionLabel,
  VoidCallback? onTap,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: _panelDecoration(),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: _kGold, fontSize: 11)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: Color(0xFF9EDBFF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _subTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w900,
    ),
  );
}

Widget _darkTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  int minLines = 1,
  int maxLines = 1,
  int? maxLength,
  bool obscureText = false,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    minLines: obscureText ? 1 : minLines,
    maxLines: obscureText ? 1 : maxLines,
    maxLength: maxLength,
    obscureText: obscureText,
    keyboardType: keyboardType,
    onChanged: onChanged,
    style: const TextStyle(color: Colors.white, fontSize: 12),
    cursorColor: _kGold,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _kGold, fontSize: 12),
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
      counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.26),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kGold),
      ),
    ),
  );
}

Widget _noticeBox(String message, bool success) {
  final color = success ? _kGold : const Color(0xFFFF6B5A);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.65)),
    ),
    child: Text(
      message,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: _kInnerBg,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _kBorder),
  );
}
