package character

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// PocketBase 컬렉션 이름을 한 곳에서 관리한다.
const (
	CollectionCharacters         = "characters"
	CollectionItemTemplates      = "item_templates"
	CollectionOwnedEquipments    = "owned_equipments"
	CollectionCharacterEquipment = "character_equipments"

	// character_equipment 컬렉션에서 장비 아이템을 가리키는 필드명이다.
	// 만약 PocketBase 필드명이 item_template이 아니라 item이면 여기만 바꾸면 된다.
	EquipmentItemField = "owned_equipment"
)

var pocketBaseClient = &http.Client{
	Timeout: 10 * time.Second,
}

// Service는 캐릭터 기능에서 PocketBase와 통신하는 역할을 한다.
type Service struct {
	PocketBaseURL string
}

// NewService는 환경변수에서 PocketBase 주소를 읽어서 서비스를 만든다.
func NewService() *Service {
	pbURL := os.Getenv("POCKETBASE_URL")
	if pbURL == "" {
		pbURL = "http://127.0.0.1:8090"
	}

	return &Service{
		PocketBaseURL: pbURL,
	}
}

// CharacterCreateRequest는 캐릭터 생성 요청 데이터다.
type CharacterCreateRequest struct {
	UserID        string `json:"user_id"`
	Name          string `json:"name"`
	Gender        string `json:"gender"`
	HairType      string `json:"hair_type"`
	HairColor     string `json:"hair_color"`
	SkinColor     string `json:"skin_color"`
	OutfitType    string `json:"outfit_type"`
	AccessoryType string `json:"accessory_type"`
}

// CharacterUpdateRequest는 캐릭터 외형/기본 정보 수정 요청 데이터다.
type CharacterUpdateRequest struct {
	CharacterID   string `json:"character_id"`
	Name          string `json:"name"`
	Gender        string `json:"gender"`
	HairType      string `json:"hair_type"`
	HairColor     string `json:"hair_color"`
	SkinColor     string `json:"skin_color"`
	OutfitType    string `json:"outfit_type"`
	AccessoryType string `json:"accessory_type"`
}

// AddExpRequest는 경험치 추가 요청 데이터다.
type AddExpRequest struct {
	CharacterID string `json:"character_id"`
	Exp         int    `json:"exp"`
}

// EquipItemRequest는 장비 착용 요청 데이터다.
type EquipItemRequest struct {
	CharacterID string `json:"character_id"`
	ItemID      string `json:"item_id"`
	Slot        string `json:"slot"`
}

// UnequipItemRequest는 장비 해제 요청 데이터다.
type UnequipItemRequest struct {
	CharacterID string `json:"character_id"`
	Slot        string `json:"slot"`
}

// FinalStatsResponse는 장비 스탯까지 합산한 최종 스탯 응답 데이터다.
type FinalStatsResponse struct {
	CharacterID string `json:"character_id"`
	Level       int    `json:"level"`

	BaseHP      int `json:"base_hp"`
	BaseAttack  int `json:"base_attack"`
	BaseDefense int `json:"base_defense"`
	BaseAgility int `json:"base_agility"`

	EquipHP      int `json:"equip_hp"`
	EquipAttack  int `json:"equip_attack"`
	EquipDefense int `json:"equip_defense"`
	EquipAgility int `json:"equip_agility"`

	FinalHP      int `json:"final_hp"`
	FinalAttack  int `json:"final_attack"`
	FinalDefense int `json:"final_defense"`
	FinalAgility int `json:"final_agility"`
}

// PocketBase 목록 조회 응답 구조다.
type pbListResponse struct {
	Page       int              `json:"page"`
	PerPage    int              `json:"perPage"`
	TotalItems int              `json:"totalItems"`
	Items      []map[string]any `json:"items"`
}

// PocketBase에 HTTP 요청을 보내는 공통 함수다.
func (s *Service) pbRequest(method string, path string, body any, authHeader string) ([]byte, error) {
	var reqBody io.Reader

	if body != nil {
		jsonBytes, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		reqBody = bytes.NewBuffer(jsonBytes)
	}

	req, err := http.NewRequest(method, s.PocketBaseURL+path, reqBody)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")

	// Flutter에서 넘겨준 PocketBase 로그인 토큰이 있으면 그대로 PocketBase에 전달한다.
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}

	res, err := pocketBaseClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	data, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return nil, fmt.Errorf("pocketbase error: %s", string(data))
	}

	return data, nil
}

// 캐릭터를 새로 생성한다.
func (s *Service) CreateCharacter(req CharacterCreateRequest, authHeader string) (map[string]any, error) {
	body := map[string]any{
		"user":                 req.UserID,
		"name":                 defaultText(req.Name, "Adventurer"),
		"gender":               defaultText(req.Gender, "other"),
		"level":                1,
		"exp":                  0,
		"stat_exp":             0,
		"current_hp":           100,
		"coin_balance":         0,
		"attack_count_balance": 0,
		"hair_type":            defaultText(req.HairType, "basic"),
		"hair_color":           defaultText(req.HairColor, "brown"),
		"skin_color":           defaultText(req.SkinColor, "default"),
		"outfit_type":          defaultText(req.OutfitType, "basic"),
		"accessory_type":       defaultText(req.AccessoryType, "none"),
	}

	data, err := s.pbRequest(
		http.MethodPost,
		"/api/collections/"+CollectionCharacters+"/records",
		body,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

func defaultText(value string, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	return value
}

// 특정 유저의 캐릭터를 조회한다.
func (s *Service) GetCharacterByUser(userID string, authHeader string) ([]map[string]any, error) {
	filter := url.QueryEscape(fmt.Sprintf(`user="%s"`, userID))
	path := "/api/collections/" + CollectionCharacters + "/records?filter=(" + filter + ")"

	data, err := s.pbRequest(http.MethodGet, path, nil, authHeader)
	if err != nil {
		return nil, err
	}

	var result pbListResponse
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}

	return result.Items, nil
}

// 캐릭터의 외형 또는 기본 정보를 수정한다.
func (s *Service) UpdateCharacter(req CharacterUpdateRequest, authHeader string) (map[string]any, error) {
	body := map[string]any{}

	if req.Name != "" {
		body["name"] = req.Name
	}
	if req.Gender != "" {
		body["gender"] = req.Gender
	}
	if req.HairType != "" {
		body["hair_type"] = req.HairType
	}
	if req.HairColor != "" {
		body["hair_color"] = req.HairColor
	}
	if req.SkinColor != "" {
		body["skin_color"] = req.SkinColor
	}
	if req.OutfitType != "" {
		body["outfit_type"] = req.OutfitType
	}
	if req.AccessoryType != "" {
		body["accessory_type"] = req.AccessoryType
	}

	data, err := s.pbRequest(
		http.MethodPatch,
		"/api/collections/"+CollectionCharacters+"/records/"+req.CharacterID,
		body,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

// 경험치를 추가하고, 기준 경험치를 넘으면 레벨업을 처리한다.
func (s *Service) AddExp(req AddExpRequest, authHeader string) (map[string]any, error) {
	character, err := s.GetCharacterByID(req.CharacterID, authHeader)
	if err != nil {
		return nil, err
	}

	level := toInt(character["level"])
	exp := toInt(character["exp"])
	statExp := toInt(character["stat_exp"])

	exp += req.Exp

	// 임시 레벨업 공식: 현재 레벨 * 100 경험치마다 1레벨 증가
	for exp >= level*100 {
		exp -= level * 100
		level++
		statExp += statExpRewardForLevel(level)
	}

	body := map[string]any{
		"level":    level,
		"exp":      exp,
		"stat_exp": statExp,
	}

	data, err := s.pbRequest(
		http.MethodPatch,
		"/api/collections/"+CollectionCharacters+"/records/"+req.CharacterID,
		body,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

// 장비를 착용한다. 같은 슬롯에 이미 장비가 있으면 먼저 제거한 뒤 새 장비를 착용한다.
func statExpRewardForLevel(level int) int {
	if level < 2 {
		return 0
	}
	return 40 + ((level - 1) / 5 * 10)
}

func (s *Service) EquipItem(req EquipItemRequest, authHeader string) (map[string]any, error) {
	ownedEquipment, err := s.GetOwnedEquipmentByID(req.ItemID, authHeader)
	if err != nil {
		return nil, err
	}
	if fmt.Sprint(ownedEquipment["character"]) != req.CharacterID {
		return nil, fmt.Errorf("owned equipment does not belong to character")
	}

	slot := normalizeEquipmentSlot(req.Slot)
	if expanded, ok := ownedEquipment["expand"].(map[string]any); ok {
		if itemTemplate, ok := expanded["item_template"].(map[string]any); ok {
			templateSlot := normalizeEquipmentSlot(fmt.Sprint(itemTemplate["equipment_slot"]))
			if templateSlot != "" {
				slot = templateSlot
			}
		}
	}
	if slot == "" {
		return nil, fmt.Errorf("equipment slot is required")
	}

	if err := s.UnequipItem(UnequipItemRequest{
		CharacterID: req.CharacterID,
		Slot:        slot,
	}, authHeader); err != nil {
		return nil, err
	}

	body := map[string]any{
		"character":        req.CharacterID,
		EquipmentItemField: req.ItemID,
		"equipped_at":      time.Now().UTC().Format(time.RFC3339),
	}

	data, err := s.pbRequest(
		http.MethodPost,
		"/api/collections/"+CollectionCharacterEquipment+"/records",
		body,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	if err != nil {
		return nil, err
	}
	if _, err := s.patchOwnedEquipmentStatus(req.ItemID, "equipped", authHeader); err != nil {
		return nil, err
	}
	return result, err
}

// 특정 슬롯에 착용된 장비를 해제한다.
func (s *Service) UnequipItem(req UnequipItemRequest, authHeader string) error {
	equippedItems, err := s.GetEquippedItemsBySlot(req.CharacterID, normalizeEquipmentSlot(req.Slot), authHeader)
	if err != nil {
		return err
	}

	for _, item := range equippedItems {
		id, ok := item["id"].(string)
		if !ok {
			continue
		}

		_, err := s.pbRequest(
			http.MethodDelete,
			"/api/collections/"+CollectionCharacterEquipment+"/records/"+id,
			nil,
			authHeader,
		)
		if err != nil {
			return err
		}
		if ownedEquipmentID, ok := item[EquipmentItemField].(string); ok && ownedEquipmentID != "" {
			if _, err := s.patchOwnedEquipmentStatus(ownedEquipmentID, "owned", authHeader); err != nil {
				return err
			}
		}
	}

	return nil
}

// 장비 스탯을 합산해서 최종 스탯을 계산한다.
func (s *Service) GetFinalStats(characterID string, authHeader string) (FinalStatsResponse, error) {
	character, err := s.GetCharacterByID(characterID, authHeader)
	if err != nil {
		return FinalStatsResponse{}, err
	}

	level := toInt(character["level"])

	// 기본 스탯은 일단 레벨 기반으로 계산한다.
	// 나중에 character_stats 컬렉션을 본격적으로 쓰면 이 부분만 DB 조회 방식으로 바꾸면 된다.
	baseHP := 100 + (level-1)*10
	baseAttack := 10 + (level-1)*2
	baseDefense := 5 + (level-1)*1
	baseAgility := 5 + (level-1)*1

	equippedItems, err := s.GetEquippedItems(characterID, authHeader)
	if err != nil {
		return FinalStatsResponse{}, err
	}

	equipHP := 0
	equipAttack := 0
	equipDefense := 0
	equipAgility := 0

	for _, equipped := range equippedItems {
		itemID, ok := equipped[EquipmentItemField].(string)
		if !ok || itemID == "" {
			continue
		}

		ownedEquipment, err := s.GetOwnedEquipmentByID(itemID, authHeader)
		if err != nil {
			return FinalStatsResponse{}, err
		}
		expanded, ok := ownedEquipment["expand"].(map[string]any)
		if !ok {
			continue
		}
		item, ok := expanded["item_template"].(map[string]any)
		if !ok {
			continue
		}

		equipHP += toInt(item["base_hp"])
		equipAttack += toInt(item["base_attack"])
		equipDefense += toInt(item["base_defense"])
		equipAgility += toInt(item["base_agility"])
	}

	result := FinalStatsResponse{
		CharacterID: characterID,
		Level:       level,

		BaseHP:      baseHP,
		BaseAttack:  baseAttack,
		BaseDefense: baseDefense,
		BaseAgility: baseAgility,

		EquipHP:      equipHP,
		EquipAttack:  equipAttack,
		EquipDefense: equipDefense,
		EquipAgility: equipAgility,

		FinalHP:      baseHP + equipHP,
		FinalAttack:  baseAttack + equipAttack,
		FinalDefense: baseDefense + equipDefense,
		FinalAgility: baseAgility + equipAgility,
	}

	return result, nil
}

// 캐릭터 ID로 캐릭터 정보를 가져온다.
func (s *Service) GetCharacterByID(characterID string, authHeader string) (map[string]any, error) {
	data, err := s.pbRequest(
		http.MethodGet,
		"/api/collections/"+CollectionCharacters+"/records/"+characterID,
		nil,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

// 아이템 템플릿 ID로 아이템 정보를 가져온다.
func (s *Service) GetItemTemplateByID(itemID string, authHeader string) (map[string]any, error) {
	data, err := s.pbRequest(
		http.MethodGet,
		"/api/collections/"+CollectionItemTemplates+"/records/"+itemID,
		nil,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

// 캐릭터가 착용한 전체 장비를 조회한다.
func (s *Service) GetOwnedEquipmentByID(ownedEquipmentID string, authHeader string) (map[string]any, error) {
	data, err := s.pbRequest(
		http.MethodGet,
		"/api/collections/"+CollectionOwnedEquipments+"/records/"+ownedEquipmentID+"?expand=item_template",
		nil,
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

func (s *Service) patchOwnedEquipmentStatus(ownedEquipmentID string, status string, authHeader string) (map[string]any, error) {
	data, err := s.pbRequest(
		http.MethodPatch,
		"/api/collections/"+CollectionOwnedEquipments+"/records/"+ownedEquipmentID,
		map[string]any{"status": status},
		authHeader,
	)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	err = json.Unmarshal(data, &result)
	return result, err
}

func (s *Service) GetEquippedItems(characterID string, authHeader string) ([]map[string]any, error) {
	filter := url.QueryEscape(fmt.Sprintf(`character="%s"`, characterID))
	path := "/api/collections/" + CollectionCharacterEquipment + "/records?filter=(" + filter + ")&expand=owned_equipment,owned_equipment.item_template"

	data, err := s.pbRequest(http.MethodGet, path, nil, authHeader)
	if err != nil {
		return nil, err
	}

	var result pbListResponse
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}

	return result.Items, nil
}

// 특정 슬롯에 착용된 장비를 조회한다.
func (s *Service) GetEquippedItemsBySlot(characterID string, slot string, authHeader string) ([]map[string]any, error) {
	filter := url.QueryEscape(fmt.Sprintf(`character="%s" && owned_equipment.item_template.equipment_slot="%s"`, characterID, normalizeEquipmentSlot(slot)))
	path := "/api/collections/" + CollectionCharacterEquipment + "/records?filter=(" + filter + ")"

	data, err := s.pbRequest(http.MethodGet, path, nil, authHeader)
	if err != nil {
		return nil, err
	}

	var result pbListResponse
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}

	return result.Items, nil
}

// PocketBase 숫자 타입을 int로 변환한다.
func normalizeEquipmentSlot(slot string) string {
	slot = strings.TrimSpace(slot)
	if slot == "greaves" {
		return "sword"
	}
	return slot
}

func toInt(value any) int {
	switch v := value.(type) {
	case int:
		return v
	case int64:
		return int(v)
	case float64:
		return int(v)
	case float32:
		return int(v)
	default:
		return 0
	}
}
