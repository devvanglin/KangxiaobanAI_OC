package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"kangxiaoban-service/internal/agent"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/security"
)

// Minimal Model Context Protocol client over the streamable HTTP transport.
// Each exchange opens one session (initialize -> initialized -> tools/list or
// tools/call) and closes it, which keeps the gateway stateless across
// requests; MCP servers tolerate short-lived sessions and this avoids
// per-tenant session bookkeeping.

const (
	mcpProtocolVersion = "2025-03-26"
	mcpClientName      = "kangxiaoban-agent"
	mcpTimeout         = 8 * time.Second
	// mcpBridgeTimeout bounds per-server tool discovery during agent setup so
	// one dead server cannot stall every conversation.
	mcpBridgeTimeout = 5 * time.Second
	// mcpMaxTools caps bridged MCP tools to protect the prompt budget.
	mcpMaxTools = 12
)

type mcpConn struct {
	endpoint  string
	apiKey    string
	sessionID string
	http      *http.Client
	nextID    int64
}

type mcpToolDef struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	InputSchema json.RawMessage `json:"inputSchema"`
}

func dialMCPServer(ctx context.Context, endpoint, apiKey string) (*mcpConn, error) {
	endpoint = strings.TrimSpace(endpoint)
	if endpoint == "" {
		return nil, fmt.Errorf("MCP endpoint is empty")
	}
	conn := &mcpConn{endpoint: endpoint, apiKey: apiKey, http: &http.Client{Timeout: mcpTimeout}, nextID: 1}
	var result struct {
		ServerInfo struct {
			Name    string `json:"name"`
			Version string `json:"version"`
		} `json:"serverInfo"`
	}
	if err := conn.request(ctx, "initialize", map[string]interface{}{
		"protocolVersion": mcpProtocolVersion,
		"capabilities":    map[string]interface{}{},
		"clientInfo":      map[string]interface{}{"name": mcpClientName, "version": "1.0"},
	}, &result); err != nil {
		return nil, fmt.Errorf("initialize 失败: %w", err)
	}
	if err := conn.notify(ctx, "notifications/initialized"); err != nil {
		return nil, fmt.Errorf("initialized 通知失败: %w", err)
	}
	return conn, nil
}

// request performs one JSON-RPC request and decodes result into out.
func (c *mcpConn) request(ctx context.Context, method string, params interface{}, out interface{}) error {
	c.nextID++
	body := map[string]interface{}{
		"jsonrpc": "2.0", "id": c.nextID, "method": method,
	}
	if params != nil {
		body["params"] = params
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return err
	}
	raw, err := c.post(ctx, payload)
	if err != nil {
		return err
	}
	var envelope struct {
		Result json.RawMessage `json:"result"`
		Error  *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return err
	}
	if envelope.Error != nil {
		return fmt.Errorf("MCP 错误 %d: %s", envelope.Error.Code, envelope.Error.Message)
	}
	if out != nil && len(envelope.Result) > 0 {
		if err := json.Unmarshal(envelope.Result, out); err != nil {
			return err
		}
	}
	return nil
}

func (c *mcpConn) notify(ctx context.Context, method string) error {
	payload, err := json.Marshal(map[string]interface{}{"jsonrpc": "2.0", "method": method})
	if err != nil {
		return err
	}
	_, err = c.post(ctx, payload)
	return err
}

// post sends one payload and returns the decoded JSON-RPC message body,
// transparently unwrapping SSE-framed responses.
func (c *mcpConn) post(ctx context.Context, payload []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}
	if c.sessionID != "" {
		req.Header.Set("Mcp-Session-Id", c.sessionID)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	if session := resp.Header.Get("Mcp-Session-Id"); session != "" {
		c.sessionID = session
	}
	body, err := readMCPBody(resp)
	if err != nil {
		return nil, err
	}
	if isNotification(payload) {
		return body, nil
	}
	return body, nil
}

func isNotification(payload []byte) bool {
	var probe struct {
		ID interface{} `json:"id"`
	}
	if err := json.Unmarshal(payload, &probe); err != nil {
		return true
	}
	return probe.ID == nil
}

// readMCPBody returns the JSON-RPC message: plain JSON passes through, while
// text/event-stream responses are scanned for the first data: line carrying a
// JSON-RPC message (a matching id when one was sent).
func readMCPBody(resp *http.Response) ([]byte, error) {
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	trimmed := bytes.TrimSpace(body)
	if !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		return trimmed, nil
	}
	for _, line := range strings.Split(string(trimmed), "\n") {
		line = strings.TrimRight(line, "\r")
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		candidate := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if strings.HasPrefix(candidate, "{") {
			return []byte(candidate), nil
		}
	}
	return nil, fmt.Errorf("event-stream 中没有 JSON-RPC 消息")
}

func listMCPTools(ctx context.Context, conn *mcpConn) ([]mcpToolDef, error) {
	var result struct {
		Tools []mcpToolDef `json:"tools"`
	}
	if err := conn.request(ctx, "tools/list", map[string]interface{}{}, &result); err != nil {
		return nil, err
	}
	return result.Tools, nil
}

func callMCPTool(ctx context.Context, conn *mcpConn, name, argsJSON string) (string, error) {
	arguments := map[string]interface{}{}
	if strings.TrimSpace(argsJSON) != "" {
		_ = json.Unmarshal([]byte(argsJSON), &arguments)
	}
	var result struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
		IsError bool `json:"isError"`
	}
	if err := conn.request(ctx, "tools/call", map[string]interface{}{
		"name": name, "arguments": arguments,
	}, &result); err != nil {
		return "", err
	}
	parts := make([]string, 0, len(result.Content))
	for _, item := range result.Content {
		if strings.TrimSpace(item.Text) != "" {
			parts = append(parts, item.Text)
		}
	}
	output := strings.Join(parts, "\n")
	if result.IsError {
		if output == "" {
			output = "MCP 工具执行失败"
		}
		return output, fmt.Errorf("%s", output)
	}
	if output == "" {
		output = "{}"
	}
	return output, nil
}

// AdminMCPServerInput is the admin create/update payload.
type AdminMCPServerInput struct {
	Name     string `json:"name"`
	Endpoint string `json:"endpoint"`
	APIKey   string `json:"api_key"`
	Enabled  bool   `json:"enabled"`
}

// AdminListMCPServers lists tenant-registered MCP servers.
func (s *AIService) AdminListMCPServers(ctx context.Context) ([]model.AIMCPServer, error) {
	var servers []model.AIMCPServer
	err := s.db.WithContext(ctx).Order("id ASC").Find(&servers).Error
	return servers, err
}

// AdminCreateMCPServer registers one MCP server.
func (s *AIService) AdminCreateMCPServer(ctx context.Context, in AdminMCPServerInput) (*model.AIMCPServer, error) {
	server, err := normalizeMCPServerInput(in)
	if err != nil {
		return nil, err
	}
	if err := s.db.WithContext(ctx).Create(server).Error; err != nil {
		return nil, err
	}
	return server, nil
}

// AdminUpdateMCPServer edits one server. An empty api_key keeps the stored one.
func (s *AIService) AdminUpdateMCPServer(ctx context.Context, id uint, in AdminMCPServerInput) (*model.AIMCPServer, error) {
	var server model.AIMCPServer
	if err := s.db.WithContext(ctx).First(&server, id).Error; err != nil {
		return nil, err
	}
	normalized, err := normalizeMCPServerInput(in)
	if err != nil {
		return nil, err
	}
	updates := map[string]interface{}{
		"name": normalized.Name, "endpoint": normalized.Endpoint, "enabled": normalized.Enabled,
	}
	if strings.TrimSpace(in.APIKey) != "" {
		encrypted, encErr := security.Encrypt(s.cfg.ConfigKey, strings.TrimSpace(in.APIKey))
		if encErr != nil {
			return nil, encErr
		}
		updates["api_key_encrypted"] = encrypted
	}
	if err := s.db.WithContext(ctx).Model(&model.AIMCPServer{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		return nil, err
	}
	var updated model.AIMCPServer
	if err := s.db.WithContext(ctx).First(&updated, id).Error; err != nil {
		return nil, err
	}
	return &updated, nil
}

// AdminDeleteMCPServer removes one server registration.
func (s *AIService) AdminDeleteMCPServer(ctx context.Context, id uint) error {
	return s.db.WithContext(ctx).Delete(&model.AIMCPServer{}, id).Error
}

// AdminProbeMCPServer dials the server, lists its tools and stores health.
func (s *AIService) AdminProbeMCPServer(ctx context.Context, id uint) (*model.AIMCPServer, error) {
	var server model.AIMCPServer
	if err := s.db.WithContext(ctx).First(&server, id).Error; err != nil {
		return nil, err
	}
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, server.APIKeyEncrypted)
	probeCtx, cancel := context.WithTimeout(ctx, mcpTimeout)
	defer cancel()
	conn, err := dialMCPServer(probeCtx, server.Endpoint, apiKey)
	message := ""
	count := 0
	status := "ok"
	if err != nil {
		status = "error"
		message = err.Error()
	} else if tools, listErr := listMCPTools(probeCtx, conn); listErr != nil {
		status = "error"
		message = listErr.Error()
	} else {
		count = len(tools)
		message = fmt.Sprintf("连接成功，发现 %d 个工具", count)
	}
	now := time.Now()
	updates := map[string]interface{}{
		"status": status, "tool_count": count, "last_probe_at": now, "last_probe_message": message,
	}
	if err := s.db.WithContext(ctx).Model(&model.AIMCPServer{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		return nil, err
	}
	return s.reloadMCPServer(ctx, id)
}

func (s *AIService) reloadMCPServer(ctx context.Context, id uint) (*model.AIMCPServer, error) {
	var server model.AIMCPServer
	if err := s.db.WithContext(ctx).First(&server, id).Error; err != nil {
		return nil, err
	}
	return &server, nil
}

// mcpAgentTools bridges enabled MCP servers into the agent registry. One dead
// server is skipped after its short bridge timeout and never blocks a chat.
func (s *AIService) mcpAgentTools(ctx context.Context) []*agent.ToolDefinition {
	var servers []model.AIMCPServer
	if err := s.db.WithContext(ctx).Where("enabled = ?", true).Order("id ASC").Find(&servers).Error; err != nil {
		return nil
	}
	tools := make([]*agent.ToolDefinition, 0, mcpMaxTools)
	for _, server := range servers {
		if len(tools) >= mcpMaxTools {
			break
		}
		bridgeCtx, cancel := context.WithTimeout(ctx, mcpBridgeTimeout)
		apiKey, _ := security.Decrypt(s.cfg.ConfigKey, server.APIKeyEncrypted)
		conn, err := dialMCPServer(bridgeCtx, server.Endpoint, apiKey)
		if err != nil {
			cancel()
			continue
		}
		toolDefs, listErr := listMCPTools(bridgeCtx, conn)
		cancel()
		if listErr != nil {
			continue
		}
		prefix := mcpToolPrefix(server.ID, server.Name)
		for _, toolDef := range toolDefs {
			if len(tools) >= mcpMaxTools {
				break
			}
			name := strings.TrimSpace(toolDef.Name)
			if name == "" {
				continue
			}
			toolName := prefix + name
			if len(toolName) > 56 {
				toolName = toolName[:56]
			}
			serverID := server.ID
			definition := &agent.ToolDefinition{
				Name:           toolName,
				Description:    fmt.Sprintf("[%s] %s", server.Name, strings.TrimSpace(toolDef.Description)),
				ParametersJSON: normalizeMCPSchema(toolDef.InputSchema),
				Handler: func(ctx context.Context, args string) (string, error) {
					apiKey, _ := security.Decrypt(s.cfg.ConfigKey, s.mcpEncryptedKeyFor(ctx, serverID))
					conn, dialErr := dialMCPServer(ctx, s.mcpEndpointFor(ctx, serverID), apiKey)
					if dialErr != nil {
						return "", dialErr
					}
					return callMCPTool(ctx, conn, name, args)
				},
			}
			tools = append(tools, definition)
		}
	}
	return tools
}

func mcpToolPrefix(serverID uint, name string) string {
	clean := strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			return r
		}
		return '_'
	}, strings.TrimSpace(name))
	if clean == "" {
		clean = fmt.Sprintf("srv%d", serverID)
	}
	return "mcp_" + clean + "_"
}

func normalizeMCPSchema(raw json.RawMessage) json.RawMessage {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 {
		return json.RawMessage(`{"type":"object","properties":{}}`)
	}
	return trimmed
}

func normalizeMCPServerInput(in AdminMCPServerInput) (*model.AIMCPServer, error) {
	name := strings.TrimSpace(in.Name)
	endpoint := strings.TrimSpace(in.Endpoint)
	if name == "" || endpoint == "" {
		return nil, fmt.Errorf("%w: MCP 名称与端点必填", ErrAIValidation)
	}
	if !strings.HasPrefix(endpoint, "http://") && !strings.HasPrefix(endpoint, "https://") {
		return nil, fmt.Errorf("%w: MCP 端点必须是 http(s) 地址", ErrAIValidation)
	}
	return &model.AIMCPServer{Name: name, Endpoint: endpoint, Enabled: in.Enabled}, nil
}

// mcpEncryptedKeyFor/mcpEndpointFor resolve live connection details at
// tool-call time (the key is still encrypted here) so admin edits apply
// without restarting conversations.
func (s *AIService) mcpEncryptedKeyFor(ctx context.Context, serverID uint) string {
	var server model.AIMCPServer
	if err := s.db.WithContext(ctx).Select("api_key_encrypted").First(&server, serverID).Error; err != nil {
		return ""
	}
	return server.APIKeyEncrypted
}

func (s *AIService) mcpEndpointFor(ctx context.Context, serverID uint) string {
	var server model.AIMCPServer
	if err := s.db.WithContext(ctx).Select("endpoint").First(&server, serverID).Error; err != nil {
		return ""
	}
	return server.Endpoint
}
