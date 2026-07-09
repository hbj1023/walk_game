import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsData {
  final bool soundEnabled;
  final bool bgmEnabled;
  final bool sfxEnabled;
  final double masterVolume;
  final bool powerSavingMode;

  const AppSettingsData({
    required this.soundEnabled,
    required this.bgmEnabled,
    required this.sfxEnabled,
    required this.masterVolume,
    required this.powerSavingMode,
  });

  const AppSettingsData.defaults()
    : soundEnabled = true,
      bgmEnabled = true,
      sfxEnabled = true,
      masterVolume = 0.8,
      powerSavingMode = false;

  AppSettingsData copyWith({
    bool? soundEnabled,
    bool? bgmEnabled,
    bool? sfxEnabled,
    double? masterVolume,
    bool? powerSavingMode,
  }) {
    return AppSettingsData(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      bgmEnabled: bgmEnabled ?? this.bgmEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      masterVolume: masterVolume ?? this.masterVolume,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
    );
  }
}

class AppSettingsService {
  static const _soundEnabledKey = 'settings:sound_enabled';
  static const _bgmEnabledKey = 'settings:bgm_enabled';
  static const _sfxEnabledKey = 'settings:sfx_enabled';
  static const _masterVolumeKey = 'settings:master_volume';
  static const _powerSavingModeKey = 'settings:power_saving_mode';

  static Future<AppSettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AppSettingsData.defaults();
    return AppSettingsData(
      soundEnabled: prefs.getBool(_soundEnabledKey) ?? defaults.soundEnabled,
      bgmEnabled: prefs.getBool(_bgmEnabledKey) ?? defaults.bgmEnabled,
      sfxEnabled: prefs.getBool(_sfxEnabledKey) ?? defaults.sfxEnabled,
      masterVolume: prefs.getDouble(_masterVolumeKey) ?? defaults.masterVolume,
      powerSavingMode:
          prefs.getBool(_powerSavingModeKey) ?? defaults.powerSavingMode,
    );
  }

  static Future<void> save(AppSettingsData settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, settings.soundEnabled);
    await prefs.setBool(_bgmEnabledKey, settings.bgmEnabled);
    await prefs.setBool(_sfxEnabledKey, settings.sfxEnabled);
    await prefs.setDouble(_masterVolumeKey, settings.masterVolume);
    await prefs.setBool(_powerSavingModeKey, settings.powerSavingMode);
  }
}
