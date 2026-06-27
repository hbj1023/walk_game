package models

type ShopPurchaseRequest struct {
	CharacterID string `json:"characterId"`
	ShopItemID  string `json:"shopItemId"`
	OfferID     string `json:"offerId"`
	Quantity    int    `json:"quantity"`
}

type ShopRecommendationRequest struct {
	CharacterID string `json:"characterId"`
}

type ShopRecord struct {
	ID       string `json:"id"`
	IsActive bool   `json:"is_active"`
}

type ShopItemRecord struct {
	ID                   string                        `json:"id"`
	Shop                 string                        `json:"shop"`
	ItemTemplate         string                        `json:"item_template"`
	PriceCoin            float64                       `json:"price_coin"`
	StockLimit           float64                       `json:"stock_limit"`
	PurchaseLimitPerUser float64                       `json:"purchase_limit_per_user"`
	IsActive             bool                          `json:"is_active"`
	StartedAt            string                        `json:"started_at"`
	EndedAt              string                        `json:"ended_at"`
	Expand               map[string]ItemTemplateRecord `json:"expand"`
}

type PurchaseLogRecord struct {
	ID             string  `json:"id"`
	Character      string  `json:"character"`
	ShopItem       string  `json:"shop_item"`
	Quantity       float64 `json:"quantity"`
	TotalPriceCoin float64 `json:"total_price_coin"`
}

type DailyShopOfferRecord struct {
	ID                string                        `json:"id"`
	Character         string                        `json:"character"`
	Shop              string                        `json:"shop"`
	ItemTemplate      string                        `json:"item_template"`
	OfferDate         string                        `json:"offer_date"`
	SlotIndex         int                           `json:"slot_index"`
	OriginalPriceCoin float64                       `json:"original_price_coin"`
	PriceCoin         float64                       `json:"price_coin"`
	DiscountRate      float64                       `json:"discount_rate"`
	RerollCount       int                           `json:"reroll_count"`
	IsActive          bool                          `json:"is_active"`
	IsPurchased       bool                          `json:"is_purchased"`
	GeneratedAt       string                        `json:"generated_at"`
	PurchasedAt       string                        `json:"purchased_at"`
	Expand            map[string]ItemTemplateRecord `json:"expand"`
}
