package face

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestEnrollSendsDataURLAndPersonID(t *testing.T) {
	var gotPerson string
	var gotImage string
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/enroll" {
			http.NotFound(w, r)
			return
		}
		var payload struct {
			PersonID string `json:"person_id"`
			Image    string `json:"image"`
		}
		_ = json.NewDecoder(r.Body).Decode(&payload)
		gotPerson = payload.PersonID
		gotImage = payload.Image
		_, _ = w.Write([]byte(`{"ok":true,"person_id":"elder-7","faces":1}`))
	}))
	defer server.Close()

	client := New(server.URL)
	// 客户端必须接受自签证书：New 内部跳过校验，这里额外确认传输层生效。
	if client.hc.Transport.(*http.Transport).TLSClientConfig == nil ||
		!client.hc.Transport.(*http.Transport).TLSClientConfig.InsecureSkipVerify {
		t.Fatal("client must skip TLS verification for self-signed cert")
	}
	if server.TLS == nil {
		t.Fatal("test server should use TLS")
	}
	if err := client.Enroll(context.Background(), "elder-7", []byte("jpeg-bytes")); err != nil {
		t.Fatal(err)
	}
	if gotPerson != "elder-7" {
		t.Fatalf("person_id = %q", gotPerson)
	}
	if !strings.HasPrefix(gotImage, "data:image/jpeg;base64,") {
		t.Fatalf("image must be wrapped as data URL, got %q", gotImage[:40])
	}
}

func TestRecognizeParsesFacesAndEmotion(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"ok":true,"faces":[{"person_id":"elder-3","known":true,"similarity":0.71,` +
			`"bbox":[10.0,20.0,110.0,140.0],"emotion":{"label":"happy","score":0.93}},` +
			`{"person_id":null,"known":false,"similarity":0.2,"bbox":[1,2,3,4]}]}`))
	}))
	defer server.Close()

	faces, err := New(server.URL).Recognize(context.Background(), []byte("jpeg"))
	if err != nil {
		t.Fatal(err)
	}
	if len(faces) != 2 {
		t.Fatalf("faces = %d", len(faces))
	}
	first := faces[0]
	if !first.Known || first.PersonID == nil || *first.PersonID != "elder-3" || first.Similarity != 0.71 {
		t.Fatalf("first face = %+v", first)
	}
	if len(first.BBox) != 4 || first.BBox[0] != 10 || first.Emotion == nil || first.Emotion.Label != "happy" {
		t.Fatalf("first face detail = %+v", first)
	}
	if faces[1].Known || faces[1].PersonID != nil {
		t.Fatalf("unknown face = %+v", faces[1])
	}
}

func TestBehaviorReturnsDescription(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"ok":true,"behavior":"老人正沿走廊缓慢行走","people":[],"model":"JoyAI"}`))
	}))
	defer server.Close()

	result, err := New(server.URL).Behavior(context.Background(), []byte("jpeg"))
	if err != nil {
		t.Fatal(err)
	}
	if !result.OK || result.Behavior == "" {
		t.Fatalf("behavior = %+v", result)
	}
}

func TestHealth(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"ok":true,"service":"face-identity-emotion","enrolled_people":2,"match_threshold":0.45,"device":"cuda"}`))
	}))
	defer server.Close()

	ok, err := New(server.URL).Health(context.Background())
	if err != nil || !ok {
		t.Fatalf("health = %v, %v", ok, err)
	}
}
