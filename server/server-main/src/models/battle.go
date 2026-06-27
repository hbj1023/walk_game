package models

type NormalBattleStartRequest struct {
	CharacterID string `json:"character_id"`
	StageID     string `json:"stage_id"`
	StageNo     int    `json:"stage_no"`
}

type NormalBattleAttackRequest struct {
	BattleID string `json:"battle_id"`
}

type NormalBattleLeaveRequest struct {
	BattleID string `json:"battle_id"`
}

type NormalBattleResponse struct {
	Battle                 BattleRecord    `json:"battle"`
	Character              CharacterRecord `json:"character"`
	CharacterMaxHP         int             `json:"character_max_hp"`
	Monster                MonsterRecord   `json:"monster"`
	PlayerDamage           int             `json:"player_damage"`
	MonsterDamage          int             `json:"monster_damage"`
	MonsterAttacked        bool            `json:"monster_attacked"`
	RewardCoin             int             `json:"reward_coin"`
	RewardItem             any             `json:"reward_item,omitempty"`
	TicketConsumed         bool            `json:"ticket_consumed,omitempty"`
	AttackCountBalance     int             `json:"attack_count_balance"`
	MonsterAttackGaugeM    float64         `json:"monster_attack_gauge_m"`
	MonsterAttackDistanceM float64         `json:"monster_attack_distance_m"`
}

type CharacterRecord struct {
	ID                 string `json:"id"`
	User               string `json:"user"`
	Name               string `json:"name"`
	CurrentHP          int    `json:"current_hp"`
	CoinBalance        int    `json:"coin_balance"`
	AttackCountBalance int    `json:"attack_count_balance"`
}

type CharacterStatsRecord struct {
	ID              string `json:"id"`
	Character       string `json:"character"`
	BaseHP          int    `json:"base_hp"`
	BaseAttack      int    `json:"base_attack"`
	BaseDefense     int    `json:"base_defense"`
	BaseAgility     int    `json:"base_agility"`
	UpgradedHP      int    `json:"upgraded_hp"`
	UpgradedAttack  int    `json:"upgraded_attack"`
	UpgradedDefense int    `json:"upgraded_defense"`
	UpgradedAgility int    `json:"upgraded_agility"`
}

func (s CharacterStatsRecord) HP() int {
	return s.BaseHP + s.UpgradedHP
}

func (s CharacterStatsRecord) Attack() int {
	return s.BaseAttack + s.UpgradedAttack
}

func (s CharacterStatsRecord) Defense() int {
	return s.BaseDefense + s.UpgradedDefense
}

func (s CharacterStatsRecord) Agility() int {
	return s.BaseAgility + s.UpgradedAgility
}

type StageRecord struct {
	ID           string `json:"id"`
	StageNo      int    `json:"stage_no"`
	Title        string `json:"title"`
	StageType    string `json:"stage_type"`
	MonsterCount int    `json:"monster_count"`
	IsActive     bool   `json:"is_active"`
}

type StageProgressRecord struct {
	ID             string `json:"id"`
	Character      string `json:"character"`
	Stage          string `json:"stage"`
	Status         string `json:"status"`
	ClearCount     int    `json:"clear_count"`
	FirstClearedAt string `json:"first_cleared_at"`
	LastClearedAt  string `json:"last_cleared_at"`
}

type NormalStageListResponse struct {
	Stages []NormalStageResponse `json:"stages"`
}

type NormalStageResponse struct {
	ID             string `json:"id"`
	StageNo        int    `json:"stage_no"`
	Title          string `json:"title"`
	StageType      string `json:"stage_type"`
	MonsterCount   int    `json:"monster_count"`
	MonsterID      string `json:"monster_id"`
	MonsterName    string `json:"monster_name"`
	MonsterHP      int    `json:"monster_hp"`
	IsActive       bool   `json:"is_active"`
	Status         string `json:"status"`
	ClearCount     int    `json:"clear_count"`
	FirstClearedAt string `json:"first_cleared_at"`
	LastClearedAt  string `json:"last_cleared_at"`
	IsUnlocked     bool   `json:"is_unlocked"`
	IsCleared      bool   `json:"is_cleared"`
}

type StageMonsterRecord struct {
	ID         string `json:"id"`
	Stage      string `json:"stage"`
	Monster    string `json:"monster"`
	SpawnOrder int    `json:"spawn_order"`
	IsBoss     bool   `json:"is_boss"`
}

type MonsterRecord struct {
	ID                   string `json:"id"`
	Name                 string `json:"name"`
	MonsterType          string `json:"monster_type"`
	RequiredDistanceMinM int    `json:"required_distance_min_m"`
	RequiredDistanceMaxM int    `json:"required_distance_max_m"`
	RewardCoinMin        int    `json:"reward_coin_min"`
	RewardCoinMax        int    `json:"reward_coin_max"`
	IsActive             bool   `json:"is_active"`
	HP                   int    `json:"hp"`
	Attack               int    `json:"attack"`
	Defense              int    `json:"defense"`
	Agility              int    `json:"agility"`
}

type BattleRecord struct {
	ID                  string  `json:"id"`
	Character           string  `json:"character"`
	Stage               string  `json:"stage"`
	Monster             string  `json:"monster"`
	Raid                string  `json:"raid"`
	BattleType          string  `json:"battle_type"`
	Status              string  `json:"status"`
	DistanceUsedM       float64 `json:"distance_used_m"`
	AttackCountUsed     int     `json:"attack_count_used"`
	TotalDamageDealt    int     `json:"total_damage_dealt"`
	TotalDamageTaken    int     `json:"total_damage_taken"`
	RewardCoin          int     `json:"reward_coin"`
	StartedAt           string  `json:"started_at"`
	EndedAt             string  `json:"ended_at"`
	MonsterCurrentHP    int     `json:"monster_current_hp"`
	CharacterCurrentHP  int     `json:"character_current_hp"`
	MonsterAttackGaugeM float64 `json:"monster_attack_gauge_m"`
	CurrentSpawnOrder   int     `json:"current_spawn_order"`
	LastAttackedAt      string  `json:"last_attacked_at"`
}
