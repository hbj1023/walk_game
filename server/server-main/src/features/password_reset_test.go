package features

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPasswordResetRequestHandlerRejectsInvalidRequests(t *testing.T) {
	tests := []struct {
		name       string
		method     string
		body       string
		statusCode int
	}{
		{name: "method", method: http.MethodGet, body: "", statusCode: http.StatusMethodNotAllowed},
		{name: "body", method: http.MethodPost, body: "{", statusCode: http.StatusBadRequest},
		{name: "email", method: http.MethodPost, body: `{"email":"not-an-email"}`, statusCode: http.StatusBadRequest},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(test.method, "/password-reset/request", strings.NewReader(test.body))
			response := httptest.NewRecorder()

			passwordResetRequestHandler(response, request)

			if response.Code != test.statusCode {
				t.Fatalf("expected status %d, got %d", test.statusCode, response.Code)
			}
		})
	}
}

func TestPasswordResetRequestHandlerUsesGenericSuccessMessage(t *testing.T) {
	pocketBase := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/collections/users/request-password-reset" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		var payload map[string]string
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if payload["email"] != "player@example.com" {
			t.Fatalf("unexpected email: %q", payload["email"])
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer pocketBase.Close()
	t.Setenv("POCKETBASE_URL", pocketBase.URL)

	request := httptest.NewRequest(
		http.MethodPost,
		"/password-reset/request",
		strings.NewReader(`{"email":"Player@Example.com"}`),
	)
	response := httptest.NewRecorder()

	passwordResetRequestHandler(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), passwordResetRequestMessage) {
		t.Fatalf("expected generic message, got %s", response.Body.String())
	}
}

func TestPasswordResetRequestHandlerHidesUnknownEmail(t *testing.T) {
	pocketBase := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"data":{},"message":"An error occurred while loading the submitted data.","status":400}`))
	}))
	defer pocketBase.Close()
	t.Setenv("POCKETBASE_URL", pocketBase.URL)

	request := httptest.NewRequest(
		http.MethodPost,
		"/api/password-reset/request",
		strings.NewReader(`{"email":"unknown@example.com"}`),
	)
	response := httptest.NewRecorder()
	mux := http.NewServeMux()
	RegisterRoutes(mux)

	mux.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), passwordResetRequestMessage) {
		t.Fatalf("expected generic message, got %s", response.Body.String())
	}
}

func TestPasswordResetRequestHandlerKeepsUpstreamFailure(t *testing.T) {
	pocketBase := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer pocketBase.Close()
	t.Setenv("POCKETBASE_URL", pocketBase.URL)

	request := httptest.NewRequest(
		http.MethodPost,
		"/api/password-reset/request",
		strings.NewReader(`{"email":"player@example.com"}`),
	)
	response := httptest.NewRecorder()

	passwordResetRequestHandler(response, request)

	if response.Code != http.StatusBadGateway {
		t.Fatalf("expected status 502, got %d: %s", response.Code, response.Body.String())
	}
}

func TestPasswordResetConfirmHandlerRejectsInvalidRequests(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		statusCode int
	}{
		{name: "body", body: "{", statusCode: http.StatusBadRequest},
		{name: "token", body: `{"password":"password1","passwordConfirm":"password1"}`, statusCode: http.StatusBadRequest},
		{name: "short password", body: `{"token":"token","password":"short","passwordConfirm":"short"}`, statusCode: http.StatusBadRequest},
		{name: "password mismatch", body: `{"token":"token","password":"password1","passwordConfirm":"password2"}`, statusCode: http.StatusBadRequest},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(
				http.MethodPost,
				"/password-reset/confirm",
				strings.NewReader(test.body),
			)
			response := httptest.NewRecorder()

			passwordResetConfirmHandler(response, request)

			if response.Code != test.statusCode {
				t.Fatalf("expected status %d, got %d", test.statusCode, response.Code)
			}
		})
	}
}

func TestPasswordResetConfirmHandlerForwardsTokenAndPasswords(t *testing.T) {
	pocketBase := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/collections/users/confirm-password-reset" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		var payload map[string]string
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if payload["token"] != "reset-token" {
			t.Fatalf("unexpected token: %q", payload["token"])
		}
		if payload["password"] != "new-password" ||
			payload["passwordConfirm"] != "new-password" {
			t.Fatalf("unexpected passwords: %#v", payload)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer pocketBase.Close()
	t.Setenv("POCKETBASE_URL", pocketBase.URL)

	request := httptest.NewRequest(
		http.MethodPost,
		"/password-reset/confirm",
		strings.NewReader(
			`{"token":"reset-token","password":"new-password","passwordConfirm":"new-password"}`,
		),
	)
	response := httptest.NewRecorder()

	passwordResetConfirmHandler(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "비밀번호가 변경되었습니다.") {
		t.Fatalf("expected success message, got %s", response.Body.String())
	}
}
