// face_enroll_service.go 把入住建档上传的【人像照】注册到 DGX 人脸识别服务，
// 作为后续摄像头画面身份比对（InsightFace）的底照。注册是尽力而为的异步动作：
// 失败会记录在 face_enrollments，可由管理端重试，绝不阻塞入住办理。
package service

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/face"
	"kangxiaoban-service/internal/model"
)

// FacePersonID 生成人脸服务里的固定 person_id（契约：elder-<ID>）。
func FacePersonID(elderID uint) string {
	return fmt.Sprintf("elder-%d", elderID)
}

// FaceEnrollService 注册/查询长者人脸底照。
type FaceEnrollService struct {
	db      *gorm.DB
	cfg     config.FaceConfig
	rootDir string
}

func NewFaceEnrollService(db *gorm.DB, cfg config.FaceConfig, rootDir string) *FaceEnrollService {
	return &FaceEnrollService{db: db, cfg: cfg, rootDir: rootDir}
}

// FaceEnrollmentView 是给前端的注册状态。
type FaceEnrollmentView struct {
	ElderID   uint       `json:"elder_id"`
	PersonID  string     `json:"person_id"`
	Status    string     `json:"status"` // pending/ok/failed
	Error     string     `json:"error,omitempty"`
	EnrolledAt *time.Time `json:"enrolled_at,omitempty"`
}

// EnrollElderFromPortrait 找到该长者最近的入住人像照并注册人脸。同步执行，
// 调用方（入住 handler）应以 goroutine 触发。
func (s *FaceEnrollService) EnrollElderFromPortrait(ctx context.Context, elderID uint) *FaceEnrollmentView {
	view := &FaceEnrollmentView{ElderID: elderID, PersonID: FacePersonID(elderID), Status: "failed"}
	defer func() { s.recordResult(ctx, view) }()

	if !s.cfg.Enabled || strings.TrimSpace(s.cfg.BaseURL) == "" {
		view.Error = "人脸服务未启用"
		return view
	}
	var photo model.AdmissionIntakePhoto
	err := s.db.WithContext(ctx).
		Where("tenant_id = ? AND elder_id = ? AND kind = ?", tenantIDFromContext(ctx), elderID, "portrait").
		Order("id DESC").First(&photo).Error
	if err != nil {
		view.Error = "未找到入住人像照"
		return view
	}
	raw, err := os.ReadFile(filepath.Join(s.rootDir, filepath.FromSlash(photo.StorageKey)))
	if err != nil {
		view.Error = "人像照文件读取失败"
		return view
	}
	if err := face.New(s.cfg.BaseURL).Enroll(ctx, FacePersonID(elderID), raw); err != nil {
		view.Error = fmt.Sprintf("人脸注册失败: %v", err)
		return view
	}
	view.Status = "ok"
	now := time.Now()
	view.EnrolledAt = &now
	return view
}

// recordResult 把每次注册结果 upsert 进 face_enrollments（每长者一行）。
func (s *FaceEnrollService) recordResult(ctx context.Context, view *FaceEnrollmentView) {
	var row model.FaceEnrollment
	err := s.db.WithContext(ctx).Where("elder_id = ?", view.ElderID).First(&row).Error
	updates := map[string]interface{}{
		"person_id":  view.PersonID,
		"status":     view.Status,
		"error":      view.Error,
		"enrolled_at": time.Now(),
	}
	if err != nil {
		row = model.FaceEnrollment{
			ElderID: view.ElderID, PersonID: view.PersonID,
			Status: view.Status, Error: view.Error, EnrolledAt: time.Now(),
		}
		_ = s.db.WithContext(ctx).Create(&row).Error
		return
	}
	_ = s.db.WithContext(ctx).Model(&model.FaceEnrollment{}).Where("id = ?", row.ID).Updates(updates).Error
}

// FaceEnrollment 查询长者的注册状态。
func (s *FaceEnrollService) Enrollment(ctx context.Context, elderID uint) (*FaceEnrollmentView, error) {
	var row model.FaceEnrollment
	err := s.db.WithContext(ctx).Where("elder_id = ?", elderID).First(&row).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return &FaceEnrollmentView{ElderID: elderID, PersonID: FacePersonID(elderID), Status: "pending"}, nil
		}
		return nil, err
	}
	return &FaceEnrollmentView{
		ElderID: row.ElderID, PersonID: row.PersonID, Status: row.Status,
		Error: row.Error, EnrolledAt: &row.EnrolledAt,
	}, nil
}
