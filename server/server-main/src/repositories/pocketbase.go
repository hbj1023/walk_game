package repositories

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const usersCollection = "users"

var pocketBaseHTTPClient = &http.Client{
	Timeout: 10 * time.Second,
}

type ListResponse[T any] struct {
	Page       int `json:"page"`
	PerPage    int `json:"perPage"`
	TotalItems int `json:"totalItems"`
	TotalPages int `json:"totalPages"`
	Items      []T `json:"items"`
}

type StatusError struct {
	status  int
	message string
}

func (e StatusError) Error() string {
	return e.message
}

func (e StatusError) StatusCode() int {
	return e.status
}

func pocketBaseURL() string {
	if url := strings.TrimSpace(os.Getenv("POCKETBASE_URL")); url != "" {
		return strings.TrimRight(url, "/")
	}
	return "http://localhost:8090"
}

func pocketBaseCollectionURL(collection string) string {
	return fmt.Sprintf("%s/api/collections/%s/records", pocketBaseURL(), collection)
}

func pocketBaseRecordURL(collection string, id string) string {
	return fmt.Sprintf("%s/api/collections/%s/records/%s", pocketBaseURL(), collection, id)
}

func pocketBaseRequest(
	ctx context.Context,
	method string,
	url string,
	authToken string,
	body any,
) (*http.Response, error) {
	var bodyReader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		bodyReader = bytes.NewReader(data)
	}

	req, err := http.NewRequestWithContext(ctx, method, url, bodyReader)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	if authToken != "" {
		req.Header.Set("Authorization", "Bearer "+authToken)
	}

	resp, err := pocketBaseHTTPClient.Do(req)
	if err != nil {
		return nil, StatusError{
			status:  http.StatusInternalServerError,
			message: fmt.Sprintf("PocketBase 요청 실패: %v", err),
		}
	}

	return resp, nil
}

func mapPocketBaseError(resp *http.Response, fallback string) error {
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return errors.New(fallback)
	}
	if resp.StatusCode >= http.StatusInternalServerError {
		log.Printf(
			"pocketbase error: fallback=%q status=%d body=%s",
			fallback,
			resp.StatusCode,
			strings.TrimSpace(string(body)),
		)
	}

	type pocketBaseErrorResponse struct {
		Message string `json:"message"`
	}
	var pbErr pocketBaseErrorResponse
	if err := json.Unmarshal(body, &pbErr); err == nil && pbErr.Message != "" {
		status := http.StatusInternalServerError
		if resp.StatusCode >= 400 && resp.StatusCode < 500 {
			status = resp.StatusCode
		}
		return StatusError{status: status, message: pbErr.Message}
	}

	status := http.StatusInternalServerError
	if resp.StatusCode >= 400 && resp.StatusCode < 500 {
		status = resp.StatusCode
	}
	return StatusError{status: status, message: fallback}
}
