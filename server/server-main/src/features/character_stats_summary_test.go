package features

import "testing"

func TestAddStatBlocks(t *testing.T) {
	got := addStatBlocks(
		statBlock{HP: 100, Attack: 10, Defense: 5, Agility: 3},
		statBlock{HP: 20, Attack: 2, Defense: 1, Agility: 4},
		statBlock{HP: 30, Attack: 7, Defense: 0, Agility: 1},
	)
	want := statBlock{HP: 150, Attack: 19, Defense: 6, Agility: 8}
	if got != want {
		t.Fatalf("addStatBlocks() = %+v, want %+v", got, want)
	}
}
