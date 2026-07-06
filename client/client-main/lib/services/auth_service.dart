import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'game_state.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _characterIdKey = 'auth_character_id';
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';
  static const _legacyProfileIconKey = 'profile_icon_key';
  static const _legacyProfileImageDataUrlKey = 'profile_image_data_url';
  static const _requestTimeout = Duration(seconds: 10);

  static Uri _apiUri(String path) => ApiConfig.uri(path);

  static Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedName = name.trim();
    final response = await _sendWithTimeout(
      http.post(
        _apiUri('/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'password': password,
          'name': normalizedName,
        }),
      ),
      timeoutMessage: '회원가입 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.',
    );
    final body = await _decodeBody(response, fallbackMessage: '회원가입에 실패했습니다.');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(body, '회원가입에 실패했습니다.'));
    }
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final response = await _sendWithTimeout(
      http.post(
        _apiUri('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail, 'password': password}),
      ),
      timeoutMessage: '로그인 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.',
    );
    final body = await _decodeBody(response, fallbackMessage: '로그인에 실패했습니다.');
    if (response.statusCode == 401) {
      await logout();
    }
    if (response.statusCode != 200) {
      throw AuthException(_extractErrorMessage(body, '로그인에 실패했습니다.'));
    }

    await _persistSession(
      token: body['token'] as String?,
      userId: (body['user_id'] as String?)?.trim(),
      characterId: (body['character_id'] as String?)?.trim(),
      email: (body['email'] as String?)?.trim(),
      name: (body['name'] as String?)?.trim(),
      fallbackEmail: normalizedEmail,
      fallbackName: null,
    );
    if (body.containsKey('coin_balance')) {
      GameState.instance.setCoins(_asInt(body['coin_balance']));
    }
    if (body.containsKey('level')) {
      GameState.instance.setLevel(_asInt(body['level']));
    }
    if (body.containsKey('exp')) {
      GameState.instance.setExp(_asInt(body['exp']));
    }
    if (body.containsKey('stat_exp')) {
      GameState.instance.setStatExp(_asInt(body['stat_exp']));
    }
    if (body.containsKey('attack_count_balance')) {
      GameState.instance.setAttackCountBalance(
        _asInt(body['attack_count_balance']),
      );
    }
  }

  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getSavedCharacterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_characterIdKey);
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String?> getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  static Future<String> fetchMainMessage() async {
    final token = await getSavedToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('로그인 정보가 없습니다.');
    }

    final response = await _sendWithTimeout(
      http.get(
        _apiUri('/main'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
      timeoutMessage: '메인 정보 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.',
    );

    final body = await _decodeBody(
      response,
      fallbackMessage: '메인 정보를 불러오지 못했습니다.',
    );
    if (response.statusCode != 200) {
      final message = (body['error'] as String?)?.trim().isNotEmpty == true
          ? (body['error'] as String).trim()
          : _extractErrorMessage(body, '메인 정보를 불러오지 못했습니다.');
      throw AuthException(message);
    }

    final refreshedToken = body['token'] as String?;
    final userId = (body['user_id'] as String?)?.trim();
    final characterId = (body['character_id'] as String?)?.trim();
    final email = (body['email'] as String?)?.trim();
    final name = (body['name'] as String?)?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (refreshedToken != null && refreshedToken.isNotEmpty) {
      await prefs.setString(_tokenKey, refreshedToken);
    }
    if (email != null && email.isNotEmpty) {
      await prefs.setString(_emailKey, email);
    }
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString(_userIdKey, userId);
    }
    if (characterId != null && characterId.isNotEmpty) {
      await prefs.setString(_characterIdKey, characterId);
    }
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_nameKey, name);
    }

    if (body.containsKey('coin_balance')) {
      GameState.instance.setCoins(_asInt(body['coin_balance']));
    }
    if (body.containsKey('level')) {
      GameState.instance.setLevel(_asInt(body['level']));
    }
    if (body.containsKey('exp')) {
      GameState.instance.setExp(_asInt(body['exp']));
    }
    if (body.containsKey('stat_exp')) {
      GameState.instance.setStatExp(_asInt(body['stat_exp']));
    }
    if (body.containsKey('attack_count_balance')) {
      GameState.instance.setAttackCountBalance(
        _asInt(body['attack_count_balance']),
      );
    }

    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (email ?? '');
    return displayName.isEmpty ? '환영합니다.' : '환영합니다, $displayName 님';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_characterIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_legacyProfileIconKey);
    await prefs.remove(_legacyProfileImageDataUrlKey);
    GameState.instance.setProfileImageDataUrl(null);
    GameState.instance.setProfileIconKey('vanguard');
  }

  static Future<Map<String, dynamic>> _decodeBody(
    http.Response response, {
    required String fallbackMessage,
  }) async {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (_) {
      throw AuthException(fallbackMessage);
    }
  }

  static Future<http.Response> _sendWithTimeout(
    Future<http.Response> request, {
    required String timeoutMessage,
  }) async {
    try {
      return await request.timeout(_requestTimeout);
    } on SocketException {
      throw const AuthException(
        'API 서버에 연결하지 못했습니다. 8080 포트 서버가 실행 중인지 확인해주세요.',
      );
    } on http.ClientException {
      throw const AuthException('API 서버에 연결하지 못했습니다. 서버 주소와 포트를 확인해주세요.');
    } on TimeoutException {
      throw AuthException(timeoutMessage);
    }
  }

  static String _extractErrorMessage(
    Map<String, dynamic> body,
    String fallbackMessage,
  ) {
    final error = body['error'] as String?;
    if (error != null && error.isNotEmpty) {
      return _localizeAuthMessage(error);
    }

    final message = body['message'] as String?;
    if (message == null || message.isEmpty) {
      return fallbackMessage;
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final emailField = data['email'];
      if (emailField is Map<String, dynamic>) {
        if (emailField['code'] == 'validation_not_unique') {
          return '이미 가입된 이메일입니다.';
        }
      }
    }

    return _localizeAuthMessage(message);
  }

  static String _localizeAuthMessage(String message) {
    final normalized = message.trim().toLowerCase();
    return switch (normalized) {
      'unauthorized' ||
      'invalid credentials' ||
      'invalid email or password' => '이메일 또는 비밀번호가 올바르지 않습니다.',
      'missing or invalid token' ||
      'invalid token' => '로그인 정보가 만료되었습니다. 다시 로그인해주세요.',
      'email already exists' || 'user already exists' => '이미 가입된 이메일입니다.',
      'failed to create character' => '캐릭터 생성에 실패했습니다. 잠시 후 다시 시도해주세요.',
      _ => message,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Future<void> _persistSession({
    required String? token,
    required String? userId,
    required String? characterId,
    required String? email,
    required String? name,
    required String fallbackEmail,
    required String? fallbackName,
  }) async {
    if (token == null || token.isEmpty) {
      throw const AuthException('로그인 토큰이 올바르지 않습니다.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString(_userIdKey, userId);
    } else {
      await prefs.remove(_userIdKey);
    }
    if (characterId != null && characterId.isNotEmpty) {
      await prefs.setString(_characterIdKey, characterId);
    } else {
      await prefs.remove(_characterIdKey);
    }
    await prefs.setString(
      _emailKey,
      (email != null && email.isNotEmpty) ? email : fallbackEmail,
    );
    final resolvedName = (name != null && name.isNotEmpty)
        ? name
        : fallbackName;
    if (resolvedName != null && resolvedName.isNotEmpty) {
      await prefs.setString(_nameKey, resolvedName);
    } else {
      await prefs.remove(_nameKey);
    }
  }
}
