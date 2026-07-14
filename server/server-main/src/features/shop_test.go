package features

import (
	"testing"
	"time"
)

func TestIsShopItemWindowActiveKeepsItemWhenDateIsBlank(t *testing.T) {
	now := time.Date(2026, 5, 27, 12, 0, 0, 0, time.UTC)

	if !isShopItemWindowActive("", "", now) {
		t.Fatal("blank shop item window should be active")
	}
}

func TestIsShopItemWindowActiveAcceptsPocketBaseDateWithoutZone(t *testing.T) {
	now := time.Date(2026, 5, 27, 12, 0, 0, 0, time.UTC)

	if !isShopItemWindowActive("2026-05-27 00:00:00.000", "2026-05-28 00:00:00.000", now) {
		t.Fatal("PocketBase date without timezone should be active inside window")
	}
}

func TestIsShopItemWindowActiveDoesNotHideOnInvalidDate(t *testing.T) {
	now := time.Date(2026, 5, 27, 12, 0, 0, 0, time.UTC)

	if !isShopItemWindowActive("invalid-date", "", now) {
		t.Fatal("invalid started_at should not hide otherwise active shop item")
	}
}

func TestEquipmentShopProgressShowsCommonAndRareBeforePurchase(t *testing.T) {
	progress := buildEquipmentShopProgress(nil)
	common := testEquipmentTemplate("common", "helmet", "", "")
	rare := testEquipmentTemplate("rare", "helmet", "", "")

	if !isEquipmentTemplateVisibleInShop(common, progress, false, nil) {
		t.Fatal("common equipment should be visible before purchase")
	}
	if !isEquipmentTemplateVisibleInShop(rare, progress, false, nil) {
		t.Fatal("rare equipment should be visible without requiring common purchase")
	}
}

func TestEquipmentShopProgressKeepsOwnedCommonAndRareVisible(t *testing.T) {
	common := testEquipmentTemplate("common", "helmet", "", "")
	rare := testEquipmentTemplate("rare", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(common, "owned"),
	})

	if !isEquipmentTemplateVisibleInShop(common, progress, false, nil) {
		t.Fatal("owned common equipment should remain visible")
	}
	if !isEquipmentTemplateVisibleInShop(rare, progress, false, nil) {
		t.Fatal("rare equipment should remain visible after owning common")
	}
}

func TestEquipmentShopProgressKeepsLowerAndSoldTiersVisible(t *testing.T) {
	common := testEquipmentTemplate("common", "helmet", "", "")
	rare := testEquipmentTemplate("rare", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(common, "owned"),
		testOwnedEquipment(rare, "sold"),
	})

	if !isEquipmentTemplateVisibleInShop(common, progress, false, nil) {
		t.Fatal("lower active tier should remain visible after reaching rare")
	}
	if !isEquipmentTemplateVisibleInShop(rare, progress, false, nil) {
		t.Fatal("sold highest tier should be visible for repurchase")
	}
}

func TestEquipmentShopProgressShowsRareEvenWhenCommonWasSold(t *testing.T) {
	common := testEquipmentTemplate("common", "helmet", "", "")
	rare := testEquipmentTemplate("rare", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(common, "sold"),
	})

	if !isEquipmentTemplateVisibleInShop(common, progress, false, nil) {
		t.Fatal("sold highest common tier should be visible for repurchase")
	}
	if !isEquipmentTemplateVisibleInShop(rare, progress, false, nil) {
		t.Fatal("rare should stay visible even when common was sold")
	}
}

func TestEquipmentShopProgressKeepsDifferentSetsIndependent(t *testing.T) {
	shadowRare := testEquipmentTemplate("rare", "helmet", "shadow", "helmet")
	vanguardRare := testEquipmentTemplate("rare", "helmet", "vanguard", "helmet")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(shadowRare, "owned"),
	})

	if !isEquipmentTemplateVisibleInShop(shadowRare, progress, true, nil) {
		t.Fatal("owned rare item in the same set should remain visible")
	}
	if !isEquipmentTemplateVisibleInShop(vanguardRare, progress, true, nil) {
		t.Fatal("owning one rare set should not block a different rare set")
	}
}

func TestEquipmentShopProgressKeepsDifferentFallbackArmorSetsIndependent(t *testing.T) {
	shadowRare := testEquipmentTemplate("rare", "helmet", "", "helmet")
	shadowRare.WeaponType = ""
	shadowRare.ImagePath = "assets/images/equipment/chapter2/ch2_armor_rare_shadow_helmet.png"
	vanguardRare := testEquipmentTemplate("rare", "helmet", "", "helmet")
	vanguardRare.WeaponType = ""
	vanguardRare.ID = "rare-helmet-vanguard"
	vanguardRare.ImagePath = "assets/images/equipment/chapter2/ch2_armor_rare_vanguard_helmet.png"
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(shadowRare, "owned"),
	})

	if !isEquipmentTemplateVisibleInShop(shadowRare, progress, true, nil) {
		t.Fatal("owned fallback armor set item should remain visible")
	}
	if !isEquipmentTemplateVisibleInShop(vanguardRare, progress, true, nil) {
		t.Fatal("fallback armor set key should keep different armor sets purchasable")
	}
}

func TestEquipmentShopProgressHidesChapter2UntilUnlocked(t *testing.T) {
	template := testEquipmentTemplate("common", "sword", "vanguard", "weapon")

	if isEquipmentTemplateVisibleInShop(template, buildEquipmentShopProgress(nil), false, nil) {
		t.Fatal("chapter 2 equipment should stay hidden until chapter 2 is unlocked")
	}
	if !isEquipmentTemplateVisibleInShop(template, buildEquipmentShopProgress(nil), true, nil) {
		t.Fatal("chapter 2 common equipment should show after chapter 2 is unlocked")
	}
}

func TestEquipmentShopChapterRecognizesQuarrySet(t *testing.T) {
	template := testEquipmentTemplate("rare", "sword", "quarry_swordsman", "weapon")

	if got := equipmentShopChapter(template); got != 3 {
		t.Fatalf("equipmentShopChapter() = %d, want 3", got)
	}
}

func TestEquipmentShopChapterKeepsChapter1PathInChapter1(t *testing.T) {
	template := testEquipmentTemplate("rare", "sword", "chapter1-adventurer", "weapon")
	template.ImagePath = "assets/images/equipment/chapter1/tutorial_weapon_rare_sword.png"

	if got := equipmentShopChapter(template); got != 1 {
		t.Fatalf("equipmentShopChapter() = %d, want 1", got)
	}
}

func TestEquipmentShopChapterRecognizesPoisonAssassinWithoutSetKey(t *testing.T) {
	template := testEquipmentTemplate("epic", "helmet", "", "helmet")
	template.Name = "맹독 암살자 복면"

	if got := equipmentShopChapter(template); got != 2 {
		t.Fatalf("equipmentShopChapter() = %d, want 2", got)
	}
}

func TestChapter1EpicOnlyAllowsCanonicalBossEquipment(t *testing.T) {
	canonical := testEquipmentTemplate("epic", "helmet", "", "helmet")
	canonical.Name = "에픽 투구"
	if !isSupportedChapterEpicTemplate(canonical) {
		t.Fatal("canonical chapter 1 epic helmet should be supported")
	}

	retired := testEquipmentTemplate("epic", "helmet", "", "helmet")
	retired.Name = "에픽 견습기사 투구"
	if isSupportedChapterEpicTemplate(retired) {
		t.Fatal("retired chapter 1 epic helmet should be hidden")
	}
}

func TestEquipmentShopProgressHidesEpicBeforeBossClear(t *testing.T) {
	epic := testEquipmentTemplate("epic", "helmet", "", "")

	if isEquipmentTemplateVisibleInShop(epic, buildEquipmentShopProgress(nil), false, nil) {
		t.Fatal("boss epic equipment should stay hidden before the boss is cleared")
	}
}

func TestEquipmentShopProgressHidesRetiredChapter2Epic(t *testing.T) {
	epic := testEquipmentTemplate("epic", "sword", "vanguard", "weapon")
	bossShopUnlocks := map[int]bool{2: true}

	if isEquipmentTemplateVisibleInShop(epic, buildEquipmentShopProgress(nil), true, bossShopUnlocks) {
		t.Fatal("retired chapter 2 epic equipment should stay hidden after boss clear")
	}
}

func TestEquipmentShopProgressShowsPoisonAssassinEpic(t *testing.T) {
	epic := testEquipmentTemplate("epic", "sword", "poison_assassin", "weapon")
	bossShopUnlocks := map[int]bool{2: true}

	if !isEquipmentTemplateVisibleInShop(epic, buildEquipmentShopProgress(nil), true, bossShopUnlocks) {
		t.Fatal("poison assassin epic equipment should show after chapter 2 boss clear")
	}
}

func TestEquipmentShopProgressShowsEpicAfterBossClear(t *testing.T) {
	epic := testEquipmentTemplate("epic", "helmet", "", "")
	bossShopUnlocks := map[int]bool{1: true}

	if !isEquipmentTemplateVisibleInShop(epic, buildEquipmentShopProgress(nil), false, bossShopUnlocks) {
		t.Fatal("boss epic equipment should show after its chapter boss is cleared")
	}
}

func TestEquipmentShopAvailabilityUnlocksEpicAfterBossClear(t *testing.T) {
	epic := testEquipmentTemplate("epic", "helmet", "", "")
	bossShopUnlocks := map[int]bool{1: true}

	availability := equipmentShopAvailabilityForTemplate(epic, buildEquipmentShopProgress(nil), false, bossShopUnlocks)
	if !availability.include {
		t.Fatal("boss epic equipment should be included after its chapter boss is cleared")
	}
	if !availability.purchaseUnlocked {
		t.Fatal("boss epic equipment should be purchasable after its chapter boss is cleared")
	}
}

func TestEquipmentShopProgressKeepsOwnedEpicVisibleAfterBossClear(t *testing.T) {
	epic := testEquipmentTemplate("epic", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(epic, "owned"),
	})
	bossShopUnlocks := map[int]bool{1: true}

	if !isEquipmentTemplateVisibleInShop(epic, progress, false, bossShopUnlocks) {
		t.Fatal("owned epic equipment should remain visible")
	}
}

func TestEquipmentShopAvailabilityLocksOwnedEquipmentPurchase(t *testing.T) {
	common := testEquipmentTemplate("common", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(common, "owned"),
	})

	availability := equipmentShopAvailabilityForTemplate(common, progress, false, nil)
	if !availability.include {
		t.Fatal("owned equipment should remain included in the shop")
	}
	if availability.purchaseUnlocked {
		t.Fatal("owned equipment should not be purchasable again")
	}
}

func TestEquipmentTemplateShopPriceUsesTemplatePriceBeforeFallback(t *testing.T) {
	template := testEquipmentTemplate("rare", "sword", "", "")
	template.PriceCoin = 720

	if got := equipmentTemplateShopPrice(template, 220); got != 720 {
		t.Fatalf("equipmentTemplateShopPrice() = %v, want 720", got)
	}
}

func TestEquipmentTemplateShopPriceFallsBackWhenTemplatePriceIsEmpty(t *testing.T) {
	template := testEquipmentTemplate("rare", "sword", "", "")

	if got := equipmentTemplateShopPrice(template, 220); got != 220 {
		t.Fatalf("equipmentTemplateShopPrice() = %v, want 220", got)
	}
}

func TestEquipmentShopWeaponTemplateAcceptsSetWeapon(t *testing.T) {
	template := testEquipmentTemplate("rare", "helmet", "vanguard", "weapon")
	template.WeaponType = "sword"

	if !isEquipmentShopWeaponTemplate(template) {
		t.Fatal("set weapon should be treated as a weapon shop template")
	}
}

func TestEquipmentShopWeaponTemplateAcceptsWeaponType(t *testing.T) {
	template := testEquipmentTemplate("rare", "", "berserker", "")
	template.WeaponType = "axe"

	if !isEquipmentShopWeaponTemplate(template) {
		t.Fatal("weapon_type should be enough to recover weapon shop templates")
	}
}

func TestEquipmentShopWeaponTemplateRejectsArmor(t *testing.T) {
	template := testEquipmentTemplate("rare", "armor", "vanguard", "armor")
	template.WeaponType = ""

	if isEquipmentShopWeaponTemplate(template) {
		t.Fatal("armor template should not be treated as a weapon")
	}
}

func testEquipmentTemplate(rarity string, slot string, setKey string, pieceType string) itemTemplateRecord {
	id := rarity + "-" + slot
	if setKey != "" {
		id += "-" + setKey
	}
	return itemTemplateRecord{
		ID:            id,
		Name:          id,
		ItemType:      "equipment",
		EquipmentSlot: slot,
		WeaponType:    "sword",
		SetKey:        setKey,
		SetPieceType:  pieceType,
		Rarity:        rarity,
		IsActive:      true,
	}
}

func testOwnedEquipment(template itemTemplateRecord, status string) ownedEquipmentRecord {
	return ownedEquipmentRecord{
		ID:           "owned-" + template.ID,
		ItemTemplate: template.ID,
		Status:       status,
		Expand: map[string]itemTemplateRecord{
			"item_template": template,
		},
	}
}
