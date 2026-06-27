package features

import "testing"

func TestItemSellRefundCoin(t *testing.T) {
	tests := []struct {
		name     string
		price    float64
		quantity int
		want     int
	}{
		{name: "equipment price half", price: 150, quantity: 1, want: 75},
		{name: "consumable quantity total half floored", price: 75, quantity: 3, want: 112},
		{name: "zero price", price: 0, quantity: 5, want: 0},
		{name: "zero quantity", price: 100, quantity: 0, want: 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := itemSellRefundCoin(tt.price, tt.quantity)
			if got != tt.want {
				t.Fatalf("itemSellRefundCoin(%v, %d) = %d, want %d", tt.price, tt.quantity, got, tt.want)
			}
		})
	}
}

func TestCalculateRecoveredHP(t *testing.T) {
	tests := []struct {
		name          string
		currentHP     int
		recoverAmount int
		maxHP         int
		want          int
	}{
		{name: "recovers within max", currentHP: 30, recoverAmount: 50, maxHP: 100, want: 80},
		{name: "caps at max", currentHP: 80, recoverAmount: 50, maxHP: 100, want: 100},
		{name: "does not go below zero", currentHP: 10, recoverAmount: -50, maxHP: 100, want: 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calculateRecoveredHP(tt.currentHP, tt.recoverAmount, tt.maxHP)
			if got != tt.want {
				t.Fatalf("calculateRecoveredHP(%d, %d, %d) = %d, want %d", tt.currentHP, tt.recoverAmount, tt.maxHP, got, tt.want)
			}
		})
	}
}
