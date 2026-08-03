package features

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPublicAccountDeletionRequestHandlerCreatesPrivateReviewRecord(t *testing.T) {
	pocketBase := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if r.URL.Path != "/api/collections/account_deletion_requests/records" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if authorization := r.Header.Get("Authorization"); authorization != "" {
			t.Fatalf("public request must not include auth token: %q", authorization)
		}

		var payload map[string]string
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if payload["email"] != "player@example.com" || payload["reason"] != "게임을 더 이상 이용하지 않습니다." {
			t.Fatalf("unexpected payload: %#v", payload)
		}
		if payload["status"] != "pending" || payload["source"] != "web" {
			t.Fatalf("unexpected review fields: %#v", payload)
		}
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"id":"request-id"}`))
	}))
	defer pocketBase.Close()
	t.Setenv("POCKETBASE_URL", pocketBase.URL)

	request := httptest.NewRequest(
		http.MethodPost,
		"/api/account-deletion-requests",
		strings.NewReader(`{"email":"Player@Example.com","reason":" 게임을 더 이상 이용하지 않습니다. "}`),
	)
	response := httptest.NewRecorder()
	mux := http.NewServeMux()
	RegisterRoutes(mux)

	mux.ServeHTTP(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d: %s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), publicAccountDeletionMessage) {
		t.Fatalf("expected public success message, got %s", response.Body.String())
	}
}

func TestPublicAccountDeletionRequestHandlerRejectsInvalidRequests(t *testing.T) {
	tests := []struct {
		name       string
		method     string
		body       string
		statusCode int
	}{
		{name: "method", method: http.MethodGet, statusCode: http.StatusMethodNotAllowed},
		{name: "body", method: http.MethodPost, body: "{", statusCode: http.StatusBadRequest},
		{name: "email", method: http.MethodPost, body: `{"email":"not-an-email"}`, statusCode: http.StatusBadRequest},
		{name: "reason", method: http.MethodPost, body: `{"email":"player@example.com","reason":"` + strings.Repeat("가", 1001) + `"}`, statusCode: http.StatusBadRequest},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(test.method, "/api/account-deletion-requests", strings.NewReader(test.body))
			response := httptest.NewRecorder()

			publicAccountDeletionRequestHandler(response, request)

			if response.Code != test.statusCode {
				t.Fatalf("expected status %d, got %d: %s", test.statusCode, response.Code, response.Body.String())
			}
		})
	}
}

func TestPublicAccountDeletionRequestHandlerDropsHoneypotSubmission(t *testing.T) {
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/account-deletion-requests",
		strings.NewReader(`{"email":"bot@example.com","website":"https://spam.example"}`),
	)
	response := httptest.NewRecorder()

	publicAccountDeletionRequestHandler(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d: %s", response.Code, response.Body.String())
	}
}
