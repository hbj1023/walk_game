package features

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	shopsCollection           = "shops"
	shopItemsCollection       = "shop_items"
	purchaseLogsCollection    = "purchase_logs"
	dailyShopOffersCollection = "daily_shop_offers"

	dailyShopOfferCount     = 4
	dailyShopDiscountRate   = 0.10
	dailyShopRerollCostCoin = 50
)

var equipmentRarityOrder = []string{"common", "rare", "epic", "legendary", "mythic"}

func shopsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if r.URL.Path != "/api/shops" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	_, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	shops, err := listActiveShops(r.Context(), token)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "shops fetched", shops)
}

func shopItemsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	shopID, resource, ok := parseShopPath(r.URL.Path)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	user, token, err := refreshAuth(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	if r.Method == http.MethodPost {
		switch resource {
		case "purchase":
			handleShopPurchase(w, r, token, user.ID, shopID)
		case "recommendations/reroll":
			handleShopRecommendationReroll(w, r, token, user.ID, shopID)
		default:
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		}
		return
	}

	if resource == "recommendations" {
		handleShopRecommendations(w, r, token, user.ID, shopID)
		return
	}

	if resource != "items" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}

	if err := ensureActiveShop(r.Context(), token, shopID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	items, err := listAvailableShopItems(r.Context(), token, shopID, time.Now().UTC())
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]string{"error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "shop items fetched", items)
}

func parseShopPath(path string) (string, string, bool) {
	const prefix = "/api/shops/"
	if !strings.HasPrefix(path, prefix) {
		return "", "", false
	}

	parts := strings.Split(strings.Trim(strings.TrimPrefix(path, prefix), "/"), "/")
	if len(parts) < 2 || parts[0] == "" {
		return "", "", false
	}
	for _, part := range parts[1:] {
		if part == "" {
			return "", "", false
		}
	}
	return parts[0], strings.Join(parts[1:], "/"), true
}

func listActiveShops(ctx context.Context, token string) (pocketBaseListResponse[map[string]any], error) {
	return listCollectionRecords(ctx, token, shopsCollection, "is_active=true", "", "shop_type,name")
}

func ensureActiveShop(ctx context.Context, token string, shopID string) error {
	_, err := getActiveShop(ctx, token, shopID)
	return err
}

func getActiveShop(ctx context.Context, token string, shopID string) (shopRecord, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseRecordURL(shopsCollection, shopID), token, nil)
	if err != nil {
		return shopRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return shopRecord{}, statusError{status: http.StatusNotFound, message: "shop not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return shopRecord{}, mapPocketBaseError(resp, "failed to get shop")
	}

	var shop shopRecord
	if err := json.NewDecoder(resp.Body).Decode(&shop); err != nil {
		return shopRecord{}, fmt.Errorf("failed to parse shop response")
	}
	if !shop.IsActive {
		return shopRecord{}, statusError{status: http.StatusNotFound, message: "shop not found"}
	}
	return shop, nil
}

func listAvailableShopItems(ctx context.Context, token string, shopID string, now time.Time) (pocketBaseListResponse[map[string]any], error) {
	query := url.Values{}
	query.Set("filter", fmt.Sprintf("shop=%q && is_active=true", shopID))
	query.Set("expand", "item_template")
	query.Set("sort", "created")
	query.Set("perPage", "100")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(shopItemsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return pocketBaseListResponse[map[string]any]{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return pocketBaseListResponse[map[string]any]{}, mapPocketBaseError(resp, "failed to list shop items")
	}

	var list pocketBaseListResponse[map[string]any]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return pocketBaseListResponse[map[string]any]{}, fmt.Errorf("failed to parse shop items response")
	}
	list.Items = filterShopItemsByAvailability(list.Items, now)
	list.TotalItems = len(list.Items)
	if list.PerPage > 0 && list.TotalItems > 0 {
		list.TotalPages = int(math.Ceil(float64(list.TotalItems) / float64(list.PerPage)))
	} else {
		list.TotalPages = 0
	}
	return list, nil
}

func filterShopItemsByAvailability(items []map[string]any, now time.Time) []map[string]any {
	available := make([]map[string]any, 0, len(items))
	for _, item := range items {
		if !isShopItemWindowActive(mapString(item["started_at"]), mapString(item["ended_at"]), now) {
			continue
		}
		available = append(available, item)
	}
	return available
}

func mapString(value any) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

func isShopItemWindowActive(startedAt string, endedAt string, now time.Time) bool {
	if startedAt != "" {
		start, err := parsePocketBaseDate(startedAt)
		if err == nil && now.Before(start) {
			return false
		}
	}
	if endedAt != "" {
		end, err := parsePocketBaseDate(endedAt)
		if err == nil && now.After(end) {
			return false
		}
	}
	return true
}

func handleShopPurchase(w http.ResponseWriter, r *http.Request, token string, userID string, shopID string) {
	var req shopPurchaseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "invalid request body"})
		return
	}

	req.CharacterID = strings.TrimSpace(req.CharacterID)
	req.ShopItemID = strings.TrimSpace(req.ShopItemID)
	req.OfferID = strings.TrimSpace(req.OfferID)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "characterId is required"})
		return
	}
	if req.ShopItemID == "" && req.OfferID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "shopItemId or offerId is required"})
		return
	}
	if req.ShopItemID != "" && req.OfferID != "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "only one of shopItemId or offerId is allowed"})
		return
	}
	if req.Quantity <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "invalid request", "error": "quantity must be greater than 0"})
		return
	}

	if err := ensureCharacterOwner(r.Context(), token, userID, req.CharacterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]any{"message": "shop purchase failed", "error": err.Error()})
		return
	}

	var data map[string]any
	var err error
	if req.OfferID != "" {
		data, err = purchaseDailyShopOffer(r.Context(), token, shopID, req.CharacterID, req.OfferID, req.Quantity)
	} else {
		data, err = purchaseShopItem(r.Context(), token, shopID, req.CharacterID, req.ShopItemID, req.Quantity)
	}
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "shop purchase failed", "error": err.Error()})
		return
	}

	writeInventoryResponse(w, http.StatusOK, "shop item purchased", data)
}

func handleShopRecommendations(w http.ResponseWriter, r *http.Request, token string, userID string, shopID string) {
	characterID := strings.TrimSpace(r.URL.Query().Get("characterId"))
	if characterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "shop recommendations fetch failed", "error": "characterId is required"})
		return
	}
	if err := ensureCharacterOwner(r.Context(), token, userID, characterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]any{"message": "shop recommendations fetch failed", "error": err.Error()})
		return
	}

	data, err := getOrCreateDailyShopOffers(r.Context(), token, shopID, characterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "shop recommendations fetch failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "shop recommendations fetched", data)
}

func handleShopRecommendationReroll(w http.ResponseWriter, r *http.Request, token string, userID string, shopID string) {
	var req shopRecommendationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "shop recommendations reroll failed", "error": "invalid request body"})
		return
	}
	req.CharacterID = strings.TrimSpace(req.CharacterID)
	if req.CharacterID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "shop recommendations reroll failed", "error": "characterId is required"})
		return
	}
	if err := ensureCharacterOwner(r.Context(), token, userID, req.CharacterID); err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusForbidden), map[string]any{"message": "shop recommendations reroll failed", "error": err.Error()})
		return
	}

	data, err := rerollDailyShopOffers(r.Context(), token, shopID, req.CharacterID)
	if err != nil {
		writeJSON(w, statusCodeForError(err, http.StatusBadRequest), map[string]any{"message": "shop recommendations reroll failed", "error": err.Error()})
		return
	}
	writeInventoryResponse(w, http.StatusOK, "shop recommendations rerolled", data)
}

func purchaseShopItem(ctx context.Context, token string, shopID string, characterID string, shopItemID string, quantity int) (map[string]any, error) {
	if _, err := getActiveShop(ctx, token, shopID); err != nil {
		return nil, err
	}

	shopItem, err := getShopItem(ctx, token, shopItemID)
	if err != nil {
		return nil, err
	}
	if shopItem.Shop != shopID {
		return nil, statusError{status: http.StatusBadRequest, message: "shop item does not belong to shop"}
	}
	if !isShopItemAvailable(shopItem, time.Now().UTC()) {
		return nil, statusError{status: http.StatusBadRequest, message: "shop item is not available"}
	}

	itemTemplate, ok := shopItem.Expand["item_template"]
	if !ok || itemTemplate.ID == "" {
		return nil, statusError{status: http.StatusBadRequest, message: "shop item template not found"}
	}
	if !itemTemplate.IsActive {
		return nil, statusError{status: http.StatusBadRequest, message: "item template is not active"}
	}
	if itemTemplate.ItemType != "consumable" && itemTemplate.ItemType != "equipment" {
		return nil, statusError{status: http.StatusBadRequest, message: "unsupported item type"}
	}

	totalPrice, err := totalCoinPrice(shopItem.PriceCoin, quantity)
	if err != nil {
		return nil, err
	}

	if shopItem.StockLimit > 0 {
		if itemTemplate.ItemType == "equipment" {
			ownedCount, err := countActiveOwnedEquipmentByTemplate(ctx, token, characterID, itemTemplate.ID)
			if err != nil {
				return nil, err
			}
			if float64(ownedCount+quantity) > shopItem.StockLimit {
				return nil, statusError{status: http.StatusBadRequest, message: "stock limit exceeded"}
			}
		} else {
			totalPurchased, err := sumPurchaseLogQuantity(ctx, token, fmt.Sprintf("shop_item=%q", shopItemID))
			if err != nil {
				return nil, err
			}
			if totalPurchased+float64(quantity) > shopItem.StockLimit {
				return nil, statusError{status: http.StatusBadRequest, message: "stock limit exceeded"}
			}
		}
	}

	if shopItem.PurchaseLimitPerUser > 0 {
		if itemTemplate.ItemType == "equipment" {
			ownedCount, err := countActiveOwnedEquipmentByTemplate(ctx, token, characterID, itemTemplate.ID)
			if err != nil {
				return nil, err
			}
			if float64(ownedCount+quantity) > shopItem.PurchaseLimitPerUser {
				return nil, statusError{status: http.StatusBadRequest, message: "purchase limit per user exceeded"}
			}
		} else {
			userPurchased, err := sumPurchaseLogQuantity(ctx, token, fmt.Sprintf("shop_item=%q && character=%q", shopItemID, characterID))
			if err != nil {
				return nil, err
			}
			if userPurchased+float64(quantity) > shopItem.PurchaseLimitPerUser {
				return nil, statusError{status: http.StatusBadRequest, message: "purchase limit per user exceeded"}
			}
		}
	}

	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.CoinBalance < totalPrice {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough coin balance"}
	}

	var reward any
	if itemTemplate.ItemType == "consumable" {
		reward, err = addCharacterConsumableQuantity(ctx, token, characterID, itemTemplate.ID, quantity)
	} else {
		reward, err = createOwnedEquipmentsFromPurchase(ctx, token, characterID, itemTemplate, quantity)
	}
	if err != nil {
		return nil, err
	}

	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"coin_balance": character.CoinBalance - totalPrice,
	})
	if err != nil {
		return nil, err
	}

	purchaseLog, err := createPurchaseLog(ctx, token, characterID, shopItemID, quantity, totalPrice)
	if err != nil {
		return nil, err
	}

	var unlockedShopItem any
	if itemTemplate.ItemType == "equipment" {
		unlockedShopItem, err = unlockNextEquipmentShopItem(ctx, token, shopID, itemTemplate)
		if err != nil {
			return nil, err
		}
	}

	return map[string]any{
		"character":          updatedCharacter,
		"shop_item":          shopItem,
		"purchase_log":       purchaseLog,
		"reward":             reward,
		"unlocked_shop_item": unlockedShopItem,
		"total_price_coin":   totalPrice,
	}, nil
}

func getOrCreateDailyShopOffers(ctx context.Context, token string, shopID string, characterID string) (map[string]any, error) {
	if _, err := getActiveShop(ctx, token, shopID); err != nil {
		return nil, err
	}

	offerDate := currentShopOfferDate()
	offers, err := listDailyShopOffers(ctx, token, shopID, characterID, offerDate)
	if err != nil {
		return nil, err
	}
	if len(offers) == 0 {
		offers, err = generateDailyShopOffers(ctx, token, shopID, characterID, offerDate, 0)
		if err != nil {
			return nil, err
		}
	}

	return dailyShopOfferResponse(offers, offerDate, maxDailyShopRerollCount(offers)), nil
}

func rerollDailyShopOffers(ctx context.Context, token string, shopID string, characterID string) (map[string]any, error) {
	if _, err := getActiveShop(ctx, token, shopID); err != nil {
		return nil, err
	}

	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.CoinBalance < dailyShopRerollCostCoin {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough coin balance"}
	}

	offerDate := currentShopOfferDate()
	currentOffers, err := listDailyShopOffers(ctx, token, shopID, characterID, offerDate)
	if err != nil {
		return nil, err
	}
	rerollCount := 0
	for _, offer := range currentOffers {
		if offer.RerollCount > rerollCount {
			rerollCount = offer.RerollCount
		}
		if err := patchDailyShopOffer(ctx, token, offer.ID, map[string]any{"is_active": false}); err != nil {
			return nil, err
		}
	}
	rerollCount++

	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"coin_balance": character.CoinBalance - dailyShopRerollCostCoin,
	})
	if err != nil {
		return nil, err
	}
	if err := createShopResourceTransaction(ctx, token, characterID, "daily_shop_reroll", "", -dailyShopRerollCostCoin, updatedCharacter.CoinBalance, "daily shop recommendations reroll"); err != nil {
		return nil, err
	}

	offers, err := generateDailyShopOffers(ctx, token, shopID, characterID, offerDate, rerollCount)
	if err != nil {
		return nil, err
	}

	response := dailyShopOfferResponse(offers, offerDate, rerollCount)
	response["character"] = updatedCharacter
	response["reroll_cost_coin"] = dailyShopRerollCostCoin
	return response, nil
}

func purchaseDailyShopOffer(ctx context.Context, token string, shopID string, characterID string, offerID string, quantity int) (map[string]any, error) {
	if quantity != 1 {
		return nil, statusError{status: http.StatusBadRequest, message: "daily shop offer quantity must be 1"}
	}
	if _, err := getActiveShop(ctx, token, shopID); err != nil {
		return nil, err
	}

	offer, err := getDailyShopOffer(ctx, token, offerID)
	if err != nil {
		return nil, err
	}
	if offer.Shop != shopID {
		return nil, statusError{status: http.StatusBadRequest, message: "offer does not belong to shop"}
	}
	if offer.Character != characterID {
		return nil, statusError{status: http.StatusForbidden, message: "offer does not belong to character"}
	}
	if !offer.IsActive {
		return nil, statusError{status: http.StatusBadRequest, message: "offer is not active"}
	}
	if offer.IsPurchased {
		return nil, statusError{status: http.StatusBadRequest, message: "offer is already purchased"}
	}
	if offer.OfferDate != currentShopOfferDate() {
		return nil, statusError{status: http.StatusBadRequest, message: "offer is expired"}
	}

	itemTemplate, ok := offer.Expand["item_template"]
	if !ok || itemTemplate.ID == "" {
		return nil, statusError{status: http.StatusBadRequest, message: "offer item template not found"}
	}
	if !itemTemplate.IsActive {
		return nil, statusError{status: http.StatusBadRequest, message: "item template is not active"}
	}

	totalPrice, err := totalCoinPrice(offer.PriceCoin, quantity)
	if err != nil {
		return nil, err
	}

	character, err := getBattleCharacterByID(ctx, token, characterID)
	if err != nil {
		return nil, err
	}
	if character.CoinBalance < totalPrice {
		return nil, statusError{status: http.StatusBadRequest, message: "not enough coin balance"}
	}

	var reward any
	if itemTemplate.ItemType == "consumable" {
		reward, err = addCharacterConsumableQuantity(ctx, token, characterID, itemTemplate.ID, quantity)
	} else if itemTemplate.ItemType == "equipment" {
		reward, err = createOwnedEquipmentsFromPurchase(ctx, token, characterID, itemTemplate, quantity)
	} else {
		return nil, statusError{status: http.StatusBadRequest, message: "unsupported item type"}
	}
	if err != nil {
		return nil, err
	}

	updatedCharacter, err := patchBattleCharacter(ctx, token, characterID, map[string]any{
		"coin_balance": character.CoinBalance - totalPrice,
	})
	if err != nil {
		return nil, err
	}

	updatedOffer, err := updateDailyShopOffer(ctx, token, offer.ID, map[string]any{
		"is_purchased": true,
		"purchased_at": time.Now().UTC().Format(time.RFC3339),
	})
	if err != nil {
		return nil, err
	}

	if err := createShopResourceTransaction(ctx, token, characterID, "daily_shop_offer", offer.ID, -totalPrice, updatedCharacter.CoinBalance, "daily shop recommendation purchase"); err != nil {
		return nil, err
	}

	return map[string]any{
		"character":        updatedCharacter,
		"offer":            updatedOffer,
		"reward":           reward,
		"total_price_coin": totalPrice,
	}, nil
}

func getShopItem(ctx context.Context, token string, shopItemID string) (shopItemRecord, error) {
	endpoint := pocketBaseRecordURL(shopItemsCollection, shopItemID) + "?expand=item_template"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return shopItemRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return shopItemRecord{}, statusError{status: http.StatusNotFound, message: "shop item not found"}
	}
	if resp.StatusCode != http.StatusOK {
		return shopItemRecord{}, mapPocketBaseError(resp, "failed to get shop item")
	}

	var record shopItemRecord
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return shopItemRecord{}, errors.New("failed to parse shop item response")
	}
	return record, nil
}

func currentShopOfferDate() string {
	location, err := time.LoadLocation("Asia/Seoul")
	if err != nil {
		location = time.FixedZone("KST", 9*60*60)
	}
	return time.Now().In(location).Format("2006-01-02")
}

func dailyShopOfferResponse(offers []dailyShopOfferRecord, offerDate string, rerollCount int) map[string]any {
	return map[string]any{
		"offer_date":        offerDate,
		"offers":            offers,
		"discount_rate":     dailyShopDiscountRate,
		"reroll_count":      rerollCount,
		"reroll_cost_coin":  dailyShopRerollCostCoin,
		"next_reset_at_kst": nextShopResetAtKST(),
	}
}

func maxDailyShopRerollCount(offers []dailyShopOfferRecord) int {
	rerollCount := 0
	for _, offer := range offers {
		if offer.RerollCount > rerollCount {
			rerollCount = offer.RerollCount
		}
	}
	return rerollCount
}

func nextShopResetAtKST() string {
	location, err := time.LoadLocation("Asia/Seoul")
	if err != nil {
		location = time.FixedZone("KST", 9*60*60)
	}
	now := time.Now().In(location)
	return time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, location).Format(time.RFC3339)
}

func listDailyShopOffers(ctx context.Context, token string, shopID string, characterID string, offerDate string) ([]dailyShopOfferRecord, error) {
	query := url.Values{}
	query.Set("filter", fmt.Sprintf("shop=%q && character=%q && offer_date=%q && is_active=true", shopID, characterID, offerDate))
	query.Set("expand", "item_template")
	query.Set("sort", "slot_index")
	query.Set("perPage", "20")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(dailyShopOffersCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list daily shop offers")
	}

	var list pocketBaseListResponse[dailyShopOfferRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse daily shop offers response")
	}
	return list.Items, nil
}

func generateDailyShopOffers(ctx context.Context, token string, shopID string, characterID string, offerDate string, rerollCount int) ([]dailyShopOfferRecord, error) {
	templates, err := listDailyShopCandidateTemplates(ctx, token)
	if err != nil {
		return nil, err
	}
	if len(templates) == 0 {
		return nil, statusError{status: http.StatusBadRequest, message: "no equipment templates available for daily shop offers"}
	}

	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	rng.Shuffle(len(templates), func(i, j int) {
		templates[i], templates[j] = templates[j], templates[i]
	})

	count := dailyShopOfferCount
	if len(templates) < count {
		count = len(templates)
	}

	offers := make([]dailyShopOfferRecord, 0, count)
	for index := 0; index < count; index++ {
		offer, err := createDailyShopOffer(ctx, token, shopID, characterID, templates[index], offerDate, index+1, rerollCount)
		if err != nil {
			return nil, err
		}
		offers = append(offers, offer)
	}
	return offers, nil
}

func listDailyShopCandidateTemplates(ctx context.Context, token string) ([]itemTemplateRecord, error) {
	query := url.Values{}
	query.Set("filter", fmt.Sprintf("item_type=%q && rarity!=%q && is_active=true", "equipment", "epic"))
	query.Set("sort", "rarity,equipment_slot,price_coin")
	query.Set("perPage", "200")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(itemTemplatesCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, mapPocketBaseError(resp, "failed to list daily shop candidates")
	}

	var list pocketBaseListResponse[itemTemplateRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, errors.New("failed to parse daily shop candidates response")
	}

	items := make([]itemTemplateRecord, 0, len(list.Items))
	for _, item := range list.Items {
		if strings.TrimSpace(item.EquipmentSlot) == "" {
			continue
		}
		items = append(items, item)
	}
	return items, nil
}

func createDailyShopOffer(
	ctx context.Context,
	token string,
	shopID string,
	characterID string,
	itemTemplate itemTemplateRecord,
	offerDate string,
	slotIndex int,
	rerollCount int,
) (dailyShopOfferRecord, error) {
	originalPrice := int(itemTemplate.PriceCoin)
	discountedPrice := discountedDailyShopPrice(originalPrice)
	payload := map[string]any{
		"character":           characterID,
		"shop":                shopID,
		"item_template":       itemTemplate.ID,
		"offer_date":          offerDate,
		"slot_index":          slotIndex,
		"original_price_coin": originalPrice,
		"price_coin":          discountedPrice,
		"discount_rate":       dailyShopDiscountRate,
		"reroll_count":        rerollCount,
		"is_active":           true,
		"is_purchased":        false,
		"generated_at":        time.Now().UTC().Format(time.RFC3339),
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(dailyShopOffersCollection)+"?expand=item_template", token, payload)
	if err != nil {
		return dailyShopOfferRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return dailyShopOfferRecord{}, mapPocketBaseError(resp, "failed to create daily shop offer")
	}

	var offer dailyShopOfferRecord
	if err := json.NewDecoder(resp.Body).Decode(&offer); err != nil {
		return dailyShopOfferRecord{}, errors.New("failed to parse daily shop offer response")
	}
	if offer.Expand == nil {
		offer.Expand = map[string]itemTemplateRecord{"item_template": itemTemplate}
	}
	return offer, nil
}

func discountedDailyShopPrice(originalPrice int) int {
	if originalPrice <= 0 {
		return 0
	}
	discounted := int(math.Floor(float64(originalPrice) * (1 - dailyShopDiscountRate)))
	if discounted < 1 {
		return 1
	}
	return discounted
}

func getDailyShopOffer(ctx context.Context, token string, offerID string) (dailyShopOfferRecord, error) {
	endpoint := pocketBaseRecordURL(dailyShopOffersCollection, offerID) + "?expand=item_template"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return dailyShopOfferRecord{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		if resp.StatusCode == http.StatusNotFound {
			return dailyShopOfferRecord{}, statusError{status: http.StatusNotFound, message: "daily shop offer not found"}
		}
		return dailyShopOfferRecord{}, mapPocketBaseError(resp, "failed to get daily shop offer")
	}

	var offer dailyShopOfferRecord
	if err := json.NewDecoder(resp.Body).Decode(&offer); err != nil {
		return dailyShopOfferRecord{}, errors.New("failed to parse daily shop offer response")
	}
	return offer, nil
}

func patchDailyShopOffer(ctx context.Context, token string, offerID string, payload map[string]any) error {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(dailyShopOffersCollection, offerID), token, payload)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to update daily shop offer")
	}
	return nil
}

func updateDailyShopOffer(ctx context.Context, token string, offerID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(dailyShopOffersCollection, offerID)+"?expand=item_template", token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update daily shop offer")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse daily shop offer update response")
	}
	return record, nil
}

func unlockNextEquipmentShopItem(ctx context.Context, token string, shopID string, itemTemplate itemTemplateRecord) (map[string]any, error) {
	nextRarity, ok := nextEquipmentRarity(itemTemplate.Rarity)
	if !ok || itemTemplate.EquipmentSlot == "" {
		return nil, nil
	}
	if nextRarity == "epic" {
		return nil, nil
	}

	nextTemplate, found, err := findEquipmentTemplateBySlotAndRarity(ctx, token, itemTemplate.EquipmentSlot, nextRarity)
	if err != nil || !found {
		return nil, err
	}

	existing, found, err := findShopItemByTemplate(ctx, token, shopID, nextTemplate.ID)
	if err != nil {
		return nil, err
	}
	if found {
		if existing.IsActive {
			return map[string]any{
				"id":            existing.ID,
				"item_template": existing.ItemTemplate,
				"is_active":     existing.IsActive,
				"already_open":  true,
			}, nil
		}
		return patchShopItem(ctx, token, existing.ID, map[string]any{"is_active": true})
	}

	priceCoin := nextTemplate.PriceCoin
	if priceCoin <= 0 {
		priceCoin = itemTemplate.PriceCoin
	}
	return createShopItem(ctx, token, map[string]any{
		"shop":          shopID,
		"item_template": nextTemplate.ID,
		"price_coin":    priceCoin,
		"is_active":     true,
	})
}

func nextEquipmentRarity(current string) (string, bool) {
	for index, rarity := range equipmentRarityOrder {
		if rarity == current && index+1 < len(equipmentRarityOrder) {
			return equipmentRarityOrder[index+1], true
		}
	}
	return "", false
}

func findEquipmentTemplateBySlotAndRarity(ctx context.Context, token string, slot string, rarity string) (itemTemplateRecord, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf(
		"item_type=%q && equipment_slot=%q && rarity=%q && is_active=true",
		"equipment",
		slot,
		rarity,
	))
	endpoint := pocketBaseCollectionURL(itemTemplatesCollection) + "?filter=" + filter + "&sort=price_coin,created&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return itemTemplateRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return itemTemplateRecord{}, false, mapPocketBaseError(resp, "failed to find next equipment template")
	}

	var list pocketBaseListResponse[itemTemplateRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return itemTemplateRecord{}, false, errors.New("failed to parse next equipment template response")
	}
	if len(list.Items) == 0 {
		return itemTemplateRecord{}, false, nil
	}
	return list.Items[0], true, nil
}

func findShopItemByTemplate(ctx context.Context, token string, shopID string, itemTemplateID string) (shopItemRecord, bool, error) {
	filter := url.QueryEscape(fmt.Sprintf("shop=%q && item_template=%q", shopID, itemTemplateID))
	endpoint := pocketBaseCollectionURL(shopItemsCollection) + "?filter=" + filter + "&expand=item_template&perPage=1"
	resp, err := pocketBaseRequest(ctx, http.MethodGet, endpoint, token, nil)
	if err != nil {
		return shopItemRecord{}, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return shopItemRecord{}, false, mapPocketBaseError(resp, "failed to find shop item by template")
	}

	var list pocketBaseListResponse[shopItemRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return shopItemRecord{}, false, errors.New("failed to parse shop item by template response")
	}
	if len(list.Items) == 0 {
		return shopItemRecord{}, false, nil
	}
	return list.Items[0], true, nil
}

func createShopItem(ctx context.Context, token string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(shopItemsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create unlocked shop item")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse unlocked shop item response")
	}
	return record, nil
}

func patchShopItem(ctx context.Context, token string, shopItemID string, payload map[string]any) (map[string]any, error) {
	resp, err := pocketBaseRequest(ctx, http.MethodPatch, pocketBaseRecordURL(shopItemsCollection, shopItemID), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to update unlocked shop item")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse unlocked shop item update response")
	}
	return record, nil
}

func isShopItemAvailable(shopItem shopItemRecord, now time.Time) bool {
	if !shopItem.IsActive {
		return false
	}
	if shopItem.StartedAt != "" {
		startedAt, err := parsePocketBaseDate(shopItem.StartedAt)
		if err == nil && now.Before(startedAt) {
			return false
		}
	}
	if shopItem.EndedAt != "" {
		endedAt, err := parsePocketBaseDate(shopItem.EndedAt)
		if err == nil && now.After(endedAt) {
			return false
		}
	}
	return true
}

func parsePocketBaseDate(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	for _, layout := range []string{
		time.RFC3339Nano,
		"2006-01-02 15:04:05.000Z",
		"2006-01-02 15:04:05Z",
		"2006-01-02 15:04:05.000",
		"2006-01-02 15:04:05",
		"2006-01-02",
	} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("invalid date")
}

func totalCoinPrice(priceCoin float64, quantity int) (int, error) {
	if priceCoin < 0 {
		return 0, statusError{status: http.StatusBadRequest, message: "shop item price is invalid"}
	}
	if priceCoin != math.Trunc(priceCoin) {
		return 0, statusError{status: http.StatusBadRequest, message: "shop item price must be whole coin"}
	}
	return int(priceCoin) * quantity, nil
}

func sumPurchaseLogQuantity(ctx context.Context, token string, filter string) (float64, error) {
	total := 0.0
	for page := 1; ; page++ {
		query := url.Values{}
		query.Set("filter", filter)
		query.Set("page", fmt.Sprintf("%d", page))
		query.Set("perPage", "100")

		resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(purchaseLogsCollection)+"?"+query.Encode(), token, nil)
		if err != nil {
			return 0, err
		}
		if resp.StatusCode != http.StatusOK {
			err := mapPocketBaseError(resp, "failed to list purchase logs")
			resp.Body.Close()
			return 0, err
		}

		var list pocketBaseListResponse[purchaseLogRecord]
		if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
			resp.Body.Close()
			return 0, errors.New("failed to parse purchase logs response")
		}
		resp.Body.Close()
		for _, item := range list.Items {
			total += item.Quantity
		}
		if page >= list.TotalPages || len(list.Items) == 0 {
			return total, nil
		}
	}
}

func countActiveOwnedEquipmentByTemplate(ctx context.Context, token string, characterID string, itemTemplateID string) (int, error) {
	query := url.Values{}
	query.Set("filter", fmt.Sprintf(
		"character=%q && item_template=%q && status!=\"sold\" && status!=\"deleted\"",
		characterID,
		itemTemplateID,
	))
	query.Set("perPage", "1")

	resp, err := pocketBaseRequest(ctx, http.MethodGet, pocketBaseCollectionURL(ownedEquipmentsCollection)+"?"+query.Encode(), token, nil)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, mapPocketBaseError(resp, "failed to count owned equipments")
	}

	var list pocketBaseListResponse[ownedEquipmentRecord]
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return 0, errors.New("failed to parse owned equipments response")
	}
	return list.TotalItems, nil
}

func addCharacterConsumableQuantity(ctx context.Context, token string, characterID string, itemTemplateID string, quantity int) (map[string]any, error) {
	consumable, err := getCharacterConsumable(ctx, token, characterID, itemTemplateID)
	if err == nil {
		return patchCharacterConsumableQuantity(ctx, token, consumable.ID, consumable.Quantity+float64(quantity))
	}

	var statusErr statusError
	if !errors.As(err, &statusErr) || statusErr.status != http.StatusNotFound {
		return nil, err
	}

	payload := map[string]any{
		"character":     characterID,
		"item_template": itemTemplateID,
		"quantity":      quantity,
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(characterConsumablesCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create character consumable")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse character consumable response")
	}
	return record, nil
}

func createOwnedEquipmentsFromPurchase(ctx context.Context, token string, characterID string, itemTemplate itemTemplateRecord, quantity int) ([]map[string]any, error) {
	equipments := make([]map[string]any, 0, quantity)
	for i := 0; i < quantity; i++ {
		equipment, err := createOwnedEquipment(ctx, token, characterID, itemTemplate)
		if err != nil {
			return nil, err
		}
		equipments = append(equipments, equipment)
	}
	return equipments, nil
}

func createOwnedEquipment(ctx context.Context, token string, characterID string, itemTemplate itemTemplateRecord) (map[string]any, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	payload := map[string]any{
		"character":      characterID,
		"item_template":  itemTemplate.ID,
		"rolled_hp":      itemTemplate.BaseHP,
		"rolled_attack":  itemTemplate.BaseAttack,
		"rolled_defense": itemTemplate.BaseDefense,
		"rolled_agility": itemTemplate.BaseAgility,
		"upgrade_level":  0,
		"status":         "owned",
		"acquired_at":    now,
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(ownedEquipmentsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create owned equipment")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse owned equipment response")
	}
	record["expand"] = map[string]any{
		"item_template": itemTemplate,
	}
	return record, nil
}

func createPurchaseLog(ctx context.Context, token string, characterID string, shopItemID string, quantity int, totalPriceCoin int) (map[string]any, error) {
	payload := map[string]any{
		"character":        characterID,
		"shop_item":        shopItemID,
		"quantity":         quantity,
		"total_price_coin": totalPriceCoin,
		"purchased_at":     time.Now().UTC().Format(time.RFC3339),
	}
	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL(purchaseLogsCollection), token, payload)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, mapPocketBaseError(resp, "failed to create purchase log")
	}

	var record map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&record); err != nil {
		return nil, errors.New("failed to parse purchase log response")
	}
	return record, nil
}

func createShopResourceTransaction(
	ctx context.Context,
	token string,
	characterID string,
	sourceType string,
	sourceID string,
	amount int,
	balanceAfter int,
	reason string,
) error {
	payload := map[string]any{
		"character":        characterID,
		"resource_type":    "coin",
		"transaction_type": "use",
		"amount":           amount,
		"balance_after":    balanceAfter,
		"source_type":      sourceType,
		"reason":           reason,
	}
	if sourceID != "" {
		payload["source_id"] = sourceID
	}

	resp, err := pocketBaseRequest(ctx, http.MethodPost, pocketBaseCollectionURL("resource_transactions"), token, payload)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return mapPocketBaseError(resp, "failed to create shop resource transaction")
	}
	return nil
}
