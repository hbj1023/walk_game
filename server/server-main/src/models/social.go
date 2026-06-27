package models

type FriendshipRequestBody struct {
	RequesterUserID string `json:"requesterUserId"`
	TargetUserID    string `json:"targetUserId"`
}

type FriendshipRecord struct {
	ID              string `json:"id"`
	UserLow         string `json:"user_low"`
	UserHigh        string `json:"user_high"`
	Status          string `json:"status"`
	RequestedByUser string `json:"requested_by_user"`
}
