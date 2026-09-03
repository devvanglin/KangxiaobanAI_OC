package database

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

func TestRetiredFamilyArtifactsAreRemovedAcrossTenants(t *testing.T) {
	dsn := fmt.Sprintf("file:family_removal_%d?mode=memory&cache=shared", time.Now().UnixNano())
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := RegisterTenantScope(db); err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("PRAGMA foreign_keys = ON").Error; err != nil {
		t.Fatal(err)
	}
	if err := model.AutoMigrateAll(db); err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&model.Tenant{Base: model.Base{ID: 2, TenantID: 2}, Code: "family-removal-two", Name: "二号机构", Status: 1}).Error; err != nil {
		t.Fatal(err)
	}

	role := model.Role{Code: "family", Name: "家属", Description: "历史角色"}
	if err := db.Create(&role).Error; err != nil {
		t.Fatal(err)
	}
	ctx1 := context.WithValue(context.Background(), model.TenantContextKey, uint(1))
	ctx2 := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	legacyElder := model.Elder{Name: "历史长者", Status: 1}
	if err := db.WithContext(ctx2).Create(&legacyElder).Error; err != nil {
		t.Fatal(err)
	}
	familyOne := model.User{Username: "family", PasswordHash: "retired-family-hash", RealName: "历史家属一", Status: 1}
	if err := db.WithContext(ctx1).Create(&familyOne).Error; err != nil {
		t.Fatal(err)
	}
	familyTwo := model.User{Username: "family_demo", PasswordHash: "retired-family-demo-hash", RealName: "历史家属二", Status: 1}
	if err := db.WithContext(ctx2).Create(&familyTwo).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO sys_user_role (user_id, role_id) VALUES (?, ?), (?, ?)", familyOne.ID, role.ID, familyTwo.ID, role.ID).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx2).Create(&model.Message{SenderID: familyTwo.ID, ReceiverID: familyOne.ID, Content: "历史家属消息", SentAt: time.Now()}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx2).Create(&model.Notification{UserID: familyTwo.ID, Title: "历史家属通知", Content: "历史数据", SentAt: timePtr(time.Now())}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.WithContext(ctx2).Create(&model.AIPromptSuggestion{Code: "family-follow-up", Title: "历史家属提示", Prompt: "历史数据", Enabled: true}).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("CREATE TABLE family_elders (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), elder_id INTEGER NOT NULL REFERENCES elders(id))").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("INSERT INTO family_elders (user_id, elder_id) VALUES (?, ?)", familyTwo.ID, legacyElder.ID).Error; err != nil {
		t.Fatal(err)
	}

	if err := AutoMigrateAndSeed(db, false); err != nil {
		t.Fatal(err)
	}

	for _, tc := range []struct {
		name string
		ctx  context.Context
		user string
	}{
		{name: "tenant one family", ctx: ctx1, user: "family"},
		{name: "tenant two family demo", ctx: ctx2, user: "family_demo"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var user model.User
			if err := db.WithContext(tc.ctx).Where("username = ?", tc.user).First(&user).Error; err != gorm.ErrRecordNotFound {
				t.Fatalf("retired family user remains visible: user=%q err=%v", tc.user, err)
			}
		})
	}
	var visibleRoleCount int64
	if err := db.Model(&model.Role{}).Where("code = ?", "family").Count(&visibleRoleCount).Error; err != nil {
		t.Fatal(err)
	}
	if visibleRoleCount != 0 {
		t.Fatalf("retired family role remains visible: %d", visibleRoleCount)
	}
	var messageCount int64
	if err := db.WithContext(ctx2).Model(&model.Message{}).Where("content = ?", "历史家属消息").Count(&messageCount).Error; err != nil {
		t.Fatal(err)
	}
	if messageCount != 0 {
		t.Fatalf("retired family message remains: %d", messageCount)
	}
	var promptCount int64
	if err := db.WithContext(ctx2).Model(&model.AIPromptSuggestion{}).Where("code = ?", "family-follow-up").Count(&promptCount).Error; err != nil {
		t.Fatal(err)
	}
	if promptCount != 0 {
		t.Fatalf("retired family prompt remains: %d", promptCount)
	}
	if db.Migrator().HasTable("family_elders") {
		t.Fatal("retired family_elders table remains")
	}
}

func timePtr(value time.Time) *time.Time {
	return &value
}
