import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
import 'package:capstone_app/widgets/player_level_badge.dart';
import 'package:capstone_app/widgets/pixel_bottom_nav.dart';

const _kBgColor = Color(0xFF1A1008);
const _kPanelColor = Color(0xFF2A1A0E);
const _kBorderColor = Color(0xFF5C3A1E);
const _kAccentRed = Color(0xFF8B1A1A);
const _kGold = Color(0xFFFFD700);
const _kTextLight = Color(0xFFEEDDCC);
const _kTextGray = Color(0xFF888888);
const _kSlotColor = Color(0xFF1E1208);

// ─── 탭 정의 ──────────────────────────────────────────────────────────────────
const _tabs = ['장비', '소모품'];

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _selectedTab = 0;
  String _userName = '...';
  bool _isLoading = true;
  bool _isBuying = false;
  String? _error;
  List<Shop> _shops = const [];
  List<ShopItem> _items = const [];
  Set<String> _ownedEquipmentTemplateIds = const {};
  Shop? _selectedShop;
  final _gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    _gs.addListener(_onGameStateChanged);
    _loadUserName();
    _loadShop();
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

  Future<void> _loadShop() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.fetchMainMessage();
      final results = await Future.wait<Object>([
        GameApiService.fetchShops(),
        GameApiService.fetchInventoryItems(),
      ]);
      final shops = results[0] as List<Shop>;
      final inventoryItems = results[1] as List<OwnedInventoryItem>;
      final selected = shops.isEmpty ? null : shops.first;
      final items = selected == null
          ? <ShopItem>[]
          : await GameApiService.fetchShopItems(selected.id);
      final ownedEquipmentTemplateIds = inventoryItems
          .where((item) => item.itemTemplate.isEquipment)
          .map((item) => item.itemTemplate.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _selectedShop = selected;
        _items = items;
        _ownedEquipmentTemplateIds = ownedEquipmentTemplateIds;
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

  List<ShopItem> get _filteredItems {
    return switch (_selectedTab) {
      0 =>
        _items
            .where(
              (item) =>
                  item.itemTemplate.isEquipment &&
                  !_ownedEquipmentTemplateIds.contains(item.itemTemplate.id),
            )
            .toList(),
      1 => _items.where((item) => item.itemTemplate.isConsumable).toList(),
      _ => _items,
    };
  }

  Future<void> _purchase(ShopItem item) async {
    if (_selectedShop == null || _isBuying) return;
    if (_gs.coins < item.priceCoin) {
      showGameToast(
        context,
        '코인이 부족합니다. 전투 보상으로 코인을 모아주세요.',
        type: GameToastType.warning,
      );
      return;
    }

    final confirmed = await showGameConfirmDialog(
      context: context,
      title: item.itemTemplate.name,
      message:
          '${item.itemTemplate.statSummary}\n가격 ${item.priceCoin} 코인\n구매 후 인벤토리에서 장착할 수 있습니다.',
      confirmLabel: '구매',
      type: GameToastType.warning,
    );
    if (!confirmed) return;

    setState(() => _isBuying = true);
    try {
      await GameApiService.purchaseShopItem(
        shopId: _selectedShop!.id,
        shopItemId: item.id,
      );
      final results = await Future.wait<Object>([
        GameApiService.fetchShopItems(_selectedShop!.id),
        GameApiService.fetchInventoryItems(),
      ]);
      final items = results[0] as List<ShopItem>;
      final inventoryItems = results[1] as List<OwnedInventoryItem>;
      if (!mounted) return;
      setState(() {
        _items = items;
        _ownedEquipmentTemplateIds = inventoryItems
            .where((ownedItem) => ownedItem.itemTemplate.isEquipment)
            .map((ownedItem) => ownedItem.itemTemplate.id)
            .where((id) => id.isNotEmpty)
            .toSet();
      });
      showGameToast(
        context,
        '${item.itemTemplate.name} 구매 완료. 남은 코인: ${_gs.coins}',
        type: GameToastType.success,
      );
    } catch (e) {
      if (mounted) {
        showGameToast(context, e.toString(), type: GameToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _kBgColor,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildShopTitle(),
                _buildTabBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          if (_isBuying)
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: _kGold),
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopTitle() {
    return Column(
      children: [
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_awesome, color: _kGold, size: 16),
            SizedBox(width: 6),
            Text(
              '상점',
              style: TextStyle(
                color: _kGold,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.auto_awesome, color: _kGold, size: 16),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _selectedShop == null
              ? '서버 상점 정보를 불러오는 중입니다.'
              : '${_selectedShop!.name}에서 아이템을 구매하세요.',
          style: const TextStyle(color: _kTextGray, fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kPanelColor,
        border: Border.all(color: _kBorderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = i == _selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _kAccentRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? _kTextLight : _kTextGray,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: _kTextLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadShop,
                child: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      );
    }
    if (_shops.isEmpty) {
      return const Center(
        child: Text('활성화된 상점이 없습니다.', style: TextStyle(color: _kTextGray)),
      );
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return const Center(
        child: Text('해당 탭에 판매 상품이 없습니다.', style: TextStyle(color: _kTextGray)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildShopItemCard(items[index]),
    );
  }

  Widget _buildShopItemCard(ShopItem item) {
    final canBuy = !_isBuying && _gs.coins >= item.priceCoin;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kSlotColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(_shopItemImage(item), fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemTemplate.name,
                  style: const TextStyle(
                    color: _kTextLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.itemTemplate.statSummary,
                  style: const TextStyle(color: _kTextGray, fontSize: 11),
                ),
                const SizedBox(height: 5),
                Text(
                  _itemMeta(item),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canBuy ? () => _purchase(item) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: canBuy ? _kAccentRed : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorderColor),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/icon/coin_icon.png',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.priceCoin}',
                    style: TextStyle(
                      color: canBuy ? Colors.white : _kTextGray,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shopItemImage(ShopItem item) {
    final template = item.itemTemplate;
    if (template.imagePath.isNotEmpty) return template.imagePath;
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

  String _itemMeta(ShopItem item) {
    final template = item.itemTemplate;
    if (template.isEquipment) {
      return '${template.slotLabel} / ${template.rarity}';
    }
    if (template.isConsumable) return '소모품';
    return '기타';
  }

  Widget _buildBottomNav() {
    const items = [
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
      currentIndex: 0,
      onTap: (item) async => _navigateBottom(item.index),
    );
  }

  void _navigateBottom(int index) {
    Widget? page;
    switch (index) {
      case 1:
        page = const InventoryPage();
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
