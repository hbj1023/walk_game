import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/widgets/profile_icon_catalog.dart';

class ProfileIconService {
  static const _legacyProfileIconKey = 'profile_icon_key';
  static const _legacyProfileImageDataUrlKey = 'profile_image_data_url';
  static const _profileIconKeyPrefix = 'profile_icon_key:';
  static const _profileImageDataUrlKeyPrefix = 'profile_image_data_url:';

  static Future<String?> _accountScopeKey() async {
    final userId = (await AuthService.getSavedUserId())?.trim();
    if (userId != null && userId.isNotEmpty) return 'user:$userId';

    final email = (await AuthService.getSavedEmail())?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) return 'email:$email';

    return null;
  }

  static Future<String?> _scopedPrefsKey(String prefix) async {
    final accountKey = await _accountScopeKey();
    if (accountKey == null) return null;
    return '$prefix$accountKey';
  }

  static Future<SharedPreferences> _prefsWithoutLegacySharedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyProfileIconKey);
    await prefs.remove(_legacyProfileImageDataUrlKey);
    return prefs;
  }

  static Future<String> loadSavedIconKey() async {
    final prefs = await _prefsWithoutLegacySharedProfile();
    final iconPrefsKey = await _scopedPrefsKey(_profileIconKeyPrefix);
    final imagePrefsKey = await _scopedPrefsKey(_profileImageDataUrlKeyPrefix);
    if (iconPrefsKey == null || imagePrefsKey == null) {
      return profileIconOptions.first.key;
    }

    final savedKey = prefs.getString(iconPrefsKey);
    final customImageDataUrl = prefs.getString(imagePrefsKey);
    if (savedKey == customProfileIconKey &&
        customImageDataUrl != null &&
        customImageDataUrl.isNotEmpty) {
      return customProfileIconKey;
    }
    return profileIconOptionFor(savedKey ?? '').key;
  }

  static Future<String?> loadCustomImageDataUrl() async {
    final prefs = await _prefsWithoutLegacySharedProfile();
    final imagePrefsKey = await _scopedPrefsKey(_profileImageDataUrlKeyPrefix);
    if (imagePrefsKey == null) return null;

    final saved = prefs.getString(imagePrefsKey)?.trim();
    return saved == null || saved.isEmpty ? null : saved;
  }

  static Future<void> loadIntoGameState() async {
    final customImageDataUrl = await loadCustomImageDataUrl();
    final key = await loadSavedIconKey();
    GameState.instance.setProfileImageDataUrl(customImageDataUrl);
    GameState.instance.setProfileIconKey(key);
  }

  static Future<void> saveIconKey(String key) async {
    final prefs = await _prefsWithoutLegacySharedProfile();
    final iconPrefsKey = await _scopedPrefsKey(_profileIconKeyPrefix);
    if (iconPrefsKey == null) return;

    final selectedKey = profileIconOptionFor(key).key;
    await prefs.setString(iconPrefsKey, selectedKey);
    GameState.instance.setProfileIconKey(selectedKey);
  }

  static Future<void> saveCustomImageDataUrl(String dataUrl) async {
    final prefs = await _prefsWithoutLegacySharedProfile();
    final iconPrefsKey = await _scopedPrefsKey(_profileIconKeyPrefix);
    final imagePrefsKey = await _scopedPrefsKey(_profileImageDataUrlKeyPrefix);
    if (iconPrefsKey == null || imagePrefsKey == null) return;

    final normalized = dataUrl.trim();
    if (normalized.isEmpty) return;
    await prefs.setString(imagePrefsKey, normalized);
    await prefs.setString(iconPrefsKey, customProfileIconKey);
    GameState.instance.setProfileImageDataUrl(normalized);
    GameState.instance.setProfileIconKey(customProfileIconKey);
  }

  static void resetGameStateToDefault() {
    GameState.instance.setProfileImageDataUrl(null);
    GameState.instance.setProfileIconKey(profileIconOptions.first.key);
  }
}
