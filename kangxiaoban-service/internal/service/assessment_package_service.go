package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/agent"
	"kangxiaoban-service/internal/model"
)

// RecommendPackage lets the configured model select one active care package
// for a completed assessment. The model can only invoke the two tools below;
// the assignment tool owns the transaction and notification side effects.
func (s *AIService) RecommendPackage(ctx context.Context, actorID, assessmentID uint) error {
	if actorID == 0 || assessmentID == 0 {
		return errors.New("assessment and actor are required")
	}
	var recommendation model.AssessmentPackageRecommendation
	if err := s.db.WithContext(ctx).Where("assessment_id = ?", assessmentID).First(&recommendation).Error; err == nil {
		if recommendation.Status == "assigned" {
			return nil
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	var assessment model.Assessment
	if err := s.db.WithContext(ctx).First(&assessment, assessmentID).Error; err != nil {
		return fmt.Errorf("assessment not found: %w", err)
	}
	var elder model.Elder
	if err := s.db.WithContext(ctx).First(&elder, assessment.ElderID).Error; err != nil {
		return fmt.Errorf("elder not found: %w", err)
	}
	var activePackageCount int64
	if err := s.db.WithContext(ctx).Model(&model.CarePackageTemplate{}).Where("status = ?", "active").Count(&activePackageCount).Error; err != nil {
		return err
	}
	if activePackageCount == 0 {
		return errors.New("没有启用中的订阅套餐")
	}
	cfg, _ := s.configForContext(WithAIRoleScope(ctx, "doctor"))
	if cfg == nil || !cfg.Enabled || strings.ToLower(strings.TrimSpace(cfg.Provider)) != "http" {
		return ErrAIProviderUnavailable
	}
	tools := []*agent.ToolDefinition{s.toolListAssessmentPackages(), s.toolAssignAssessmentPackage(actorID)}
	userMessage := fmt.Sprintf("请为刚完成评估的长者选择并落实一个订阅套餐。\n评估ID：%d\n长者：%s（性别%s，当前照护等级%d）\n评估报告：\n%s\n\n候选套餐由工具 get_active_care_packages 提供。必须先调用该工具，再根据报告调用 assign_assessment_package 完成落地；不能自行编造套餐ID。落地后简要说明选择理由。", assessment.ID, elder.Name, elderGenderLabel(elder.Gender), elder.CareLevel, assessment.Report)
	runner := &agent.Agent{LLM: s.agentClient(cfg), Model: cfg.Model}
	result, err := runner.Run(ctx, agent.RunRequest{
		Mode: agent.ModeWork, SystemPrompt: "你是康小伴的护理套餐决策助手。套餐推荐仅作照护运营建议，不能替代医师判断。你必须调用工具完成真实落地，先读候选套餐，再选择一个最匹配的启用套餐并推送给护工。若报告不足，选择与照护等级和风险最匹配的套餐，并在理由中注明需医师复核。",
		UserMessage: userMessage, Tools: tools, MaxTurns: 5, Temperature: 0.1,
	})
	if err != nil {
		return err
	}
	for _, step := range result.Steps {
		if step.Tool == "assign_assessment_package" && step.OK {
			return nil
		}
	}
	return errors.New("大模型未完成套餐落地工具调用")
}

func (s *AIService) toolListAssessmentPackages() *agent.ToolDefinition {
	return &agent.ToolDefinition{
		Name: "get_active_care_packages", Description: "读取机构当前启用的订阅套餐及护理项目，返回可供本次评估选择的真实套餐ID。",
		ParametersJSON: json.RawMessage(`{"type":"object","properties":{}}`),
		Handler: func(ctx context.Context, _ string) (string, error) {
			var packages []model.CarePackageTemplate
			if err := s.db.WithContext(ctx).Preload("Items").Where("status = ?", "active").Order("id ASC").Find(&packages).Error; err != nil {
				return "", err
			}
			if len(packages) == 0 {
				return "", errors.New("没有启用中的订阅套餐")
			}
			rows := make([]map[string]interface{}, 0, len(packages))
			for _, item := range packages {
				services := make([]map[string]interface{}, 0, len(item.Items))
				for _, service := range item.Items {
					if service.Enabled {
						services = append(services, map[string]interface{}{"id": service.ID, "title": service.Title, "frequency": service.Frequency, "risk_level": service.RiskLevel})
					}
				}
				rows = append(rows, map[string]interface{}{"template_id": item.ID, "code": item.Code, "name": item.Name, "description": item.Description, "applicable_care_level": item.ApplicableCareLevel, "monthly_price": item.MonthlyPrice, "items": services})
			}
			return toolJSON(map[string]interface{}{"packages": rows})
		},
	}
}

func (s *AIService) toolAssignAssessmentPackage(actorID uint) *agent.ToolDefinition {
	type input struct {
		AssessmentID uint   `json:"assessment_id"`
		TemplateID   uint   `json:"template_id"`
		Reason       string `json:"reason"`
	}
	return &agent.ToolDefinition{
		Name: "assign_assessment_package", Description: "将选定的真实启用套餐订阅给评估长者，生成护理计划和任务，并向负责护工推送通知。只能使用 get_active_care_packages 返回的 template_id。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"assessment_id": map[string]interface{}{"type": "integer"},
			"template_id":   map[string]interface{}{"type": "integer"},
			"reason":        map[string]interface{}{"type": "string", "description": "基于评估报告的简短选择理由"},
		}, []string{"assessment_id", "template_id", "reason"}),
		Handler: func(ctx context.Context, raw string) (string, error) {
			var request input
			if err := toolArgs(raw, &request); err != nil || request.AssessmentID == 0 || request.TemplateID == 0 || strings.TrimSpace(request.Reason) == "" {
				return "", errors.New("assessment_id、template_id、reason 均必填")
			}
			return s.assignAssessmentPackage(ctx, actorID, request.AssessmentID, request.TemplateID, request.Reason)
		},
	}
}

func (s *AIService) assignAssessmentPackage(ctx context.Context, actorID, assessmentID, templateID uint, reason string) (string, error) {
	var subscription model.ElderCarePackageSubscription
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var assessment model.Assessment
		if err := tx.First(&assessment, assessmentID).Error; err != nil {
			return fmt.Errorf("评估不存在")
		}
		var existing model.AssessmentPackageRecommendation
		if err := tx.Where("assessment_id = ?", assessmentID).First(&existing).Error; err == nil && existing.Status == "assigned" {
			return nil
		}
		var elder model.Elder
		if err := tx.First(&elder, assessment.ElderID).Error; err != nil {
			return fmt.Errorf("长者不存在")
		}
		var template model.CarePackageTemplate
		if err := tx.Preload("Items").Where("id = ? AND status = ?", templateID, "active").First(&template).Error; err != nil {
			return fmt.Errorf("只能选择启用中的真实套餐")
		}
		caregiver, err := firstAvailableCaregiver(tx)
		if err != nil {
			return err
		}
		var caregiverID *uint
		caregiverName := "值班护工"
		if caregiver != nil {
			caregiverID = &caregiver.ID
			caregiverName = strings.TrimSpace(caregiver.RealName)
			if caregiverName == "" {
				caregiverName = caregiver.Username
			}
		}
		start := time.Now().Format("2006-01-02")
		plan := model.CarePlan{ElderID: elder.ID, TemplateID: &template.ID, Name: template.Name, Status: "active", StartDate: start, CreatedBy: actorID}
		if err := tx.Create(&plan).Error; err != nil {
			return err
		}
		for _, item := range template.Items {
			if !item.Enabled {
				continue
			}
			planItem := model.CarePlanItem{CarePlanID: plan.ID, Title: item.Title, Kind: item.Kind, Frequency: item.Frequency, Instructions: item.Instructions, RiskLevel: item.RiskLevel, AssigneeID: caregiverID, Assignee: caregiverName, Active: true}
			if err := tx.Create(&planItem).Error; err != nil {
				return err
			}
			task := model.CareTask{ElderID: elder.ID, PlanItemID: &planItem.ID, Title: item.Title, Kind: item.Kind, Priority: item.RiskLevel, Category: "todo", AssigneeID: caregiverID, Assignee: caregiverName, Status: "todo", Remark: item.Instructions}
			if err := tx.Create(&task).Error; err != nil {
				return err
			}
		}
		subscription = model.ElderCarePackageSubscription{ElderID: elder.ID, AssessmentID: &assessment.ID, TemplateID: template.ID, CarePlanID: &plan.ID, TemplateName: template.Name, TemplateVersion: template.Version, StartDate: start, Status: "active", MonthlyPrice: template.MonthlyPrice, Currency: template.Currency, AssignedBy: actorID}
		if err := tx.Create(&subscription).Error; err != nil {
			return err
		}
		now := time.Now()
		recommendation := model.AssessmentPackageRecommendation{AssessmentID: assessment.ID, ElderID: elder.ID, TemplateID: &template.ID, CaregiverID: caregiverID, Status: "assigned", Reason: truncateRunes(reason, 2048), AttemptedAt: &now, CompletedAt: &now}
		if err := tx.Where("assessment_id = ?", assessment.ID).Assign(recommendation).FirstOrCreate(&recommendation).Error; err != nil {
			return err
		}
		if caregiver == nil {
			return fmt.Errorf("没有可用护工，套餐未推送")
		}
		content := fmt.Sprintf("%s 的 AI 评估已完成，已推荐并生成「%s」订阅套餐（%s）。选择理由：%s 请结合完整评估报告复核后执行。", elder.Name, template.Name, strings.Join(packageItemTitles(template.Items), "、"), truncateRunes(reason, 500))
		notification := model.Notification{UserID: valueOrZero(caregiverID), Role: "caregiver", Channel: "in_app", Type: "assessment_package_assigned", Title: "AI评估已生成护理套餐", Content: content, Severity: "important", SentAt: &now}
		return tx.Create(&notification).Error
	})
	if err != nil {
		return "", err
	}
	if s.packageEvents != nil {
		s.packageEvents.SendToRole(subscription.TenantID, "caregiver", "assessment.package.assigned", map[string]interface{}{
			"assessment_id": assessmentID, "elder_id": subscription.ElderID, "subscription_id": subscription.ID,
			"template_id": subscription.TemplateID, "template_name": subscription.TemplateName,
		})
	}
	return toolJSON(map[string]interface{}{"status": "assigned", "assessment_id": assessmentID, "subscription_id": subscription.ID, "template_id": subscription.TemplateID, "message": "套餐已生成护理计划并推送给负责护工，需医师复核"})
}

func packageItemTitles(items []model.CarePackageItem) []string {
	result := make([]string, 0, len(items))
	for _, item := range items {
		if item.Enabled {
			result = append(result, item.Title)
		}
	}
	return result
}

func valueOrZero(value *uint) uint {
	if value == nil {
		return 0
	}
	return *value
}
