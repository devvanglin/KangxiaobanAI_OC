// comfort_service.go 摄像头识别到悲伤表情后的主动语音安抚会话：
// 行为分析器创建 pending 会话 → 老人端设备轮询领取并执行 TTS 开场 + ASR 监听 →
// 老人有回应则继续对话；无回应或超时无人领取时通知护工。会话状态只反映
// 设备与扫描器的真实回报，不虚构进度。
package service

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strconv"
	"strings"
	"sync"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// ComfortNotifier 与 NotificationService.CreateRoleNotificationContext 对齐的通知回调。
type ComfortNotifier func(ctx context.Context, tenantID uint, role, typ, title, content, severity string) error

const (
	ComfortStatusPending   = "pending"
	ComfortStatusTalking   = "talking"
	ComfortStatusResponded = "responded"
	ComfortStatusReported  = "reported"
	ComfortStatusClosed    = "closed"
)

// ComfortService 悲伤表情触发的主动安抚会话存储与状态机。
type ComfortService struct {
	db       *gorm.DB
	notifier ComfortNotifier
	stop     chan struct{}
	once     sync.Once
}

func NewComfortService(db *gorm.DB) *ComfortService {
	return &ComfortService{db: db, stop: make(chan struct{})}
}

// SetNotifier 注入护工通知回调（cmd/server/main.go 装配）。
func (s *ComfortService) SetNotifier(n ComfortNotifier) { s.notifier = n }

// comfortCooldown 同一长者两次安抚的最小间隔；冷却期内的新事件只记录不触发。
func (s *ComfortService) comfortCooldown() time.Duration {
	return comfortMinutes("KXB_COMFORT_COOLDOWN_MINUTES", 30)
}

// comfortPendingTTL pending 会话等待设备领取的时限；超时由扫描器上报护工。
func (s *ComfortService) comfortPendingTTL() time.Duration {
	return comfortMinutes("KXB_COMFORT_PENDING_TTL_MINUTES", 10)
}

func comfortMinutes(key string, def int) time.Duration {
	if v := strings.TrimSpace(getEnv(key)); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return time.Duration(n) * time.Minute
		}
	}
	return time.Duration(def) * time.Minute
}

// CreateForSadEmotion 为悲伤表情事件创建安抚会话。冷却期内返回 (nil, nil)。
func (s *ComfortService) CreateForSadEmotion(ctx context.Context, tenantID, elderID uint,
	deviceID string, areaID *uint, eventID uint, expression string, similarity float64) (*model.ComfortSession, error) {
	tctx := context.WithValue(ctx, model.TenantContextKey, tenantID)
	var last model.ComfortSession
	err := s.db.WithContext(tctx).Where("elder_id = ?", elderID).Order("id DESC").First(&last).Error
	if err == nil && time.Since(last.CreatedAt) < s.comfortCooldown() {
		return nil, nil
	}
	session := model.ComfortSession{
		ElderID: elderID, DeviceID: deviceID, AreaID: areaID, BehaviorEventID: eventID,
		Trigger: "sad_emotion", Expression: expression, Similarity: similarity,
		Status: ComfortStatusPending,
	}
	if err := s.db.WithContext(tctx).Create(&session).Error; err != nil {
		return nil, err
	}
	return &session, nil
}

// PendingForElder 返回该长者最早一个未过期的 pending 会话；没有则返回 (nil, nil)。
func (s *ComfortService) PendingForElder(ctx context.Context, elderID uint) (*model.ComfortSession, error) {
	var session model.ComfortSession
	err := s.db.WithContext(ctx).
		Where("elder_id = ? AND status = ? AND created_at > ?",
			elderID, ComfortStatusPending, time.Now().Add(-s.comfortPendingTTL())).
		Order("id ASC").First(&session).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &session, nil
}

// MarkTalking 设备领取：pending → talking。
func (s *ComfortService) MarkTalking(ctx context.Context, id uint) (*model.ComfortSession, error) {
	return s.transition(ctx, id, ComfortStatusPending, ComfortStatusTalking, nil)
}

// MarkResponded 老人有语音回应：talking → responded，并记录第一句 ASR 文本。
func (s *ComfortService) MarkResponded(ctx context.Context, id uint, transcript string) (*model.ComfortSession, error) {
	now := time.Now()
	updates := map[string]interface{}{"transcript": transcript, "responded_at": &now}
	return s.transition(ctx, id, ComfortStatusTalking, ComfortStatusResponded, updates)
}

// MarkNoResponse 老人无回应：talking → reported，并通知护工前往查看。
func (s *ComfortService) MarkNoResponse(ctx context.Context, id uint) (*model.ComfortSession, error) {
	now := time.Now()
	session, err := s.transition(ctx, id, ComfortStatusTalking, ComfortStatusReported,
		map[string]interface{}{"reported_at": &now})
	if err != nil {
		return nil, err
	}
	s.notifyNoResponse(ctx, session, "设备主动安抚后未检测到语音回应，请前往查看")
	return session, nil
}

// notifyNoResponse 发护工通知；通知失败只记日志，不改变会话状态。
func (s *ComfortService) notifyNoResponse(ctx context.Context, session *model.ComfortSession, reason string) {
	if s.notifier == nil {
		return
	}
	name := s.elderName(ctx, session.ElderID)
	content := fmt.Sprintf("%s 主动语音安抚无回应：%s（摄像头 %s）", name, reason, session.DeviceID)
	if err := s.notifier(ctx, session.TenantID, "caregiver", "comfort", "长者情绪安抚无回应", content, "important"); err != nil {
		log.Printf("[comfort] notify caregiver: %v", err)
	}
}

func (s *ComfortService) elderName(ctx context.Context, elderID uint) string {
	var elder model.Elder
	if err := s.db.WithContext(ctx).Select("name").First(&elder, elderID).Error; err != nil {
		return fmt.Sprintf("长者%d", elderID)
	}
	return elder.Name
}

// transition 校验状态迁移并落库；状态不符返回错误（HTTP 409）。
func (s *ComfortService) transition(ctx context.Context, id uint, from, to string,
	extra map[string]interface{}) (*model.ComfortSession, error) {
	var session model.ComfortSession
	if err := s.db.WithContext(ctx).First(&session, id).Error; err != nil {
		return nil, err
	}
	if session.Status != from {
		return nil, fmt.Errorf("会话状态为 %s，不能变更为 %s", session.Status, to)
	}
	updates := map[string]interface{}{"status": to}
	for key, value := range extra {
		updates[key] = value
	}
	if err := s.db.WithContext(ctx).Model(&model.ComfortSession{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		return nil, err
	}
	// 重载以返回包含 transcript/reported_at 等额外字段的最新状态。
	if err := s.db.WithContext(ctx).First(&session, id).Error; err != nil {
		return nil, err
	}
	return &session, nil
}

// StartScanner 启动后台清理：超时未领取的 pending 会话上报护工；长时间无回报
// 的 talking 会话静默关闭（设备离线/中断，老人可能已由人工照看）。
func (s *ComfortService) StartScanner() {
	s.once.Do(func() {
		go func() {
			ticker := time.NewTicker(time.Minute)
			defer ticker.Stop()
			for {
				select {
				case <-s.stop:
					return
				case <-ticker.C:
					s.sweep()
				}
			}
		}()
	})
}

func (s *ComfortService) sweep() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	var tenants []model.Tenant
	if err := s.db.WithContext(ctx).Find(&tenants).Error; err != nil {
		return
	}
	for _, tenant := range tenants {
		s.sweepTenant(context.WithValue(ctx, model.TenantContextKey, tenant.ID))
	}
}

func (s *ComfortService) sweepTenant(ctx context.Context) {
	pendingCutoff := time.Now().Add(-s.comfortPendingTTL())
	var unclaimed []model.ComfortSession
	if err := s.db.WithContext(ctx).
		Where("status = ? AND created_at < ?", ComfortStatusPending, pendingCutoff).
		Find(&unclaimed).Error; err == nil {
		for _, stale := range unclaimed {
			now := time.Now()
			updates := map[string]interface{}{
				"status": ComfortStatusReported, "reported_at": &now,
				"error": "未在时限内被设备领取",
			}
			if err := s.db.WithContext(ctx).Model(&model.ComfortSession{}).
				Where("id = ? AND status = ?", stale.ID, ComfortStatusPending).Updates(updates).Error; err != nil {
				log.Printf("[comfort] sweep pending %d: %v", stale.ID, err)
				continue
			}
			session := stale
			session.Status = ComfortStatusReported
			s.notifyNoResponse(ctx, &session, "设备未能领取安抚任务（可能离线或未绑定），请人工前往查看")
		}
	}
	talkingCutoff := time.Now().Add(-30 * time.Minute)
	if err := s.db.WithContext(ctx).Model(&model.ComfortSession{}).
		Where("status = ? AND updated_at < ?", ComfortStatusTalking, talkingCutoff).
		Update("status", ComfortStatusClosed).Error; err != nil {
		log.Printf("[comfort] sweep talking: %v", err)
	}
}
