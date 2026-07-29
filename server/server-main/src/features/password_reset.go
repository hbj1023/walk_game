package features

import (
	"encoding/json"
	"net/http"
	"net/mail"
	"strings"
)

const passwordResetRequestMessage = "가입된 이메일이라면 비밀번호 재설정 안내를 보냈습니다. 메일함과 스팸함을 확인해주세요."

type passwordResetRequest struct {
	Email string `json:"email"`
}

type passwordResetConfirmRequest struct {
	Token           string `json:"token"`
	Password        string `json:"password"`
	PasswordConfirm string `json:"passwordConfirm"`
}

func passwordResetRequestHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var request passwordResetRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "이메일을 확인해주세요."})
		return
	}

	email := strings.ToLower(strings.TrimSpace(request.Email))
	if !isValidPasswordResetEmail(email) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "이메일 형식을 확인해주세요."})
		return
	}

	if err := requestPocketBasePasswordReset(r.Context(), email); err != nil {
		writeJSON(
			w,
			statusCodeForError(err, http.StatusBadGateway),
			map[string]string{"error": "비밀번호 재설정 메일을 보내지 못했습니다. 잠시 후 다시 시도해주세요."},
		)
		return
	}

	// Keep the response identical whether the email exists or not.
	writeJSON(w, http.StatusOK, map[string]string{"message": passwordResetRequestMessage})
}

func passwordResetConfirmHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var request passwordResetConfirmRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "요청 내용을 확인해주세요."})
		return
	}

	request.Token = strings.TrimSpace(request.Token)
	if request.Token == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "비밀번호 재설정 링크가 올바르지 않습니다."})
		return
	}
	if len(request.Password) < 8 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "비밀번호는 8자 이상 입력해주세요."})
		return
	}
	if request.Password != request.PasswordConfirm {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "비밀번호가 서로 일치하지 않습니다."})
		return
	}

	if err := confirmPocketBasePasswordReset(r.Context(), request); err != nil {
		writeJSON(
			w,
			statusCodeForError(err, http.StatusBadRequest),
			map[string]string{"error": "재설정 링크가 만료되었거나 이미 사용되었습니다. 메일을 다시 요청해주세요."},
		)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요."})
}

func isValidPasswordResetEmail(value string) bool {
	address, err := mail.ParseAddress(value)
	return err == nil && strings.EqualFold(address.Address, value)
}
