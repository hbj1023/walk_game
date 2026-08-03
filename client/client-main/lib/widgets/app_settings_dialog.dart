import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:capstone_app/services/app_settings_service.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/support_service.dart';

const _kPanelBg = Color(0xFF1A1A1A);
const _kInnerBg = Color(0xFF140C08);
const _kBorder = Color(0xFF6B3A1F);
const _kGold = Color(0xFFFFD15C);
const _kRed = Color(0xFF7A1A1A);
const _kBlue = Color(0xFF245A8F);
const _kChapter1HomeBg = 'assets/images/bg/home_bg.png';
const _kChapter2HomeBg = 'assets/images/bg/home_bg_chapter2_shadow_forest.png';
const _kChapter3HomeBg = 'assets/images/bg/home_bg_chapter3_ancient_quarry.png';

Future<void> _dismissKeyboard() async {
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  } catch (_) {
    // The text input channel can already be detached while a dialog is closing.
  }
}

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
  bool _chapter2BackgroundUnlocked = false;
  bool _chapter3BackgroundUnlocked = false;

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
    var chapter2Unlocked = false;
    var chapter3Unlocked = false;
    try {
      final stages = await BattleApiService.fetchNormalStages();
      chapter2Unlocked =
          stages.any((stage) => stage.stageNo >= 6 && stage.isUnlocked) ||
          stages.any((stage) => stage.stageNo == 5 && stage.isCleared);
      chapter3Unlocked =
          stages.any((stage) => stage.stageNo >= 11 && stage.isUnlocked) ||
          stages.any((stage) => stage.stageNo == 10 && stage.isCleared);
    } catch (_) {
      chapter2Unlocked = false;
      chapter3Unlocked = false;
    }
    if (!mounted) return;
    setState(() {
      _settings = results[0] as AppSettingsData;
      _email = (results[1] as String?)?.trim() ?? '';
      _name = (results[2] as String?)?.trim() ?? '';
      _chapter2BackgroundUnlocked = chapter2Unlocked;
      _chapter3BackgroundUnlocked = chapter3Unlocked;
      _isLoading = false;
    });
  }

  Future<void> _save(AppSettingsData settings) async {
    setState(() => _settings = settings);
    await AppSettingsService.save(settings);
  }

  Future<void> _setPowerSavingMode(bool enabled) async {
    await _save(_settings.copyWith(powerSavingMode: enabled));
    if (enabled && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSoundSettings() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) =>
          _SoundSettingsDialog(settings: _settings, onChanged: _save),
    );
  }

  Future<void> _openNotificationSettings() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) =>
          _NotificationSettingsDialog(settings: _settings, onChanged: _save),
    );
  }

  Future<void> _openBackgroundSettings() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _BackgroundSettingsDialog(
        settings: _settings,
        chapter2Unlocked: _chapter2BackgroundUnlocked,
        chapter3Unlocked: _chapter3BackgroundUnlocked,
        onChanged: _save,
      ),
    );
  }

  Future<void> _openCustomerCenter() async {
    await _dismissKeyboard();
    if (!mounted) return;
    final deleted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _CustomerCenterDialog(email: _email, name: _name),
    );
    await _dismissKeyboard();
    if (deleted != true || !mounted) return;
    Navigator.pop(context);
    await widget.onAccountDeleted();
  }

  Future<void> _openPrivacyPolicy() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const _PrivacyPolicyDialog(),
    );
  }

  String get _backgroundSubtitle {
    switch (_settings.homeBackgroundChapter) {
      case AppSettingsData.homeBackgroundChapter1:
        return '1장 배경';
      case AppSettingsData.homeBackgroundChapter2:
        return _chapter2BackgroundUnlocked ? '2장 배경' : '2장 배경 잠김';
      case AppSettingsData.homeBackgroundChapter3:
        return _chapter3BackgroundUnlocked ? '3장 배경' : '3장 배경 잠김';
      default:
        return _chapter3BackgroundUnlocked
            ? '자동: 가장 높은 장'
            : (_chapter2BackgroundUnlocked ? '자동: 가장 높은 장' : '자동: 1장');
    }
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
                _menuTile(
                  icon: Icons.notifications_active,
                  title: '알림 설정',
                  subtitle: _settings.allowNightNotifications
                      ? '5시간마다 · 야간 알림 허용'
                      : '5시간마다 · 야간 알림 제외',
                  onTap: _openNotificationSettings,
                ),
                const SizedBox(height: 8),
                _menuTile(
                  icon: Icons.landscape,
                  title: '홈 배경',
                  subtitle: _backgroundSubtitle,
                  onTap: _openBackgroundSettings,
                ),
                const SizedBox(height: 8),
                _powerTile(),
                const SizedBox(height: 8),
                _menuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: '개인정보 처리방침',
                  subtitle: '수집 정보와 이용 목적 확인',
                  onTap: _openPrivacyPolicy,
                ),
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
      child: Column(
        children: [
          Row(
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
                      '화면 효과를 줄여 배터리 사용을 낮춥니다.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _settings.powerSavingMode,
                activeThumbColor: _kGold,
                onChanged: _setPowerSavingMode,
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '자동 절전',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              DropdownButton<int>(
                value: _settings.autoPowerSavingMinutes,
                dropdownColor: _kPanelBg,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  color: _kGold,
                  fontFamily: 'Galmuri',
                  fontSize: 12,
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('사용 안 함')),
                  DropdownMenuItem(value: 3, child: Text('3분')),
                  DropdownMenuItem(value: 5, child: Text('5분')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _save(_settings.copyWith(autoPowerSavingMinutes: value));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyPolicyDialog extends StatelessWidget {
  const _PrivacyPolicyDialog();

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      title: '개인정보 처리방침',
      icon: Icons.privacy_tip_outlined,
      maxWidth: 480,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시행일: 2026년 8월 3일',
            style: TextStyle(color: _kGold, fontSize: 12),
          ),
          SizedBox(height: 12),
          _PrivacySection(
            title: '수집하는 정보',
            body:
                '계정 생성과 로그인을 위해 이메일, 닉네임, 사용자 식별자를 처리합니다. 사용자가 선택하면 프로필 이미지를 저장합니다. 게임 진행을 위해 레벨, 장비, 재화, 전투 및 미션 기록을 저장합니다.',
          ),
          _PrivacySection(
            title: '걸음 및 위치 정보',
            body:
                '걸음 수와 활동 인식 정보는 이동 기반 게임 기능과 오프라인 공격 기회 계산에 사용됩니다. 위치 좌표는 이동 거리 확인과 부정 이용 방지를 위해 기기에서 처리하며, 서버에는 걸음 수와 계산된 이동 거리 및 판정 결과만 전송합니다.',
          ),
          _PrivacySection(
            title: '알림과 고객센터',
            body:
                '알림 권한은 오프라인 공격 기회가 가득 찼을 때 안내하는 데 사용합니다. 고객센터 제보에는 계정 정보와 사용자가 작성한 화면명 및 제보 내용이 포함됩니다.',
          ),
          _PrivacySection(
            title: '보관과 삭제',
            body:
                '정보는 서비스 제공에 필요한 기간 동안 보관합니다. 설정의 고객센터에서 계정을 즉시 삭제하거나, 앱을 사용할 수 없다면 https://walk-master.com/delete-account.html 에서 삭제를 요청할 수 있습니다. 삭제가 완료되면 계정과 연결된 게임 데이터가 삭제됩니다. 법적 의무 또는 보안상 필요한 기록은 해당 목적에 필요한 기간 동안만 별도로 보관할 수 있습니다.',
          ),
          _PrivacySection(
            title: '제3자 제공과 보호',
            body:
                '개인정보를 판매하지 않습니다. 비밀번호 재설정 메일과 사용자가 선택한 외부 로그인 기능을 제공하는 데 필요한 범위에서만 관련 서비스 제공자가 정보를 처리할 수 있습니다. 통신은 HTTPS로 암호화합니다.',
          ),
          _PrivacySection(
            title: '문의',
            body:
                '개인정보 열람, 정정, 삭제 및 기타 문의는 설정의 고객센터에서 접수할 수 있습니다. 최신 방침은 https://walk-master.com/privacy.html 에서도 확인할 수 있습니다.',
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
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
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.55,
            ),
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

class _NotificationSettingsDialog extends StatefulWidget {
  final AppSettingsData settings;
  final Future<void> Function(AppSettingsData settings) onChanged;

  const _NotificationSettingsDialog({
    required this.settings,
    required this.onChanged,
  });

  @override
  State<_NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<_NotificationSettingsDialog> {
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
      title: '알림 설정',
      icon: Icons.notifications_active,
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: _panelDecoration(),
            child: const Row(
              children: [
                Icon(Icons.hourglass_full, color: _kGold, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '공격 기회 가득 참 알림',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text('5시간마다', style: TextStyle(color: _kGold, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _switchRow(
            label: '야간 알림 허용',
            value: _settings.allowNightNotifications,
            onChanged: (value) =>
                _save(_settings.copyWith(allowNightNotifications: value)),
          ),
          if (!_settings.allowNightNotifications) ...[
            const SizedBox(height: 8),
            const Text(
              '밤 10시부터 오전 8시까지 알림을 보내지 않습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackgroundSettingsDialog extends StatefulWidget {
  final AppSettingsData settings;
  final bool chapter2Unlocked;
  final bool chapter3Unlocked;
  final Future<void> Function(AppSettingsData settings) onChanged;

  const _BackgroundSettingsDialog({
    required this.settings,
    required this.chapter2Unlocked,
    required this.chapter3Unlocked,
    required this.onChanged,
  });

  @override
  State<_BackgroundSettingsDialog> createState() =>
      _BackgroundSettingsDialogState();
}

class _BackgroundSettingsDialogState extends State<_BackgroundSettingsDialog> {
  late AppSettingsData _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  Future<void> _select(int chapter) async {
    if (chapter == AppSettingsData.homeBackgroundChapter2 &&
        !widget.chapter2Unlocked) {
      return;
    }
    if (chapter == AppSettingsData.homeBackgroundChapter3 &&
        !widget.chapter3Unlocked) {
      return;
    }
    final next = _settings.copyWith(homeBackgroundChapter: chapter);
    setState(() => _settings = next);
    await widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      title: '홈 배경',
      icon: Icons.landscape,
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _backgroundOption(
            title: '자동',
            subtitle: '열려있는 가장 높은 장 배경으로 변경',
            assetPath: widget.chapter3Unlocked
                ? _kChapter3HomeBg
                : (widget.chapter2Unlocked
                      ? _kChapter2HomeBg
                      : _kChapter1HomeBg),
            value: AppSettingsData.homeBackgroundAuto,
            enabled: true,
          ),
          const SizedBox(height: 8),
          _backgroundOption(
            title: '1장 배경',
            subtitle: '튜토리얼 초원',
            assetPath: _kChapter1HomeBg,
            value: AppSettingsData.homeBackgroundChapter1,
            enabled: true,
          ),
          const SizedBox(height: 8),
          _backgroundOption(
            title: '2장 배경',
            subtitle: widget.chapter2Unlocked ? '그림자 숲' : '2장 해금 후 선택 가능',
            assetPath: _kChapter2HomeBg,
            value: AppSettingsData.homeBackgroundChapter2,
            enabled: widget.chapter2Unlocked,
          ),
          const SizedBox(height: 8),
          _backgroundOption(
            title: '3장 배경',
            subtitle: widget.chapter3Unlocked ? '고대 채석장' : '3장 해금 후 선택 가능',
            assetPath: _kChapter3HomeBg,
            value: AppSettingsData.homeBackgroundChapter3,
            enabled: widget.chapter3Unlocked,
          ),
        ],
      ),
    );
  }

  Widget _backgroundOption({
    required String title,
    required String subtitle,
    required String assetPath,
    required int value,
    required bool enabled,
  }) {
    final selected = _settings.homeBackgroundChapter == value;
    final borderColor = selected ? _kGold : _kBorder;
    return GestureDetector(
      onTap: enabled ? () => _select(value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.48,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kInnerBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 72,
                  height: 44,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled
                    ? (selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked)
                    : Icons.lock,
                color: selected ? _kGold : Colors.white38,
                size: 20,
              ),
            ],
          ),
        ),
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
  final _scrollController = ScrollController();
  final _screenFocusNode = FocusNode();
  final _messageFocusNode = FocusNode();
  bool _isSubmitting = false;
  String? _notice;
  bool _noticeSuccess = true;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_scrollToMessageField);
  }

  @override
  void dispose() {
    unawaited(_dismissKeyboard());
    _screenController.dispose();
    _messageController.dispose();
    _screenFocusNode.dispose();
    _messageFocusNode.removeListener(_scrollToMessageField);
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToMessageField() {
    if (!_messageFocusNode.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
      await _dismissKeyboard();
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
    await _dismissKeyboard();
    if (!mounted) return;
    final deleted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
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
      scrollController: _scrollController,
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
            focusNode: _screenFocusNode,
            label: '발생 화면',
            hint: '예: 상점, 레이드, 전투',
            maxLength: 80,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _messageFocusNode.requestFocus(),
          ),
          const SizedBox(height: 8),
          _darkTextField(
            controller: _messageController,
            focusNode: _messageFocusNode,
            label: '내용',
            hint: '무엇을 하다가 어떤 문제가 생겼는지 짧게 적어주세요.',
            minLines: 4,
            maxLines: 5,
            maxLength: 1000,
            keyboardType: TextInputType.multiline,
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_dismissKeyboard());
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _canDelete {
    final passwordOk = _passwordController.text.trim().isNotEmpty;
    if (widget.email.isEmpty) return passwordOk;
    return passwordOk &&
        _emailController.text.trim().toLowerCase() ==
            widget.email.trim().toLowerCase();
  }

  Future<bool> _confirmPermanentDelete() async {
    await _dismissKeyboard();
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.76),
      builder: (dialogContext) => _SettingsShell(
        title: '계정 영구 삭제',
        icon: Icons.warning_amber_rounded,
        maxWidth: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '삭제하면 캐릭터, 장비, 전투 기록, 친구/레이드 정보가 영구 삭제되며 복구할 수 없습니다. 계속 삭제할까요?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _fullWidthButton(
                    icon: Icons.close,
                    label: '취소',
                    color: _kBlue,
                    onTap: () => Navigator.pop(dialogContext, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _fullWidthButton(
                    icon: Icons.delete_forever,
                    label: '영구 삭제',
                    color: _kRed,
                    onTap: () => Navigator.pop(dialogContext, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete || _isDeleting) return;
    final confirmed = await _confirmPermanentDelete();
    if (!confirmed || !mounted) return;

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
              focusNode: _emailFocusNode,
              label: '이메일 확인',
              hint: widget.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
          ],
          const SizedBox(height: 8),
          _darkTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: '비밀번호',
            hint: '현재 비밀번호',
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofocus: widget.email.isEmpty,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_dismissKeyboard()),
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
  final ScrollController? scrollController;

  const _SettingsShell({
    required this.title,
    required this.icon,
    required this.maxWidth,
    required this.child,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_dismissKeyboard());
      },
      child: Dialog(
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
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        onTap: () async {
                          await _dismissKeyboard();
                          if (context.mounted) Navigator.pop(context);
                        },
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
  FocusNode? focusNode,
  int minLines = 1,
  int maxLines = 1,
  int? maxLength,
  bool obscureText = false,
  bool autofocus = false,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) {
  return TextField(
    controller: controller,
    focusNode: focusNode,
    minLines: obscureText ? 1 : minLines,
    maxLines: obscureText ? 1 : maxLines,
    maxLength: maxLength,
    obscureText: obscureText,
    autofocus: autofocus,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
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
