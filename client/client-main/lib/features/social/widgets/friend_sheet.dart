import 'package:flutter/material.dart';

import 'package:capstone_app/services/friendship_service.dart';
import 'package:capstone_app/widgets/user_profile_avatar.dart';

class FriendSheet extends StatefulWidget {
  const FriendSheet({super.key});

  @override
  State<FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<FriendSheet> {
  final _searchController = TextEditingController();

  String? _currentUserId;
  String? _message;
  int _tabIndex = 0;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasSearched = false;

  List<FriendshipRecord> _friends = const [];
  List<FriendshipRecord> _receivedRequests = const [];
  List<FriendshipRecord> _sentRequests = const [];
  List<FriendshipRecord> _blockedFriends = const [];
  List<FriendUser> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final userId = await FriendshipService.currentUserId();
      final results = await Future.wait([
        FriendshipService.fetchFriends(),
        FriendshipService.fetchReceivedRequests(),
        FriendshipService.fetchSentRequests(),
        FriendshipService.fetchBlockedFriends(),
      ]);

      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _friends = results[0];
        _receivedRequests = results[1];
        _sentRequests = results[2];
        _blockedFriends = results[3];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _hasSearched = true;
        _searchResults = const [];
        _message = '닉네임이나 이메일을 2글자 이상 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _message = null;
    });

    try {
      final users = await FriendshipService.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _searchResults = users;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _isSearching = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage, {
    VoidCallback? afterSuccess,
  }) async {
    setState(() => _message = null);

    try {
      await action();
      if (!mounted) return;
      try {
        await _loadAll();
      } catch (_) {
        if (!mounted) return;
      }
      if (!mounted) return;
      setState(() {
        afterSuccess?.call();
        _message = successMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    }
  }

  Future<void> _sendFriendRequest(FriendUser user) {
    return _runAction(
      () => FriendshipService.sendRequest(user.id),
      '친구 요청을 보냈습니다.',
      afterSuccess: () {
        _tabIndex = 2;
        _searchResults = _searchResults
            .where((candidate) => candidate.id != user.id)
            .toList(growable: false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '친구',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isLoading ? null : _loadAll,
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSearchBox(),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _message!,
                    style: const TextStyle(
                      color: Color(0xFFFFD15C),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (_hasSearched) ...[
                const SizedBox(height: 10),
                _buildSearchResults(),
              ],
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF6B3A1F)),
              const SizedBox(height: 8),
              _buildTabs(),
              const SizedBox(height: 10),
              SizedBox(height: 300, child: _buildTabBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchUsers(),
            decoration: InputDecoration(
              hintText: '닉네임 또는 이메일 검색',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 18,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6B3A1F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFFD15C)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: _isSearching ? '검색 중' : '검색',
          color: const Color(0xFF4DA6FF),
          onTap: _isSearching ? null : _searchUsers,
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD15C)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: _innerBoxDecoration(),
        child: Text(
          '검색 결과가 없습니다.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      height: 132,
      decoration: _innerBoxDecoration(),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _searchResults.length,
        separatorBuilder: (_, _) =>
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 10),
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return _FriendUserRow(
            user: user,
            title: user.displayName,
            subtitle: user.subtitle,
            leadingIcon: Icons.person_add_alt_1,
            actions: [
              _ActionButton(
                label: '요청',
                color: const Color(0xFF4DA6FF),
                onTap: () => _sendFriendRequest(user),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['친구', '받은 요청', '보낸 요청', '차단'];
    final counts = [
      _friends.length,
      _receivedRequests.length,
      _sentRequests.length,
      _blockedFriends.length,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _tabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF8F2A1E)
                      : Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFD15C)
                        : const Color(0xFF6B3A1F),
                  ),
                ),
                child: Text(
                  '${labels[index]} ${counts[index]}',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD15C)),
      );
    }

    final userId = _currentUserId ?? '';
    switch (_tabIndex) {
      case 0:
        return _buildFriendshipList(
          records: _friends,
          emptyMessage: '아직 친구가 없어요',
          itemBuilder: (record) {
            final user = record.otherUser(userId);
            return _FriendUserRow(
              user: user,
              title: user.displayName,
              subtitle: user.subtitle,
              leadingIcon: Icons.people_outline,
              actions: [
                _ActionButton(
                  label: '삭제',
                  color: const Color(0xFFFF7043),
                  onTap: () => _runAction(
                    () => FriendshipService.unfriend(record.id),
                    '친구를 삭제했습니다.',
                  ),
                ),
                _ActionButton(
                  label: '차단',
                  color: const Color(0xFFE53935),
                  onTap: () => _runAction(
                    () => FriendshipService.block(record.id),
                    '친구를 차단했습니다.',
                  ),
                ),
              ],
            );
          },
        );
      case 1:
        return _buildFriendshipList(
          records: _receivedRequests,
          emptyMessage: '받은 친구 요청이 없습니다.',
          itemBuilder: (record) {
            final user = record.requestSender;
            return _FriendUserRow(
              user: user,
              title: user.displayName,
              subtitle: user.subtitle,
              leadingIcon: Icons.mark_email_unread_outlined,
              actions: [
                _ActionButton(
                  label: '수락',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _runAction(
                    () => FriendshipService.accept(record.id),
                    '친구 요청을 수락했습니다.',
                  ),
                ),
                _ActionButton(
                  label: '거절',
                  color: const Color(0xFFFF7043),
                  onTap: () => _runAction(
                    () => FriendshipService.reject(record.id),
                    '친구 요청을 거절했습니다.',
                  ),
                ),
                _ActionButton(
                  label: '차단',
                  color: const Color(0xFFE53935),
                  onTap: () => _runAction(
                    () => FriendshipService.block(record.id),
                    '사용자를 차단했습니다.',
                  ),
                ),
              ],
            );
          },
        );
      case 2:
        return _buildFriendshipList(
          records: _sentRequests,
          emptyMessage: '보낸 친구 요청이 없습니다.',
          itemBuilder: (record) {
            final user = record.otherUser(userId);
            return _FriendUserRow(
              user: user,
              title: user.displayName,
              subtitle: user.subtitle,
              leadingIcon: Icons.outgoing_mail,
              actions: [
                _ActionButton(
                  label: '취소',
                  color: const Color(0xFFFF7043),
                  onTap: () => _runAction(
                    () => FriendshipService.cancel(record.id),
                    '친구 요청을 취소했습니다.',
                  ),
                ),
              ],
            );
          },
        );
      default:
        return _buildFriendshipList(
          records: _blockedFriends,
          emptyMessage: '차단한 사용자가 없습니다.',
          itemBuilder: (record) {
            final user = record.otherUser(userId);
            return _FriendUserRow(
              user: user,
              title: user.displayName,
              subtitle: user.subtitle,
              leadingIcon: Icons.block,
              actions: [
                _ActionButton(
                  label: '해제',
                  color: const Color(0xFF4DA6FF),
                  onTap: () => _runAction(
                    () => FriendshipService.unblock(record.id),
                    '차단을 해제했습니다.',
                  ),
                ),
              ],
            );
          },
        );
    }
  }

  Widget _buildFriendshipList({
    required List<FriendshipRecord> records,
    required String emptyMessage,
    required Widget Function(FriendshipRecord record) itemBuilder,
  }) {
    if (records.isEmpty) {
      return _FriendEmptyState(message: emptyMessage);
    }

    return Container(
      decoration: _innerBoxDecoration(),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: records.length,
        separatorBuilder: (_, _) =>
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 10),
        itemBuilder: (context, index) => itemBuilder(records[index]),
      ),
    );
  }

  BoxDecoration _innerBoxDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF6B3A1F)),
    );
  }
}

class _FriendEmptyState extends StatelessWidget {
  const _FriendEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '검색으로 친구를 추가하고 함께 레이드에 도전해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendUserRow extends StatelessWidget {
  const _FriendUserRow({
    required this.user,
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.actions,
  });

  final FriendUser user;
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            UserProfileAvatar(profileImage: user.profileImage, size: 38),
            if (user.profileImage == null ||
                !user.profileImage!.hasDisplayImage)
              Icon(leadingIcon, color: const Color(0xFF4DA6FF), size: 15),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Wrap(spacing: 6, runSpacing: 6, children: actions),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? color : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
