package service

import (
	"context"
	"fmt"
	"strings"

	"kangxiaoban-service/internal/model"
)

// AISkillInput is the admin-facing create/update payload for one skill.
type AISkillInput struct {
	RoleScope    string `json:"role_scope"`
	Code         string `json:"code"`
	Name         string `json:"name"`
	Description  string `json:"description"`
	Version      string `json:"version"`
	Tags         string `json:"tags"`
	Instructions string `json:"instructions"`
	SortOrder    int    `json:"sort_order"`
	Enabled      bool   `json:"enabled"`
}

// AdminListSkills lists tenant skills, optionally filtered by role scope
// (caregiver/doctor/all) and including disabled rows for management.
func (s *AIService) AdminListSkills(ctx context.Context, role string) ([]model.AISkill, error) {
	query := s.db.WithContext(ctx).Model(&model.AISkill{})
	switch strings.TrimSpace(role) {
	case "caregiver", "doctor", "all":
		query = query.Where("role_scope = ?", strings.TrimSpace(role))
	}
	var skills []model.AISkill
	err := query.Order("sort_order ASC, id ASC").Find(&skills).Error
	return skills, err
}

// AdminCreateSkill adds one skill. The code is the unique handle.
func (s *AIService) AdminCreateSkill(ctx context.Context, in AISkillInput) (*model.AISkill, error) {
	skill, err := normalizeAISkillInput(in)
	if err != nil {
		return nil, err
	}
	var existing model.AISkill
	if err := s.db.WithContext(ctx).Where("code = ?", skill.Code).First(&existing).Error; err == nil {
		return nil, fmt.Errorf("%w: 技能编码 %s 已存在", ErrAIValidation, skill.Code)
	}
	if err := s.db.WithContext(ctx).Create(skill).Error; err != nil {
		return nil, err
	}
	return skill, nil
}

// AdminUpdateSkill edits one skill. Built-in rows keep their code.
func (s *AIService) AdminUpdateSkill(ctx context.Context, id uint, in AISkillInput) (*model.AISkill, error) {
	var skill model.AISkill
	if err := s.db.WithContext(ctx).First(&skill, id).Error; err != nil {
		return nil, err
	}
	normalized, err := normalizeAISkillInput(in)
	if err != nil {
		return nil, err
	}
	if normalized.Code != skill.Code {
		if skill.IsBuiltin {
			return nil, fmt.Errorf("%w: 内置技能不可修改编码", ErrAIValidation)
		}
		var conflict model.AISkill
		if err := s.db.WithContext(ctx).Where("code = ? AND id <> ?", normalized.Code, id).First(&conflict).Error; err == nil {
			return nil, fmt.Errorf("%w: 技能编码 %s 已存在", ErrAIValidation, normalized.Code)
		}
	}
	updates := map[string]interface{}{
		"role_scope": normalized.RoleScope, "code": normalized.Code, "name": normalized.Name,
		"description": normalized.Description, "version": normalized.Version, "tags": normalized.Tags,
		"instructions": normalized.Instructions, "sort_order": normalized.SortOrder, "enabled": normalized.Enabled,
	}
	if err := s.db.WithContext(ctx).Model(&model.AISkill{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		return nil, err
	}
	return s.reloadSkill(ctx, id)
}

// AdminDeleteSkill removes one skill; built-ins are protected so the starter
// capability set always stays discoverable in the admin UI.
func (s *AIService) AdminDeleteSkill(ctx context.Context, id uint) error {
	var skill model.AISkill
	if err := s.db.WithContext(ctx).First(&skill, id).Error; err != nil {
		return err
	}
	if skill.IsBuiltin {
		return fmt.Errorf("%w: 内置技能不可删除，可停用", ErrAIValidation)
	}
	return s.db.WithContext(ctx).Delete(&model.AISkill{}, id).Error
}

func normalizeAISkillInput(in AISkillInput) (*model.AISkill, error) {
	code := strings.TrimSpace(in.Code)
	name := strings.TrimSpace(in.Name)
	if code == "" || name == "" {
		return nil, fmt.Errorf("%w: 技能编码与名称必填", ErrAIValidation)
	}
	if strings.TrimSpace(in.Instructions) == "" {
		return nil, fmt.Errorf("%w: 技能指引内容必填", ErrAIValidation)
	}
	role := strings.TrimSpace(in.RoleScope)
	if role != "caregiver" && role != "doctor" && role != "all" {
		role = "all"
	}
	version := strings.TrimSpace(in.Version)
	if version == "" {
		version = "1.0.0"
	}
	return &model.AISkill{
		RoleScope: role, Code: code, Name: name,
		Description: strings.TrimSpace(in.Description), Version: version, Tags: strings.TrimSpace(in.Tags),
		Instructions: strings.TrimSpace(in.Instructions), SortOrder: in.SortOrder, Enabled: in.Enabled,
	}, nil
}

func (s *AIService) reloadSkill(ctx context.Context, id uint) (*model.AISkill, error) {
	var skill model.AISkill
	if err := s.db.WithContext(ctx).First(&skill, id).Error; err != nil {
		return nil, err
	}
	return &skill, nil
}
