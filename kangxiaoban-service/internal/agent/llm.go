package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const defaultMaxCompletionTokens = 1024

// OpenAIClient talks to one OpenAI-compatible /v1/chat/completions endpoint
// (vLLM, new-api gateways and friends).
//
// Tool calling is prompt-based by default: many on-prem vLLM deployments run
// without --enable-auto-tool-choice and reject the OpenAI "tools" field, so
// tool schemas are rendered into the system prompt and the model answers with
// hermes-style <tool_call> blocks that ParseTextToolCalls recovers. When
// NativeTools is enabled the client sends the tools field as well, keeps
// native tool_calls, and falls back to prompt-embedded schemas after one
// tool-choice rejection. Text-protocol calls are parsed in every mode, which
// also covers the known vLLM bug class of unparsed tool calls leaking into
// message content.
type OpenAIClient struct {
	BaseURL     string
	APIKey      string
	NativeTools bool
	HTTP        *http.Client
	// toolsUnsupported memoizes a provider rejection of the tools field so
	// later turns skip the extra round trip.
	toolsUnsupported bool
}

// ChatOnce performs one completion request.
func (c *OpenAIClient) ChatOnce(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	if c.HTTP == nil {
		c.HTTP = &http.Client{} // deadlines come from the request context
	}
	resp, usedNative, err := c.do(ctx, req, true)
	if err != nil && c.NativeTools && !c.toolsUnsupported && isToolChoiceRejection(err) {
		c.toolsUnsupported = true
		return c.doPlain(ctx, req)
	}
	if err != nil {
		return ChatResponse{}, err
	}
	_ = usedNative
	return resp, nil
}

func (c *OpenAIClient) doPlain(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	resp, _, err := c.do(ctx, req, false)
	return resp, err
}

// buildBody assembles the OpenAI wire body for one completion. The augmented
// system prompt (tool schemas embedded) is prepended here, before body
// assembly — append() re-slices, so prepending after body["messages"] was
// assigned would silently drop the system message.
func (c *OpenAIClient) buildBody(req ChatRequest, useNative bool) map[string]interface{} {
	wireMessages := make([]map[string]interface{}, 0, len(req.Messages)+1)
	systemPrompt := ""
	for i, message := range req.Messages {
		if message.Role == "system" {
			// The system prompt carries the tool schemas in prompt-based mode.
			if i == 0 && !useNative && len(req.Tools) > 0 {
				systemPrompt = message.Content + "\n\n" + renderToolSchemas(req.Tools)
				continue
			}
		}
		entry := map[string]interface{}{"role": message.Role, "content": message.Content}
		if message.Role == "assistant" && len(message.ToolCalls) > 0 && message.ToolCalls[0].Native {
			calls := make([]map[string]interface{}, 0, len(message.ToolCalls))
			for _, call := range message.ToolCalls {
				calls = append(calls, map[string]interface{}{
					"id": call.ID, "type": "function",
					"function": map[string]interface{}{"name": call.Name, "arguments": call.Args},
				})
			}
			entry["tool_calls"] = calls
			if strings.TrimSpace(message.Content) != "" {
				entry["content"] = message.Content
			} else {
				entry["content"] = ""
			}
		}
		if message.Role == "tool" {
			entry["tool_call_id"] = message.ToolCallID
		}
		wireMessages = append(wireMessages, entry)
	}
	if systemPrompt != "" {
		wireMessages = append([]map[string]interface{}{{"role": "system", "content": systemPrompt}}, wireMessages...)
	}
	body := map[string]interface{}{
		"model":       req.Model,
		"messages":    wireMessages,
		"temperature": req.Temperature,
		"max_tokens":  defaultMaxCompletionTokens,
		"stream":      false,
	}
	if useNative {
		tools := make([]map[string]interface{}, 0, len(req.Tools))
		for _, tool := range req.Tools {
			tools = append(tools, tool.OpenAITool())
		}
		body["tools"] = tools
		body["tool_choice"] = "auto"
	}
	return body
}

func (c *OpenAIClient) do(ctx context.Context, req ChatRequest, allowNative bool) (ChatResponse, bool, error) {
	base := strings.TrimRight(strings.TrimSpace(c.BaseURL), "/")
	if base == "" {
		return ChatResponse{}, false, fmt.Errorf("model base url is empty")
	}
	useNative := allowNative && c.NativeTools && !c.toolsUnsupported && len(req.Tools) > 0

	body := c.buildBody(req, useNative)
	encoded, err := json.Marshal(body)
	if err != nil {
		return ChatResponse{}, false, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/v1/chat/completions", bytes.NewReader(encoded))
	if err != nil {
		return ChatResponse{}, false, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if c.APIKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+c.APIKey)
	}
	httpResp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return ChatResponse{}, useNative, err
	}
	defer httpResp.Body.Close()
	if httpResp.StatusCode < http.StatusOK || httpResp.StatusCode >= http.StatusMultipleChoices {
		preview := make([]byte, 400)
		n, _ := httpResp.Body.Read(preview)
		return ChatResponse{}, useNative, fmt.Errorf("provider HTTP %d: %s", httpResp.StatusCode, string(preview[:n]))
	}
	var out struct {
		Choices []struct {
			Message struct {
				Content          string `json:"content"`
				ReasoningContent string `json:"reasoning_content"`
				ToolCalls        []struct {
					ID       string `json:"id"`
					Function struct {
						Name      string          `json:"name"`
						Arguments json.RawMessage `json:"arguments"`
					} `json:"function"`
				} `json:"tool_calls"`
			} `json:"message"`
			FinishReason string `json:"finish_reason"`
		} `json:"choices"`
		Usage struct {
			PromptTokens     int64 `json:"prompt_tokens"`
			CompletionTokens int64 `json:"completion_tokens"`
			TotalTokens      int64 `json:"total_tokens"`
		} `json:"usage"`
		Model string `json:"model"`
	}
	if err := json.NewDecoder(httpResp.Body).Decode(&out); err != nil {
		return ChatResponse{}, useNative, err
	}
	if len(out.Choices) == 0 {
		return ChatResponse{}, useNative, fmt.Errorf("provider returned no choices")
	}
	choice := out.Choices[0]
	response := ChatResponse{
		Content:          strings.TrimSpace(choice.Message.Content),
		Reasoning:        strings.TrimSpace(choice.Message.ReasoningContent),
		FinishReason:     choice.FinishReason,
		PromptTokens:     out.Usage.PromptTokens,
		CompletionTokens: out.Usage.CompletionTokens,
		TotalTokens:      out.Usage.TotalTokens,
	}
	if response.TotalTokens <= 0 {
		response.TotalTokens = response.PromptTokens + response.CompletionTokens
	}
	// Prompt-based thinking: models instructed to reason in <think> blocks
	// return the block inside content; move it into Reasoning. A tool call
	// written inside the block still counts as an action.
	if strings.Contains(response.Content, "<think>") {
		think, remainder := ParseThinkBlock(response.Content)
		response.Reasoning = appendReasoning(response.Reasoning, think)
		response.Content = remainder
	}
	if len(response.ToolCalls) == 0 && hasTextToolCall(response.Reasoning) {
		if calls, cleaned := ParseTextToolCalls(response.Reasoning); len(calls) > 0 {
			response.Reasoning = strings.TrimSpace(cleaned)
			response.ToolCalls = append(response.ToolCalls, calls...)
		}
	}
	for _, call := range choice.Message.ToolCalls {
		response.ToolCalls = append(response.ToolCalls, ToolInvocation{
			ID: call.ID, Name: strings.TrimSpace(call.Function.Name),
			Args: normalizeToolArguments(call.Function.Arguments), Native: true,
		})
	}
	// Recover tool calls written into plain content (hermes protocol), for
	// prompt-based mode and for the unparsed-call bug class alike.
	if len(response.ToolCalls) == 0 || hasTextToolCall(response.Content) {
		calls, remainder := ParseTextToolCalls(response.Content)
		if len(calls) > 0 {
			response.Content = strings.TrimSpace(remainder)
			response.ToolCalls = append(response.ToolCalls, calls...)
		}
	}
	return response, useNative, nil
}

func isToolChoiceRejection(err error) bool {
	if err == nil {
		return false
	}
	text := err.Error()
	return strings.Contains(text, "tool choice requires") ||
		strings.Contains(text, "tool-call-parser") ||
		strings.Contains(text, "enable-auto-tool-choice")
}

// normalizeToolArguments flattens object-or-string argument payloads into the
// canonical JSON string form used by ToolInvocation.Args.
func normalizeToolArguments(raw json.RawMessage) string {
	trimmed := strings.TrimSpace(string(raw))
	if trimmed == "" {
		return "{}"
	}
	return trimmed
}

// renderToolSchemas writes the tool list into the system prompt in a compact,
// tokenizer-friendly hermes format.
func renderToolSchemas(tools []*ToolDefinition) string {
	var b strings.Builder
	b.WriteString("【可用工具】需要机构数据时，仅用如下格式调用（工具行外不得混入其他说明）：\n<tool_call>\n{\"name\": \"工具名\", \"arguments\": {参数}}\n</tool_call>\n")
	for _, tool := range tools {
		schema := "{}"
		if len(tool.ParametersJSON) > 0 {
			schema = string(tool.ParametersJSON)
		}
		b.WriteString(fmt.Sprintf("\n%s: %s\n参数schema: %s\n", tool.Name, tool.Description, schema))
	}
	b.WriteString("\n收到 <tool_response> 后继续；信息足够时直接给出最终中文回答。")
	return b.String()
}

// ParseTextToolCalls extracts hermes-style <tool_call> blocks from message
// content and returns the remaining prose. Arguments may arrive as a JSON
// object (Qwen hermes template) or as a string; both normalize to a string.
func ParseTextToolCalls(content string) ([]ToolInvocation, string) {
	if !strings.Contains(content, "<tool_call>") {
		return nil, content
	}
	var calls []ToolInvocation
	var remainder strings.Builder
	offset := 0
	for {
		start := strings.Index(content[offset:], "<tool_call>")
		if start < 0 {
			remainder.WriteString(content[offset:])
			break
		}
		start += offset
		remainder.WriteString(content[offset:start])
		end := strings.Index(content[start:], "</tool_call>")
		if end < 0 {
			remainder.WriteString(content[start:])
			offset = len(content)
			break
		}
		end = start + end
		payload := strings.TrimSpace(content[start+len("<tool_call>") : end])
		offset = end + len("</tool_call>")
		invocation, err := parseToolCallPayload(payload)
		if err != nil {
			// Unparsable blocks stay in the remainder for transparency.
			remainder.WriteString(content[start:offset])
			continue
		}
		calls = append(calls, invocation)
	}
	return calls, strings.TrimSpace(remainder.String())
}

func parseToolCallPayload(payload string) (ToolInvocation, error) {
	var envelope struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if err := json.Unmarshal([]byte(payload), &envelope); err != nil {
		return ToolInvocation{}, err
	}
	name := strings.TrimSpace(envelope.Name)
	if name == "" {
		return ToolInvocation{}, fmt.Errorf("tool call without name")
	}
	return ToolInvocation{
		Name:    name,
		Args:    normalizeToolArguments(envelope.Arguments),
		Preview: truncateRunes(payload, 200),
	}, nil
}

// ParseThinkBlock extracts a <think>…</think> reasoning block from message
// content and returns the reasoning plus the remaining user-facing text. An
// unclosed block consumes the whole remainder (the model forgot the closing
// tag); both parts are trimmed.
func ParseThinkBlock(content string) (string, string) {
	start := strings.Index(content, "<think>")
	if start < 0 {
		return "", content
	}
	before := strings.TrimSpace(content[:start])
	rest := content[start+len("<think>"):]
	end := strings.Index(rest, "</think>")
	if end < 0 {
		return strings.TrimSpace(rest), before
	}
	think := strings.TrimSpace(rest[:end])
	after := strings.TrimSpace(rest[end+len("</think>"):])
	joined := before
	if after != "" {
		if joined != "" {
			joined += "\n" + after
		} else {
			joined = after
		}
	}
	return think, joined
}

func hasTextToolCall(content string) bool {
	return strings.Contains(content, "<tool_call>")
}

// EstimateTokens gives a conservative token estimate for budgeting: Chinese
// text is roughly one token per rune on Qwen tokenizers.
func EstimateTokens(text string) int64 {
	return int64(len([]rune(text)))
}

// BudgetContext trims the replayed history so system prompt, history, the new
// user message and a completion reserve fit inside the model context window.
// It returns the kept turns, the number of dropped turns, and the concatenated
// dropped text eligible for rolling summarization.
func BudgetContext(history []Turn, systemPrompt, userMessage string, contextWindow int) (kept []Turn, dropped []Turn, droppedText string) {
	reserve := EstimateTokens(systemPrompt) + EstimateTokens(userMessage) + defaultMaxCompletionTokens + 128
	budget := int64(contextWindow) - reserve
	if budget < 256 {
		budget = 256
	}
	kept = history
	var used int64
	for i := len(history) - 1; i >= 0; i-- {
		used += EstimateTokens(history[i].Content)
		if used > budget {
			dropped = make([]Turn, 0, i+1)
			dropped = append(dropped, history[:i+1]...)
			kept = history[i+1:]
			break
		}
	}
	if len(dropped) > 0 {
		parts := make([]string, 0, len(dropped))
		for _, turn := range dropped {
			parts = append(parts, turn.Role+": "+truncateRunes(turn.Content, 160))
		}
		droppedText = strings.Join(parts, "\n")
	}
	return kept, dropped, droppedText
}

// SummarizeDropped asks the model for a short rolling summary of compacted
// history. Failures are non-fatal: summarization is best-effort context care.
func SummarizeDropped(ctx context.Context, client LLMClient, model, previous, dropped string) string {
	if client == nil || strings.TrimSpace(dropped) == "" {
		return previous
	}
	prompt := "请把以下养老院工作对话压缩为不超过300字的连贯摘要，保留长者姓名、关键数据、待办与结论，直接输出摘要:\n"
	if previous != "" {
		prompt += "[此前摘要]\n" + truncateRunes(previous, 500) + "\n[新增对话]\n"
	}
	prompt += truncateRunes(dropped, 2400)
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	resp, err := client.ChatOnce(ctx, ChatRequest{
		Model: model,
		Messages: []ChatMessage{
			{Role: "system", Content: "你是对话摘要助手，只输出摘要正文。"},
			{Role: "user", Content: prompt},
		},
		Temperature: 0.1,
	})
	if err != nil || strings.TrimSpace(resp.Content) == "" {
		return previous
	}
	return strings.TrimSpace(resp.Content)
}
