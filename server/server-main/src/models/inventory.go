package models

type EquipmentActionRequest struct {
	OwnedEquipmentID string `json:"ownedEquipmentId"`
}

type ConsumableUseRequest struct {
	ItemTemplateID string `json:"itemTemplateId"`
	UseQuantity    int    `json:"useQuantity"`
}

type ItemTemplateRecord struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	ItemType      string  `json:"item_type"`
	EquipmentSlot string  `json:"equipment_slot"`
	Rarity        string  `json:"rarity"`
	IsActive      bool    `json:"is_active"`
	BaseHP        float64 `json:"base_hp"`
	BaseAttack    float64 `json:"base_attack"`
	BaseDefense   float64 `json:"base_defense"`
	BaseAgility   float64 `json:"base_agility"`
	RecoverHP     float64 `json:"recover_hp"`
	PriceCoin     float64 `json:"price_coin"`
}

type OwnedEquipmentRecord struct {
	ID           string                        `json:"id"`
	Character    string                        `json:"character"`
	ItemTemplate string                        `json:"item_template"`
	Status       string                        `json:"status"`
	Expand       map[string]ItemTemplateRecord `json:"expand"`
}

type CharacterEquipmentRecord struct {
	ID             string `json:"id"`
	Character      string `json:"character"`
	OwnedEquipment string `json:"owned_equipment"`
}

type CharacterConsumableRecord struct {
	ID           string  `json:"id"`
	Character    string  `json:"character"`
	ItemTemplate string  `json:"item_template"`
	Quantity     float64 `json:"quantity"`
}
