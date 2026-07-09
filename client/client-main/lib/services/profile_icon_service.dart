import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/services/api_config.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/widgets/profile_icon_catalog.dart';

class ProfileIconService {
  static const _legacyProfileIconKey = 'profile_icon_key';
  static const _legacyProfileImageDataUrlKey = 'profile_image_data_url';
  static const _profileIconKeyPrefix = 'profile_icon_key:';
  static const _profileImageDataUrlKeyPrefix = 'profile_image_data_url:';
  static const _requestTimeout = Duration(seconds: 15);

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
    if (selectedKey != customProfileIconKey) {
      await _uploadProfileIconAsset(selectedKey);
    }
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
    await _uploadCustomImageDataUrl(normalized);
    await prefs.setString(imagePrefsKey, normalized);
    await prefs.setString(iconPrefsKey, customProfileIconKey);
    GameState.instance.setProfileImageDataUrl(normalized);
    GameState.instance.setProfileIconKey(customProfileIconKey);
  }

  static void resetGameStateToDefault() {
    GameState.instance.setProfileImageDataUrl(null);
    GameState.instance.setProfileIconKey(profileIconOptions.first.key);
  }

  static Future<void> _uploadCustomImageDataUrl(String dataUrl) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('로그인 정보가 없습니다.');
    }

    final image = _decodeProfileImageDataUrl(dataUrl);
    await _uploadProfileImageBytes(
      token: token,
      bytes: image.bytes,
      extension: image.extension,
    );
  }

  static Future<void> _uploadProfileIconAsset(String key) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('로그인 정보가 없습니다.');
    }

    final option = profileIconOptionFor(key);
    final assetPath = option.assetPath;
    if (assetPath == null || assetPath.trim().isEmpty) return;

    final data = await rootBundle.load(assetPath);
    final extension = _extensionFromPath(assetPath);
    await _uploadProfileImageBytes(
      token: token,
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      extension: extension,
    );
  }

  static Future<void> _uploadProfileImageBytes({
    required String token,
    required List<int> bytes,
    required String extension,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      ApiConfig.uri('/api/users/profile-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'profile.$extension',
      ),
    );

    final streamedResponse = await request.send().timeout(
      _requestTimeout,
      onTimeout: () => throw const AuthException('프로필 이미지 업로드 시간이 초과되었습니다.'),
    );
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw AuthException(_profileUploadErrorMessage(response));
  }

  static String _extensionFromPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'png' ||
      'jpg' ||
      'jpeg' ||
      'webp' => extension == 'jpeg' ? 'jpg' : extension,
      _ => 'png',
    };
  }

  static _ProfileImageUpload _decodeProfileImageDataUrl(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0) {
      throw const AuthException('프로필 이미지 형식이 올바르지 않습니다.');
    }

    final header = dataUrl.substring(0, commaIndex).toLowerCase();
    final payload = dataUrl.substring(commaIndex + 1);
    if (!header.contains(';base64')) {
      throw const AuthException('프로필 이미지 형식이 올바르지 않습니다.');
    }

    final mimeMatch = RegExp(r'^data:([^;]+);base64').firstMatch(header);
    final mimeType = mimeMatch?.group(1) ?? '';
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/webp' => 'webp',
      _ => '',
    };
    if (extension.isEmpty) {
      throw const AuthException('PNG, JPG, WEBP 이미지만 사용할 수 있습니다.');
    }

    try {
      return _ProfileImageUpload(
        bytes: base64Decode(payload),
        extension: extension,
      );
    } on FormatException {
      throw const AuthException('프로필 이미지 파일을 읽지 못했습니다.');
    }
  }

  static String _profileUploadErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return _friendlyProfileUploadError(error);
        }
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _friendlyProfileUploadError(message);
        }
      }
    } catch (_) {
      // Fall through to the generic message.
    }
    return '프로필 이미지 업로드에 실패했습니다.';
  }

  static String _friendlyProfileUploadError(String message) {
    return switch (message.trim()) {
      'image file is too large' => '프로필 이미지는 5MB 이하만 사용할 수 있습니다.',
      'image must be png, jpg, jpeg, or webp' =>
        'PNG, JPG, WEBP 이미지만 사용할 수 있습니다.',
      'image file is required' => '프로필 이미지 파일을 찾지 못했습니다.',
      'unauthorized' => '로그인 정보가 만료되었습니다. 다시 로그인해주세요.',
      _ => message,
    };
  }
}

class _ProfileImageUpload {
  final List<int> bytes;
  final String extension;

  const _ProfileImageUpload({required this.bytes, required this.extension});
}
