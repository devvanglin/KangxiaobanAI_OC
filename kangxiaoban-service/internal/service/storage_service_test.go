package service

import (
	"context"
	"errors"
	"testing"

	"kangxiaoban-service/internal/config"
)

// 未配置 MinIO 时，服务必须显式报告不可用，handler 据此返回 503 而不是假数据。
func TestStorageServiceNotConfigured(t *testing.T) {
	svc := NewStorageService(config.StorageConfig{})
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
	svc := NewStorageService(config.StorageConfig{Endpoint: "not a valid endpoint", AccessKey: "db", SecretKey: "x"})
	if svc.Available() {
		t.Fatalf("非法 Endpoint 不应构造出可用客户端")
	}
}
