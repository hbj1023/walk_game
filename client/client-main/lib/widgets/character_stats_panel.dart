import 'package:flutter/material.dart';

import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/services/profile_image_picker.dart';
import 'package:capstone_app/services/profile_icon_service.dart';
import 'package:capstone_app/widgets/profile_icon_catalog.dart';

const _kPanelColor = Color(0xFF271610);
const _kBorderColor = Color(0xFF5C3D22);
const _kGold = Color(0xFFCCA84A);
const _kTextLight = Color(0xFFD9C9A8);
const _kTextGray = Color(0xFF7A6247);
const _kGreen = Color(0xFF4E8C4E);

const _statKeys = ['hp', 'attack', 'defense', 'agility'];
const _statLabel = {
  'hp': '최대 HP',
  'attack': '공격력',
  'defense': '방어력',
  'agility': '민첩',
};

class CharacterStatsPanel extends StatelessWidget {
  final CharacterStatsSummary? summary;
  final Map<String, int>? fallbackStats;
  final int level;
  final String selectedStatKey;
  final ValueChanged<String> onStatSelected;
  final EdgeInsetsGeometry margin;
  final String title;

  const CharacterStatsPanel({
    super.key,
    required this.summary,
    required this.level,
    required this.selectedStatKey,
    required this.onStatSelected,
    this.fallbackStats,
    this.margin = const EdgeInsets.fromLTRB(8, 8, 8, 8),
    this.title = '스탯',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kPanelColor,
        border: Border.all(color: _kBorderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: _kGold, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: _kTextLight,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'LV.$level',
                style: const TextStyle(
                  color: _kGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statKeys
                    .map((key) => _buildStatOverviewTile(key, tileWidth))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildCombatPowerSummary(),
        ],
      ),
    );
  }

  Widget _buildStatOverviewTile(String key, double width) {
    final selected = selectedStatKey == key;
    final value = _statValue(
      summary?.finalStats,
      key,
      fallback: fallbackStats?[key] ?? 0,
    );
    final equipment = _statValue(summary?.equipmentStats, key);
    final setBonus = _statValue(summary?.setBonusStats, key);
    final extra = equipment + setBonus;

    return GestureDetector(
      onTap: () => onStatSelected(key),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF332015)
              : Colors.black.withValues(alpha: 0.22),
          border: Border.all(
            color: selected ? _kGold : _kBorderColor,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              _statIconPath(key),
              width: 24,
              height: 24,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.auto_awesome, color: _kGold, size: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statLabel[key]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kTextGray, fontSize: 10),
                  ),
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    extra > 0 ? '장비+$extra' : '기본 성장',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: extra > 0 ? _kGreen : _kTextGray,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombatPowerSummary() {
    final finalStats = summary?.finalStats ?? fallbackStats;
    final totalPower = _combatPower(finalStats);
    final basePower = _combatPower(summary?.baseStats);
    final upgradePower = _combatPower(summary?.upgradeStats);
    final equipmentPower = _combatPower(summary?.equipmentStats);
    final setBonusPower = _combatPower(summary?.setBonusStats);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: _kGold, size: 18),
              const SizedBox(width: 6),
              const Text(
                '전투력',
                style: TextStyle(
                  color: _kTextLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (summary != null)
                Text(
                  '장비 ${summary!.equippedItemCount} / 세트 ${summary!.activeSetBonusCount}',
                  style: const TextStyle(color: _kTextGray, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalPower',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '공격력, 방어력, 민첩, HP를 합산한 현재 전투 기준치',
                  style: TextStyle(
                    color: _kTextGray,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (summary != null) ...[
            const Divider(color: _kBorderColor, height: 14),
            _buildCombatPowerRow('기본 성장', basePower, _kTextGray),
            _buildCombatPowerRow(
              '직접 강화',
              upgradePower,
              const Color(0xFFBFF4FF),
            ),
            _buildCombatPowerRow('장비', equipmentPower, _kGreen),
            _buildCombatPowerRow('세트', setBonusPower, _kGold),
          ],
        ],
      ),
    );
  }

  Widget _buildCombatPowerRow(
    String label,
    int value,
    Color color, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _kTextGray, fontSize: 11)),
          const Spacer(),
          Text(
            strong || value == 0 ? '$value' : '+$value',
            style: TextStyle(
              color: color,
              fontSize: strong ? 14 : 12,
              fontWeight: strong ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  int _statValue(Map<String, int>? stats, String key, {int fallback = 0}) {
    if (stats == null) return fallback;
    return stats[key] ?? fallback;
  }

  int _combatPower(Map<String, int>? stats) {
    if (stats == null || stats.isEmpty) return 0;
    final hp = _statValue(stats, 'hp');
    final attack = _statValue(stats, 'attack');
    final defense = _statValue(stats, 'defense');
    final agility = _statValue(stats, 'agility');
    return (hp / 3 + attack * 8 + defense * 5 + agility * 4).round();
  }

  String _statIconPath(String key) {
    return switch (key) {
      'attack' => 'assets/images/icon/atk.png',
      'defense' => 'assets/images/icon/def.png',
      'agility' => 'assets/images/icon/agi.png',
      _ => 'assets/images/icon/hp.png',
    };
  }
}

class CharacterStatsDialog extends StatefulWidget {
  final String userName;
  final int level;

  const CharacterStatsDialog({
    super.key,
    required this.userName,
    required this.level,
  });

  @override
  State<CharacterStatsDialog> createState() => _CharacterStatsDialogState();
}

class _CharacterStatsDialogState extends State<CharacterStatsDialog> {
  CharacterStatsSummary? _summary;
  String _selectedStatKey = 'hp';
  String _selectedProfileIconKey = 'vanguard';
  String? _customProfileImageDataUrl;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _isSavingProfileIcon = false;
  String? _error;
  String? _profileImageError;

  @override
  void initState() {
    super.initState();
    _selectedProfileIconKey = GameState.instance.profileIconKey;
    _customProfileImageDataUrl = GameState.instance.profileImageDataUrl;
    _loadStats();
    _loadProfileIcon();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summary = await GameApiService.fetchCharacterStatsSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileIcon() async {
    final key = await ProfileIconService.loadSavedIconKey();
    final customImageDataUrl =
        await ProfileIconService.loadCustomImageDataUrl();
    if (!mounted) return;
    setState(() {
      _selectedProfileIconKey = key;
      _customProfileImageDataUrl = customImageDataUrl;
    });
  }

  Future<void> _selectProfileIcon(String key) async {
    if (key == customProfileIconKey && _customProfileImageDataUrl == null) {
      await _pickCustomProfileImage();
      return;
    }
    if (_isSavingProfileIcon || key == _selectedProfileIconKey) return;
    setState(() {
      _selectedProfileIconKey = key;
      _isSavingProfileIcon = true;
      _profileImageError = null;
    });
    try {
      await ProfileIconService.saveIconKey(key);
    } catch (error) {
      final savedKey = await ProfileIconService.loadSavedIconKey();
      if (mounted) {
        setState(() {
          _selectedProfileIconKey = savedKey;
          _profileImageError = _profileImageErrorText(error);
        });
      }
    } finally {
      if (mounted) setState(() => _isSavingProfileIcon = false);
    }
  }

  Future<void> _pickCustomProfileImage() async {
    if (_isSavingProfileIcon) return;
    setState(() {
      _isSavingProfileIcon = true;
      _profileImageError = null;
    });
    try {
      final dataUrl = await ProfileImagePicker.pickProfileImageDataUrl();
      if (!mounted) return;
      if (dataUrl == null || dataUrl.trim().isEmpty) {
        setState(() => _isSavingProfileIcon = false);
        return;
      }
      final accepted = await _showCustomImageApplyPreview(dataUrl);
      if (!mounted) return;
      if (!accepted) {
        setState(() => _isSavingProfileIcon = false);
        return;
      }
      await ProfileIconService.saveCustomImageDataUrl(dataUrl);
      if (!mounted) return;
      setState(() {
        _selectedProfileIconKey = customProfileIconKey;
        _customProfileImageDataUrl = dataUrl;
        _isSavingProfileIcon = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileImageError = _profileImageErrorText(error);
        _isSavingProfileIcon = false;
      });
    }
  }

  String _profileImageErrorText(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('Unsupported')) {
      return '이 실행 환경에서는 직접 이미지 선택을 지원하지 않습니다.';
    }
    return message;
  }

  Future<bool> _showCustomImageApplyPreview(String dataUrl) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) {
        return _ProfilePreviewDialog(
          title: '이미지 적용',
          label: '프로필 프레임 미리보기',
          iconKey: customProfileIconKey,
          customImageDataUrl: dataUrl,
          showCropGuide: true,
          primaryLabel: '적용',
          onPrimary: () => Navigator.pop(context, true),
          secondaryLabel: '취소',
          onSecondary: () => Navigator.pop(context, false),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _openProfileIconPreview(String iconKey) async {
    final option = profileIconOptionFor(iconKey);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) {
        return _ProfilePreviewDialog(
          title: option.label,
          label: '프로필 아이콘',
          iconKey: option.key,
          customImageDataUrl: _customProfileImageDataUrl,
          showCropGuide: option.key == customProfileIconKey,
          primaryLabel: '닫기',
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfileIcon = profileIconOptionFor(_selectedProfileIconKey);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF080403).withValues(alpha: 0.96),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF202638).withValues(alpha: 0.98),
            border: Border.all(color: _kGold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        _openProfileIconPreview(_selectedProfileIconKey),
                    child: ProfileIconPreview(
                      iconKey: _selectedProfileIconKey,
                      customImageDataUrl: _customProfileImageDataUrl,
                      size: 38,
                      selected: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 21,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectedProfileIcon.label,
                  style: const TextStyle(
                    color: _kTextGray,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildTabBar(),
              const SizedBox(height: 10),
              if (_selectedTabIndex == 0)
                _buildStatsBody()
              else
                _buildProfileBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        border: Border.all(color: _kBorderColor, width: 1),
      ),
      child: Row(
        children: [
          _buildTabButton('스탯', 0, Icons.auto_graph),
          const SizedBox(width: 4),
          _buildTabButton('프로필', 1, Icons.account_box),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final selected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5A2A10) : Colors.transparent,
            border: Border.all(
              color: selected ? _kGold : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _kGold : _kTextGray, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _kTextGray,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: CircularProgressIndicator(color: _kGold),
      );
    }
    if (_error != null) return _buildError();
    return CharacterStatsPanel(
      summary: _summary,
      level: widget.level,
      selectedStatKey: _selectedStatKey,
      onStatSelected: (key) {
        setState(() => _selectedStatKey = key);
      },
      margin: EdgeInsets.zero,
      title: '스탯',
    );
  }

  Widget _buildProfileBody() {
    final current = profileIconOptionFor(_selectedProfileIconKey);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kPanelColor,
        border: Border.all(color: _kBorderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openProfileIconPreview(current.key),
                child: ProfileIconPreview(
                  iconKey: current.key,
                  customImageDataUrl: _customProfileImageDataUrl,
                  size: 58,
                  selected: _isSavingProfileIcon,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '프로필 아이콘',
                      style: TextStyle(
                        color: _kTextLight,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSavingProfileIcon ? '저장 중...' : '${current.label} 선택됨',
                      style: const TextStyle(color: _kTextGray, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '세트 아이콘',
            style: TextStyle(
              color: _kTextGray,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 3;
              return Wrap(
                spacing: 6,
                runSpacing: 8,
                children: profileIconOptions
                    .map((option) => _buildProfileIconTile(option, tileWidth))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildCustomProfileImageButton(),
          if (_profileImageError != null) ...[
            const SizedBox(height: 6),
            Text(
              _profileImageError!,
              style: const TextStyle(
                color: Color(0xFFFF9078),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomProfileImageButton() {
    final hasCustomImage = _customProfileImageDataUrl != null;
    final customSelected = _selectedProfileIconKey == customProfileIconKey;
    final title = !hasCustomImage
        ? '직접 이미지 넣기'
        : customSelected
        ? '직접 이미지 크게 보기'
        : '직접 이미지 선택';
    return GestureDetector(
      onTap: () {
        if (!hasCustomImage) {
          _pickCustomProfileImage();
        } else if (customSelected) {
          _openProfileIconPreview(customProfileIconKey);
        } else {
          _selectProfileIcon(customProfileIconKey);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: customSelected
              ? const Color(0xFF332015)
              : Colors.black.withValues(alpha: 0.22),
          border: Border.all(
            color: customSelected ? _kGold : _kBorderColor,
            width: customSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ProfileIconPreview(
              iconKey: customProfileIconKey,
              customImageDataUrl: _customProfileImageDataUrl,
              size: 42,
              selected: customSelected,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _kTextLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'PNG, JPG, WEBP, GIF / 1.5MB 이하',
                    style: TextStyle(color: _kTextGray, fontSize: 10),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickCustomProfileImage,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border.all(
                    color: customSelected ? _kGold : _kBorderColor,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.file_upload_outlined,
                  color: customSelected ? _kGold : _kTextGray,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIconTile(ProfileIconOption option, double width) {
    final selected = option.key == _selectedProfileIconKey;
    return GestureDetector(
      onTap: selected
          ? () => _openProfileIconPreview(option.key)
          : () => _selectProfileIcon(option.key),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF332015)
              : Colors.black.withValues(alpha: 0.22),
          border: Border.all(
            color: selected ? _kGold : _kBorderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileIconPreview(
              iconKey: option.key,
              size: 48,
              selected: selected,
            ),
            const SizedBox(height: 5),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _kTextLight,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1210),
        border: Border.all(color: const Color(0xFFB34A35), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '스탯 정보를 불러오지 못했습니다.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextLight, fontSize: 11),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _loadStats,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kPanelColor,
                border: Border.all(color: _kGold, width: 1.5),
              ),
              child: const Text(
                '다시 불러오기',
                style: TextStyle(
                  color: _kGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePreviewDialog extends StatelessWidget {
  final String title;
  final String label;
  final String iconKey;
  final String? customImageDataUrl;
  final bool showCropGuide;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _ProfilePreviewDialog({
    required this.title,
    required this.label,
    required this.iconKey,
    this.customImageDataUrl,
    this.showCropGuide = false,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.92),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF202638),
            border: Border.all(color: _kGold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kTextGray,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildLargePreview(),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (secondaryLabel != null && onSecondary != null) ...[
                    Expanded(
                      child: _buildDialogButton(
                        label: secondaryLabel!,
                        onTap: onSecondary!,
                        highlighted: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _buildDialogButton(
                      label: primaryLabel,
                      onTap: onPrimary,
                      highlighted: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargePreview() {
    const previewSize = 148.0;
    const innerSize = previewSize * 0.68;
    return SizedBox(
      width: previewSize,
      height: previewSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ProfileIconPreview(
            iconKey: iconKey,
            customImageDataUrl: customImageDataUrl,
            size: previewSize,
            selected: false,
          ),
          if (showCropGuide)
            IgnorePointer(
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required VoidCallback onTap,
    required bool highlighted,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFF5A2A10) : _kPanelColor,
          border: Border.all(
            color: highlighted ? _kGold : _kBorderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: highlighted ? Colors.white : _kTextLight,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
