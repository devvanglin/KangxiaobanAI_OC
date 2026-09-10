package agent

import (
	"context"
	"strings"
	"testing"
)

func TestParseThinkBlockWithAnswer(t *testing.T) {
	reasoning, remainder := ParseThinkBlock("<think>\n用户在打招呼，简单回应即可。\n</think>\n你好！有什么可以帮您？")
	if reasoning != "用户在打招呼，简单回应即可。" {
		t.Fatalf("reasoning wrong: %q", reasoning)
	}
	if remainder != "你好！有什么可以帮您？" {
		t.Fatalf("remainder wrong: %q", remainder)
	}
}

func TestParseThinkBlockUnclosed(t *testing.T) {
	reasoning, remainder := ParseThinkBlock("<think>\n只有思考没有收尾")
	if reasoning == "" || remainder != "" {
		t.Fatalf("unclosed think: %q / %q", reasoning, remainder)
	}
}

func TestParseThinkBlockAbsent(t *testing.T) {
	reasoning, remainder := ParseThinkBlock("普通回答")
	if reasoning != "" || remainder != "普通回答" {
		t.Fatalf("no-think handling wrong: %q / %q", reasoning, remainder)
	}
}

func TestRunExtractsThinkReasoning(t *testing.T) {
	client := &scriptClient{replies: []ChatResponse{
		{Content: "<think>\n用户在问候，无需工具，直接友好回应。\n</think>\n您好！有什么可以帮您？"},
	}}
	agent := &Agent{LLM: client, Model: "qwen-test"}
	result, err := agent.Run(context.Background(), RunRequest{
		Mode: ModeChat, SystemPrompt: "p", UserMessage: "你好",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Answer != "您好！有什么可以帮您？" {
		t.Fatalf("answer polluted by think block: %q", result.Answer)
	}
	if !strings.Contains(result.Reasoning, "无需工具") {
		t.Fatalf("reasoning not captured: %q", result.Reasoning)
	}
	if len(result.Steps) != 1 || result.Steps[0].Type != StepReasoning {
		t.Fatalf("expected one reasoning step: %+v", result.Steps)
	}
}

func TestRunSystemPromptIncludesThinkConvention(t *testing.T) {
	req := RunRequest{SystemPrompt: "角色", UserMessage: "u"}
	prompt := req.buildSystemPrompt(false)
	if !strings.Contains(prompt, "<think>") || !strings.Contains(prompt, "回答前先思考") {
		t.Fatalf("think convention missing: %q", prompt)
	}
}

// 模型偶尔把 <tool_call> 写进 <think> 块内部：思考里出现的工具请求仍然是
// 真实动作，必须提取执行，不能当作纯文本吞掉。
func TestRunRecoversToolCallInsideThink(t *testing.T) {
	client := &scriptClient{replies: []ChatResponse{
		{Content: "<think>\n需要查询在住长者名单。\n<tool_call>\n{\"name\": \"get_elder_count\", \"arguments\": {}}\n</tool_call>\n</think>"},
		{Content: "共32位。"},
	}}
	agent := &Agent{LLM: client, Model: "qwen-test"}
	result, err := agent.Run(context.Background(), RunRequest{
		Mode: ModeWork, SystemPrompt: "p", UserMessage: "人数", Tools: []*ToolDefinition{echoTool()},
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.ToolCallCount != 1 {
		t.Fatalf("tool call inside think must still execute, got %d", result.ToolCallCount)
	}
	if result.Answer != "共32位。" {
		t.Fatalf("unexpected answer: %q", result.Answer)
	}
	if strings.Contains(result.Reasoning, "<tool_call>") {
		t.Fatalf("reasoning should not keep the raw tool call: %q", result.Reasoning)
	}
}
