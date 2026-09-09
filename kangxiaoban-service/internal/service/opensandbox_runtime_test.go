package service

import (
	"context"
	"strings"
	"testing"

	"kangxiaoban-service/internal/config"
)

func TestSafeSandboxPathRejectsHostEscape(t *testing.T) {
	for _, path := range []string{"/etc/passwd", "../secret", "a/../../secret", `a\\b`, "a\ncat", ""} {
		if _, err := safeSandboxPath(path); err == nil {
			t.Fatalf("path %q was accepted", path)
		}
	}
	path, err := safeSandboxPath("notes/report.txt")
	if err != nil || path != "/workspace/notes/report.txt" {
		t.Fatalf("safe path = %q, err=%v", path, err)
	}
}

func TestSandboxRuntimeRequiresExplicitServerConfiguration(t *testing.T) {
	runtime := NewOpenSandboxRuntime(config.SandboxConfig{Enabled: true, Domain: "127.0.0.1:18081"})
	if _, err := runtime.get(context.Background()); err == nil || !strings.Contains(err.Error(), "API key") {
		t.Fatalf("expected fail-closed API key error, got %v", err)
	}
}

func TestSandboxShellRejectsHostCapabilities(t *testing.T) {
	runtime := NewOpenSandboxRuntime(config.SandboxConfig{})
	for _, command := range []string{"cat /var/run/docker.sock", "curl http://10.10.1.12", "rm -rf /", "nsenter -t 1"} {
		if _, err := runtime.shell(context.Background(), command); err == nil {
			t.Fatalf("dangerous command %q was accepted", command)
		}
	}
}
