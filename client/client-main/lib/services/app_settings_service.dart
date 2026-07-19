import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsData {
  static const homeBackgroundAuto = 0;
  static const homeBackgroundChapter1 = 1;
  static const homeBackgroundChapter2 = 2;
  static const homeBackgroundChapter3 = 3;

  final bool soundEnabled;
  final bool bgmEnabled;
  final bool sfxEnabled;
  final double masterVolume;
  final bool powerSavingMode;
  final int autoPowerSavingMinutes;
  final int homeBackgroundChapter;

  const AppSettingsData({
    required this.soundEnabled,
    required this.bgmEnabled,
    required this.sfxEnabled,
    required this.masterVolume,
    required this.powerSavingMode,
    required this.autoPowerSavingMinutes,
    required this.homeBackgroundChapter,
  });

  const AppSettingsData.defaults()
    : soundEnabled = true,
      bgmEnabled = true,
      sfxEnabled = true,
      masterVolume = 0.8,
      powerSavingMode = false,
      autoPowerSavingMinutes = 5,
      homeBackgroundChapter = homeBackgroundAuto;

  AppSettingsData copyWith({
    bool? soundEnabled,
    bool? bgmEnabled,
    bool? sfxEnabled,
    double? masterVolume,
    bool? powerSavingMode,
    int? autoPowerSavingMinutes,
    int? homeBackgroundChapter,
  }) {
    return AppSettingsData(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      bgmEnabled: bgmEnabled ?? this.bgmEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      masterVolume: masterVolume ?? this.masterVolume,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
      autoPowerSavingMinutes:
          autoPowerSavingMinutes ?? this.autoPowerSavingMinutes,
      homeBackgroundChapter:
          homeBackgroundChapter ?? this.homeBackgroundChapter,
    );
  }
}

class AppSettingsService {
  static final notifier = ValueNotifier<AppSettingsData>(
    const AppSettingsData.defaults(),
  );
  static bool _sessionInitialized = false;

  static const _soundEnabledKey = 'settings:sound_enabled';
  static const _bgmEnabledKey = 'settings:bgm_enabled';
  static const _sfxEnabledKey = 'settings:sfx_enabled';
  static const _masterVolumeKey = 'settings:master_volume';
  static const _powerSavingModeKey = 'settings:power_saving_mode';
  static const _autoPowerSavingMinutesKey =
      'settings:auto_power_saving_minutes';
  static const _homeBackgroundChapterKey = 'settings:home_background_chapter';

  static Future<AppSettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AppSettingsData.defaults();
    final isFirstLoadOfSession = !_sessionInitialized;
    _sessionInitialized = true;
    if (isFirstLoadOfSession) {
      await prefs.remove(_powerSavingModeKey);
    }
    final settings = AppSettingsData(
      soundEnabled: prefs.getBool(_soundEnabledKey) ?? defaults.soundEnabled,
      bgmEnabled: prefs.getBool(_bgmEnabledKey) ?? defaults.bgmEnabled,
      sfxEnabled: prefs.getBool(_sfxEnabledKey) ?? defaults.sfxEnabled,
      masterVolume: prefs.getDouble(_masterVolumeKey) ?? defaults.masterVolume,
      powerSavingMode: isFirstLoadOfSession
          ? false
          : notifier.value.powerSavingMode,
      autoPowerSavingMinutes: _normalizeAutoPowerSavingMinutes(
        prefs.getInt(_autoPowerSavingMinutesKey) ??
            defaults.autoPowerSavingMinutes,
      ),
      homeBackgroundChapter: _normalizeHomeBackgroundChapter(
        prefs.getInt(_homeBackgroundChapterKey) ??
            defaults.homeBackgroundChapter,
      ),
    );
    notifier.value = settings;
    return settings;
  }

  static Future<void> save(AppSettingsData settings) async {
    final normalized = settings.copyWith(
      homeBackgroundChapter: _normalizeHomeBackgroundChapter(
        settings.homeBackgroundChapter,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, normalized.soundEnabled);
    await prefs.setBool(_bgmEnabledKey, normalized.bgmEnabled);
    await prefs.setBool(_sfxEnabledKey, normalized.sfxEnabled);
    await prefs.setDouble(_masterVolumeKey, normalized.masterVolume);
    await prefs.setInt(
      _autoPowerSavingMinutesKey,
      normalized.autoPowerSavingMinutes,
    );
    await prefs.setInt(
      _homeBackgroundChapterKey,
      normalized.homeBackgroundChapter,
    );
    notifier.value = normalized;
  }

  static void resetPowerSavingAfterLogin() {
    final settings = notifier.value;
    notifier.value = settings.copyWith(powerSavingMode: false);
  }

  static int _normalizeHomeBackgroundChapter(int value) {
    if (value == AppSettingsData.homeBackgroundChapter1 ||
        value == AppSettingsData.homeBackgroundChapter2 ||
        value == AppSettingsData.homeBackgroundChapter3) {
      return value;
    }
    return AppSettingsData.homeBackgroundAuto;
  }

  static int _normalizeAutoPowerSavingMinutes(int value) {
    if (value == 0 || value == 3 || value == 5) return value;
    return 5;
  }
}
