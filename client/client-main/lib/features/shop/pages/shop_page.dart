import 'package:flutter/material.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/battle_api_service.dart';
import 'package:capstone_app/services/game_api_service.dart';
import 'package:capstone_app/services/game_state.dart';
import 'package:capstone_app/features/battle/pages/battle_stage_page.dart';
import 'package:capstone_app/features/home/pages/home_page.dart';
import 'package:capstone_app/features/inventory/pages/inventory_page.dart';
import 'package:capstone_app/features/raid/pages/raid_list_page.dart';
import 'package:capstone_app/widgets/game_feedback.dart';
import 'package:capstone_app/widgets/character_stats_panel.dart';
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
const _kCommonColor = Color(0xFF56B866);
const _kRareColor = Color(0xFF4C8DFF);
const _kEpicColor = Color(0xFFC177FF);

const _equipmentRarityOrder = ['common', 'rare', 'epic'];
const _standardSetRarityRows = ['common', 'rare'];
const _epicSetRarityRows = ['epic'];
const _equipmentSlotOrder = ['weapon', 'helmet', 'armor', 'shoes'];

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
  List<OwnedInventoryItem> _inventoryItems = const [];
  Set<String> _ownedEquipmentTemplateIds = const {};
  bool _chapter2EquipmentUnlocked = false;
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
        BattleApiService.fetchNormalStages(),
      ]);
      final shops = results[0] as List<Shop>;
      final inventoryItems = results[1] as List<OwnedInventoryItem>;
      final stages = results[2] as List<NormalStageInfo>;
      final selected = shops.isEmpty ? null : shops.first;
      final items = selected == null
          ? <ShopItem>[]
          : await GameApiService.fetchShopItems(selected.id);
      final chapter2Unlocked =
          stages.any((stage) => stage.stageNo >= 6 && stage.isUnlocked) ||
          stages.any(
            (stage) =>
                stage.stageNo == 5 &&
                stage.stageType == 'boss' &&
                stage.isCleared,
          );
      final ownedEquipmentTemplateIds = inventoryItems
          .where((item) => item.itemTemplate.isEquipment && !item.isRemoved)
          .map((item) => item.itemTemplate.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _selectedShop = selected;
        _items = items;
        _inventoryItems = inventoryItems;
        _ownedEquipmentTemplateIds = ownedEquipmentTemplateIds;
        _chapter2EquipmentUnlocked = chapter2Unlocked;
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
                  item.isActive &&
                  (_chapter2EquipmentUnlocked ||
                      !_isChapter2Equipment(item.itemTemplate)) &&
                  !_ownedEquipmentTemplateIds.contains(item.itemTemplate.id),
            )
            .toList(),
      1 => _items.where((item) => item.itemTemplate.isConsumable).toList(),
      _ => _items,
    };
  }

  Future<void> _purchase(ShopItem item) async {
    if (_selectedShop == null || _isBuying) return;
    if (!item.isPurchaseUnlocked) {
      showGameToast(
        context,
        item.lockedReason.isEmpty ? '아직 구매 조건이 열리지 않았습니다.' : item.lockedReason,
        type: GameToastType.warning,
      );
      return;
    }
    final quantity = item.itemTemplate.isConsumable
        ? await _showConsumablePurchaseDialog(item)
        : await _confirmEquipmentPurchase(item);
    if (!mounted) return;
    if (quantity == null || quantity <= 0) return;

    final totalPrice = item.priceCoin * quantity;
    if (_gs.coins < totalPrice) {
      showGameToast(
        context,
        '코인이 부족합니다. 전투 보상으로 코인을 모아주세요.',
        type: GameToastType.warning,
      );
      return;
    }

    setState(() => _isBuying = true);
    try {
      await GameApiService.purchaseShopItem(
        shopId: _selectedShop!.id,
        shopItemId: item.id,
        quantity: quantity,
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
        _inventoryItems = inventoryItems;
        _ownedEquipmentTemplateIds = inventoryItems
            .where(
              (ownedItem) =>
                  ownedItem.itemTemplate.isEquipment && !ownedItem.isRemoved,
            )
            .map((ownedItem) => ownedItem.itemTemplate.id)
            .where((id) => id.isNotEmpty)
            .toSet();
      });
      showGameToast(
        context,
        item.itemTemplate.isConsumable
            ? '${item.itemTemplate.name} $quantity개 구매 완료. 남은 코인: ${_gs.coins}'
            : '${item.itemTemplate.name} 구매 완료. 남은 코인: ${_gs.coins}',
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

  Future<int?> _confirmEquipmentPurchase(ShopItem item) async {
    final setEffect = item.itemTemplate.setEffectSummary;
    final confirmed = await showGameConfirmDialog(
      context: context,
      title: item.itemTemplate.name,
      message: [
        item.itemTemplate.statSummary,
        if (setEffect.isNotEmpty) setEffect,
        '가격 ${item.priceCoin} 코인',
        '구매 후 인벤토리에서 장착할 수 있습니다.',
      ].join('\n'),
      confirmLabel: '구매',
      type: GameToastType.warning,
    );
    return confirmed ? 1 : null;
  }

  Future<int?> _showConsumablePurchaseDialog(ShopItem item) async {
    final maxByCoin = item.priceCoin <= 0 ? 99 : _gs.coins ~/ item.priceCoin;
    final maxQuantity = maxByCoin.clamp(1, 99).toInt();
    final ownedQuantity = _ownedConsumableQuantity(item.itemTemplate.id);
    int quantity = 1;

    return showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalPrice = item.priceCoin * quantity;
            final canBuy = item.priceCoin <= 0 || _gs.coins >= totalPrice;

            void setQuantity(int next) {
              setDialogState(() {
                quantity = next.clamp(1, maxQuantity);
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xF21B1008),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.75),
                      offset: const Offset(0, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _kSlotColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _kBorderColor,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(7),
                          child: Image.asset(
                            _shopItemImage(item),
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemTemplate.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kGold,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '보유 $ownedQuantity개',
                                style: const TextStyle(
                                  color: _kTextGray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text(
                                '수량',
                                style: TextStyle(
                                  color: _kTextLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              _buildQuantityButton(
                                '-',
                                quantity > 1,
                                () => setQuantity(quantity - 1),
                              ),
                              Container(
                                width: 58,
                                height: 34,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _kPanelColor,
                                  border: Border.all(
                                    color: _kBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              _buildQuantityButton(
                                '+',
                                quantity < maxQuantity,
                                () => setQuantity(quantity + 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildQuickQuantityButton(
                                '+5',
                                quantity < maxQuantity,
                                () => setQuantity(quantity + 5),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickQuantityButton(
                                '최대',
                                quantity < maxQuantity,
                                () => setQuantity(maxQuantity),
                              ),
                              const Spacer(),
                              Image.asset(
                                'assets/images/icon/coin_icon.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$totalPrice',
                                style: TextStyle(
                                  color: canBuy ? _kGold : Colors.redAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogButton(
                            label: '취소',
                            color: const Color(0xFF352419),
                            borderColor: _kBorderColor,
                            onTap: () => Navigator.pop(dialogContext),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogButton(
                            label: '구매',
                            color: canBuy ? _kAccentRed : Colors.grey.shade800,
                            borderColor: const Color(0xFFB56838),
                            onTap: canBuy
                                ? () => Navigator.pop(dialogContext, quantity)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _ownedConsumableQuantity(String itemTemplateId) {
    for (final item in _inventoryItems) {
      if (item.itemTemplate.id == itemTemplateId &&
          item.itemTemplate.isConsumable) {
        return item.quantity;
      }
    }
    return 0;
  }

  Widget _buildQuantityButton(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? _kPanelColor : Colors.grey.shade900,
          border: Border.all(
            color: enabled ? _kBorderColor : Colors.white12,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? _kTextLight : _kTextGray,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickQuantityButton(
    String label,
    bool enabled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF352419) : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? _kBorderColor : Colors.white12,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? _kGold : _kTextGray,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade800 : color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null ? _kTextGray : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
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
    if (_selectedTab == 0) {
      return _buildEquipmentSetShelf(items);
    }

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

  Widget _buildEquipmentSetShelf(List<ShopItem> items) {
    final sections = _buildEquipmentSetSections(items);
    if (sections.isEmpty) {
      return const Center(
        child: Text('판매 중인 장비가 없습니다.', style: TextStyle(color: _kTextGray)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
      itemCount: sections.length,
      itemBuilder: (context, index) =>
          _buildEquipmentSetSection(sections[index]),
    );
  }

  List<_EquipmentSetSection> _buildEquipmentSetSections(List<ShopItem> items) {
    final sections = <String, _EquipmentSetSection>{};

    void putCell({
      required ItemTemplate template,
      ShopItem? shopItem,
      required bool owned,
      bool equipped = false,
    }) {
      if (!template.isEquipment) return;
      final slot = _equipmentPieceType(template);
      if (!_equipmentSlotOrder.contains(slot)) return;
      final rarity = _equipmentRarity(template);
      if (!_equipmentRarityOrder.contains(rarity)) return;

      final setKey = _equipmentSetKey(template);
      final section = sections.putIfAbsent(
        setKey,
        () => _EquipmentSetSection(
          key: setKey,
          name: _equipmentSetName(template),
          chapter: _equipmentChapter(template),
          order: _equipmentSetOrder(template),
          isEpicSet: _equipmentRarity(template) == 'epic',
        ),
      );
      final row = section.rows.putIfAbsent(
        rarity,
        () => _EquipmentRarityRow(rarity: rarity),
      );
      final current = row.cells[slot];
      if (current == null || equipped || owned || !current.owned) {
        row.cells[slot] = _EquipmentShopCell(
          template: template,
          shopItem: shopItem,
          owned: owned,
          equipped: equipped,
        );
      }
    }

    for (final item in _inventoryItems) {
      if (!item.itemTemplate.isEquipment || item.isRemoved) continue;
      putCell(
        template: item.itemTemplate,
        owned: true,
        equipped: item.isEquipped,
      );
    }
    for (final item in items) {
      if (_ownedEquipmentTemplateIds.contains(item.itemTemplate.id)) continue;
      putCell(template: item.itemTemplate, shopItem: item, owned: false);
    }

    final list = sections.values.toList()
      ..sort((a, b) {
        final chapter = a.chapter.compareTo(b.chapter);
        if (chapter != 0) return chapter;
        final order = a.order.compareTo(b.order);
        if (order != 0) return order;
        return a.name.compareTo(b.name);
      });
    return list;
  }

  Widget _buildEquipmentSetSection(_EquipmentSetSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: section.isEpicSet ? _kEpicColor : _kBorderColor,
          width: section.isEpicSet ? 1.8 : 1.5,
        ),
        image: section.chapter >= 2
            ? const DecorationImage(
                image: AssetImage(
                  'assets/images/bg/stage2_shadow_mushroom_forest_map.png',
                ),
                fit: BoxFit.cover,
                opacity: 0.10,
              )
            : const DecorationImage(
                image: AssetImage(
                  'assets/images/bg/stage1_forest_path_ui_strip.png',
                ),
                fit: BoxFit.cover,
                opacity: 0.10,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorderColor),
                ),
                child: Icon(
                  section.isEpicSet
                      ? Icons.workspace_premium_rounded
                      : section.chapter >= 2
                      ? Icons.forest_rounded
                      : Icons.hiking_rounded,
                  color: section.isEpicSet
                      ? _kEpicColor
                      : section.chapter >= 2
                      ? _kCommonColor
                      : _kGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildChapterBadge(section.chapter, isEpicSet: section.isEpicSet),
            ],
          ),
          const SizedBox(height: 10),
          for (final rarity
              in section.isEpicSet
                  ? _epicSetRarityRows
                  : _standardSetRarityRows)
            _buildEquipmentRarityRow(
              section.rows[rarity] ?? _EquipmentRarityRow(rarity: rarity),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterBadge(int chapter, {required bool isEpicSet}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorderColor),
      ),
      child: Text(
        isEpicSet
            ? '보스 세트'
            : chapter >= 2
            ? '버섯숲'
            : '숲길',
        style: TextStyle(
          color: isEpicSet ? _kEpicColor : _kTextGray,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEquipmentRarityRow(_EquipmentRarityRow row) {
    final color = _rarityColor(row.rarity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          Colors.black.withValues(alpha: 0.34),
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.58), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final slot in _equipmentSlotOrder) ...[
            Expanded(child: _buildEquipmentSetTile(row.cells[slot], slot)),
            if (slot != _equipmentSlotOrder.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildEquipmentSetTile(_EquipmentShopCell? cell, String slot) {
    final template = cell?.template;
    final shopItem = cell?.shopItem;
    final owned = cell?.owned ?? false;
    final equipped = cell?.equipped ?? false;
    final canBuy =
        shopItem != null &&
        shopItem.isPurchaseUnlocked &&
        !_isBuying &&
        _gs.coins >= shopItem.priceCoin;
    final rarity = template == null ? 'locked' : _equipmentRarity(template);
    final borderColor = template == null
        ? Colors.white24
        : equipped
        ? _kGold
        : _rarityColor(rarity).withValues(alpha: owned ? 0.45 : 0.9);
    final backgroundColor = template == null
        ? Colors.black.withValues(alpha: 0.30)
        : Color.alphaBlend(
            _rarityColor(rarity).withValues(alpha: 0.06),
            _kSlotColor,
          );

    return GestureDetector(
      onTap: template == null || _isBuying
          ? null
          : () => _openEquipmentInfo(cell!, slot),
      child: Opacity(
        opacity: template == null ? 0.46 : 1,
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.1),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 32,
                child: Center(
                  child: template == null
                      ? Icon(_slotIcon(slot), color: Colors.white24, size: 28)
                      : Image.asset(
                          _templateImage(template),
                          width: 46,
                          height: 46,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              Positioned(
                left: 2,
                right: 2,
                bottom: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    template?.name ?? _slotLabel(slot),
                    maxLines: 1,
                    style: const TextStyle(
                      color: _kTextGray,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: _buildEquipmentTileState(
                    template: template,
                    shopItem: shopItem,
                    owned: owned,
                    equipped: equipped,
                    canBuy: canBuy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEquipmentInfo(_EquipmentShopCell cell, String slot) async {
    final template = cell.template;
    final shopItem = cell.shopItem;
    final owned = cell.owned;
    final unlocked = shopItem?.isPurchaseUnlocked ?? false;
    final canBuy =
        shopItem != null &&
        unlocked &&
        !_isBuying &&
        _gs.coins >= shopItem.priceCoin;
    final statusText = owned
        ? '이미 보유 중인 장비입니다.'
        : shopItem == null
        ? '아직 구매 조건이 열리지 않았습니다.'
        : !unlocked
        ? (shopItem.lockedReason.isEmpty
              ? '아직 구매 조건이 열리지 않았습니다.'
              : shopItem.lockedReason)
        : canBuy
        ? '구매할 수 있습니다.'
        : '코인이 부족합니다.';
    final statusColor = owned
        ? _kGold
        : canBuy
        ? _kCommonColor
        : _kTextGray;

    final shouldBuy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _kPanelColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _rarityColor(_equipmentRarity(template))),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            template.name,
            style: const TextStyle(
              color: _kTextLight,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kSlotColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Image.asset(
                      _templateImage(template),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _slotLabel(slot),
                          style: const TextStyle(
                            color: _kTextGray,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          template.statSummary,
                          style: const TextStyle(
                            color: _kTextLight,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        if (template.setEffectLines.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildSetEffectInfo(template),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (shopItem != null)
                Row(
                  children: [
                    Image.asset(
                      'assets/images/icon/coin_icon.png',
                      width: 15,
                      height: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${shopItem.priceCoin} 코인',
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('닫기', style: TextStyle(color: _kTextGray)),
            ),
            if (shopItem != null)
              TextButton(
                onPressed: canBuy
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: Text(
                  '구매',
                  style: TextStyle(
                    color: canBuy ? _kGold : Colors.white30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (shouldBuy == true && shopItem != null) {
      await _purchase(shopItem);
    }
  }

  Widget _buildSetEffectInfo(ItemTemplate template) {
    final lines = template.setEffectLines;
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _kGold.withValues(alpha: 0.42), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.setNameLabel,
            style: const TextStyle(
              color: _kGold,
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
                style: const TextStyle(color: _kTextLight, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTileState({
    required ItemTemplate? template,
    required ShopItem? shopItem,
    required bool owned,
    required bool equipped,
    required bool canBuy,
  }) {
    if (template == null) {
      return _buildTinyStateChip('잠김', Colors.white24);
    }
    if (equipped) {
      return _buildTinyStateChip('보유', _kGold);
    }
    if (owned) {
      return _buildTinyStateChip('보유', _kGold);
    }
    if (shopItem == null) {
      return _buildTinyStateChip('조건', Colors.white24);
    }
    if (!shopItem.isPurchaseUnlocked) {
      return _buildTinyStateChip('조건', _kTextGray);
    }
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: canBuy ? _kAccentRed : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/icon/coin_icon.png',
            width: 10,
            height: 10,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${shopItem.priceCoin}',
                style: TextStyle(
                  color: canBuy ? Colors.white : _kTextGray,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyStateChip(String label, Color color) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildShopItemCard(ShopItem item) {
    final canBuy =
        !_isBuying && item.isPurchaseUnlocked && _gs.coins >= item.priceCoin;
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
                if (item.itemTemplate.setEffectCompactSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.itemTemplate.setEffectCompactSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kGold, fontSize: 10),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  item.isPurchaseUnlocked
                      ? _itemMeta(item)
                      : (item.lockedReason.isEmpty
                            ? _itemMeta(item)
                            : item.lockedReason),
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
    return _templateImage(item.itemTemplate);
  }

  String _templateImage(ItemTemplate template) {
    if (template.displayImagePath.isNotEmpty) return template.displayImagePath;
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

  String _equipmentRarity(ItemTemplate template) {
    final rarity = template.rarity.trim().toLowerCase();
    return _equipmentRarityOrder.contains(rarity) ? rarity : 'common';
  }

  Color _rarityColor(String rarity) {
    return switch (rarity) {
      'common' => _kCommonColor,
      'rare' => _kRareColor,
      'epic' => _kEpicColor,
      _ => Colors.white24,
    };
  }

  String _equipmentPieceType(ItemTemplate template) {
    if (template.setPieceType.trim().isNotEmpty) {
      final piece = template.setPieceType.trim();
      return piece == 'sword' ? 'weapon' : piece;
    }
    if (template.equipmentSlot == 'sword') return 'weapon';
    if (_equipmentSlotOrder.contains(template.equipmentSlot)) {
      return template.equipmentSlot;
    }
    final name = template.name.toLowerCase();
    if (name.contains('검') ||
        name.contains('도끼') ||
        name.contains('창') ||
        name.contains('단검') ||
        name.contains('sword') ||
        name.contains('axe') ||
        name.contains('spear') ||
        name.contains('dagger')) {
      return 'weapon';
    }
    if (name.contains('투구') || name.contains('두건') || name.contains('helm')) {
      return 'helmet';
    }
    if (name.contains('갑옷') || name.contains('armor')) return 'armor';
    if (name.contains('신발') || name.contains('장화') || name.contains('boots')) {
      return 'shoes';
    }
    return '';
  }

  String _slotLabel(String slot) {
    return switch (slot) {
      'weapon' => '무기',
      'helmet' => '투구',
      'armor' => '갑옷',
      'shoes' => '신발',
      _ => '',
    };
  }

  IconData _slotIcon(String slot) {
    return switch (slot) {
      'weapon' => Icons.gavel_rounded,
      'helmet' => Icons.health_and_safety_rounded,
      'armor' => Icons.shield_rounded,
      'shoes' => Icons.directions_walk_rounded,
      _ => Icons.lock_rounded,
    };
  }

  int _equipmentChapter(ItemTemplate template) {
    return _isChapter2Equipment(template) ? 2 : 1;
  }

  int _equipmentSetOrder(ItemTemplate template) {
    final key = _equipmentBaseSetKey(template);
    final offset = _equipmentRarity(template) == 'epic' ? 100 : 0;
    return switch (key) {
      'chapter1-adventurer' => 0 + offset,
      'vanguard' => 10 + offset,
      'berserker' => 20 + offset,
      'sentinel' => 30 + offset,
      'shadow' => 40 + offset,
      'colossus' => 50 + offset,
      _ => 90 + offset,
    };
  }

  String _equipmentSetKey(ItemTemplate template) {
    final baseKey = _equipmentBaseSetKey(template);
    if (_equipmentRarity(template) == 'epic') {
      return 'epic-$baseKey';
    }
    return baseKey;
  }

  String _equipmentBaseSetKey(ItemTemplate template) {
    if (template.setKey.trim().isNotEmpty) return template.setKey.trim();
    final name = template.name.toLowerCase();
    if (name.contains('모험가') || name.contains('vanguard')) return 'vanguard';
    if (name.contains('광전사') || name.contains('berserker')) {
      return 'berserker';
    }
    if (name.contains('창술사') || name.contains('sentinel')) return 'sentinel';
    if (name.contains('도적') || name.contains('shadow')) return 'shadow';
    if (name.contains('견습기사') || name.contains('colossus')) {
      return 'colossus';
    }
    return 'chapter1-adventurer';
  }

  String _equipmentSetName(ItemTemplate template) {
    final key = _equipmentBaseSetKey(template);
    if (_equipmentRarity(template) == 'epic') {
      return switch (key) {
        'vanguard' => '모험가 보스 에픽 세트',
        'berserker' => '광전사 보스 에픽 세트',
        'sentinel' => '창술사 보스 에픽 세트',
        'shadow' => '도적 보스 에픽 세트',
        'colossus' => '견습기사 보스 에픽 세트',
        _ => '숲길 보스 에픽 세트',
      };
    }
    return switch (key) {
      'vanguard' => '모험가 세트',
      'berserker' => '광전사 세트',
      'sentinel' => '창술사 세트',
      'shadow' => '도적 세트',
      'colossus' => '견습기사 세트',
      _ => '숲길 준비 세트',
    };
  }

  bool _isChapter2Equipment(ItemTemplate template) {
    if (!template.isEquipment) return false;
    if (template.setKey.trim().isNotEmpty) return true;

    final imagePath = '${template.imagePath} ${template.displayImagePath}'
        .toLowerCase();
    if (imagePath.contains('/chapter2/') ||
        imagePath.contains('\\chapter2\\')) {
      return true;
    }

    final name = template.name.toLowerCase();
    return name.contains('모험가') ||
        name.contains('광전사') ||
        name.contains('창술사') ||
        name.contains('도적') ||
        name.contains('견습기사') ||
        name.contains('vanguard') ||
        name.contains('berserker') ||
        name.contains('sentinel') ||
        name.contains('shadow') ||
        name.contains('colossus');
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

class _EquipmentSetSection {
  final String key;
  final String name;
  final int chapter;
  final int order;
  final bool isEpicSet;
  final Map<String, _EquipmentRarityRow> rows = {};

  _EquipmentSetSection({
    required this.key,
    required this.name,
    required this.chapter,
    required this.order,
    required this.isEpicSet,
  });
}

class _EquipmentRarityRow {
  final String rarity;
  final Map<String, _EquipmentShopCell> cells = {};

  _EquipmentRarityRow({required this.rarity});
}

class _EquipmentShopCell {
  final ItemTemplate template;
  final ShopItem? shopItem;
  final bool owned;
  final bool equipped;

  const _EquipmentShopCell({
    required this.template,
    required this.shopItem,
    required this.owned,
    required this.equipped,
  });
}
