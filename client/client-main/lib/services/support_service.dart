import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class SupportService {
  static const _requestTimeout = Duration(seconds: 10);

  static Future<void> submitBugReport({
    required String screen,
    required String message,
  }) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('로그인이 필요합니다.');
    }

    final response = await _sendWithTimeout(
      http.post(
        ApiConfig.uri('/api/support/bug-reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'screen': screen.trim(), 'message': message.trim()}),
      ),
    );
    final body = _decodeBody(response, '버그 제보를 보내지 못했습니다.');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _asString(body['error']);
      final messageText = _asString(body['message']);
      throw AuthException(
        error.isNotEmpty
            ? _localizeSupportError(error)
            : messageText.isNotEmpty
            ? _localizeSupportError(messageText)
            : '버그 제보를 보내지 못했습니다.',
      );
    }
  }

  static Future<http.Response> _sendWithTimeout(
    Future<http.Response> request,
  ) async {
    try {
      return await request.timeout(_requestTimeout);
    } on SocketException {
      throw const AuthException('API 서버에 연결하지 못했습니다.');
    } on http.ClientException {
      throw const AuthException('API 서버 주소와 포트를 확인해주세요.');
    } on TimeoutException {
      throw const AuthException('서버 응답 시간이 초과되었습니다.');
    }
  }

  static Map<String, dynamic> _decodeBody(
    http.Response response,
    String fallbackMessage,
  ) {
    if (response.body.isEmpty) return {};

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

  static String _localizeSupportError(String message) {
    return switch (message.trim().toLowerCase()) {
      'message is required' => '제보 내용을 입력해주세요.',
      'message is too long' => '제보 내용이 너무 깁니다.',
      'screen is too long' => '발생 화면 이름이 너무 깁니다.',
      'unauthorized' => '로그인이 필요합니다.',
      _ => message,
    };
  }

  static String _asString(dynamic value) {
    if (value is String) return value;
    return '';
  }
}
