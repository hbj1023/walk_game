package character

import (
	"encoding/json"
	"net/http"
)

// Handler는 캐릭터 관련 HTTP 요청을 처리한다.
type Handler struct {
	Service *Service
}

// NewHandler는 캐릭터 핸들러를 만든다.
func NewHandler() *Handler {
	return &Handler{
		Service: NewService(),
	}
}

// RegisterRoutes는 캐릭터 관련 API 주소를 등록한다.
func RegisterRoutes(mux *http.ServeMux) {
	handler := NewHandler()

	mux.HandleFunc("/characters/create", handler.CreateCharacter)
	mux.HandleFunc("/characters/me", handler.GetMyCharacter)
	mux.HandleFunc("/characters/update", handler.UpdateCharacter)
	mux.HandleFunc("/characters/exp", handler.AddExp)
	mux.HandleFunc("/characters/equip", handler.EquipItem)
	mux.HandleFunc("/characters/unequip", handler.UnequipItem)
	mux.HandleFunc("/characters/final-stats", handler.GetFinalStats)
}

// 캐릭터 생성 API
func (h *Handler) CreateCharacter(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "POST method required")
		return
	}

	var req CharacterCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.UserID == "" || req.Name == "" {
		writeError(w, http.StatusBadRequest, "user_id and name are required")
		return
	}

	result, err := h.Service.CreateCharacter(req, r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, result)
}

// 유저별 캐릭터 조회 API
func (h *Handler) GetMyCharacter(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "GET method required")
		return
	}

	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		writeError(w, http.StatusBadRequest, "user_id is required")
		return
	}

	result, err := h.Service.GetCharacterByUser(userID, r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// 캐릭터 정보 수정 API
func (h *Handler) UpdateCharacter(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPatch {
		writeError(w, http.StatusMethodNotAllowed, "PATCH method required")
		return
	}

	var req CharacterUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.CharacterID == "" {
		writeError(w, http.StatusBadRequest, "character_id is required")
		return
	}

	result, err := h.Service.UpdateCharacter(req, r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// 경험치 추가 및 레벨업 API
func (h *Handler) AddExp(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "POST method required")
		return
	}

	var req AddExpRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.CharacterID == "" {
		writeError(w, http.StatusBadRequest, "character_id is required")
		return
	}

	result, err := h.Service.AddExp(req, r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// 장비 착용 API
func (h *Handler) EquipItem(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "POST method required")
		return
	}

	var req EquipItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.CharacterID == "" || req.ItemID == "" || req.Slot == "" {
		writeError(w, http.StatusBadRequest, "character_id, item_id, slot are required")
		return
	}

	result, err := h.Service.EquipItem(req, r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// 장비 해제 API
func (h *Handler) UnequipItem(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "POST method required")
		return
	}

	var req UnequipItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.CharacterID == "" || req.Slot == "" {
		writeError(w, http.StatusBadRequest, "character_id and slot are required")
		return
	}

	if err := h.Service.UnequipItem(req, r.Header.Get("Authorization")); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"message": "equipment unequipped",
	})
}

// 장비 포함 최종 스탯 조회 API
func (h *Handler) GetFinalStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "GET method required")
		return
	}

	characterID := r.URL.Query().Get("character_id")
	if characterID == "" {
		writeError(w, http.StatusBadRequest, "character_id is required")
		return
	}

	result, err := h.Service.GetFinalStats(characterID, r.Header.Get("Authorization"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// JSON 응답을 보내는 공통 함수다.
func writeJSON(w http.ResponseWriter, statusCode int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(data)
}

// 에러 응답을 보내는 공통 함수다.
func writeError(w http.ResponseWriter, statusCode int, message string) {
	writeJSON(w, statusCode, map[string]any{
		"error": message,
	})
}
