import 'package:flutter/material.dart';

class ProfileIconOption {
  final String key;
  final String label;
  final IconData icon;
  final String? assetPath;
  final Color backgroundColor;
  final Color iconColor;
  final Color glowColor;

  const ProfileIconOption({
    required this.key,
    required this.label,
    required this.icon,
    this.assetPath,
    required this.backgroundColor,
    required this.iconColor,
    required this.glowColor,
  });
}

const customProfileIconKey = 'custom';

const customProfileIconOption = ProfileIconOption(
  key: customProfileIconKey,
  label: '직접 이미지',
  icon: Icons.add_photo_alternate,
  backgroundColor: Color(0xFF221E2A),
  iconColor: Color(0xFFFFE7A4),
  glowColor: Color(0xFFE5B447),
);

const profileIconOptions = <ProfileIconOption>[
  ProfileIconOption(
    key: 'vanguard',
    label: '모험가',
    icon: Icons.person,
    assetPath: 'assets/images/equipment/chapter2/ch2_weapon_sword.png',
    backgroundColor: Color(0xFF17271C),
    iconColor: Color(0xFFE9F9DF),
    glowColor: Color(0xFF77C66A),
  ),
  ProfileIconOption(
    key: 'berserker',
    label: '광전사',
    icon: Icons.local_fire_department,
    assetPath: 'assets/images/equipment/chapter2/ch2_weapon_axe.png',
    backgroundColor: Color(0xFF141D32),
    iconColor: Color(0xFFE1F3FF),
    glowColor: Color(0xFF5FA8FF),
  ),
  ProfileIconOption(
    key: 'sentinel',
    label: '창술사',
    icon: Icons.shield,
    assetPath: 'assets/images/equipment/chapter2/ch2_weapon_spear.png',
    backgroundColor: Color(0xFF182A2C),
    iconColor: Color(0xFFDDFDFF),
    glowColor: Color(0xFF7ED7D9),
  ),
  ProfileIconOption(
    key: 'shadow',
    label: '도적',
    icon: Icons.explore,
    assetPath: 'assets/images/equipment/chapter2/ch2_weapon_dagger.png',
    backgroundColor: Color(0xFF2B1C14),
    iconColor: Color(0xFFFFE0B8),
    glowColor: Color(0xFFC69055),
  ),
  ProfileIconOption(
    key: 'colossus',
    label: '견습기사',
    icon: Icons.security,
    assetPath: 'assets/images/equipment/chapter2/ch2_weapon_colossus.png',
    backgroundColor: Color(0xFF252A2F),
    iconColor: Color(0xFFE5E9EF),
    glowColor: Color(0xFF9AA9B8),
  ),
];

ProfileIconOption profileIconOptionFor(String key) {
  final normalizedKey = switch (key) {
    'adventurer' => 'vanguard',
    'swordsman' => 'berserker',
    'guardian' => 'sentinel',
    'scout' => 'shadow',
    'mage' => 'colossus',
    'ranger' => 'vanguard',
    _ => key,
  };
  if (normalizedKey == customProfileIconKey) return customProfileIconOption;
  for (final option in profileIconOptions) {
    if (option.key == normalizedKey) return option;
  }
  return profileIconOptions.first;
}

class ProfileIconPreview extends StatelessWidget {
  final String iconKey;
  final String? customImageDataUrl;
  final double size;
  final bool selected;
  final bool showFrame;

  const ProfileIconPreview({
    super.key,
    required this.iconKey,
    this.customImageDataUrl,
    this.size = 56,
    this.selected = false,
    this.showFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    final option = profileIconOptionFor(iconKey);
    final innerSize = size * 0.68;
    final innerRadius = size * 0.075;
    final iconSize = size * 0.38;
    final assetSize = size * 0.56;
    final customImage = customImageDataUrl?.trim();
    final hasCustomImage =
        option.key == customProfileIconKey &&
        customImage != null &&
        customImage.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showFrame)
            Image.asset(
              'assets/images/profile_frame.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              color: option.backgroundColor,
              borderRadius: BorderRadius.circular(innerRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: option.glowColor.withValues(
                    alpha: selected ? 0.42 : 0.22,
                  ),
                  blurRadius: selected ? 10 : 6,
                  spreadRadius: selected ? 1 : 0,
                ),
              ],
            ),
          ),
          if (hasCustomImage)
            _buildCustomImage(customImage, innerSize, innerRadius)
          else if (option.assetPath != null)
            Image.asset(
              option.assetPath!,
              width: assetSize,
              height: assetSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) =>
                  Icon(option.icon, size: iconSize, color: option.iconColor),
            )
          else
            Icon(option.icon, size: iconSize, color: option.iconColor),
          if (selected)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A7A35),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Icon(
                  Icons.check,
                  size: size * 0.18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomImage(String dataUrl, double innerSize, double radius) {
    try {
      final bytes = UriData.parse(dataUrl).contentAsBytes();
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: innerSize,
          height: innerSize,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Icon(
            customProfileIconOption.icon,
            size: size * 0.38,
            color: customProfileIconOption.iconColor,
          ),
        ),
      );
    } catch (_) {
      return Icon(
        customProfileIconOption.icon,
        size: size * 0.38,
        color: customProfileIconOption.iconColor,
      );
    }
  }
}
