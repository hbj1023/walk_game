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

func TestEquipmentShopProgressHidesOwnedCommonButKeepsRareVisible(t *testing.T) {
	common := testEquipmentTemplate("common", "helmet", "", "")
	rare := testEquipmentTemplate("rare", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(common, "owned"),
	})

	if isEquipmentTemplateVisibleInShop(common, progress, false, nil) {
		t.Fatal("owned common equipment should not remain visible")
	}
	if !isEquipmentTemplateVisibleInShop(rare, progress, false, nil) {
		t.Fatal("rare equipment should remain visible after owning common")
	}
}

func TestEquipmentShopProgressReopensHighestSoldTierOnly(t *testing.T) {
	common := testEquipmentTemplate("common", "helmet", "", "")
	rare := testEquipmentTemplate("rare", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(common, "owned"),
		testOwnedEquipment(rare, "sold"),
	})

	if isEquipmentTemplateVisibleInShop(common, progress, false, nil) {
		t.Fatal("lower active tier should stay hidden after reaching rare")
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

	if isEquipmentTemplateVisibleInShop(shadowRare, progress, true, nil) {
		t.Fatal("owned rare item in the same set should stay hidden")
	}
	if !isEquipmentTemplateVisibleInShop(vanguardRare, progress, true, nil) {
		t.Fatal("owning one rare set should not block a different rare set")
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

func TestEquipmentShopProgressHidesEpicBeforeBossClear(t *testing.T) {
	epic := testEquipmentTemplate("epic", "helmet", "", "")

	if isEquipmentTemplateVisibleInShop(epic, buildEquipmentShopProgress(nil), false, nil) {
		t.Fatal("boss epic equipment should stay hidden before the boss is cleared")
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

func TestEquipmentShopProgressHidesOwnedEpicAfterBossClear(t *testing.T) {
	epic := testEquipmentTemplate("epic", "helmet", "", "")
	progress := buildEquipmentShopProgress([]ownedEquipmentRecord{
		testOwnedEquipment(epic, "owned"),
	})
	bossShopUnlocks := map[int]bool{1: true}

	if isEquipmentTemplateVisibleInShop(epic, progress, false, bossShopUnlocks) {
		t.Fatal("owned epic equipment should not remain visible")
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
