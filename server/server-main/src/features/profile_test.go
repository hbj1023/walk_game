package features

import (
	"mime/multipart"
	"net/textproto"
	"testing"
)

func TestBuildProfileImageSourcePriority(t *testing.T) {
	record := map[string]any{
		"id":                   "user123",
		"avatar":               "avatar.png",
		"profile_image_source": "emote",
		"expand": map[string]any{
			"profile_emote": map[string]any{
				"id":        "emote123",
				"name":      "Happy",
				"asset_key": "emote_happy",
				"image_url": "assets/images/profile/emote_happy.png",
			},
		},
	}

	image := buildProfileImage(record)
	if image["source"] != "emote" {
		t.Fatalf("source = %v, want emote", image["source"])
	}
	if image["asset_key"] != "emote_happy" {
		t.Fatalf("asset_key = %v, want emote_happy", image["asset_key"])
	}
}

func TestIsAllowedProfileImage(t *testing.T) {
	if !isAllowedProfileImage((&multipartFileHeader{filename: "profile.png", contentType: "image/png"}).FileHeader()) {
		t.Fatal("png should be allowed")
	}
	if isAllowedProfileImage((&multipartFileHeader{filename: "profile.exe", contentType: "application/octet-stream"}).FileHeader()) {
		t.Fatal("exe should not be allowed")
	}
}

type multipartFileHeader struct {
	filename    string
	contentType string
}

func (h *multipartFileHeader) FileHeader() *multipart.FileHeader {
	header := make(textproto.MIMEHeader)
	header.Set("Content-Type", h.contentType)
	return &multipart.FileHeader{
		Filename: h.filename,
		Header:   header,
	}
}
