import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/auth_service.dart';

const _kPanelBg = Color(0xFF1A1A1A);
const _kInnerBg = Color(0xFF140C08);
const _kBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFFFD15C);
const _kRed = Color(0xFF7A1A1A);

class AppSettingsDialog extends StatefulWidget {
  final Future<void> Function() onLogout;

  const AppSettingsDialog({super.key, required this.onLogout});

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

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder, width: 2),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: _kGold),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 12),
                      _buildSoundSection(),
                      const SizedBox(height: 10),
                      _buildPowerSection(),
                      const SizedBox(height: 10),
                      _buildSupportSection(),
                      const SizedBox(height: 10),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          '설정',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.white54, size: 20),
        ),
      ],
    );
  }

  Widget _buildSoundSection() {
    return _section(
      title: '사운드',
      icon: Icons.volume_up,
      children: [
        _switchRow(
          label: '전체 사운드',
          value: _settings.soundEnabled,
          onChanged: (value) => _save(_settings.copyWith(soundEnabled: value)),
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
        const SizedBox(height: 4),
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
                    ? (value) => _save(_settings.copyWith(masterVolume: value))
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
    );
  }

  Widget _buildPowerSection() {
    return _section(
      title: '절전',
      icon: Icons.battery_saver,
      children: [
        _switchRow(
          label: '절전 모드',
          value: _settings.powerSavingMode,
          onChanged: (value) =>
              _save(_settings.copyWith(powerSavingMode: value)),
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    final displayEmail = _email.isEmpty ? '로그인 정보 없음' : _email;
    return _section(
      title: '고객센터',
      icon: Icons.support_agent,
      children: [
        _infoRow(
          label: '내 이메일',
          value: displayEmail,
          actionLabel: '복사',
          onTap: _email.isEmpty ? null : () => _copy(_email, '이메일을 복사했습니다.'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.bug_report,
                label: '버그 제보',
                onTap: _showBugReportDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionButton(
                icon: Icons.person_remove,
                label: '계정 삭제',
                color: _kRed,
                onTap: _showAccountDeleteDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await widget.onLogout();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _kRed,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A0E0E), width: 1.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              '로그아웃',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kInnerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _kGold, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white70 : Colors.white30,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: _kGold,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    required String actionLabel,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
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
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: TextStyle(
                color: onTap == null ? Colors.white24 : const Color(0xFF9EDBFF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF245A8F),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.75)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBugReportDialog() {
    final template = [
      '[버그 제보]',
      '계정 이메일: ${_email.isEmpty ? "" : _email}',
      '닉네임: ${_name.isEmpty ? "" : _name}',
      '발생 화면:',
      '증상:',
      '재현 방법:',
      '스크린샷 여부:',
    ].join('\n');
    _showSupportTemplateDialog(
      title: '버그 제보',
      icon: Icons.bug_report,
      body: '아래 양식을 복사해서 증상과 화면을 같이 적어주세요.',
      template: template,
      copiedMessage: '버그 제보 양식을 복사했습니다.',
    );
  }

  void _showAccountDeleteDialog() {
    final template = [
      '[계정 삭제 요청]',
      '계정 이메일: ${_email.isEmpty ? "" : _email}',
      '닉네임: ${_name.isEmpty ? "" : _name}',
      '삭제 요청 확인: 계정과 진행 데이터를 삭제해도 됩니다.',
      '요청 사유:',
    ].join('\n');
    _showSupportTemplateDialog(
      title: '계정 삭제',
      icon: Icons.person_remove,
      body: '계정 삭제는 복구가 어려우니 요청 내용을 한 번 더 확인해주세요.',
      template: template,
      copiedMessage: '계정 삭제 요청 양식을 복사했습니다.',
    );
  }

  void _showSupportTemplateDialog({
    required String title,
    required IconData icon,
    required String body,
    required String template,
    required String copiedMessage,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: _kGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  template,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _actionButton(
                icon: Icons.copy,
                label: '양식 복사',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _copy(template, copiedMessage);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
