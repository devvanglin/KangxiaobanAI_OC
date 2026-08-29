package service

import (
	"context"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// FamilyService 家属绑定与账号管理。
type FamilyService struct {
	repo *repository.FamilyRepository
	db   *gorm.DB
}

func NewFamilyService(repo *repository.FamilyRepository, db *gorm.DB) *FamilyService {
	return &FamilyService{repo: repo, db: db}
}

// BoundElderIDs 该家属可查看的长者 id 集合。
func (s *FamilyService) BoundElderIDs(ctx context.Context, userID uint) ([]uint, error) {
	return s.repo.BoundElderIDs(ctx, userID)
}

// CreateMember 为家长建家属账号并绑定长者（已存在的绑定幂等跳过）。
func (s *FamilyService) CreateMember(ctx context.Context, username, password, realName, phone string, elderIDs []uint) (*model.User, error) {
	db := s.db.WithContext(ctx)
	var n int64
	if err := db.Model(&model.User{}).Where("username = ?", username).Count(&n).Error; err != nil {
		return nil, err
	}
	if n > 0 {
		return nil, errUsernameTaken
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	u := model.User{Username: username, PasswordHash: string(hash), RealName: realName, Phone: phone, Status: 1}
	if err := db.Create(&u).Error; err != nil {
		return nil, err
	}
	var famRole model.Role
	if err := db.Where("code = ?", "family").First(&famRole).Error; err != nil {
		return nil, err
	}
	if err := db.Model(&u).Association("Roles").Replace([]model.Role{famRole}); err != nil {
		return nil, err
	}
	for _, eid := range elderIDs {
		_ = s.repo.Bind(ctx, u.ID, eid)
	}
	u.PasswordHash = ""
	return &u, nil
}

var errUsernameTaken = &svcError{"用户名已存在"}

type svcError struct{ msg string }

func (e *svcError) Error() string { return e.msg }

// ListBindings 绑定列表（可按 elder_id 过滤），关联家长与长者信息。
func (s *FamilyService) ListBindings(ctx context.Context, elderID uint, page, size int) ([]model.FamilyElder, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.FamilyElder{})
	if elderID > 0 {
		q = q.Where("elder_id = ?", elderID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.FamilyElder
	err := q.Preload("User").Preload("Elder").Order("id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

// Unbind 解除家属与长者的绑定。
func (s *FamilyService) Unbind(ctx context.Context, userID, elderID uint) error {
	return s.db.WithContext(ctx).Where("user_id = ? AND elder_id = ?", userID, elderID).Delete(&model.FamilyElder{}).Error
}
