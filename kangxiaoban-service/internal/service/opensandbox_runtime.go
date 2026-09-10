package service

import (
	"context"
	"fmt"
	"io"
	"strings"
	"sync"
	"time"

	opensandbox "github.com/alibaba/OpenSandbox/sdks/sandbox/go"
	"kangxiaoban-service/internal/config"
)

const sandboxWorkspace = "/workspace"

// OpenSandboxRuntime creates one short-lived, no-host-mount workspace per
// model-directed tool session. It is intentionally process-local: a sandbox
// id is never accepted from model arguments, so one tenant cannot attach to
// another tenant's workspace.
type OpenSandboxRuntime struct {
	cfg     config.SandboxConfig
	mu      sync.Mutex
	sandbox *opensandbox.Sandbox
}

func NewOpenSandboxRuntime(cfg config.SandboxConfig) *OpenSandboxRuntime {
	return &OpenSandboxRuntime{cfg: cfg}
}

func (r *OpenSandboxRuntime) enabled() bool {
	return r != nil && r.cfg.Enabled && strings.TrimSpace(r.cfg.Domain) != "" && strings.TrimSpace(r.cfg.APIKey) != ""
}

func (r *OpenSandboxRuntime) get(ctx context.Context) (*opensandbox.Sandbox, error) {
	if !r.enabled() {
		return nil, fmt.Errorf("OpenSandbox 未启用或未配置 API key")
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.sandbox != nil {
		return r.sandbox, nil
	}
	connection := opensandbox.ConnectionConfig{Domain: r.cfg.Domain, Protocol: r.cfg.Protocol, APIKey: r.cfg.APIKey, UseServerProxy: true, RequestTimeout: 600 * time.Second, DisableMetrics: true}
	sandbox, err := opensandbox.CreateSandbox(ctx, connection, opensandbox.SandboxCreateOptions{
		Image: r.cfg.Image, Entrypoint: []string{"/bin/sh", "-c", "while true; do sleep 3600; done"},
		TimeoutSeconds: ptrInt(300), ResourceLimits: opensandbox.ResourceLimits{"cpu": "500m", "memory": "512Mi"},
		NetworkPolicy: &opensandbox.NetworkPolicy{DefaultAction: "deny"},
		Metadata:      map[string]string{"managed-by": "kangxiaoban-agent", "purpose": "model-tool"},
		ReadyTimeout:  240 * time.Second,
	})
	if err != nil {
		return nil, fmt.Errorf("创建 OpenSandbox 失败: %w", err)
	}
	r.sandbox = sandbox
	return sandbox, nil
}

func ptrInt(v int) *int { return &v }

func (r *OpenSandboxRuntime) close(ctx context.Context) {
	r.mu.Lock()
	sandbox := r.sandbox
	r.sandbox = nil
	r.mu.Unlock()
	if sandbox != nil {
		_ = sandbox.Kill(ctx)
		_ = sandbox.Close()
	}
}

func safeSandboxPath(path string) (string, error) {
	path = strings.TrimSpace(path)
	// 模型常给绝对路径；把恰好落在工作区内的 /workspace 前缀归一化为相对路径。
	if path == sandboxWorkspace {
		path = ""
	} else if strings.HasPrefix(path, sandboxWorkspace+"/") {
		path = strings.TrimPrefix(path, sandboxWorkspace+"/")
	}
	if path == "" || strings.Contains(path, "\\") || strings.Contains(path, "..") || strings.HasPrefix(path, "/") || strings.ContainsAny(path, "\x00\r\n") {
		return "", fmt.Errorf("路径必须是 /workspace 下的安全相对路径")
	}
	return sandboxWorkspace + "/" + path, nil
}

func (r *OpenSandboxRuntime) write(ctx context.Context, path, content string) (string, error) {
	remote, err := safeSandboxPath(path)
	if err != nil {
		return "", err
	}
	sandbox, err := r.get(ctx)
	if err != nil {
		return "", err
	}
	if len([]byte(content)) > 256*1024 {
		return "", fmt.Errorf("文件内容超过 256KB 沙箱限制")
	}
	err = sandbox.UploadFile(ctx, strings.NewReader(content), opensandbox.UploadFileOptions{FileName: path, Metadata: opensandbox.FileMetadata{Path: remote, Mode: 0600}})
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("已写入沙箱 %s（%d 字节）", path, len([]byte(content))), nil
}

func (r *OpenSandboxRuntime) read(ctx context.Context, path string) (string, error) {
	remote, err := safeSandboxPath(path)
	if err != nil {
		return "", err
	}
	sandbox, err := r.get(ctx)
	if err != nil {
		return "", err
	}
	reader, err := sandbox.DownloadFile(ctx, remote, "bytes=0-262143")
	if err != nil {
		return "", err
	}
	defer reader.Close()
	data, err := io.ReadAll(io.LimitReader(reader, 256*1024))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func (r *OpenSandboxRuntime) list(ctx context.Context, path string) (string, error) {
	remote := sandboxWorkspace
	if strings.TrimSpace(path) != "" {
		var err error
		remote, err = safeSandboxPath(path)
		if err != nil {
			return "", err
		}
	}
	sandbox, err := r.get(ctx)
	if err != nil {
		return "", err
	}
	entries, err := sandbox.ListDirectory(ctx, remote)
	if err != nil {
		return "", err
	}
	return toolJSON(entries)
}

func (r *OpenSandboxRuntime) shell(ctx context.Context, command string) (string, error) {
	command = strings.TrimSpace(command)
	if command == "" || len([]byte(command)) > 8192 {
		return "", fmt.Errorf("命令为空或超过 8KB 沙箱限制")
	}
	if strings.ContainsAny(command, "\x00\r\n") {
		return "", fmt.Errorf("命令包含非法控制字符")
	}
	// OpenSandbox is the isolation boundary, but prevent obvious attempts to
	// leave the workspace or reach its control plane from inside the sandbox.
	lower := strings.ToLower(command)
	for _, marker := range []string{"/var/run/docker.sock", "169.254.169.254", "10.10.1.12", "10.10.1.11", "mount ", "nsenter", "--privileged", "rm -rf /"} {
		if strings.Contains(lower, marker) {
			return "", fmt.Errorf("命令触及被沙箱禁止的主机能力")
		}
	}
	sandbox, err := r.get(ctx)
	if err != nil {
		return "", err
	}
	exec, err := sandbox.RunCommandWithOpts(ctx, opensandbox.RunCommandRequest{Command: command, Cwd: sandboxWorkspace, Timeout: 30000}, nil)
	if err != nil {
		return "", err
	}
	return toolJSON(map[string]interface{}{"exit_code": exec.ExitCode, "stdout": exec.Text(), "stderr": executionStderr(exec)})
}

func executionStderr(exec *opensandbox.Execution) string {
	if exec == nil {
		return ""
	}
	parts := make([]string, 0, len(exec.Stderr))
	for _, item := range exec.Stderr {
		parts = append(parts, item.Text)
	}
	return strings.Join(parts, "\n")
}
