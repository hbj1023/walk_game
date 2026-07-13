package models

type StepSyncRequest struct {
	SourceType     string  `json:"source_type"`
	SyncType       string  `json:"sync_type"`
	StepCount      int     `json:"step_count"`
	DistanceM      int     `json:"distance_m"`
	StrideM        float64 `json:"stride_m"`
	CapturedAt     string  `json:"captured_at"`
	IsDelta        bool    `json:"is_delta"`
	GpsDistanceM   int     `json:"gps_distance_m"`
	AbnormalFlag   bool    `json:"abnormal_flag"`
	AbnormalReason string  `json:"abnormal_reason"`
}

type StepSyncResponse struct {
	ProfileID                            string  `json:"profile_id"`
	CharacterID                          string  `json:"character_id"`
	StepSyncLogID                        string  `json:"step_sync_log_id"`
	DailySummaryID                       string  `json:"daily_summary_id"`
	RecordDate                           string  `json:"record_date"`
	StepCount                            int     `json:"step_count"`
	DistanceM                            int     `json:"distance_m"`
	DeltaStepCount                       int     `json:"delta_step_count"`
	DeltaDistanceM                       int     `json:"delta_distance_m"`
	Agility                              int     `json:"agility"`
	AttackDistanceM                      float64 `json:"attack_distance_m"`
	AttackDistanceRemainderM             float64 `json:"attack_distance_remainder_m"`
	AttackCountEarned                    int     `json:"attack_count_earned"`
	AttackCountBalance                   int     `json:"attack_count_balance"`
	OfflineAttackCountCap                int     `json:"offline_attack_count_cap"`
	OfflineAttackCountEarned             int     `json:"offline_attack_count_earned"`
	OfflineAttackCountStored             int     `json:"offline_attack_count_stored"`
	OfflineAttackCountLost               int     `json:"offline_attack_count_lost"`
	BossTicketFragmentEarned             int     `json:"boss_ticket_fragment_earned"`
	BossTicketFragmentBalance            int     `json:"boss_ticket_fragment_balance"`
	BossTicketFragmentDistanceM          float64 `json:"boss_ticket_fragment_distance_m"`
	BossTicketFragmentDistanceRemainderM float64 `json:"boss_ticket_fragment_distance_remainder_m"`
	Token                                string  `json:"token"`
}

type StepSyncLogRecord struct {
	ID string `json:"id"`
}

type DailyStepSummaryRecord struct {
	ID                                   string  `json:"id"`
	User                                 string  `json:"user"`
	RecordDate                           string  `json:"record_date"`
	TotalStepCount                       int     `json:"total_step_count"`
	TotalDistanceM                       int     `json:"total_distance_m"`
	AttackCountEarned                    int     `json:"attack_count_earned"`
	AttackDistanceRemainderM             float64 `json:"attack_distance_remainder_m"`
	OfflineAttackCountEarned             int     `json:"offline_attack_count_earned"`
	OfflineAttackCountLost               int     `json:"offline_attack_count_lost"`
	BossTicketFragmentEarned             int     `json:"boss_ticket_fragment_earned"`
	BossTicketFragmentDistanceRemainderM float64 `json:"boss_ticket_fragment_distance_remainder_m"`
}
