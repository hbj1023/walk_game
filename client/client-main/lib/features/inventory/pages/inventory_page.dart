import 'dart:async';

import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_audio_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';
import 'package:capstone_app/widgets/character_stats_panel.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
import 'package:capstone_app/widgets/game_top_actions.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';
import 'package:capstone_app/widgets/pixel_bottom_nav.dart';

const kBgColor = Color(0xFF110A05);
const kPanelColor = Color(0xFF271610);
const kBorderColor = Color(0xFF5C3D22);
const kAccentRed = Color(0xFF5A2A10);
const kGold = Color(0xFFCCA84A);
const kTextLight = Color(0xFFD9C9A8);
const kTextGray = Color(0xFF7A6247);
const kGreen = Color(0xFF4E8C4E);
const kSlotColor = Color(0xFF190E07);
const kCommonColor = Color(0xFF56B866);
const kRareColor = Color(0xFF4C8DFF);
const kEpicColor = Color(0xFFC177FF);

const _statKeys = ['hp', 'attack', 'defense', 'agility'];
const _statLabel = {
  'hp': '최대 HP',
  'attack': '공격력',
  'defense': '방어력',
  'agility': '민첩성',
};
const _statDesc = {
  'hp': '최대 HP - 캐릭터의 최대 생명력을 증가시킵니다.',
  'attack': '공격력 - 적에게 가하는 피해량을 증가시킵니다.',
  'defense': '방어력 - 적에게 받는 피해를 줄입니다.',
  'agility': '민첩성 - 걸음 거리로 얻는 공격 횟수 효율에 영향을 줍니다.',
};
const _slotLabels = {
  'helmet': '투구',
  'armor': '갑옷',
  'sword': '무기',
  'shoes': '신발',
};

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int _selectedTab = 0;
  int _inventoryFilter = 0;
  String? _selectedSlot;
  String _selectedStatKey = 'hp';
  String _userName = '...';
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  List<OwnedInventoryItem> _items = const [];
  StatUpgradeSummary? _statSummary;
  ExplorationUpgradeSummary? _explorationSummary;
  CharacterStatsSummary? _characterStatsSummary;
  _EquipmentStatFeedback? _equipmentFeedback;
  Timer? _equipmentFeedbackTimer;

  final _gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    _gs.addListener(_onGameStateChanged);
    _loadUserName();
    _loadInventory();
  }

  @override
  void dispose() {
    _equipmentFeedbackTimer?.cancel();
    _gs.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getSavedName();
    if (mounted) setState(() => _userName = name ?? '모험가');
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.fetchMainMessage();
      final results = await Future.wait<Object>([
        GameApiService.fetchInventoryItems(),
        GameApiService.fetchStatUpgradeSummary(),
        GameApiService.fetchExplorationUpgradeSummary(),
        GameApiService.fetchCharacterStatsSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<OwnedInventoryItem>;
        _statSummary = results[1] as StatUpgradeSummary;
        _explorationSummary = results[2] as ExplorationUpgradeSummary;
        _characterStatsSummary = results[3] as CharacterStatsSummary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    showGameToast(context, message);
  }

  void _showEquipmentStatFeedback({
    required OwnedInventoryItem item,
    required String action,
    required CharacterStatsSummary before,
    required CharacterStatsSummary after,
  }) {
    final statDeltas = _buildStatDeltas(before.finalStats, after.finalStats);
    final beforePower = _calculateCombatPower(before.finalStats);
    final afterPower = _calculateCombatPower(after.finalStats);
    final feedback = _EquipmentStatFeedback(
      id: DateTime.now().microsecondsSinceEpoch,
      title: '${item.itemTemplate.displayName} $action 완료',
      combatPower: afterPower,
      combatPowerDelta: afterPower - beforePower,
      statDeltas: statDeltas,
    );

    _equipmentFeedbackTimer?.cancel();
    setState(() => _equipmentFeedback = feedback);
    _equipmentFeedbackTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || _equipmentFeedback?.id != feedback.id) return;
      setState(() => _equipmentFeedback = null);
    });
  }

  List<_StatDelta> _buildStatDeltas(
    Map<String, int> before,
    Map<String, int> after,
  ) {
    final deltas = <_StatDelta>[];
    for (final key in _statKeys) {
      final delta = (after[key] ?? 0) - (before[key] ?? 0);
      if (delta == 0) continue;
      deltas.add(_StatDelta(label: _statLabel[key] ?? key, value: delta));
    }
    return deltas;
  }

  int _calculateCombatPower(Map<String, int>? stats) {
    if (stats == null || stats.isEmpty) return 0;
    final hp = stats['hp'] ?? 0;
    final attack = stats['attack'] ?? 0;
    final defense = stats['defense'] ?? 0;
    final agility = stats['agility'] ?? 0;
    return (hp / 3 + attack * 8 + defense * 5 + agility * 4).round();
  }

  int get _statPointBalance => _statSummary?.statExp ?? _gs.statExp;

  Widget _buildSelectedTab() {
    return switch (_selectedTab) {
      0 => _buildInventoryTab(),
      1 => _buildStatsTab(),
      _ => _buildExplorationTab(),
    };
  }

  List<OwnedInventoryItem> get _filteredItems {
    final items = switch (_inventoryFilter) {
      1 => _items.where((item) => item.itemTemplate.isEquipment),
      2 => _items.where(
        (item) =>
            item.itemTemplate.isConsumable &&
            !item.itemTemplate.isInventoryMisc,
      ),
      3 => _items.where(
        (item) =>
            item.itemTemplate.isInventoryMisc ||
            (!item.itemTemplate.isEquipment && !item.itemTemplate.isConsumable),
      ),
      _ => _items,
    };
    return _sortInventoryItems(items);
  }

  List<OwnedInventoryItem> _sortInventoryItems(
    Iterable<OwnedInventoryItem> source,
  ) {
    final indexedItems = source.toList().asMap().entries.toList();
    indexedItems.sort((a, b) {
      final categoryCompare = _inventoryCategoryRank(
        a.value,
      ).compareTo(_inventoryCategoryRank(b.value));
      if (categoryCompare != 0) return categoryCompare;
      final equippedCompare = _inventoryEquippedRank(
        a.value,
      ).compareTo(_inventoryEquippedRank(b.value));
      if (equippedCompare != 0) return equippedCompare;

      if (a.value.isEquipped && b.value.isEquipped) {
        final slotCompare = _inventorySlotRank(
          a.value,
        ).compareTo(_inventorySlotRank(b.value));
        if (slotCompare != 0) return slotCompare;
        final setCompare = _inventorySetRank(
          a.value,
        ).compareTo(_inventorySetRank(b.value));
        if (setCompare != 0) return setCompare;
        final rarityCompare = _inventoryRarityRank(
          a.value,
        ).compareTo(_inventoryRarityRank(b.value));
        if (rarityCompare != 0) return rarityCompare;
        return a.key.compareTo(b.key);
      }

      final setCompare = _inventorySetRank(
        a.value,
      ).compareTo(_inventorySetRank(b.value));
      if (setCompare != 0) return setCompare;
      final slotCompare = _inventorySlotRank(
        a.value,
      ).compareTo(_inventorySlotRank(b.value));
      if (slotCompare != 0) return slotCompare;
      final rarityCompare = _inventoryRarityRank(
        a.value,
      ).compareTo(_inventoryRarityRank(b.value));
      if (rarityCompare != 0) return rarityCompare;
      return a.key.compareTo(b.key);
    });
    return indexedItems.map((entry) => entry.value).toList();
  }

  int _inventoryCategoryRank(OwnedInventoryItem item) {
    if (item.itemTemplate.isEquipment) return 0;
    if (item.itemTemplate.isInventoryMisc) return 2;
    if (item.itemTemplate.isConsumable) return 1;
    return 2;
  }

  int _inventorySetRank(OwnedInventoryItem item) {
    if (!item.itemTemplate.isEquipment) return 99;
    return switch (item.itemTemplate.inferredSetKey) {
      'vanguard' => 0,
      'berserker' => 1,
      'sentinel' => 2,
      'shadow' => 3,
      'colossus' => 4,
      'crusher' => 5,
      'riftbreaker' => 15,
      'quarry_swordsman' => 10,
      'quarry_berserker' => 11,
      'quarry_spearmaster' => 12,
      'quarry_rogue' => 13,
      'quarry_knight' => 14,
      _ => 90,
    };
  }

  int _inventorySlotRank(OwnedInventoryItem item) {
    if (!item.itemTemplate.isEquipment) return 99;
    return switch (item.itemTemplate.equipmentSlot) {
      'sword' => 0,
      'helmet' => 1,
      'armor' => 2,
      'shoes' => 3,
      _ => 4,
    };
  }

  int _inventoryRarityRank(OwnedInventoryItem item) {
    return switch (item.itemTemplate.rarity) {
      'common' => 0,
      'rare' => 1,
      'epic' => 2,
      'legendary' => 3,
      _ => 9,
    };
  }

  int _inventoryEquippedRank(OwnedInventoryItem item) =>
      item.isEquipped ? 0 : 1;

  OwnedInventoryItem? _equippedInSlot(String slot) {
    for (final item in _items) {
      if (item.isEquipped && item.itemTemplate.equipmentSlot == slot) {
        return item;
      }
    }
    return null;
  }

  // 반환값: 'action' | 'sell' | null
  Future<String?> _showItemDialog(OwnedInventoryItem item) async {
    final isInfoOnly = item.itemTemplate.blocksManualInventoryAction;
    final action = item.itemTemplate.isConsumable
        ? '사용'
        : item.isEquipped
        ? '해제'
        : '장착';
    final sellPrice = (item.itemTemplate.priceCoin * 0.5).floor();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPanelColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: kBorderColor, width: 1.5),
        ),
        title: Text(
          item.itemTemplate.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemTemplate.statSummary,
              style: const TextStyle(color: kTextLight, fontSize: 13),
            ),
            if (item.itemTemplate.setEffectLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSetEffectInfo(item.itemTemplate),
            ],
            if (!isInfoOnly) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Image.asset(
                    'assets/images/icon/coin_icon.png',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '판매가: $sellPrice',
                    style: const TextStyle(color: kGold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              isInfoOnly ? '닫기' : '취소',
              style: const TextStyle(color: kTextGray),
            ),
          ),
          if (!isInfoOnly)
            TextButton(
              onPressed: () => Navigator.pop(context, 'sell'),
              child: const Text(
                '판매',
                style: TextStyle(color: Color(0xFFE06030)),
              ),
            ),
          if (!isInfoOnly)
            TextButton(
              onPressed: () => Navigator.pop(context, 'action'),
              child: Text(action, style: const TextStyle(color: kGold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSetEffectInfo(ItemTemplate template) {
    final lines = template.setEffectLines;
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kGold.withValues(alpha: 0.42), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.setNameLabel,
            style: const TextStyle(
              color: kGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                style: const TextStyle(color: kTextLight, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openItemAction(OwnedInventoryItem item) async {
    final result = await _showItemDialog(item);
    if (result == null) return;

    if (result == 'sell') {
      if (item.isEquipped) {
        _showMessage('착용 중인 장비는 판매할 수 없습니다. 먼저 해제해주세요.');
        return;
      }
      await _sellItem(item);
      return;
    }

    // result == 'action'
    final action = item.itemTemplate.isConsumable
        ? '사용'
        : item.isEquipped
        ? '해제'
        : '장착';
    setState(() => _isActionLoading = true);
    try {
      if (item.itemTemplate.isConsumable) {
        await GameApiService.useConsumable(item.itemTemplate.id);
      } else {
        CharacterStatsSummary? beforeStats;
        try {
          beforeStats = await GameApiService.fetchCharacterStatsSummary();
        } catch (_) {
          beforeStats = null;
        }

        if (item.isEquipped) {
          await GameApiService.unequipItem(item.id);
        } else {
          await GameApiService.equipItem(item.id);
        }
        await _loadInventory();

        CharacterStatsSummary? afterStats;
        if (beforeStats != null) {
          try {
            afterStats = await GameApiService.fetchCharacterStatsSummary();
          } catch (_) {
            afterStats = null;
          }
        }

        if (mounted && beforeStats != null && afterStats != null) {
          _showEquipmentStatFeedback(
            item: item,
            action: action,
            before: beforeStats,
            after: afterStats,
          );
        } else if (mounted) {
          _showMessage('${item.itemTemplate.displayName} $action 완료');
        }
        return;
      }
      await _loadInventory();
      if (mounted) _showMessage('${item.itemTemplate.displayName} $action 완료');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _sellItem(OwnedInventoryItem item) async {
    setState(() => _isActionLoading = true);
    try {
      final earned = await GameApiService.sellItem(item: item);
      if (mounted) {
        setState(() => _removeSoldItemLocally(item, quantity: 1));
        GameAudioService.playItemSell();
        _showMessage(
          earned > 0
              ? '${item.itemTemplate.displayName} 판매 완료! +$earned 코인'
              : '${item.itemTemplate.displayName} 판매 완료',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString());
        await _loadInventory();
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _removeSoldItemLocally(
    OwnedInventoryItem soldItem, {
    required int quantity,
  }) {
    if (soldItem.itemTemplate.isEquipment) {
      _items = _items.where((item) => item.id != soldItem.id).toList();
      return;
    }

    _items = _items
        .map((item) {
          if (item.id != soldItem.id) return item;
          final remainingQuantity = item.quantity - quantity;
          if (remainingQuantity <= 0) return null;
          return OwnedInventoryItem(
            id: item.id,
            status: item.status,
            quantity: remainingQuantity,
            itemTemplate: item.itemTemplate,
          );
        })
        .whereType<OwnedInventoryItem>()
        .toList();
  }

  Future<void> _upgradeStat(String key) async {
    if (_isActionLoading) return;
    final cost = _statSummary?.costs[key] ?? 0;
    if (_statPointBalance < cost) {
      _showMessage('SP가 부족합니다. 레벨업으로 SP를 모아주세요.');
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final summary = await GameApiService.upgradeStat(key);
      if (!mounted) return;
      setState(() {
        _statSummary = summary;
      });
      _showMessage('${_statLabel[key]} 강화 완료! -$cost SP');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _upgradeExploration(String key) async {
    if (_isActionLoading) return;
    final upgrade = _explorationSummary?.upgrades[key];
    if (upgrade == null || upgrade.isMaxed) return;
    if (_explorationSummary?.serverAvailable != true) {
      _showMessage('서버 업데이트 후 사용할 수 있습니다.');
      return;
    }
    if (_gs.coins < upgrade.costCoin) {
      _showMessage('코인이 부족합니다.');
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final summary = await GameApiService.upgradeExploration(key);
      if (!mounted) return;
      setState(() => _explorationSummary = summary);
      _showMessage('${upgrade.title} 강화 완료! -${upgrade.costCoin} 코인');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: kBgColor,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildEquipmentSection(),
                  _buildActiveSetEffectsPanel(),
                  _buildTabBar(),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(color: kGold),
                    )
                  else if (_error != null)
                    _buildError()
                  else
                    _buildSelectedTab(),
                ],
              ),
            ),
          ),
          if (_isActionLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: kGold),
                ),
              ),
            ),
          _buildEquipmentStatFeedbackOverlay(),
        ],
      ),
    );
  }

  Widget _buildEquipmentStatFeedbackOverlay() {
    return Positioned(
      top: 104,
      left: 14,
      right: 14,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          reverseDuration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, -0.22),
              end: Offset.zero,
            ).animate(curved);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: _equipmentFeedback == null
              ? const SizedBox.shrink(key: ValueKey('empty-equipment-feedback'))
              : _EquipmentStatFeedbackCard(
                  key: ValueKey(_equipmentFeedback!.id),
                  feedback: _equipmentFeedback!,
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _openCharacterStatsDialog,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPlayerProfileBlock(),
                const SizedBox(width: 8),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 6,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCoinCard(),
              const SizedBox(height: 6),
              const GameTopActions(),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProfileFrame() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/profile_frame.png',
          width: 56,
          height: 56,
          fit: BoxFit.contain,
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.person,
            size: 24,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerProfileBlock() {
    return PlayerProfileWithLevel(
      level: _gs.level,
      exp: _gs.exp,
      expToNext: _gs.expToNextLevel,
    );
  }

  void _openCharacterStatsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) =>
          CharacterStatsDialog(userName: _userName, level: _gs.level),
    );
  }

  Widget _buildCoinCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6B3A1F), width: 2),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/icon/coin_icon.png',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 6),
          Text(
            '${_gs.coins}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            _error!,
            style: const TextStyle(color: kTextLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadInventory,
            child: const Text('다시 불러오기'),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSection() {
    return Container(
      height: 218,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPanelColor,
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEquipSlot('helmet'),
                const SizedBox(height: 24),
                _buildEquipSlot('shoes'),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/character/idle.png',
                height: 130,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEquipSlot('armor'),
                const SizedBox(height: 24),
                _buildEquipSlot('sword'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSetEffectsPanel() {
    final bonuses = _characterStatsSummary?.activeSetBonuses ?? const [];
    final groups = _activeSetEffectGroups(bonuses);
    final activeSetCount = groups.fold<int>(
      0,
      (maxCount, group) =>
          group.activeCount > maxCount ? group.activeCount : maxCount,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: kGold, size: 17),
              const SizedBox(width: 6),
              const Text(
                '활성 세트효과',
                style: TextStyle(
                  color: kTextLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (groups.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    groups.map((group) => group.setName).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '$activeSetCount',
                style: const TextStyle(
                  color: kGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (bonuses.isEmpty)
            const Text(
              '같은 세트 방어구 3개부터 효과가 활성화됩니다.',
              style: TextStyle(color: kTextGray, fontSize: 11),
            )
          else
            Column(children: groups.map(_buildActiveSetEffectGroup).toList()),
        ],
      ),
    );
  }

  List<_ActiveSetEffectGroup> _activeSetEffectGroups(
    List<EquipmentSetBonusInfo> bonuses,
  ) {
    final bySet = <String, List<EquipmentSetBonusInfo>>{};
    for (final bonus in bonuses) {
      final key = bonus.setKey.isNotEmpty ? bonus.setKey : bonus.displaySetName;
      bySet.putIfAbsent(key, () => []).add(bonus);
    }

    final groups = bySet.entries.map((entry) {
      final bonuses = entry.value;
      final first = bonuses.first;
      final effectsByCount = <int, List<String>>{};
      for (final bonus in bonuses) {
        effectsByCount.putIfAbsent(bonus.requiredCount, () => []);
        effectsByCount[bonus.requiredCount]!.add(
          _stripActiveSetCountPrefix(
            bonus.displayDescription,
            bonus.requiredCount,
          ),
        );
      }
      final activeCount = effectsByCount.keys.fold<int>(
        0,
        (maxCount, count) => count > maxCount ? count : maxCount,
      );
      return _ActiveSetEffectGroup(
        setName: _shortSetName(first.displaySetName),
        activeCount: activeCount,
        effectsByCount: effectsByCount,
      );
    }).toList();

    groups.sort((a, b) => a.setName.compareTo(b.setName));
    return groups;
  }

  Widget _buildActiveSetEffectGroup(_ActiveSetEffectGroup group) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: kGold.withValues(alpha: 0.38), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.setName,
                style: const TextStyle(
                  color: kTextLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${group.activeCount}세트 활성',
                style: const TextStyle(
                  color: kGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildActiveSetStageLine(3, group.effectsByCount[3]),
          const SizedBox(height: 4),
          _buildActiveSetStageLine(4, group.effectsByCount[4]),
        ],
      ),
    );
  }

  Widget _buildActiveSetStageLine(int count, List<String>? effects) {
    final isActive = effects != null && effects.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 45,
          child: Text(
            '$count세트:',
            style: TextStyle(
              color: isActive ? kGold : kTextGray,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            isActive ? effects.join(' / ') : '미활성',
            style: TextStyle(
              color: isActive ? kTextLight : kTextGray,
              fontSize: 11,
              height: 1.2,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  String _stripActiveSetCountPrefix(String description, int count) {
    final trimmed = description.trim();
    final pattern = RegExp('^$count\\s*[^:]*:\\s*');
    return trimmed.replaceFirst(pattern, '').trim();
  }

  String _shortSetName(String setName) {
    final shortened = setName.replaceFirst(RegExp(r'\s*세트$'), '').trim();
    return shortened.isEmpty ? setName : shortened;
  }

  Widget _buildEquipSlot(String slot) {
    final item = _equippedInSlot(slot);
    final isSelected = _selectedSlot == slot;
    final rarityColor = item == null
        ? kBorderColor
        : _rarityColor(item.itemTemplate);
    return GestureDetector(
      onTap: () => setState(() => _selectedSlot = isSelected ? null : slot),
      onLongPress: item == null ? null : () => _openItemAction(item),
      child: Column(
        children: [
          Text(
            _slotLabels[slot] ?? slot,
            style: const TextStyle(color: kTextGray, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: item == null
                  ? kSlotColor
                  : Color.alphaBlend(
                      rarityColor.withValues(alpha: 0.08),
                      kSlotColor,
                    ),
              border: Border.all(
                color: isSelected ? kGold : rarityColor,
                width: item == null ? 1.5 : 2,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: item == null
                ? Icon(_slotIcon(slot), color: kTextGray, size: 28)
                : Stack(
                    children: [
                      Positioned.fill(
                        bottom: 14,
                        child: Center(
                          child: Image.asset(
                            _inventoryItemImage(item.itemTemplate),
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _buildEquippedMarker(),
                      ),
                      Positioned(
                        left: 1,
                        right: 1,
                        bottom: 1,
                        child: Text(
                          item.itemTemplate.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kTextLight,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  IconData _slotIcon(String slot) {
    return switch (slot) {
      'helmet' => Icons.sports_motorsports,
      'armor' => Icons.shield,
      'sword' => Icons.gavel,
      'shoes' => Icons.directions_run,
      _ => Icons.crop_square,
    };
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildTabButton('인벤', 0),
          const SizedBox(width: 4),
          _buildTabButton('스텟', 1),
          const SizedBox(width: 4),
          _buildTabButton('탐험', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? kAccentRed : kPanelColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: kBorderColor, width: 1.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : kTextGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    return Column(
      children: [
        _buildFilterRow(),
        _buildItemGrid(),
        _buildInventoryBottomRow(),
      ],
    );
  }

  Widget _buildFilterRow() {
    final filters = ['전체', '장비', '소모품', '기타'];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final isActive = _inventoryFilter == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _inventoryFilter = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? kAccentRed : kPanelColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kBorderColor, width: 1.5),
                ),
                child: Text(
                  filters[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? Colors.white : kTextGray,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildItemGrid() {
    final items = _filteredItems;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: items.length < 20 ? 20 : items.length,
        itemBuilder: (context, index) {
          if (index >= items.length) return _emptySlot();
          final item = items[index];
          final rarityColor = item.itemTemplate.isEquipment
              ? _rarityColor(item.itemTemplate)
              : kBorderColor;
          return GestureDetector(
            onTap: () => _openItemAction(item),
            child: Container(
              decoration: BoxDecoration(
                color: item.itemTemplate.isEquipment
                    ? Color.alphaBlend(
                        rarityColor.withValues(alpha: 0.08),
                        kSlotColor,
                      )
                    : kSlotColor,
                border: Border.all(
                  color: item.isEquipped ? kGold : rarityColor,
                  width: item.itemTemplate.isEquipment ? 2 : 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    bottom: 15,
                    child: Center(
                      child: Image.asset(
                        _inventoryItemImage(item.itemTemplate),
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (item.isEquipped)
                    Positioned(top: 2, left: 2, child: _buildEquippedMarker()),
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 2,
                    child: Text(
                      item.itemTemplate.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kTextLight, fontSize: 9),
                    ),
                  ),
                  if (item.quantity > 1)
                    Positioned(
                      right: 3,
                      top: 2,
                      child: Text(
                        'x${item.quantity}',
                        style: const TextStyle(color: kGold, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEquippedMarker() {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          kGold.withValues(alpha: 0.24),
          Colors.black.withValues(alpha: 0.48),
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: kGold.withValues(alpha: 0.86), width: 1),
      ),
      child: const Icon(Icons.check_rounded, color: kGold, size: 13),
    );
  }

  Color _rarityColor(ItemTemplate template) {
    return switch (template.rarity.trim().toLowerCase()) {
      'common' => kCommonColor,
      'rare' => kRareColor,
      'epic' => kEpicColor,
      _ => kBorderColor,
    };
  }

  Widget _emptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: kSlotColor,
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
    );
  }

  String _inventoryItemImage(ItemTemplate template) {
    if (template.displayImagePath.isNotEmpty) return template.displayImagePath;
    if (template.isBossEntranceTicket || template.isBossTicketFragment) {
      return 'assets/images/icon/ticket.png';
    }
    final normalizedName = template.name.replaceAll(' ', '').trim();
    return switch (normalizedName) {
      '부서진검' => 'assets/images/icon/sword1.png',
      '초급회복물약' => 'assets/images/icon/potion1.png',
      '중급회복물약' => 'assets/images/icon/potion2.png',
      '고급회복물약' => 'assets/images/icon/potion3.png',
      '낡은모자' => 'assets/images/icon/cap1.png',
      '낡은갑옷' => 'assets/images/icon/armor1.png',
      '낡은신발' => 'assets/images/icon/shoes1.png',
      '튼튼한모자' => 'assets/images/icon/cap2.png',
      '튼튼한갑옷' => 'assets/images/icon/armor2.png',
      '튼튼한신발' => 'assets/images/icon/shoes2.png',
      '에픽투구' => 'assets/images/icon/cap3.png',
      '에픽갑옷' => 'assets/images/icon/armor3.png',
      '에픽신발' => 'assets/images/icon/shoes3.png',
      '낡은검' => 'assets/images/icon/sword1.png',
      '초급검' => 'assets/images/icon/sword1.png',
      '일반검' => 'assets/images/icon/sword2.png',
      '레어검' => 'assets/images/icon/sword2.png',
      '에픽검' => 'assets/images/icon/sword3.png',
      '5스테이지보스입장권' => 'assets/images/icon/ticket.png',
      _ => switch (template.equipmentSlot) {
        'helmet' => 'assets/images/icon/helmet.png',
        'armor' => 'assets/images/icon/armor.png',
        'sword' => 'assets/images/icon/weapon.png',
        'shoes' => 'assets/images/icon/boots.png',
        _ =>
          template.isConsumable
              ? 'assets/images/icon/hp.png'
              : 'assets/images/icon/weapon.png',
      },
    };
  }

  Widget _buildInventoryBottomRow() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Text(
            '보유 아이템 ${_filteredItems.length}개',
            style: const TextStyle(color: kTextGray, fontSize: 12),
          ),
          const Spacer(),
          _buildSmallButton('새로고침', _loadInventory),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kPanelColor,
          border: Border.all(color: kBorderColor, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(color: kTextLight, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Column(
      children: [
        _buildCurrencyRow(),
        const SizedBox(height: 8),
        Column(children: _statKeys.map(_buildStatRow).toList()),
        _buildStatDetailCard(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExplorationTab() {
    final summary = _explorationSummary;
    final storage = summary?.upgrades['offline_storage'];
    final efficiency = summary?.upgrades['offline_efficiency'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        children: [
          _buildExplorationHeader(),
          const SizedBox(height: 8),
          if (storage != null)
            _buildExplorationUpgradeCard(
              keyName: 'offline_storage',
              upgrade: storage,
              icon: Icons.inventory_2,
            ),
          if (efficiency != null)
            _buildExplorationUpgradeCard(
              keyName: 'offline_efficiency',
              upgrade: efficiency,
              icon: Icons.travel_explore,
              lowerIsBetter: true,
            ),
          const SizedBox(height: 8),
          _buildExplorationNote(),
        ],
      ),
    );
  }

  Widget _buildExplorationHeader() {
    final serverReady = _explorationSummary?.serverAvailable == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanelColor,
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2D1E),
              border: Border.all(color: kGreen, width: 1.5),
            ),
            child: const Icon(Icons.hiking, color: kGold, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '탐험 가방',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  serverReady
                      ? '앱을 꺼둔 동안 쌓이는 공격기회와 오프라인 걷기 효율을 강화합니다.'
                      : '서버 업데이트 전이라 기본 수치만 표시 중입니다.',
                  style: TextStyle(color: kTextLight, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildCoinMiniBadge(),
        ],
      ),
    );
  }

  Widget _buildCoinMiniBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: kBorderColor, width: 1),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/icon/coin_icon.png',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${_gs.coins}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorationUpgradeCard({
    required String keyName,
    required ExplorationUpgradeInfo upgrade,
    required IconData icon,
    bool lowerIsBetter = false,
  }) {
    final serverReady = _explorationSummary?.serverAvailable == true;
    final canUpgrade =
        serverReady &&
        !_isActionLoading &&
        !upgrade.isMaxed &&
        _gs.coins >= upgrade.costCoin;
    final labels = _explorationLabels(keyName);
    final delta = (upgrade.nextValue - upgrade.currentValue).abs();
    final deltaText = keyName == 'offline_storage'
        ? '+$delta${upgrade.valueUnit}'
        : '-$delta%p';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanelColor,
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kSlotColor,
              border: Border.all(color: kBorderColor, width: 1.5),
            ),
            child: Icon(icon, color: kGold, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '레벨 ${upgrade.level}/${upgrade.maxLevel}',
                      style: const TextStyle(color: kGold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  labels.description,
                  style: const TextStyle(color: kTextLight, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  _explorationCurrentText(keyName, upgrade),
                  style: const TextStyle(color: kTextGray, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  upgrade.isMaxed
                      ? '최대 레벨입니다.'
                      : '다음 강화: $deltaText (${_explorationNextText(keyName, upgrade)})',
                  style: TextStyle(
                    color: lowerIsBetter ? kGreen : const Color(0xFFBFF4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labels.source,
                  style: const TextStyle(color: kTextGray, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildExplorationUpgradeButton(keyName, upgrade, canUpgrade),
        ],
      ),
    );
  }

  Widget _buildExplorationUpgradeButton(
    String keyName,
    ExplorationUpgradeInfo upgrade,
    bool enabled,
  ) {
    final serverReady = _explorationSummary?.serverAvailable == true;
    final textOnlyLabel = upgrade.isMaxed ? 'MAX' : '준비';
    final priceLabel = '${upgrade.costCoin}';
    return GestureDetector(
      onTap: enabled ? () => _upgradeExploration(keyName) : null,
      child: Container(
        width: 58,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? kAccentRed : kSlotColor,
          border: Border.all(color: enabled ? kGold : kBorderColor, width: 1.5),
        ),
        child: Center(
          child: upgrade.isMaxed || !serverReady
              ? Text(
                  textOnlyLabel,
                  style: const TextStyle(
                    color: kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/icon/coin_icon.png',
                      width: 13,
                      height: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      priceLabel,
                      style: TextStyle(
                        color: enabled ? Colors.white : kTextGray,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  _ExplorationLabels _explorationLabels(String keyName) {
    if (keyName == 'offline_storage') {
      return const _ExplorationLabels(
        title: '공격기회 보관함',
        description: '앱을 꺼둔 동안 쌓을 수 있는 공격기회 최대치를 늘립니다.',
        source: '변경 원인: 탐험 가방 > 공격기회 보관함 레벨',
      );
    }
    return const _ExplorationLabels(
      title: '탐험 효율',
      description: '오프라인 걷기에서 추가로 더 걸어야 하는 부담을 줄입니다.',
      source: '변경 원인: 탐험 가방 > 탐험 효율 레벨',
    );
  }

  String _explorationCurrentText(
    String keyName,
    ExplorationUpgradeInfo upgrade,
  ) {
    if (keyName == 'offline_storage') {
      return '현재 효과: 오프라인 공격기회 최대 ${upgrade.currentValue}회 저장';
    }
    return '현재 효과: 오프라인 추가 거리 ${upgrade.currentValue}% 적용';
  }

  String _explorationNextText(String keyName, ExplorationUpgradeInfo upgrade) {
    if (keyName == 'offline_storage') {
      return '최대 ${upgrade.nextValue}회 저장';
    }
    return '추가 거리 ${upgrade.nextValue}% 적용';
  }

  Widget _buildExplorationNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: kBorderColor, width: 1),
      ),
      child: const Text(
        '오프라인 공격기회는 앱을 다시 켰을 때 정산됩니다. 쌓인 공격기회는 전투 화면에서 직접 공격 버튼으로 사용할 수 있습니다.',
        style: TextStyle(color: kTextLight, fontSize: 11, height: 1.35),
      ),
    );
  }

  Widget _buildExpBadge({
    required double width,
    required double height,
    required double fontSize,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF173F54),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF69D8FF), width: 1),
      ),
      child: Text(
        'SP',
        style: TextStyle(
          color: const Color(0xFFBFF4FF),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCurrencyRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildExpBadge(width: 28, height: 22, fontSize: 10),
          const SizedBox(width: 6),
          const Text(
            '보유 SP',
            style: TextStyle(color: kTextLight, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '$_statPointBalance',
            style: const TextStyle(
              color: Color(0xFFBFF4FF),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          _buildSmallButton('동기화', _loadInventory),
        ],
      ),
    );
  }

  Widget _buildStatRow(String key) {
    final summary = _statSummary;
    final cur = summary?.currentStats[key] ?? 0;
    final next = cur + (key == 'hp' ? 10 : 1);
    final cost = summary?.costs[key] ?? 0;
    final canUp = !_isActionLoading && cost > 0 && _statPointBalance >= cost;

    return GestureDetector(
      onTap: () => setState(() => _selectedStatKey = key),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _selectedStatKey == key
              ? kPanelColor.withValues(alpha: 0.9)
              : kPanelColor,
          border: Border.all(
            color: _selectedStatKey == key ? kGold : kBorderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              _statIconPath(key),
              width: 24,
              height: 24,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.auto_awesome, color: kGold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statLabel[key]!,
                    style: const TextStyle(
                      color: kTextLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$cur',
                        style: const TextStyle(color: kTextGray, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '>>',
                        style: TextStyle(color: kTextGray, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$next',
                        style: const TextStyle(
                          color: kGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildExpBadge(width: 24, height: 18, fontSize: 9),
            const SizedBox(width: 4),
            Text(
              '$cost',
              style: TextStyle(
                color: canUp ? const Color(0xFFBFF4FF) : kTextGray,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildStatAdjButton('+', canUp, () => _upgradeStat(key)),
          ],
        ),
      ),
    );
  }

  String _statIconPath(String key) {
    return switch (key) {
      'attack' => 'assets/images/icon/atk.png',
      'defense' => 'assets/images/icon/def.png',
      'agility' => 'assets/images/icon/agi.png',
      _ => 'assets/images/icon/hp.png',
    };
  }

  Widget _buildStatAdjButton(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: kPanelColor,
          border: Border.all(color: kBorderColor, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? kTextLight : kTextGray,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatDetailCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanelColor,
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      child: Text(
        _statDesc[_selectedStatKey]!,
        style: const TextStyle(color: kTextLight, fontSize: 12),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_shop.png',
        label: '상점',
        index: 0,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_character.png',
        label: '캐릭터',
        index: 1,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_home.png',
        label: '홈',
        index: 2,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_battle.png',
        label: '전투',
        index: 3,
      ),
      PixelBottomNavItem(
        icon: 'assets/images/nav/nav_raid.png',
        label: '레이드',
        index: 4,
      ),
    ];

    return PixelBottomNav(
      items: items,
      currentIndex: 1,
      onTap: (item) async => _navigateBottom(item.index),
    );
  }

  void _navigateBottom(int index) {
    Widget? page;
    switch (index) {
      case 0:
        page = const ShopPage();
        break;
      case 2:
        page = const HomePage();
        break;
      case 3:
        page = const BattleStagePage();
        break;
      case 4:
        page = const RaidListPage();
        break;
    }
    if (page == null) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => page!,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _ActiveSetEffectGroup {
  final String setName;
  final int activeCount;
  final Map<int, List<String>> effectsByCount;

  const _ActiveSetEffectGroup({
    required this.setName,
    required this.activeCount,
    required this.effectsByCount,
  });
}

class _EquipmentStatFeedback {
  final int id;
  final String title;
  final int combatPower;
  final int combatPowerDelta;
  final List<_StatDelta> statDeltas;

  const _EquipmentStatFeedback({
    required this.id,
    required this.title,
    required this.combatPower,
    required this.combatPowerDelta,
    required this.statDeltas,
  });
}

class _StatDelta {
  final String label;
  final int value;

  const _StatDelta({required this.label, required this.value});
}

class _EquipmentStatFeedbackCard extends StatelessWidget {
  final _EquipmentStatFeedback feedback;

  const _EquipmentStatFeedbackCard({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final isPowerUp = feedback.combatPowerDelta >= 0;
    final accent = isPowerUp
        ? const Color(0xFF68D46E)
        : const Color(0xFFFF7563);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xF21B1008),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent, width: 1.5),
                ),
                child: Icon(
                  isPowerUp ? Icons.trending_up : Icons.trending_down,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  feedback.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextLight,
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '전투력',
                    style: TextStyle(
                      color: kTextGray,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${feedback.combatPower} (${_signed(feedback.combatPowerDelta)})',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (feedback.statDeltas.isEmpty)
            const Text(
              '스탯 변화 없음',
              style: TextStyle(
                color: kTextGray,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: feedback.statDeltas.map(_buildDeltaChip).toList(),
            ),
        ],
      ),
    );
  }

  static Widget _buildDeltaChip(_StatDelta delta) {
    final isUp = delta.value >= 0;
    final color = isUp ? const Color(0xFF68D46E) : const Color(0xFFFF7563);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 1),
      ),
      child: Text(
        '${delta.label} ${_signed(delta.value)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  static String _signed(int value) => value > 0 ? '+$value' : '$value';
}

class _ExplorationLabels {
  final String title;
  final String description;
  final String source;

  const _ExplorationLabels({
    required this.title,
    required this.description,
    required this.source,
  });
}
