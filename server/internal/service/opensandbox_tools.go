package service

import (
	"context"
	"fmt"

	"kangxiaoban-service/internal/agent"
	"kangxiaoban-service/internal/config"
)

func (s *AIService) openSandboxTools(runtime *OpenSandboxRuntime) []*agent.ToolDefinition {
	if runtime == nil || !runtime.enabled() {
		return nil
	}
	return []*agent.ToolDefinition{
		{
			Name: "sandbox_list_files", Trust: agent.TrustedBusiness,
			Description:    "列出本次 OpenSandbox 隔离工作区中的文件。不能读取宿主机或其他沙箱。",
			ParametersJSON: jsonSchema(map[string]interface{}{"path": map[string]interface{}{"type": "string", "description": "相对 /workspace 的目录，留空表示根目录"}}, nil),
			Handler: func(ctx context.Context, raw string) (string, error) {
				var in struct {
					Path string `json:"path"`
				}
				if err := toolArgs(raw, &in); err != nil {
					return "", fmt.Errorf("参数格式错误")
				}
				return runtime.list(ctx, in.Path)
			},
		},
		{
			Name: "sandbox_read_file", Trust: agent.TrustedBusiness,
			Description:    "读取本次 OpenSandbox 隔离工作区内不超过 256KB 的文本文件。只能使用安全相对路径。",
			ParametersJSON: jsonSchema(map[string]interface{}{"path": map[string]interface{}{"type": "string"}}, []string{"path"}),
			Handler: func(ctx context.Context, raw string) (string, error) {
				var in struct {
					Path string `json:"path"`
				}
				if err := toolArgs(raw, &in); err != nil {
					return "", fmt.Errorf("参数格式错误")
				}
				return runtime.read(ctx, in.Path)
			},
		},
		{
			Name: "sandbox_write_file", Trust: agent.TrustedBusiness,
			Description:    "向本次 OpenSandbox 隔离工作区写入文本文件。不能写宿主机，最大 256KB。",
			ParametersJSON: jsonSchema(map[string]interface{}{"path": map[string]interface{}{"type": "string"}, "content": map[string]interface{}{"type": "string"}}, []string{"path", "content"}),
			Handler: func(ctx context.Context, raw string) (string, error) {
				var in struct {
					Path    string `json:"path"`
					Content string `json:"content"`
				}
				if err := toolArgs(raw, &in); err != nil {
					return "", fmt.Errorf("参数格式错误")
				}
				return runtime.write(ctx, in.Path, in.Content)
			},
		},
		{
			Name: "sandbox_shell", Trust: agent.TrustedBusiness,
			Description:    "在本次 OpenSandbox 容器的 /workspace 中执行 Shell，30 秒超时、无宿主机目录挂载、默认禁止联网。",
			ParametersJSON: jsonSchema(map[string]interface{}{"command": map[string]interface{}{"type": "string"}}, []string{"command"}),
			Handler: func(ctx context.Context, raw string) (string, error) {
				var in struct {
					Command string `json:"command"`
				}
				if err := toolArgs(raw, &in); err != nil {
					return "", fmt.Errorf("参数格式错误")
				}
				return runtime.shell(ctx, in.Command)
			},
		},
	}
}

func newSandboxRuntime(cfg config.SandboxConfig) *OpenSandboxRuntime {
	return NewOpenSandboxRuntime(cfg)
}
