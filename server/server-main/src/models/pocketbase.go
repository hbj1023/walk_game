package models

type PocketBaseUser struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
}

type PocketBaseAuthResponse struct {
	Token  string         `json:"token"`
	Record PocketBaseUser `json:"record"`
}

type PocketBaseErrorResponse struct {
	Message string                 `json:"message"`
	Data    map[string]interface{} `json:"data"`
}
