package features

import "testing"

func TestBossRewardRarityForRoll(t *testing.T) {
	tests := []struct {
		roll int
		want string
	}{
		{roll: 0, want: ""},
		{roll: 39, want: ""},
		{roll: 40, want: "epic"},
		{roll: 99, want: "epic"},
	}

	for _, tt := range tests {
		if got := bossRewardRarityForRoll(tt.roll); got != tt.want {
			t.Fatalf("bossRewardRarityForRoll(%d) = %q, want %q", tt.roll, got, tt.want)
		}
	}
}

func TestIsBossRewardTemplateForStage(t *testing.T) {
	tests := []struct {
		name     string
		stageNo  int
		template itemTemplateRecord
		want     bool
	}{
		{
			name:    "chapter 1 boss accepts tutorial epic equipment",
			stageNo: 5,
			template: itemTemplateRecord{
				Name:          "에픽 검",
				ItemType:      "equipment",
				EquipmentSlot: "sword",
				Rarity:        "epic",
			},
			want: true,
		},
		{
			name:    "chapter 1 boss rejects chapter 2 set equipment",
			stageNo: 5,
			template: itemTemplateRecord{
				Name:          "에픽 모험가 검",
				ItemType:      "equipment",
				EquipmentSlot: "sword",
				SetKey:        "vanguard",
				Rarity:        "epic",
			},
			want: false,
		},
		{
			name:    "chapter 2 boss rejects retired chapter 2 epic equipment",
			stageNo: 10,
			template: itemTemplateRecord{
				Name:          "에픽 모험가 검",
				ItemType:      "equipment",
				EquipmentSlot: "sword",
				SetKey:        "vanguard",
				Rarity:        "epic",
			},
			want: false,
		},
		{
			name:    "chapter 2 boss accepts poison assassin epic equipment",
			stageNo: 10,
			template: itemTemplateRecord{
				Name:          "맹독 암살자 단검",
				ItemType:      "equipment",
				EquipmentSlot: "sword",
				SetKey:        "poison_assassin",
				Rarity:        "epic",
			},
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isBossRewardTemplateForStage(tt.template, tt.stageNo); got != tt.want {
				t.Fatalf("isBossRewardTemplateForStage(%+v, %d) = %v, want %v", tt.template, tt.stageNo, got, tt.want)
			}
		})
	}
}

func TestBossClearRequiresTicket(t *testing.T) {
	if bossClearRequiresTicket(stageProgressRecord{}, false) {
		t.Fatal("missing progress should not require a boss ticket")
	}

	if bossClearRequiresTicket(stageProgressRecord{ClearCount: 0}, true) {
		t.Fatal("first boss clear should not require a boss ticket")
	}

	if !bossClearRequiresTicket(stageProgressRecord{ClearCount: 1}, true) {
		t.Fatal("repeat boss clear should require a boss ticket")
	}
}
