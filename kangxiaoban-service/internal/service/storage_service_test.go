package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"kangxiaoban-service/internal/config"
)

// 未配置 MinIO 时，服务必须显式报告不可用，handler 据此返回 503 而不是假数据。
func TestStorageServiceNotConfigured(t *testing.T) {
	svc := NewStorageService(config.StorageConfig{}, "sign-secret")
	if svc.Available() {
		t.Fatalf("空配置不应构造出可用客户端")
	}
	if _, err := svc.Buckets(context.Background()); !errors.Is(err, ErrStorageNotConfigured) {
		t.Fatalf("Buckets 未配置时应返回 ErrStorageNotConfigured，得到 %v", err)
	}
	if _, err := svc.Objects(context.Background(), "bucket", "", 100); !errors.Is(err, ErrStorageNotConfigured) {
		t.Fatalf("Objects 未配置时应返回 ErrStorageNotConfigured，得到 %v", err)
	}
	if _, _, err := svc.PreviewURL(context.Background(), "bucket", "key"); !errors.Is(err, ErrStorageNotConfigured) {
		t.Fatalf("PreviewURL 未配置时应返回 ErrStorageNotConfigured，得到 %v", err)
	}
}

// 非法 Endpoint 必须让客户端保持不可用，而不是带着坏客户端继续服务。
func TestStorageServiceBadEndpointStaysUnavailable(t *testing.T) {
	svc := NewStorageService(config.StorageConfig{Endpoint: "not a valid endpoint", AccessKey: "db", SecretKey: "x"}, "sign-secret")
	if svc.Available() {
		t.Fatalf("非法 Endpoint 不应构造出可用客户端")
	}
}

// 对象键规范化：拒绝路径穿越/空键，容忍多余斜杠与空白。
func TestSanitizeObjectKey(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"a.jpg", "a.jpg"},
		{"  a.jpg  ", "a.jpg"},
		{"/music/a b.mp3", "music/a b.mp3"},
		{"music//a.mp3", ""},
		{"../secret", ""},
		{"a/../b", ""},
		{"", ""},
		{"/", ""},
		{"./a", ""},
	}
	for _, tc := range cases {
		if got := SanitizeObjectKey(tc.in); got != tc.want {
			t.Fatalf("SanitizeObjectKey(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// 代理流令牌：签名可验证，且换一个对象/密钥即失效。
func TestRawTokenSignAndVerify(t *testing.T) {
	svc := NewStorageService(config.StorageConfig{Endpoint: "10.10.1.13:9000", AccessKey: "ak", SecretKey: "sk"}, "sign-secret")
	token, exp := svc.SignRawToken("bucket", "dir/a.mp3", time.Minute)
	if !svc.VerifyRawToken(token, "bucket", "dir/a.mp3", exp) {
		t.Fatalf("正确令牌应通过校验")
	}
	if svc.VerifyRawToken(token, "bucket", "dir/b.mp3", exp) {
		t.Fatalf("对象不同令牌不应通过")
	}
	if svc.VerifyRawToken(token, "bucket", "dir/a.mp3", exp-1) {
		t.Fatalf("过期令牌不应通过")
	}
	bad := NewStorageService(config.StorageConfig{Endpoint: "10.10.1.13:9000", AccessKey: "ak", SecretKey: "sk"}, "other-secret")
	if bad.VerifyRawToken(token, "bucket", "dir/a.mp3", exp) {
		t.Fatalf("密钥不同令牌不应通过")
	}
}
