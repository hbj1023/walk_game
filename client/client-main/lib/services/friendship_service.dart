import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class FriendUser {
  final String id;
  final String email;
  final String name;
  final String nickname;
  final String username;

  const FriendUser({
    required this.id,
    required this.email,
    required this.name,
    required this.nickname,
    required this.username,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: _asString(json['id']),
      email: _asString(json['email']),
      name: _asString(json['name']),
      nickname: _asString(json['nickname']),
      username: _asString(json['username']),
    );
  }

  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return id;
  }

  String get subtitle {
    if (email.isNotEmpty && email != displayName) return email;
    if (username.isNotEmpty && username != displayName) return username;
    return id;
  }
}

class FriendshipRecord {
  final String id;
  final String userLow;
  final String userHigh;
  final String status;
  final String requestedByUser;
  final FriendUser? lowUser;
  final FriendUser? highUser;
  final FriendUser? requester;

  const FriendshipRecord({
    required this.id,
    required this.userLow,
    required this.userHigh,
    required this.status,
    required this.requestedByUser,
    required this.lowUser,
    required this.highUser,
    required this.requester,
  });

  factory FriendshipRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] is Map<String, dynamic>
        ? json['expand'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return FriendshipRecord(
      id: _asString(json['id']),
      userLow: _asString(json['user_low']),
      userHigh: _asString(json['user_high']),
      status: _asString(json['status']),
      requestedByUser: _asString(json['requested_by_user']),
      lowUser: _expandedUser(expand['user_low']),
      highUser: _expandedUser(expand['user_high']),
      requester: _expandedUser(expand['requested_by_user']),
    );
  }

  FriendUser otherUser(String currentUserId) {
    if (userLow == currentUserId) {
      return highUser ?? _fallbackUser(userHigh);
    }
    return lowUser ?? _fallbackUser(userLow);
  }

  FriendUser get requestSender {
    return requester ?? _fallbackUser(requestedByUser);
  }
}

class FriendshipService {
  static const _requestTimeout = Duration(seconds: 10);

  static Future<List<FriendUser>> searchUsers(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const [];

    final response = await _sendWithTimeout(
      http.get(
        ApiConfig.uri(
          '/api/users/search',
        ).replace(queryParameters: {'q': normalized}),
        headers: await _authHeaders(),
      ),
    );
    final body = _decodeBody(response, '사용자를 검색하지 못했습니다.');
    _throwIfFailed(response, body, '사용자를 검색하지 못했습니다.');

    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(FriendUser.fromJson)
        .where((user) => user.id.isNotEmpty)
        .toList();
  }

  static Future<List<FriendshipRecord>> fetchFriends() {
    return _fetchFriendshipList('friends');
  }

  static Future<List<FriendshipRecord>> fetchReceivedRequests() {
    return _fetchFriendshipList('friend-requests');
  }

  static Future<List<FriendshipRecord>> fetchSentRequests() {
    return _fetchFriendshipList('sent-friend-requests');
  }

  static Future<List<FriendshipRecord>> fetchBlockedFriends() {
    return _fetchFriendshipList('blocked-friends');
  }

  static Future<void> sendRequest(String targetUserId) async {
    final response = await _sendWithTimeout(
      http.post(
        ApiConfig.uri('/api/friendships/request'),
        headers: await _authHeaders(),
        body: jsonEncode({'targetUserId': targetUserId}),
      ),
    );
    final body = _decodeBody(response, '친구 요청을 보내지 못했습니다.');
    _throwIfFailed(response, body, '친구 요청을 보내지 못했습니다.');
  }

  static Future<void> accept(String friendshipId) {
    return _postAction(friendshipId, 'accept', '친구 요청을 수락하지 못했습니다.');
  }

  static Future<void> reject(String friendshipId) {
    return _postAction(friendshipId, 'reject', '친구 요청을 거절하지 못했습니다.');
  }

  static Future<void> cancel(String friendshipId) {
    return _postAction(friendshipId, 'cancel', '친구 요청을 취소하지 못했습니다.');
  }

  static Future<void> block(String friendshipId) {
    return _postAction(friendshipId, 'block', '친구를 차단하지 못했습니다.');
  }

  static Future<void> unblock(String friendshipId) {
    return _postAction(friendshipId, 'unblock', '차단을 해제하지 못했습니다.');
  }

  static Future<void> unfriend(String friendshipId) {
    return _postAction(friendshipId, 'unfriend', '친구를 삭제하지 못했습니다.');
  }

  static Future<String> currentUserId() async {
    final saved = (await AuthService.getSavedUserId())?.trim();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }

    await AuthService.fetchMainMessage();
    final refreshed = (await AuthService.getSavedUserId())?.trim();
    if (refreshed == null || refreshed.isEmpty) {
      throw const AuthException('사용자 정보를 불러오지 못했습니다.');
    }
    return refreshed;
  }

  static Future<List<FriendshipRecord>> _fetchFriendshipList(
    String resource,
  ) async {
    final userId = await currentUserId();
    final response = await _sendWithTimeout(
      http.get(
        ApiConfig.uri('/api/users/$userId/$resource'),
        headers: await _authHeaders(),
      ),
    );
    final body = _decodeBody(response, '친구 정보를 불러오지 못했습니다.');
    _throwIfFailed(response, body, '친구 정보를 불러오지 못했습니다.');

    final data = body['data'];
    if (data is! Map<String, dynamic>) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(FriendshipRecord.fromJson)
        .where((record) => record.id.isNotEmpty)
        .toList();
  }

  static Future<void> _postAction(
    String friendshipId,
    String action,
    String fallbackMessage,
  ) async {
    final response = await _sendWithTimeout(
      http.post(
        ApiConfig.uri('/api/friendships/$friendshipId/$action'),
        headers: await _authHeaders(),
      ),
    );
    final body = _decodeBody(response, fallbackMessage);
    _throwIfFailed(response, body, fallbackMessage);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('로그인이 필요합니다.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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

  static void _throwIfFailed(
    http.Response response,
    Map<String, dynamic> body,
    String fallbackMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final error = _asString(body['error']);
    if (error.isNotEmpty) {
      throw AuthException(_friendlyMessage(error));
    }

    final message = _asString(body['message']);
    throw AuthException(
      message.isNotEmpty ? _friendlyMessage(message) : fallbackMessage,
    );
  }
}

FriendUser? _expandedUser(dynamic value) {
  if (value is Map<String, dynamic>) {
    return FriendUser.fromJson(value);
  }
  return null;
}

FriendUser _fallbackUser(String id) {
  return FriendUser(id: id, email: '', name: '', nickname: '', username: '');
}

String _asString(dynamic value) {
  if (value is String) return value;
  return '';
}

String _friendlyMessage(String message) {
  switch (message) {
    case 'cannot request friendship with yourself':
      return '자기 자신에게는 친구 요청을 보낼 수 없습니다.';
    case 'friend request already pending':
      return '이미 대기 중인 친구 요청입니다.';
    case 'friendship already accepted':
      return '이미 친구입니다.';
    case 'friendship is blocked':
      return '차단된 친구 관계입니다. 먼저 차단을 해제해주세요.';
    case 'only the request receiver can respond':
      return '받은 친구 요청만 처리할 수 있습니다.';
    case 'only the request sender can cancel':
      return '보낸 친구 요청만 취소할 수 있습니다.';
    default:
      return message;
  }
}
