package agent

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
)

// scriptClient replays scripted provider replies; it records every request so
// tests can assert the loop's message threading.
type scriptClient struct {
	replies  []ChatResponse
	err      error
	requests []ChatRequest
}

func (c *scriptClient) ChatOnce(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	c.requests = append(c.requests, req)
	if c.err != nil {
		return ChatResponse{}, c.err
	}
	resp := c.replies[0]
	c.replies = c.replies[1:]
	return resp, nil
}

func echoTool() *ToolDefinition {
	return &ToolDefinition{
		Name: "get_elder_count", Description: "count elders",
		ParametersJSON: json.RawMessage(`{"type":"object","properties":{}}`),
		Handler: func(ctx context.Context, args string) (string, error) {
			return `{"count": 32}`, nil
		},
	}
}

func TestRunTextProtocolLoop(t *testing.T) {
	client := &scriptClient{replies: []ChatResponse{
		{Content: "<tool_call>\n{\"name\": \"get_elder_count\", \"arguments\": {}}\n</tool_call>"},
		{Content: "目前院里一共有32位长者。"},
	}}
	agent := &Agent{LLM: client, Model: "qwen-test"}
	result, err := agent.Run(context.Background(), RunRequest{
		Mode: ModeWork, SystemPrompt: "你是助理", UserMessage: "院里多少人?", Tools: []*ToolDefinition{echoTool()},
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Answer != "目前院里一共有32位长者。" {
		t.Fatalf("unexpected answer: %q", result.Answer)
	}
	if result.ToolCallCount != 1 {
		t.Fatalf("expected 1 tool call, got %d", result.ToolCallCount)
	}
	// The follow-up request must thread the assistant tool call and the
	// user-role tool_response block.
	second := client.requests[1].Messages
	foundResponse := false
	for _, message := range second {
		if message.Role == "user" && strings.Contains(message.Content, "<tool_response>") && strings.Contains(message.Content, "32") {
			foundResponse = true
		}
	}
	if !foundResponse {
		t.Fatalf("tool_response not threaded: %+v", second)
	}
	if result.Steps[0].Type != StepToolCall || !result.Steps[0].OK {
		t.Fatalf("expected successful tool_call step, got %+v", result.Steps[0])
	}
}

func TestRunNativeToolCalls(t *testing.T) {
	client := &scriptClient{replies: []ChatResponse{
		{ToolCalls: []ToolInvocation{{ID: "call_1", Name: "get_elder_count", Args: "{}", Native: true}}},
		{Content: "32位。"},
	}}
	agent := &Agent{LLM: client, Model: "qwen-test"}
	result, err := agent.Run(context.Background(), RunRequest{
		Mode: ModeWork, SystemPrompt: "p", UserMessage: "人数", Tools: []*ToolDefinition{echoTool()},
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Answer == "" || result.ToolCallCount != 1 {
		t.Fatalf("unexpected result: %+v", result)
	}
	second := client.requests[1].Messages
	var sawToolRole bool
	for _, message := range second {
		if message.Role == "tool" && message.ToolCallID == "call_1" && strings.Contains(message.Content, "32") {
			sawToolRole = true
		}
	}
	if !sawToolRole {
		t.Fatalf("native tool message not threaded: %+v", second)
	}
}

func TestRunMaxTurnsGuard(t *testing.T) {
	replies := make([]ChatResponse, 0, 12)
	for i := 0; i < 12; i++ {
		replies = append(replies, ChatResponse{Content: "<tool_call>\n{\"name\": \"get_elder_count\", \"arguments\": {}}\n</tool_call>"})
	}
	client := &scriptClient{replies: replies}
	agent := &Agent{LLM: client, Model: "qwen-test"}
	result, err := agent.Run(context.Background(), RunRequest{
		Mode: ModeWork, SystemPrompt: "p", UserMessage: "loop", Tools: []*ToolDefinition{echoTool()}, MaxTurns: 3,
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(client.requests) != 3 {
		t.Fatalf("expected loop to stop at 3 turns, got %d", len(client.requests))
	}
	if result.Answer == "" {
		t.Fatal("guard should still produce a fallback answer")
	}
}

func TestRunFailsWithoutLLM(t *testing.T) {
	agent := &Agent{Model: "m"}
	if _, err := agent.Run(context.Background(), RunRequest{UserMessage: "hi"}); err == nil {
		t.Fatal("expected error without llm client")
	}
}

func TestParseTextToolCallsMultiple(t *testing.T) {
	content := "我先查一下。\n<tool_call>\n{\"name\": \"get_alerts\", \"arguments\": {\"status\": \"open\"}}\n</tool_call>\n中间的话\n<tool_call>\n{\"name\": \"get_elder_count\", \"arguments\": {}}\n</tool_call>"
	calls, remainder := ParseTextToolCalls(content)
	if len(calls) != 2 {
		t.Fatalf("expected 2 calls, got %d", len(calls))
	}
	if calls[0].Name != "get_alerts" || !strings.Contains(calls[0].Args, "open") {
		t.Fatalf("bad first call: %+v", calls[0])
	}
	if calls[1].Name != "get_elder_count" {
		t.Fatalf("bad second call: %+v", calls[1])
	}
	if !strings.Contains(remainder, "我先查一下") || !strings.Contains(remainder, "中间的话") {
		t.Fatalf("prose lost: %q", remainder)
	}
	if strings.Contains(remainder, "<tool_call>") {
		t.Fatalf("remainder should not keep parsed blocks: %q", remainder)
	}
}

func TestParseTextToolCallStringArguments(t *testing.T) {
	calls, _ := ParseTextToolCalls(`<tool_call>
{"name": "search_kb", "arguments": "{\"query\": \"跌倒\"}"}
</tool_call>`)
	if len(calls) != 1 || calls[0].Name != "search_kb" {
		t.Fatalf("unexpected: %+v", calls)
	}
	if !strings.Contains(calls[0].Args, "跌倒") {
		t.Fatalf("string arguments lost: %q", calls[0].Args)
	}
}

func TestBudgetContextTrimsOldest(t *testing.T) {
	history := make([]Turn, 0, 10)
	for i := 0; i < 10; i++ {
		history = append(history, Turn{Role: "user", Content: strings.Repeat("数据", 200)})
	}
	kept, dropped, droppedText := BudgetContext(history, "sys", "问", 4096)
	if len(dropped) == 0 || len(kept) == 0 {
		t.Fatalf("expected mixed trim, kept=%d dropped=%d", len(kept), len(dropped))
	}
	if dropped[0].Content != history[0].Content {
		t.Fatal("oldest turns must be dropped first")
	}
	if droppedText == "" {
		t.Fatal("dropped text should feed the summarizer")
	}
}

func TestBuildSystemPromptLayers(t *testing.T) {
	req := RunRequest{
		SystemPrompt: "角色提示", Skills: []string{"跌倒处置: 先保现场"},
		Summary: "此前讨论了张某的血压", UserMessage: "u",
		Tools: []*ToolDefinition{echoTool()},
	}
	prompt := req.buildSystemPrompt(true)
	for _, part := range []string{"角色提示", "跌倒处置", "此前讨论", "可用工具规范不可见"} {
		_ = part
	}
	if !strings.Contains(prompt, "角色提示") || !strings.Contains(prompt, "跌倒处置") ||
		!strings.Contains(prompt, "此前讨论") || !strings.Contains(prompt, "工具使用规范") {
		t.Fatalf("prompt layering incomplete: %q", prompt)
	}
}
