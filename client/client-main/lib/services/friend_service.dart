import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class FriendException implements Exception {
  final String message;
  const FriendException(this.message);

  @override
  String toString() => message;
}

class Friend {
  final String id;
  final String name;
  final String email;

  const Friend({required this.id, required this.name, required this.email});

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: (json['id'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    email: (json['email'] ?? '') as String,
  );
}

class FriendRequest {
  final String id;
  final String fromName;
  final String fromEmail;

  const FriendRequest({
    required this.id,
    required this.fromName,
    required this.fromEmail,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: (json['id'] ?? '') as String,
    fromName: (json['from_name'] ?? json['name'] ?? '') as String,
    fromEmail: (json['from_email'] ?? json['email'] ?? '') as String,
  );
}

class FriendService {
  static const _timeout = Duration(seconds: 10);

  static Future<List<Friend>> fetchFriends() async {
    final resp = await _get('/friends');
    final list = resp['friends'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Friend.fromJson)
        .toList();
  }

  static Future<List<FriendRequest>> fetchIncomingRequests() async {
    final resp = await _get('/friends/requests');
    final list = resp['requests'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(FriendRequest.fromJson)
        .toList();
  }

  static Future<void> sendRequest(String targetName) async {
    await _post('/friends/request', {'target_name': targetName.trim()});
  }

  static Future<void> acceptRequest(String requestId) async {
    await _post('/friends/accept', {'request_id': requestId});
  }

  static Future<void> rejectRequest(String requestId) async {
    await _post('/friends/reject', {'request_id': requestId});
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const FriendException('로그인 정보가 없습니다.');
    }
    late final http.Response response;
    try {
      response = await http
          .get(
            ApiConfig.uri(path),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on SocketException {
      throw const FriendException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw const FriendException('서버 응답이 지연되고 있습니다.');
    }
    return _decode(response);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const FriendException('로그인 정보가 없습니다.');
    }
    late final http.Response response;
    try {
      response = await http
          .post(
            ApiConfig.uri(path),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on SocketException {
      throw const FriendException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw const FriendException('서버 응답이 지연되고 있습니다.');
    }
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = (body['error'] as String?)?.trim();
      throw FriendException((msg == null || msg.isEmpty) ? '요청에 실패했습니다.' : msg);
    }
    return body;
  }
}
