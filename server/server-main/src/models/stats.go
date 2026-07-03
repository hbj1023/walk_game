package models

type StatUpgradeRequest struct {
	CharacterID string `json:"characterId"`
	StatType    string `json:"statType"`
}

type StatBalanceSettingRecord struct {
	ID               string  `json:"id"`
	StatType         string  `json:"stat_type"`
	BaseCost         float64 `json:"base_cost"`
	SquareDivisor    float64 `json:"square_divisor"`
	LinearMultiplier float64 `json:"linear_multiplier"`
	FormulaText      string  `json:"formula_text"`
	IsActive         bool    `json:"is_active"`
}

type StatBlock struct {
	HP      int `json:"hp"`
	Attack  int `json:"attack"`
	Defense int `json:"defense"`
	Agility int `json:"agility"`
}

type EquippedStatItem struct {
	EquipmentID  string    `json:"equipment_id"`
	TemplateID   string    `json:"template_id"`
	Name         string    `json:"name"`
	Slot         string    `json:"slot"`
	Rarity       string    `json:"rarity"`
	SetKey       string    `json:"set_key"`
	SetPieceType string    `json:"set_piece_type"`
	Stats        StatBlock `json:"stats"`
}

type EquipmentSetBonusRecord struct {
	ID            string  `json:"id"`
	SetKey        string  `json:"set_key"`
	SetName       string  `json:"set_name"`
	RequiredCount int     `json:"required_count"`
	BonusType     string  `json:"bonus_type"`
	BonusValue    float64 `json:"bonus_value"`
	Description   string  `json:"description"`
	IsActive      bool    `json:"is_active"`
}

type EquippedStatRecord struct {
	ID     string `json:"id"`
	Expand struct {
		OwnedEquipment struct {
			ID            string `json:"id"`
			ItemTemplate  string `json:"item_template"`
			RolledHP      int    `json:"rolled_hp"`
			RolledAttack  int    `json:"rolled_attack"`
			RolledDefense int    `json:"rolled_defense"`
			RolledAgility int    `json:"rolled_agility"`
			Expand        struct {
				ItemTemplate ItemTemplateRecord `json:"item_template"`
			} `json:"expand"`
		} `json:"owned_equipment"`
	} `json:"expand"`
}
