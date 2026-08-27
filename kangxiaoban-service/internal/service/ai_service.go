package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/config"
)

// AIService 对话网关：provider=local 用本地确定性答复（演示/离线），provider=http 走真实模型。
type AIService struct {
	cfg *config.AIConfig
	db  *gorm.DB
}

func NewAIService(cfg *config.AIConfig, db *gorm.DB) *AIService {
	return &AIService{cfg: cfg, db: db}
}

// Chat 返回模型答复（advisory，非临床诊断）。
func (s *AIService) Chat(ctx context.Context, question string) (string, string, error) {
	if question == "" {
		return "", "", fmt.Errorf("question 不能为空")
	}
	if s.cfg != nil && s.cfg.Enabled && s.cfg.Provider == "http" && s.cfg.BaseURL != "" {
		if ans, err := s.chatHTTP(ctx, question); err == nil {
			return ans, s.cfg.Model, nil
		}
	}
	return localAnswer(question), s.cfg.Model, nil
}

// chatHTTP 兼容 OpenAI /v1/chat/completions 的远端模型。
func (s *AIService) chatHTTP(ctx context.Context, question string) (string, error) {
	body, _ := json.Marshal(map[string]interface{}{
		"model": s.cfg.Model,
		"messages": []map[string]string{
			{"role": "system", "content": "你是康小伴智慧康养护理平台的照护助理，回答须谨慎、贴题、仅作参考，不做临床诊断。"},
			{"role": "user", "content": question},
		},
		"temperature": 0.3,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.BaseURL+"/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	if s.cfg.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.cfg.APIKey)
	}
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	if len(out.Choices) == 0 || out.Choices[0].Message.Content == "" {
		return "", fmt.Errorf("empty response")
	}
	return out.Choices[0].Message.Content, nil
}

// localAnswer 本地确定性答复：按关键词给出审慎、贴题的帮助。
func localAnswer(q string) string {
	qq := strings.ToLower(q)
	switch {
	case strings.Contains(qq, "跌倒") || strings.Contains(qq, "摔倒"):
		return "跌倒属于高风险事件：请先保持现场、评估长者意识与伤情，勿贸然搬动疑似骨折/头颈部伤者，立即呼叫值班医师并按 SOP 处置，同时在系统标记处置状态。建议关注跌倒高发时段（起身/如厕）并核对离床告警。以上仅为系统建议，具体处置遵循医嘱与机构流程。"
	case strings.Contains(qq, "呼吸") || strings.Contains(qq, "心率"):
		return "该系统毫米波雷达实时监测呼吸与心率：呼吸 <10 或 >25 次/分、心率 <40 或 >120 bpm 会触发「重要」告警并推送。若多次出现请结合血氧复查异常原因，必要时联系医生评估，勿仅凭单次读数判断。"
	case strings.Contains(qq, "家属") || strings.Contains(qq, "家属端"):
		return "家属端支持独立账号登录，仅可查看绑定长者：实时状态、健康记录、月度账单与告警提醒。管理员可在「家属管理」为家属建号并绑定长者，数据按绑定范围隔离。"
	case strings.Contains(qq, "费用") || strings.Contains(qq, "账单") || strings.Contains(qq, "缴费"):
		return "机构按要求为在院长者按床费+护理费+餐费生成月度账单；缴费后系统自动更新已缴金额与账单状态，并写资金流水。账单与缴费数据可在费用账单页查看与操作。"
	case strings.Contains(qq, "排班") || strings.Contains(qq, "交接"):
		return "系统支持按日期/班次维护排班，并记录交接班摘要与待办问题，确保责任到人、信息不断档。"
	default:
		return "您好，我是康小伴照护助理。您可以问我比如：跌倒如何处理、毫米波监测的呼吸/心率指标、家属端如何使用、账单与缴费、排班与交接等日常照护问题。我的回答仅作参考，紧急情况请联系值班人员。"
	}
}