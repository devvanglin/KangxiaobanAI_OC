// comfort_service_test.go 安抚会话状态机、冷却、扫描与异常行为规则的单测。
package service

import (
	"context"
	"strings"
	"testing"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/model"
)

func newComfortTestService(t *testing.T) (*ComfortService, *gorm.DB, context.Context) {
	t.Helper()
	name := strings.NewReplacer("/", "_", " ", "_").Replace(t.Name())
	db, err := database.Connect(&config.DBConfig{Driver: "sqlite", SQLitePath: "file:" + name + "?mode=memory&cache=shared"})
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	db.Logger = logger.Default.LogMode(logger.Silent)
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := database.AutoMigrateAndSeed(db, false); err != nil {
		t.Fatalf("AutoMigrateAndSeed: %v", err)
	}
	ctx := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	return NewComfortService(db), db, ctx
}

func TestClassifyAbnormal(t *testing.T) {
	cases := []struct {
		behavior string
		want     string
	}{
		{behavior: "老人张牙舞爪，情绪激动", want: "张牙舞爪"},
		{behavior: "老人在走廊缓慢行走", want: ""},
		{behavior: "老人突然摔倒在地", want: "摔倒"},
		{behavior: "", want: ""},
	}
	for _, c := range cases {
		if got := classifyAbnormal(c.behavior); got != c.want {
			t.Fatalf("classifyAbnormal(%q) = %q, want %q", c.behavior, got, c.want)
		}
	}
}

func TestEmotionChineseCoversEmotiEffLibWordForms(t *testing.T) {
	// EmotiEffLib idx_to_emotion_class 实际输出词形（首字母大写名词）。
	cases := map[string]string{
		"Sadness": "悲伤", "Happiness": "高兴", "Anger": "愤怒", "Neutral": "中性",
		"Surprise": "惊讶", "Fear": "恐惧", "Disgust": "厌恶", "Contempt": "轻蔑",
	}
	for label, want := range cases {
		if got := emotionChinese(label); got != want {
			t.Fatalf("emotionChinese(%q) = %q, want %q", label, got, want)
		}
	}
}

func TestCreateForSadEmotionCooldown(t *testing.T) {
	svc, _, ctx := newComfortTestService(t)
	first, err := svc.CreateForSadEmotion(ctx, 1, 7, "cam-01", nil, 11, "悲伤", 0.83)
	if err != nil {
		t.Fatalf("CreateForSadEmotion: %v", err)
	}
	if first == nil || first.Status != ComfortStatusPending || first.ElderID != 7 {
		t.Fatalf("unexpected session: %+v", first)
	}
	second, err := svc.CreateForSadEmotion(ctx, 1, 7, "cam-01", nil, 12, "悲伤", 0.81)
	if err != nil {
		t.Fatalf("second CreateForSadEmotion: %v", err)
	}
	if second != nil {
		t.Fatalf("cooldown expected nil session, got %+v", second)
	}
}

func TestPendingAndTransitions(t *testing.T) {
	svc, _, ctx := newComfortTestService(t)
	session, err := svc.CreateForSadEmotion(ctx, 1, 9, "cam-02", nil, 21, "悲伤", 0.9)
	if err != nil {
		t.Fatalf("CreateForSadEmotion: %v", err)
	}

	pending, err := svc.PendingForElder(ctx, 9)
	if err != nil || pending == nil || pending.ID != session.ID {
		t.Fatalf("PendingForElder = %+v, %v", pending, err)
	}

	if _, err := svc.MarkResponded(ctx, session.ID, "嗯"); err == nil {
		t.Fatal("pending → responded must be rejected")
	}

	if _, err := svc.MarkTalking(ctx, session.ID); err != nil {
		t.Fatalf("MarkTalking: %v", err)
	}
	if pending, _ := svc.PendingForElder(ctx, 9); pending != nil {
		t.Fatalf("claimed session must not be returned again, got %+v", pending)
	}

	responded, err := svc.MarkResponded(ctx, session.ID, "我有点想家")
	if err != nil || responded.Status != ComfortStatusResponded || responded.Transcript != "我有点想家" {
		t.Fatalf("MarkResponded = %+v, %v", responded, err)
	}
}

func TestMarkNoResponseNotifiesCaregiver(t *testing.T) {
	svc, _, ctx := newComfortTestService(t)
	var notified []string
	svc.SetNotifier(func(ctx context.Context, tenantID uint, role, typ, title, content, severity string) error {
		notified = append(notified, role+"|"+typ+"|"+content)
		return nil
	})
	session, err := svc.CreateForSadEmotion(ctx, 1, 9, "cam-02", nil, 21, "悲伤", 0.9)
	if err != nil {
		t.Fatalf("CreateForSadEmotion: %v", err)
	}
	if _, err := svc.MarkTalking(ctx, session.ID); err != nil {
		t.Fatalf("MarkTalking: %v", err)
	}
	reported, err := svc.MarkNoResponse(ctx, session.ID)
	if err != nil || reported.Status != ComfortStatusReported {
		t.Fatalf("MarkNoResponse = %+v, %v", reported, err)
	}
	if len(notified) != 1 {
		t.Fatalf("exactly one notification expected, got %v", notified)
	}
	parts := strings.SplitN(notified[0], "|", 3)
	if len(parts) != 3 || parts[0] != "caregiver" || parts[1] != "comfort" {
		t.Fatalf("unexpected notification: %q", notified[0])
	}
	if !strings.Contains(parts[2], "无回应") {
		t.Fatalf("notification content should mention no response: %q", parts[2])
	}
}

func TestSweepReportsUnclaimedAndClosesStaleTalking(t *testing.T) {
	svc, db, ctx := newComfortTestService(t)
	var notified []string
	svc.SetNotifier(func(ctx context.Context, tenantID uint, role, typ, title, content, severity string) error {
		notified = append(notified, role+"|"+title)
		return nil
	})
	stalePending, err := svc.CreateForSadEmotion(ctx, 1, 9, "cam-02", nil, 21, "悲伤", 0.9)
	if err != nil {
		t.Fatalf("CreateForSadEmotion: %v", err)
	}
	staleTalking, err := svc.CreateForSadEmotion(ctx, 1, 10, "cam-02", nil, 22, "悲伤", 0.9)
	if err != nil {
		t.Fatalf("CreateForSadEmotion: %v", err)
	}
	if _, err := svc.MarkTalking(ctx, staleTalking.ID); err != nil {
		t.Fatalf("MarkTalking: %v", err)
	}
	backdated := time.Now().Add(-2 * time.Hour)
	if err := db.WithContext(ctx).Model(&model.ComfortSession{}).Where("id IN ?", []uint{stalePending.ID, staleTalking.ID}).
		UpdateColumn("created_at", backdated).Error; err != nil {
		t.Fatalf("backdate: %v", err)
	}
	if err := db.WithContext(ctx).Model(&model.ComfortSession{}).Where("id = ?", staleTalking.ID).
		UpdateColumn("updated_at", backdated).Error; err != nil {
		t.Fatalf("backdate talking: %v", err)
	}

	svc.sweep()

	var afterPending, afterTalking model.ComfortSession
	if err := db.WithContext(ctx).First(&afterPending, stalePending.ID).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx).First(&afterTalking, staleTalking.ID).Error; err != nil {
		t.Fatal(err)
	}
	if afterPending.Status != ComfortStatusReported {
		t.Fatalf("unclaimed pending should be reported, got %s", afterPending.Status)
	}
	if afterTalking.Status != ComfortStatusClosed {
		t.Fatalf("stale talking should be closed, got %s", afterTalking.Status)
	}
	if len(notified) != 1 || !strings.HasPrefix(notified[0], "caregiver|") {
		t.Fatalf("exactly one caregiver notification expected, got %v", notified)
	}
}
