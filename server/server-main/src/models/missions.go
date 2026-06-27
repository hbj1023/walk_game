package models

type MissionRecord struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	MissionType string  `json:"mission_type"`
	TargetType  string  `json:"target_type"`
	TargetValue float64 `json:"target_value"`
	RewardCoin  float64 `json:"reward_coin"`
	IsActive    bool    `json:"is_active"`
}

type UserMissionRecord struct {
	ID            string                   `json:"id"`
	User          string                   `json:"user"`
	Mission       string                   `json:"mission"`
	MissionDate   string                   `json:"mission_date"`
	ProgressValue float64                  `json:"progress_value"`
	Status        string                   `json:"status"`
	CompletedAt   string                   `json:"completed_at"`
	ClaimedAt     string                   `json:"claimed_at"`
	Expand        map[string]MissionRecord `json:"expand"`
}
