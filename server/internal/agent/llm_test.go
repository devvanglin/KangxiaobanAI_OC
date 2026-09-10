package agent

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The client must put the augmented system prompt (tool schemas embedded) into
// the actual wire body. Regression for the slice-header bug that dropped the
// system message from every request.
func TestOpenAIClientSendsSystemAndSchemas(t *testing.T) {
	var body map[string]interface{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}`))
	}))
	defer server.Close()

	client := &OpenAIClient{BaseURL: server.URL, NativeTools: false}
	resp, err := client.ChatOnce(context.Background(), ChatRequest{
		Model:    "qwen-test",
		Messages: []ChatMessage{{Role: "system", Content: "角色提示"}, {Role: "user", Content: "院里多少人？"}},
		Tools:    []*ToolDefinition{echoTool()},
	})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Content != "ok" {
		t.Fatalf("unexpected reply %q", resp.Content)
	}
	messages, ok := body["messages"].([]interface{})
	if !ok || len(messages) != 2 {
		t.Fatalf("messages wrong: %v", body["messages"])
	}
	first := messages[0].(map[string]interface{})
	if first["role"] != "system" {
		t.Fatalf("first message must be system: %v", first)
	}
	systemText, _ := first["content"].(string)
	for _, marker := range []string{"角色提示", "可用工具", "get_elder_count", "tool_call"} {
		if !strings.Contains(systemText, marker) {
			t.Fatalf("system prompt missing %q: %s", marker, systemText)
		}
	}
	if body["model"] != "qwen-test" {
		t.Fatalf("model missing: %v", body["model"])
	}
}
