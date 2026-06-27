package models

type RaidCreateRequest struct {
	HostCharacterID string `json:"hostCharacterId"`
	MonsterID       string `json:"monsterId"`
	Title           string `json:"title"`
	Description     string `json:"description"`
}

type RaidJoinRequest struct {
	CharacterID string `json:"characterId"`
}

type RaidInviteRequest struct {
	InviterCharacterID string `json:"inviterCharacterId"`
	InvitedUserID      string `json:"invitedUserId"`
}

type RaidInvitationResponseRequest struct {
	CharacterID string `json:"characterId"`
}

type RaidDistanceRequest struct {
	CharacterID string  `json:"characterId"`
	DistanceM   float64 `json:"distanceM"`
}

type RaidRecord struct {
	ID              string  `json:"id"`
	HostCharacter   string  `json:"host_character"`
	Monster         string  `json:"monster"`
	Title           string  `json:"title"`
	Description     string  `json:"description"`
	MaxParticipants float64 `json:"max_participants"`
	Status          string  `json:"status"`
	RewardCoin      float64 `json:"reward_coin"`
}

type RaidParticipantRecord struct {
	ID                      string  `json:"id"`
	Raid                    string  `json:"raid"`
	Character               string  `json:"character"`
	ContributionDamage      float64 `json:"contribution_damage"`
	ContributionDistanceM   float64 `json:"contribution_distance_m"`
	ContributionAttackCount float64 `json:"contribution_attack_count"`
	JoinStatus              string  `json:"join_status"`
}

type RaidInvitationRecord struct {
	ID               string `json:"id"`
	Raid             string `json:"raid"`
	InviterCharacter string `json:"inviter_character"`
	InvitedUser      string `json:"invited_user"`
	Status           string `json:"status"`
}

type RaidProgressRecord struct {
	ID                              string  `json:"id"`
	Raid                            string  `json:"raid"`
	MonsterCurrentHP                float64 `json:"monster_current_hp"`
	TotalDistanceAccumulatedM       float64 `json:"total_distance_accumulated_m"`
	DistanceSinceLastAttackCycleM   float64 `json:"distance_since_last_attack_cycle_m"`
	DistanceSinceLastMonsterAttackM float64 `json:"distance_since_last_monster_attack_m"`
	TotalAttackCycles               float64 `json:"total_attack_cycles"`
	TotalMonsterAttackCycles        float64 `json:"total_monster_attack_cycles"`
	Status                          string  `json:"status"`
	StartedAt                       string  `json:"started_at"`
	EndedAt                         string  `json:"ended_at"`
}
