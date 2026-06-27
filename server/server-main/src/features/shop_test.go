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
