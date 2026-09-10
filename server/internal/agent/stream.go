package agent

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// ChatStream performs the completion with stream:true, forwarding reasoning
// and answer deltas through emit as they arrive. The returned ChatResponse
// carries the fully accumulated content, reasoning, tool calls and usage —
// identical in shape to ChatOnce.
//
// Streamed content is routed through a zone router: text inside <think>…
// </think> is reasoning, text inside <tool_call>…</tool_call> is protocol
// (not shown to the user), everything else is the answer. This mirrors the
// prompt conventions the agent imposes.
func (c *OpenAIClient) ChatStream(ctx context.Context, req ChatRequest, emit StreamCallback) (ChatResponse, error) {
	base := strings.TrimRight(strings.TrimSpace(c.BaseURL), "/")
	if base == "" {
		return ChatResponse{}, fmt.Errorf("model base url is empty")
	}
	useNative := c.NativeTools && !c.toolsUnsupported && len(req.Tools) > 0
	body := c.buildBody(req, useNative)
	body["stream"] = true
	body["stream_options"] = map[string]interface{}{"include_usage": true}
	encoded, err := json.Marshal(body)
	if err != nil {
		return ChatResponse{}, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/v1/chat/completions", bytes.NewReader(encoded))
	if err != nil {
		return ChatResponse{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "text/event-stream")
	if c.APIKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+c.APIKey)
	}
	client := c.HTTP
	if client == nil {
		client = &http.Client{}
	}
	httpResp, err := client.Do(httpReq)
	if err != nil {
		return ChatResponse{}, err
	}
	defer httpResp.Body.Close()
	if httpResp.StatusCode < http.StatusOK || httpResp.StatusCode >= http.StatusMultipleChoices {
		preview, _ := io.ReadAll(io.LimitReader(httpResp.Body, 400))
		if useNative && isToolChoiceRejectionText(string(preview)) {
			c.toolsUnsupported = true
			return c.ChatOnce(ctx, req)
		}
		return ChatResponse{}, fmt.Errorf("provider HTTP %d: %s", httpResp.StatusCode, string(preview))
	}

	response := ChatResponse{}
	router := newStreamRouter(emit)
	scanner := bufio.NewScanner(httpResp.Body)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		payload := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if payload == "" || payload == "[DONE]" {
			continue
		}
		var chunk struct {
			Choices []struct {
				Delta struct {
					Content          string `json:"content"`
					ReasoningContent string `json:"reasoning_content"`
					ToolCalls        []struct {
						ID       string `json:"id"`
						Function struct {
							Name      string `json:"name"`
							Arguments string `json:"arguments"`
						} `json:"function"`
					} `json:"tool_calls"`
				} `json:"delta"`
				FinishReason string `json:"finish_reason"`
			} `json:"choices"`
			Usage *struct {
				PromptTokens     int64 `json:"prompt_tokens"`
				CompletionTokens int64 `json:"completion_tokens"`
				TotalTokens      int64 `json:"total_tokens"`
			} `json:"usage"`
			Error *struct {
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.Unmarshal([]byte(payload), &chunk); err != nil {
			continue
		}
		if chunk.Error != nil {
			return ChatResponse{}, fmt.Errorf("provider stream error: %s", chunk.Error.Message)
		}
		if chunk.Usage != nil {
			response.PromptTokens = chunk.Usage.PromptTokens
			response.CompletionTokens = chunk.Usage.CompletionTokens
			response.TotalTokens = chunk.Usage.TotalTokens
		}
		if len(chunk.Choices) == 0 {
			continue
		}
		delta := chunk.Choices[0].Delta
		if strings.TrimSpace(delta.ReasoningContent) != "" {
			response.Reasoning = appendReasoning(response.Reasoning, delta.ReasoningContent)
			router.emitRaw("reasoning", delta.ReasoningContent)
		}
		if delta.Content != "" {
			router.feed(delta.Content)
		}
		if chunk.Choices[0].FinishReason != "" {
			response.FinishReason = chunk.Choices[0].FinishReason
		}
		for _, call := range delta.ToolCalls {
			if strings.TrimSpace(call.Function.Name) != "" {
				response.pendingToolName = call.Function.Name
			}
			if call.ID != "" {
				response.pendingToolID = call.ID
			}
			response.pendingToolArgs += call.Function.Arguments
		}
	}
	if err := scanner.Err(); err != nil {
		return ChatResponse{}, err
	}
	router.flush()

	response.Content = router.answer.String()
	combined := strings.TrimSpace(router.reasoningNative.String())
	if think := strings.TrimSpace(router.reasoningThink.String()); think != "" {
		combined = appendReasoning(combined, think)
	}
	response.Reasoning = combined
	if response.TotalTokens <= 0 {
		response.TotalTokens = response.PromptTokens + response.CompletionTokens
	}
	if response.pendingToolName != "" {
		response.ToolCalls = append(response.ToolCalls, ToolInvocation{
			ID: response.pendingToolID, Name: response.pendingToolName,
			Args: normalizeToolArguments(json.RawMessage(response.pendingToolArgs)), Native: true,
		})
	}
	// Same recovery rules as the non-streaming path (prompt-based protocol).
	if len(response.ToolCalls) == 0 && hasTextToolCall(response.Reasoning) {
		if calls, cleaned := ParseTextToolCalls(response.Reasoning); len(calls) > 0 {
			response.Reasoning = strings.TrimSpace(cleaned)
			response.ToolCalls = append(response.ToolCalls, calls...)
		}
	}
	if len(response.ToolCalls) == 0 && hasTextToolCall(response.Content) {
		if calls, remainder := ParseTextToolCalls(response.Content); len(calls) > 0 {
			response.Content = strings.TrimSpace(remainder)
			response.ToolCalls = append(response.ToolCalls, calls...)
		}
	}
	return response, nil
}

func isToolChoiceRejectionText(text string) bool {
	return strings.Contains(text, "tool choice requires") ||
		strings.Contains(text, "tool-call-parser") ||
		strings.Contains(text, "enable-auto-tool-choice")
}

// streamRouter routes streamed content pieces into reasoning / answer /
// toolcall zones by tracking <think> and <tool_call> tag transitions. A small
// tail of each buffer is held back so tags split across chunks are detected.
type streamRouter struct {
	emit            StreamCallback
	zoneStack       []string
	buf             strings.Builder
	reasoningNative strings.Builder
	reasoningThink  strings.Builder
	answer          strings.Builder
}

func newStreamRouter(emit StreamCallback) *streamRouter {
	return &streamRouter{emit: emit, zoneStack: []string{"answer"}}
}

func (r *streamRouter) zone() string { return r.zoneStack[len(r.zoneStack)-1] }

func (r *streamRouter) push(zone string) { r.zoneStack = append(r.zoneStack, zone) }

func (r *streamRouter) pop() {
	if len(r.zoneStack) > 1 {
		r.zoneStack = r.zoneStack[:len(r.zoneStack)-1]
	}
}

func (r *streamRouter) emitRaw(kind, text string) {
	if r.emit != nil && text != "" {
		r.emit(kind, text)
	}
}

func (r *streamRouter) route(kind, text string) {
	if text == "" {
		return
	}
	switch kind {
	case "reasoning":
		r.reasoningThink.WriteString(text)
		r.emitRaw("reasoning", text)
	case "toolcall":
		// Raw protocol text stays out of the user-facing stream; the executed
		// step is emitted separately by the loop.
	default:
		r.answer.WriteString(text)
		r.emitRaw("answer", text)
	}
}

func (r *streamRouter) feed(piece string) {
	r.buf.WriteString(piece)
	const holdback = 15
	for {
		buf := r.buf.String()
		bestIdx, bestTag, bestClose := -1, "", false
		for _, tag := range []string{"<think>", "</think>", "<tool_call>", "</tool_call>"} {
			// Protocol tags are ASCII and emitted in this exact lowercase form.
			// Searching the original buffer is important: strings.ToLower can
			// change the byte length of surrounding Unicode text, making an index
			// from the lowercased copy invalid for slicing the original buffer.
			if idx := strings.Index(buf, tag); idx >= 0 && (bestIdx < 0 || idx < bestIdx) {
				bestIdx, bestTag, bestClose = idx, tag, strings.HasPrefix(tag, "</")
			}
		}
		if bestIdx < 0 {
			if len(buf) > holdback {
				safe := buf[:len(buf)-holdback]
				r.route(r.zone(), safe)
				r.buf.Reset()
				r.buf.WriteString(buf[len(buf)-holdback:])
			}
			return
		}
		if bestIdx > 0 {
			r.route(r.zone(), buf[:bestIdx])
		}
		if bestClose {
			r.pop()
		} else {
			switch bestTag {
			case "<think>":
				r.push("reasoning")
			case "<tool_call>":
				r.push("toolcall")
			}
		}
		r.buf.Reset()
		r.buf.WriteString(buf[bestIdx+len(bestTag):])
	}
}

func (r *streamRouter) flush() {
	if r.buf.Len() > 0 {
		r.route(r.zone(), r.buf.String())
		r.buf.Reset()
	}
}
