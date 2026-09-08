// Package agent implements the server-side conversational agent loop for the
// Kangxiaoban AI gateway: prompt layering, tool calling over OpenAI-compatible
// providers (with a hermes-style text fallback), bounded reasoning turns,
// context budgeting and a per-answer execution trace for the client UI.
//
// The design intentionally keeps the core narrow: capabilities arrive as tools
// (native institutional data tools, Dify retrieval, MCP bridges), never as new
// loop surface.
package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// Mode selects how much capability the agent exposes for one exchange.
type Mode string

const (
	// ModeChat is ordinary conversation: no institutional data tools, only the
	// knowledge-base search tool so the model can still consult the manual.
	ModeChat Mode = "chat"
	// ModeWork is the workbench assistant: full read-only institutional tools.
	ModeWork Mode = "work"
)

// NormalizeMode coerces arbitrary client input into a supported mode.
func NormalizeMode(value string) Mode {
	switch strings.TrimSpace(value) {
	case string(ModeWork):
		return ModeWork
	default:
		return ModeChat
	}
}

// ToolFunc executes one tool invocation. args is the raw JSON arguments string
// produced by the model. Tool failures are reported to the model as result
// text (the loop keeps running); only context cancellation aborts.
type ToolFunc func(ctx context.Context, args string) (string, error)

// ToolDefinition is one tool exposed to the model. ParametersJSON is the
// OpenAI JSON-schema object for the "parameters" field.
type ToolDefinition struct {
	Name           string
	Description    string
	ParametersJSON json.RawMessage
	Handler        ToolFunc
}

// OpenAITool renders the definition in OpenAI /v1/chat/completions tool format.
func (t *ToolDefinition) OpenAITool() map[string]interface{} {
	parameters := map[string]interface{}{"type": "object", "properties": map[string]interface{}{}}
	if len(t.ParametersJSON) > 0 {
		_ = json.Unmarshal(t.ParametersJSON, &parameters)
	}
	return map[string]interface{}{
		"type": "function",
		"function": map[string]interface{}{
			"name":        t.Name,
			"description": t.Description,
			"parameters":  parameters,
		},
	}
}

// ToolInvocation is one tool call requested by the model. Native marks calls
// recovered from the provider's tool_calls field (replies go back with
// role="tool"); non-native calls were parsed out of the message content
// (replies go back wrapped in a user-role tool_response block).
type ToolInvocation struct {
	ID      string `json:"id,omitempty"`
	Name    string `json:"name"`
	Args    string `json:"args"`
	Preview string `json:"preview,omitempty"`
	Native  bool   `json:"-"`
}

// StepType labels one entry of the execution trace shown in the client UI.
type StepType string

const (
	StepReasoning  StepType = "reasoning"
	StepToolCall   StepType = "tool_call"
	StepToolResult StepType = "tool_result"
	StepRetrieval  StepType = "retrieval"
	StepNotice     StepType = "notice"
)

// Step is one observable agent action. Summaries are size-bounded so the trace
// stays renderable; the full answer lives on the message itself.
type Step struct {
	Type        StepType `json:"type"`
	Title       string   `json:"title,omitempty"`
	Detail      string   `json:"detail,omitempty"`
	Tool        string   `json:"tool,omitempty"`
	ArgsPreview string   `json:"args_preview,omitempty"`
	Result      string   `json:"result,omitempty"`
	OK          bool     `json:"ok"`
	DurationMS  int64    `json:"duration_ms"`
}

// Turn is one prior conversation message replayed as agent context.
type Turn struct {
	Role    string `json:"role"` // "user" | "assistant"
	Content string `json:"content"`
}

// RunRequest is one agent invocation.
type RunRequest struct {
	Mode          Mode
	SystemPrompt  string
	Skills        []string // rendered instruction fragments appended to the prompt
	History       []Turn
	UserMessage   string
	Tools         []*ToolDefinition
	MaxTurns      int
	Temperature   float64
	ContextWindow int    // model context window used for history budgeting
	Summary       string // rolling summary of previously compacted history
}

// RunResult is the completed agent answer plus everything the UI needs to
// render the thinking process.
type RunResult struct {
	Answer           string
	Reasoning        string
	Steps            []Step
	Turns            int
	ToolCallCount    int
	PromptTokens     int64
	CompletionTokens int64
	TotalTokens      int64
	Model            string
}

const (
	defaultMaxTurns = 8
	// stepLimit bounds the persisted trace so one runaway conversation cannot
	// grow the message row indefinitely.
	stepLimit = 40
)

func (r *RunRequest) maxTurns() int {
	if r.MaxTurns > 0 {
		return r.MaxTurns
	}
	return defaultMaxTurns
}

// buildSystemPrompt layers the role prompt (stable), skill fragments and the
// tool-protocol conventions into one system message.
func (r *RunRequest) buildSystemPrompt(withTools bool) string {
	var b strings.Builder
	b.WriteString(strings.TrimSpace(r.SystemPrompt))
	b.WriteString("\n\n你是康小伴平台的智能助理。回答使用简体中文，条理清晰，" +
		"涉及健康与护理的内容仅作参考提示，不做诊断结论，紧急情况提醒联系值班人员。")
	for _, skill := range r.Skills {
		if trimmed := strings.TrimSpace(skill); trimmed != "" {
			b.WriteString("\n\n【技能指引】\n" + trimmed)
		}
	}
	if withTools {
		b.WriteString("\n\n【工具使用规范】\n" +
			"- 需要机构实时数据时必须调用工具查询，禁止编造长者、任务、告警等数据。\n" +
			"- 一次尽量只调用完成当前步骤所需的工具，依据结果决定下一步。\n" +
			"- 工具返回错误时可以直接告知用户原因，不要重复尝试超过两次。\n" +
			"- 最终回答先给结论，再给关键数据依据，保持简洁。")
	}
	if r.Summary != "" {
		b.WriteString("\n\n【更早对话摘要】\n" + r.Summary)
	}
	return b.String()
}

// ChatMessage is one wire-format message sent to the provider.
type ChatMessage struct {
	Role       string           `json:"role"`
	Content    string           `json:"content"`
	ToolCalls  []ToolInvocation `json:"-"`
	ToolCallID string           `json:"-"`
}

// ChatRequest is one provider completion request inside the loop.
type ChatRequest struct {
	Model       string
	Messages    []ChatMessage
	Tools       []*ToolDefinition
	Temperature float64
}

// ChatResponse is one normalized provider reply. ToolCalls are populated from
// the native tool_calls field or recovered from hermes-style text protocol.
type ChatResponse struct {
	Content          string
	Reasoning        string
	ToolCalls        []ToolInvocation
	PromptTokens     int64
	CompletionTokens int64
	TotalTokens      int64
	FinishReason     string
}

// LLMClient performs one completion. Implementations must be safe for
// sequential use inside the loop and must normalize provider quirks.
type LLMClient interface {
	ChatOnce(ctx context.Context, req ChatRequest) (ChatResponse, error)
}

// Agent runs the bounded tool-calling loop on top of an LLMClient.
type Agent struct {
	LLM   LLMClient
	Model string
}

// Run executes the agent loop and returns the final answer with its trace.
func (a *Agent) Run(ctx context.Context, req RunRequest) (*RunResult, error) {
	if a.LLM == nil {
		return nil, fmt.Errorf("agent llm client is required")
	}
	if strings.TrimSpace(req.UserMessage) == "" {
		return nil, fmt.Errorf("user message is required")
	}
	withTools := len(req.Tools) > 0
	systemPrompt := req.buildSystemPrompt(withTools)

	messages := make([]ChatMessage, 0, len(req.History)+2)
	messages = append(messages, ChatMessage{Role: "system", Content: systemPrompt})
	for _, turn := range req.History {
		role := strings.ToLower(strings.TrimSpace(turn.Role))
		if role != "user" && role != "assistant" {
			continue
		}
		if strings.TrimSpace(turn.Content) == "" {
			continue
		}
		messages = append(messages, ChatMessage{Role: role, Content: turn.Content})
	}
	messages = append(messages, ChatMessage{Role: "user", Content: req.UserMessage})

	result := &RunResult{Model: a.Model, Steps: make([]Step, 0, 8)}
	for turn := 0; turn < req.maxTurns(); turn++ {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		result.Turns = turn + 1
		resp, err := a.LLM.ChatOnce(ctx, ChatRequest{
			Model:       a.Model,
			Messages:    messages,
			Tools:       req.Tools,
			Temperature: req.Temperature,
		})
		if err != nil {
			return nil, err
		}
		result.PromptTokens += resp.PromptTokens
		result.CompletionTokens += resp.CompletionTokens
		result.TotalTokens += resp.TotalTokens
		// Defense in depth: recover hermes-style tool calls from plain
		// content even if the client layer did not strip them already.
		if len(resp.ToolCalls) == 0 && hasTextToolCall(resp.Content) {
			if calls, remainder := ParseTextToolCalls(resp.Content); len(calls) > 0 {
				resp.Content = strings.TrimSpace(remainder)
				resp.ToolCalls = calls
			}
		}
		if resp.Reasoning != "" {
			result.Reasoning = appendReasoning(result.Reasoning, resp.Reasoning)
			result.Steps = append(result.Steps, Step{
				Type: StepReasoning, Title: "思考",
				Detail: truncateRunes(resp.Reasoning, 600), OK: true,
			})
		}
		if len(resp.ToolCalls) > 0 {
			assistant := ChatMessage{Role: "assistant", Content: resp.Content, ToolCalls: resp.ToolCalls}
			messages = append(messages, assistant)
			results := make([]string, 0, len(resp.ToolCalls))
			for _, call := range resp.ToolCalls {
				result.ToolCallCount++
				tool := findTool(req.Tools, call.Name)
				startedAt := time.Now()
				step := Step{Type: StepToolCall, Title: "调用工具 " + call.Name, Tool: call.Name, ArgsPreview: truncateRunes(call.Args, 200)}
				var output string
				if tool == nil {
					step.Result = "工具不存在"
					step.OK = false
					output = "工具不存在: " + call.Name
				} else {
					text, toolErr := tool.Handler(ctx, call.Args)
					step.DurationMS = time.Since(startedAt).Milliseconds()
					if toolErr != nil {
						step.Result = "执行失败: " + truncateRunes(toolErr.Error(), 200)
						step.OK = false
						output = "工具执行失败: " + toolErr.Error()
					} else {
						step.Result = truncateRunes(text, 400)
						step.OK = true
						output = text
					}
				}
				results = append(results, toolResponseLine(call.Name, output))
				result.Steps = append(result.Steps, step)
				if call.Native {
					messages = append(messages, ChatMessage{
						Role: "tool", ToolCallID: call.ID, Content: output,
					})
				}
			}
			if !resp.ToolCalls[0].Native {
				// Hermes-style text protocol: feed results back as a user-role
				// block so any chat template can render them.
				messages = append(messages, ChatMessage{Role: "user",
					Content: "<tool_response>\n" + strings.Join(results, "\n") + "\n</tool_response>\n请继续：依据以上结果决定下一步，或直接给出最终回答。"})
			}
			continue
		}
		if strings.TrimSpace(resp.Content) != "" {
			result.Answer = strings.TrimSpace(resp.Content)
			result.Steps = append(result.Steps, Step{Type: StepNotice, Title: "生成回答", Detail: truncateRunes(result.Answer, 200), OK: true})
			result.appendStepLimit()
			return result, nil
		}
		// Empty reply: nudge the model once rather than ending silently.
		messages = append(messages, ChatMessage{Role: "user",
			Content: "请基于已有信息给出最终回答；若信息不足，请说明还缺什么。"})
	}
	result.Answer = "这个问题我暂时没有完成完整的查询流程，请稍后重试或换一种问法。"
	result.Steps = append(result.Steps, Step{Type: StepNotice, Title: "达到推理轮次上限", Detail: "已停止继续调用工具", OK: false})
	result.appendStepLimit()
	return result, nil
}

func (r *RunResult) appendStepLimit() {
	if len(r.Steps) > stepLimit {
		r.Steps = r.Steps[:stepLimit]
	}
}

func findTool(tools []*ToolDefinition, name string) *ToolDefinition {
	for _, tool := range tools {
		if tool.Name == name {
			return tool
		}
	}
	return nil
}

// toolResponseLine renders one tool result line for the hermes-style
// user-role <tool_response> block.
func toolResponseLine(name, output string) string {
	encoded, err := json.Marshal(output)
	if err != nil {
		return fmt.Sprintf("{\"tool\": %q, \"error\": \"result encode failed\"}", name)
	}
	return fmt.Sprintf("{\"tool\": %q, \"result\": %s}", name, string(encoded))
}

func appendReasoning(existing, addition string) string {
	if existing == "" {
		return addition
	}
	return existing + "\n" + addition
}

// truncateRunes bounds display strings by runes so Chinese text stays intact.
func truncateRunes(text string, limit int) string {
	text = strings.TrimSpace(text)
	runes := []rune(text)
	if len(runes) <= limit {
		return text
	}
	return string(runes[:limit]) + "…"
}
