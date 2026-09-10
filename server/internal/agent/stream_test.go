package agent

import (
	"context"
	"strings"
	"testing"
)

// streamingMock 实现 StreamingClient：按 zone 记录 emit 的事件并回放内容。
type streamingMock struct {
	scriptClient
}

func (m *streamingMock) ChatStream(ctx context.Context, req ChatRequest, emit StreamCallback) (ChatResponse, error) {
	resp := m.replies[0]
	m.replies = m.replies[1:]
	// 模拟逐段产出：reasoning 先行，answer 分两段
	emit("reasoning", "先判断意图。")
	emit("answer", "你")
	emit("answer", "好")
	_ = resp
	return ChatResponse{Content: "你好", Reasoning: "先判断意图。"}, nil
}

func TestRunStreamsEvents(t *testing.T) {
	events := make([]string, 0, 4)
	client := &streamingMock{scriptClient{replies: []ChatResponse{{}}}}
	agent := &Agent{LLM: client, Model: "qwen-test"}
	result, err := agent.Run(context.Background(), RunRequest{
		Mode: ModeChat, SystemPrompt: "p", UserMessage: "你好", OnStream: func(kind, text string) {
			events = append(events, kind+":"+text)
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Answer != "你好" {
		t.Fatalf("answer %q", result.Answer)
	}
	joined := strings.Join(events, "|")
	if !strings.Contains(joined, "reasoning:先判断意图。") || !strings.Contains(joined, "answer:你") || !strings.Contains(joined, "answer:好") {
		t.Fatalf("events missing: %v", events)
	}
}

func TestStreamRouterSplitsZones(t *testing.T) {
	router := newStreamRouter(nil)
	// 标签跨 chunk："<th" + "ink>" 分两段喂入
	router.feed("<th")
	router.feed("ink>内部思考")
	router.feed("</think>可见回答<tool_call>{\"n\":1}</tool_call>")
	router.feed("收尾")
	router.flush()
	if router.reasoningThink.String() != "内部思考" {
		t.Fatalf("reasoning wrong: %q", router.reasoningThink.String())
	}
	got := router.answer.String()
	if got != "可见回答收尾" {
		t.Fatalf("answer wrong: %q", got)
	}
}
