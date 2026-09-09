package service

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/security"
)

// AISandboxView 是沙箱设置的只读视图：密钥只回「是否已配置」旗标。
type AISandboxView struct {
	Enabled          bool   `json:"enabled"`
	Domain           string `json:"domain"`
	Protocol         string `json:"protocol"`
	Image            string `json:"image"`
	APIKeyConfigured bool   `json:"api_key_configured"`
	Source           string `json:"source"` // db = 管理端配置 / env = 服务器环境变量
}

// AISandboxSettingInput 携带可编辑的沙箱设置；密钥留空表示保留原值。
type AISandboxSettingInput struct {
	Enabled bool
	Domain  string
	Protocol string
	Image   string
	APIKey  string
}

// sandboxSettingForContext 读取当前租户的沙箱设置行（可能为 nil）。
func (s *AIService) sandboxSettingForContext(ctx context.Context) *model.AISandboxSetting {
	var row model.AISandboxSetting
	if err := s.db.WithContext(ctx).Order("id ASC").First(&row).Error; err != nil {
		return nil
	}
	return &row
}

// effectiveSandboxConfig 解析生效的沙箱配置：管理端设置行优先，未配置回落 .env。
func (s *AIService) effectiveSandboxConfig(ctx context.Context) config.SandboxConfig {
	if row := s.sandboxSettingForContext(ctx); row != nil {
		apiKey, _ := security.Decrypt(s.cfg.ConfigKey, row.APIKeyEncrypted)
		return config.SandboxConfig{
			Enabled:  row.Enabled,
			Domain:   strings.TrimSpace(row.Domain),
			Protocol: strings.TrimSpace(row.Protocol),
			Image:    strings.TrimSpace(row.Image),
			APIKey:   strings.TrimSpace(apiKey),
		}
	}
	return s.sandboxCfg
}

// SandboxSetting 返回生效的沙箱设置视图。
func (s *AIService) SandboxSetting(ctx context.Context) (*AISandboxView, error) {
	if row := s.sandboxSettingForContext(ctx); row != nil {
		apiKey, _ := security.Decrypt(s.cfg.ConfigKey, row.APIKeyEncrypted)
		return &AISandboxView{
			Enabled:          row.Enabled,
			Domain:           strings.TrimSpace(row.Domain),
			Protocol:         strings.TrimSpace(row.Protocol),
			Image:            strings.TrimSpace(row.Image),
			APIKeyConfigured: strings.TrimSpace(apiKey) != "",
			Source:           "db",
		}, nil
	}
	return &AISandboxView{
		Enabled:          s.sandboxCfg.Enabled,
		Domain:           s.sandboxCfg.Domain,
		Protocol:         s.sandboxCfg.Protocol,
		Image:            s.sandboxCfg.Image,
		APIKeyConfigured: strings.TrimSpace(s.sandboxCfg.APIKey) != "",
		Source:           "env",
	}, nil
}

// UpdateSandboxSetting 创建或更新沙箱设置行（管理端优先于 .env）。
func (s *AIService) UpdateSandboxSetting(ctx context.Context, input AISandboxSettingInput) (*AISandboxView, error) {
	protocol := strings.ToLower(strings.TrimSpace(input.Protocol))
	if protocol != "http" && protocol != "https" {
		protocol = "http"
	}
	var saved model.AISandboxSetting
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row model.AISandboxSetting
		err := tx.Order("id ASC").First(&row).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			row = model.AISandboxSetting{}
		} else if err != nil {
			return err
		}
		row.Enabled = input.Enabled
		row.Domain = strings.TrimSpace(input.Domain)
		row.Protocol = protocol
		row.Image = strings.TrimSpace(input.Image)
		if strings.TrimSpace(input.APIKey) != "" {
			encrypted, encryptErr := security.Encrypt(s.cfg.ConfigKey, strings.TrimSpace(input.APIKey))
			if encryptErr != nil {
				return encryptErr
			}
			row.APIKeyEncrypted = encrypted
		}
		if row.ID == 0 {
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
		} else if err := tx.Save(&row).Error; err != nil {
			return err
		}
		saved = row
		return nil
	})
	if err != nil {
		return nil, err
	}
	apiKey, _ := security.Decrypt(s.cfg.ConfigKey, saved.APIKeyEncrypted)
	return &AISandboxView{
		Enabled:          saved.Enabled,
		Domain:           strings.TrimSpace(saved.Domain),
		Protocol:         strings.TrimSpace(saved.Protocol),
		Image:            strings.TrimSpace(saved.Image),
		APIKeyConfigured: strings.TrimSpace(apiKey) != "",
		Source:           "db",
	}, nil
}

// SandboxProbe 对控制面做一次轻量 HTTP 探测：能建立连接即视为可达。
func (s *AIService) SandboxProbe(ctx context.Context) (map[string]interface{}, error) {
	cfg := s.effectiveSandboxConfig(ctx)
	if strings.TrimSpace(cfg.Domain) == "" {
		return nil, fmt.Errorf("沙箱控制面地址未配置")
	}
	scheme := strings.TrimSpace(cfg.Protocol)
	if scheme != "https" {
		scheme = "http"
	}
	startedAt := time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, scheme+"://"+strings.TrimSpace(cfg.Domain)+"/", nil)
	if err != nil {
		return nil, err
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("无法连接沙箱控制面: %w", err)
	}
	defer resp.Body.Close()
	return map[string]interface{}{
		"reachable":  true,
		"status":     resp.StatusCode,
		"latency_ms": time.Since(startedAt).Milliseconds(),
		"enabled":    cfg.Enabled,
	}, nil
}
