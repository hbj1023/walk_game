import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/features/shop/pages/shop_page.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
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
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<OwnedInventoryItem>;
        _statSummary = results[1] as StatUpgradeSummary;
        _explorationSummary = results[2] as ExplorationUpgradeSummary;
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

  int get _statPointBalance => _statSummary?.statExp ?? _gs.statExp;

  Widget _buildSelectedTab() {
    return switch (_selectedTab) {
      0 => _buildInventoryTab(),
      1 => _buildStatsTab(),
      _ => _buildExplorationTab(),
    };
  }

  List<OwnedInventoryItem> get _filteredItems {
    return switch (_inventoryFilter) {
      1 => _items.where((item) => item.itemTemplate.isEquipment).toList(),
      2 => _items.where((item) => item.itemTemplate.isConsumable).toList(),
      3 =>
        _items
            .where(
              (item) =>
                  !item.itemTemplate.isEquipment &&
                  !item.itemTemplate.isConsumable,
            )
            .toList(),
      _ => _items,
    };
  }

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
          item.itemTemplate.name,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('취소', style: TextStyle(color: kTextGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'sell'),
            child: const Text('판매', style: TextStyle(color: Color(0xFFE06030))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'action'),
            child: Text(action, style: const TextStyle(color: kGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openItemAction(OwnedInventoryItem item) async {
    final result = await _showItemDialog(item);
    if (result == null) return;

    if (result == 'sell') {
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
      } else if (item.isEquipped) {
        await GameApiService.unequipItem(item.id);
      } else {
        await GameApiService.equipItem(item.id);
      }
      await _loadInventory();
      if (mounted) _showMessage('${item.itemTemplate.name} $action 완료');
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
        _showMessage(
          earned > 0
              ? '${item.itemTemplate.name} 판매 완료! +$earned 코인'
              : '${item.itemTemplate.name} 판매 완료',
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
      setState(() => _statSummary = summary);
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
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const Spacer(),
          _buildCoinCard(),
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

  Widget _buildEquipSlot(String slot) {
    final item = _equippedInSlot(slot);
    final isSelected = _selectedSlot == slot;
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
              color: kSlotColor,
              border: Border.all(
                color: isSelected ? kGold : kBorderColor,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: item == null
                ? Icon(_slotIcon(slot), color: kTextGray, size: 28)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        _inventoryItemImage(item.itemTemplate),
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.itemTemplate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextLight, fontSize: 9),
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
          return GestureDetector(
            onTap: () => _openItemAction(item),
            child: Container(
              decoration: BoxDecoration(
                color: kSlotColor,
                border: Border.all(
                  color: item.isEquipped ? kGold : kBorderColor,
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Image.asset(
                      _inventoryItemImage(item.itemTemplate),
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 2,
                    child: Text(
                      item.itemTemplate.name,
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

  Widget _emptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: kSlotColor,
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
    );
  }

  String _inventoryItemImage(ItemTemplate template) {
    final normalizedName = template.name.replaceAll(' ', '').trim();
    return switch (normalizedName) {
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
      '초급검' => 'assets/images/icon/sword1.png',
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
              valueLabel: '최대 저장',
            ),
          if (efficiency != null)
            _buildExplorationUpgradeCard(
              keyName: 'offline_efficiency',
              upgrade: efficiency,
              icon: Icons.travel_explore,
              valueLabel: '추가 거리',
              lowerIsBetter: true,
            ),
          const SizedBox(height: 8),
          _buildExplorationNote(),
        ],
      ),
    );
  }

  Widget _buildExplorationHeader() {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '탐험 가방',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '앱을 꺼둔 동안 쌓이는 공격기회와 오프라인 걷기 효율을 강화합니다.',
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
    required String valueLabel,
    bool lowerIsBetter = false,
  }) {
    final canUpgrade =
        !_isActionLoading && !upgrade.isMaxed && _gs.coins >= upgrade.costCoin;
    final valueText = '${upgrade.currentValue}${upgrade.valueUnit}';
    final nextText = '${upgrade.nextValue}${upgrade.valueUnit}';
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
                        upgrade.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Lv.${upgrade.level}/${upgrade.maxLevel}',
                      style: const TextStyle(color: kGold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  upgrade.description,
                  style: const TextStyle(color: kTextLight, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$valueLabel $valueText',
                      style: const TextStyle(color: kTextGray, fontSize: 11),
                    ),
                    if (!upgrade.isMaxed) ...[
                      const SizedBox(width: 5),
                      const Text(
                        '>',
                        style: TextStyle(color: kTextGray, fontSize: 11),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        nextText,
                        style: TextStyle(
                          color: lowerIsBetter
                              ? kGreen
                              : const Color(0xFFBFF4FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
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
    final label = upgrade.isMaxed ? 'MAX' : '${upgrade.costCoin}';
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
          child: upgrade.isMaxed
              ? const Text(
                  'MAX',
                  style: TextStyle(
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
                      label,
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
