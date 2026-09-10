package service

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The fake MCP server speaks JSON-RPC over the streamable HTTP transport and
// answers initialize/tools/list/tools/call; tool results come back framed as
// SSE data lines to exercise both response shapes.
func TestMCPServerBridgeFlow(t *testing.T) {
	toolCalled := false
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		var envelope struct {
			ID     interface{}    `json:"id"`
			Method string         `json:"method"`
			Params map[string]any `json:"params"`
		}
		_ = json.NewDecoder(r.Body).Decode(&envelope)
		w.Header().Set("Mcp-Session-Id", "session-42")
		respond := func(result map[string]any) {
			w.Header().Set("Content-Type", "text/event-stream")
			encoded, _ := json.Marshal(map[string]any{
				"jsonrpc": "2.0", "id": envelope.ID, "result": result,
			})
			_, _ = w.Write([]byte("event: message\ndata: " + string(encoded) + "\n\n"))
		}
		switch envelope.Method {
		case "initialize":
			respond(map[string]any{
				"serverInfo": map[string]any{"name": "fake-mcp", "version": "0.1"},
			})
		case "tools/list":
			respond(map[string]any{
				"tools": []map[string]any{{
					"name":        "echo",
					"description": "回显输入",
					"inputSchema": map[string]any{"type": "object", "properties": map[string]any{}},
				}},
			})
		case "tools/call":
			toolCalled = true
			name := envelope.Params["name"].(string)
			if name != "echo" {
				t.Errorf("unexpected tool %q", name)
			}
			respond(map[string]any{
				"content": []map[string]any{{"type": "text", "text": `{"echo": "ok"}`}},
			})
		default:
			respond(map[string]any{})
		}
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	ctx := context.Background()
	conn, err := dialMCPServer(ctx, server.URL, "")
	if err != nil {
		t.Fatal(err)
	}
	if conn.sessionID != "session-42" {
		t.Fatalf("session id not captured: %q", conn.sessionID)
	}
	tools, err := listMCPTools(ctx, conn)
	if err != nil || len(tools) != 1 || tools[0].Name != "echo" {
		t.Fatalf("tools/list failed: %+v err=%v", tools, err)
	}
	output, err := callMCPTool(ctx, conn, "echo", `{"text": "hi"}`)
	if err != nil || !strings.Contains(output, "ok") {
		t.Fatalf("tools/call failed: %q err=%v", output, err)
	}
	if !toolCalled {
		t.Fatal("server never received tools/call")
	}
}

func TestMCPToolPrefixSanitizesNames(t *testing.T) {
	prefix := mcpToolPrefix(7, "北京站点 Server")
	if !strings.HasPrefix(prefix, "mcp_") || !strings.HasSuffix(prefix, "_") {
		t.Fatalf("bad prefix: %q", prefix)
	}
	if strings.ContainsAny(prefix, " ") {
		t.Fatalf("prefix must not contain spaces: %q", prefix)
	}
}
