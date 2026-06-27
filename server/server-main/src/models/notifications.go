package models

type NotificationRecord struct {
	ID         string         `json:"id"`
	User       string         `json:"user"`
	Type       string         `json:"type"`
	Title      string         `json:"title"`
	Message    string         `json:"message"`
	Data       map[string]any `json:"data"`
	SourceType string         `json:"source_type"`
	SourceID   string         `json:"source_id"`
	IsRead     bool           `json:"is_read"`
	ReadAt     string         `json:"read_at"`
	Created    string         `json:"created"`
	Updated    string         `json:"updated"`
}

type NotificationCreateInput struct {
	UserID     string
	Type       string
	Title      string
	Message    string
	Data       map[string]any
	SourceType string
	SourceID   string
}
