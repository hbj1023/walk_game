import 'package:flutter/material.dart';

import 'package:capstone_app/services/game_api_service.dart'
    show equipmentSetNameForKey;
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
    required this.actions,
  });

  final FriendUser user;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showFriendProfile(context),
          child: UserProfileAvatar(profileImage: user.profileImage, size: 38),
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

  void _showFriendProfile(BuildContext context) {
    final profileStats = user.profileStats;
    final hasStats = profileStats?.hasStats == true;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      UserProfileAvatar(
                        profileImage: user.profileImage,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (user.characterLevel != null)
                              Text(
                                'Lv.${user.characterLevel}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD15C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCombatPowerBlock(),
                  const SizedBox(height: 10),
                  if (hasStats) ...[
                    _buildStatGrid(profileStats!),
                    const SizedBox(height: 10),
                    _buildEquipmentProfileSection(profileStats),
                  ] else ...[
                    const SizedBox(height: 10),
                    const Text(
                      '캐릭터 스탯 정보가 아직 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCombatPowerBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: const Color(0xFF6B3A1F)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Color(0xFFFFD15C),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            '전투력',
            style: TextStyle(
              color: Color(0xFFFFD15C),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            user.combatPower == null ? '-' : '${user.combatPower}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(FriendProfileStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatTile('최대 HP', stats.finalStats['hp'] ?? 0, tileWidth),
            _buildStatTile('공격력', stats.finalStats['attack'] ?? 0, tileWidth),
            _buildStatTile('방어력', stats.finalStats['defense'] ?? 0, tileWidth),
            _buildStatTile('민첩', stats.finalStats['agility'] ?? 0, tileWidth),
          ],
        );
      },
    );
  }

  Widget _buildStatTile(String label, int value, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: const Color(0xFF6B3A1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentProfileSection(FriendProfileStats stats) {
    final equippedItems = stats.equippedItems;
    final primarySet = _primaryEquippedSet(stats);
    final weapon = stats.equippedWeapon;
    final hasActiveSet = primarySet != null && primarySet.count >= 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        border: Border.all(color: const Color(0xFF6B3A1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, color: Color(0xFFFFD15C), size: 16),
              const SizedBox(width: 6),
              const Text(
                '장착 정보',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${equippedItems.length}/4',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasActiveSet) ...[
            Text(
              '${primarySet.name} ${primarySet.count}/4',
              style: const TextStyle(
                color: Color(0xFFFFD15C),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            ...stats.activeSetBonuses.map(
              (bonus) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  bonus.displayDescription,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ),
            ),
          ] else if (weapon != null) ...[
            Text(
              weapon.weaponTypeLabel.isEmpty
                  ? '장착 무기: ${weapon.name}'
                  : '장착 무기: ${weapon.weaponTypeLabel}',
              style: const TextStyle(
                color: Color(0xFFFFD15C),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              weapon.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ] else
            const Text(
              '장착한 세트나 무기가 없습니다.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          if (equippedItems.isNotEmpty) ...[
            const Divider(color: Color(0xFF6B3A1F), height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: equippedItems
                  .map((item) => _buildEquippedChip(item))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquippedChip(FriendEquippedItem item) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '${_slotLabel(item)} ${item.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
    );
  }

  _FriendEquippedSet? _primaryEquippedSet(FriendProfileStats stats) {
    final counts = <String, int>{};
    for (final item in stats.equippedItems) {
      final setKey = item.setKey.trim();
      if (setKey.isEmpty) continue;
      counts[setKey] = (counts[setKey] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final entry = entries.first;
    final name = equipmentSetNameForKey(entry.key);
    return _FriendEquippedSet(
      name: name.isEmpty ? entry.key : name,
      count: entry.value,
    );
  }

  String _slotLabel(FriendEquippedItem item) {
    if (item.isWeapon) return '무기';
    return switch (item.slot) {
      'helmet' => '투구',
      'armor' => '갑옷',
      'shoes' => '신발',
      _ => '장비',
    };
  }
}

class _FriendEquippedSet {
  final String name;
  final int count;

  const _FriendEquippedSet({required this.name, required this.count});
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
