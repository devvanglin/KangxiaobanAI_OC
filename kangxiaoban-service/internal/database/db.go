package database

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	mysqlDriver "gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/glebarez/sqlite"
	"golang.org/x/crypto/bcrypt"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
)

const defaultAccountPassword = "123456"

// Connect 根据配置驱动建立 GORM 连接。
// 开发默认 sqlite（无外部依赖，开箱即跑），生产用 mysql（配置 KXB_DB_DRIVER=mysql）。
func Connect(cfg *config.DBConfig) (*gorm.DB, error) {
	var (
		db  *gorm.DB
		err error
	)
	gc := &gorm.Config{Logger: logger.Default.LogMode(logger.Warn)}

	switch cfg.Driver {
	case "sqlite":
		db, err = gorm.Open(sqlite.Open(cfg.SQLitePath), gc)
	case "mysql":
		db, err = gorm.Open(mysqlDriver.Open(cfg.MySQLDSN), gc)
	default:
		return nil, errors.New("unsupported KXB_DB_DRIVER, use sqlite or mysql")
	}
	if err != nil {
		return nil, fmt.Errorf("open db (%s): %w", cfg.Driver, err)
	}
	if cfg.Driver == "sqlite" {
		if err := configureSQLite(db, cfg.SQLitePath); err != nil {
			return nil, err
		}
	}
	if err := RegisterTenantScope(db); err != nil {
		return nil, fmt.Errorf("register tenant scope: %w", err)
	}
	return db, nil
}

const sqliteBusyTimeout = 5000

// configureSQLite keeps the embedded database deterministic when the HTTP
// handlers and the IoT scanners access it at the same time.  SQLite permits
// many readers but only one writer; a single pooled connection plus WAL and a
// bounded busy timeout prevents lock errors from turning into an unbounded
// request wait.  In-memory test databases do not support WAL, so only the
// timeout is applied there.
func configureSQLite(db *gorm.DB, path string) error {
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("get sqlite connection: %w", err)
	}
	// Sharing one connection is intentional for the default local SQLite
	// deployment. It serializes writes and avoids a second connection waiting
	// forever on a lock held by the first one.
	sqlDB.SetMaxOpenConns(1)
	sqlDB.SetMaxIdleConns(1)

	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("ping sqlite: %w", err)
	}
	if err := db.Exec(fmt.Sprintf("PRAGMA busy_timeout = %d", sqliteBusyTimeout)).Error; err != nil {
		return fmt.Errorf("configure sqlite busy timeout: %w", err)
	}
	pathLower := strings.ToLower(path)
	if !strings.Contains(pathLower, ":memory:") && !strings.Contains(pathLower, "mode=memory") {
		if err := db.Exec("PRAGMA journal_mode = WAL").Error; err != nil {
			return fmt.Errorf("configure sqlite journal mode: %w", err)
		}
		if err := db.Exec("PRAGMA synchronous = NORMAL").Error; err != nil {
			return fmt.Errorf("configure sqlite synchronous mode: %w", err)
		}
	}
	return nil
}

// AutoMigrateAndSeed 建表并注入角色、权限、账号和可选的业务初始数据。
func AutoMigrateAndSeed(db *gorm.DB, seedBusiness bool) error {
	if err := model.AutoMigrateAll(db); err != nil {
		return fmt.Errorf("auto migrate: %w", err)
	}
	// 单机构历史库统一迁移到默认租户，避免新增 tenant_id 后出现不可见数据。
	if err := ensureDefaultTenant(db); err != nil {
		return fmt.Errorf("ensure default tenant: %w", err)
	}
	if err := ensureAIPromptSuggestionConstraint(db); err != nil {
		return fmt.Errorf("ensure AI prompt suggestion constraint: %w", err)
	}
	if err := seedAIPromptSuggestions(db); err != nil {
		return fmt.Errorf("seed AI prompt suggestions: %w", err)
	}
	if err := seedOperationPolicies(db); err != nil {
		return fmt.Errorf("seed operation policies: %w", err)
	}
	if err := ensureBillingRateConstraint(db); err != nil {
		return fmt.Errorf("ensure billing rate constraint: %w", err)
	}
	if err := seedBillingRates(db); err != nil {
		return fmt.Errorf("seed billing rates: %w", err)
	}
	if err := ensureHealthThresholdConstraint(db); err != nil {
		return fmt.Errorf("ensure health threshold constraint: %w", err)
	}
	if err := seedHealthThresholds(db); err != nil {
		return fmt.Errorf("seed health thresholds: %w", err)
	}
	if err := ensureElderIdentityConstraint(db); err != nil {
		return fmt.Errorf("ensure elder identity constraint: %w", err)
	}
	if err := ensureAdmissionIntakeConstraint(db); err != nil {
		return fmt.Errorf("ensure admission intake constraint: %w", err)
	}
	if err := ensureAdmissionPhotoConstraint(db); err != nil {
		return fmt.Errorf("ensure admission photo constraint: %w", err)
	}
	if err := seed(db); err != nil {
		return err
	}
	// A/B/C 表单定义属于正式参考数据，不受业务初始数据开关影响。
	if err := seedAdmissionReferenceData(db); err != nil {
		return fmt.Errorf("seed admission reference data: %w", err)
	}
	if err := seedCoreBusinessData(db); err != nil {
		return err
	}
	if err := ensureBusinessRelations(db); err != nil {
		return fmt.Errorf("ensure business relations: %w", err)
	}
	if seedBusiness {
		if err := seedBusinessData(db); err != nil {
			return err
		}
	}
	if err := backfillBusinessFields(db); err != nil {
		return fmt.Errorf("backfill business fields: %w", err)
	}
	return nil
}

// ensureHealthThresholdConstraint keeps one active rule per metric and tenant.
// The application lookup remains useful for preserving configured values, while
// this database guard closes concurrent initialization and update races.
func ensureHealthThresholdConstraint(db *gorm.DB) error {
	type duplicate struct {
		TenantID uint
		Metric   string
		Count    int64
	}
	var duplicates []duplicate
	if err := db.Raw("SELECT tenant_id, metric, COUNT(*) AS count FROM health_thresholds WHERE deleted_at IS NULL GROUP BY tenant_id, metric HAVING COUNT(*) > 1").Scan(&duplicates).Error; err != nil {
		return err
	}
	if len(duplicates) > 0 {
		return fmt.Errorf("duplicate active health threshold in tenant %d: %s", duplicates[0].TenantID, duplicates[0].Metric)
	}
	switch db.Dialector.Name() {
	case "sqlite":
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_health_thresholds_tenant_metric ON health_thresholds(tenant_id, metric) WHERE deleted_at IS NULL").Error
	case "mysql":
		if !db.Migrator().HasColumn(&model.HealthThreshold{}, "active_metric") {
			if err := db.Exec("ALTER TABLE health_thresholds ADD COLUMN active_metric VARCHAR(32) GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL THEN metric ELSE NULL END) STORED").Error; err != nil {
				return err
			}
		}
		if !db.Migrator().HasIndex(&model.HealthThreshold{}, "uk_health_thresholds_tenant_metric") {
			if err := db.Exec("CREATE UNIQUE INDEX uk_health_thresholds_tenant_metric ON health_thresholds(tenant_id, active_metric)").Error; err != nil {
				return err
			}
		}
		return nil
	default:
		return fmt.Errorf("unsupported database driver %q", db.Dialector.Name())
	}
}

// ensureElderIdentityConstraint prevents two active elders in the same tenant
// from sharing a non-empty ID card. The application check in the admission
// service is retained for a friendly validation error; this database guard
// closes the concurrent-write race.
func ensureElderIdentityConstraint(db *gorm.DB) error {
	type duplicate struct {
		TenantID uint
		IDCard   string
		Count    int64
	}
	var duplicates []duplicate
	if err := db.Raw("SELECT tenant_id, id_card, COUNT(*) AS count FROM elders WHERE id_card <> '' AND deleted_at IS NULL GROUP BY tenant_id, id_card HAVING COUNT(*) > 1").Scan(&duplicates).Error; err != nil {
		return err
	}
	if len(duplicates) > 0 {
		return fmt.Errorf("duplicate active elder id_card in tenant %d: %s", duplicates[0].TenantID, duplicates[0].IDCard)
	}
	switch db.Dialector.Name() {
	case "sqlite":
		return db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS uk_elders_tenant_id_card ON elders(tenant_id, id_card) WHERE id_card <> '' AND deleted_at IS NULL").Error
	case "mysql":
		// MySQL/MariaDB do not support SQLite's partial-index predicate. A
		// generated nullable value preserves duplicate blank/deleted records
		// while enforcing active non-empty identities.
		if !db.Migrator().HasColumn(&model.Elder{}, "active_id_card") {
			if err := db.Exec("ALTER TABLE elders ADD COLUMN active_id_card VARCHAR(28) GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL AND id_card <> '' THEN id_card ELSE NULL END) STORED").Error; err != nil {
				return err
			}
		}
		if !db.Migrator().HasIndex(&model.Elder{}, "uk_elders_tenant_active_id_card") {
			if err := db.Exec("CREATE UNIQUE INDEX uk_elders_tenant_active_id_card ON elders(tenant_id, active_id_card)").Error; err != nil {
				return err
			}
		}
		return nil
	default:
		return fmt.Errorf("unsupported database driver %q", db.Dialector.Name())
	}
}

func ensureDefaultTenant(db *gorm.DB) error {
	var tenant model.Tenant
	if err := db.Where("id = ?", 1).First(&tenant).Error; err != nil {
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		tenant = model.Tenant{Base: model.Base{ID: 1, TenantID: 1}, Code: "default", Name: "默认机构", Status: 1}
		if err := db.Create(&tenant).Error; err != nil {
			return err
		}
	}
	// GORM 默认值通常会填充历史行；显式修复可能遗留的 0 值。
	// This is a startup-wide repair, not a tenant-scoped request. Use the
	// private migration context so the tenant callback does not turn the
	// predicate into `tenant_id = 0 AND tenant_id = 1`.
	backfillDB := db.WithContext(withoutTenantScope(context.Background()))
	for _, table := range []interface{}{&model.User{}, &model.Role{}, &model.Permission{}, &model.AuditLog{}, &model.Elder{}, &model.Room{}, &model.Bed{}, &model.CareTask{}, &model.HealthRecord{}, &model.HealthThreshold{}, &model.Assessment{}, &model.CarePlan{}, &model.CarePlanItem{}, &model.CareExecution{}, &model.Incident{}, &model.AssessmentTemplate{}, &model.AssessmentQuestion{}, &model.AssessmentOption{}, &model.AdmissionDictionaryItem{}, &model.AdmissionCarePlanTemplate{}, &model.AdmissionAssessment{}, &model.AdmissionAssessmentAnswer{}, &model.AdmissionScreening{}, &model.AdmissionScreeningAnswer{}, &model.AdmissionIntake{}, &model.AdmissionIntakePhoto{}, &model.IotDevice{}, &model.SignalRecord{}, &model.Alert{}, &model.AlertAction{}, &model.Notification{}, &model.Schedule{}, &model.ShiftHandover{}, &model.BillingRate{}, &model.Bill{}, &model.FundFlow{}, &model.MedicationRecord{}, &model.MedicineStock{}, &model.DiningOrder{}, &model.FamilyElder{}, &model.Message{}, &model.OperationPolicy{}, &model.AIPromptSuggestion{}, &model.AIConversation{}, &model.AIMessage{}} {
		if err := backfillDB.Model(table).Where("tenant_id = 0").Update("tenant_id", 1).Error; err != nil {
			return err
		}
	}
	return nil
}

func seed(db *gorm.DB) error {
	if err := migrateLegacyAccountNames(db); err != nil {
		return err
	}
	// 权限：M0-M1 核心权限集；后续里程碑扩展。
	perms := []struct{ code, name string }{
		{"dash:read", "工作台查看"},
		{"elder:read", "长者档案查看"},
		{"elder:write", "长者档案编辑"},
		{"task:read", "任务查看"},
		{"task:write", "任务处理"},
		{"care:review", "护理执行复核"},
		{"health:read", "体征查看"},
		{"health:write", "体征录入"},
		{"alert:read", "告警查看"},
		{"admission:read", "入住评估查看"},
		{"admission:write", "入住评估办理"},
		{"admin:all", "系统管理"},
	}
	permByCode := map[string]model.Permission{}
	for _, p := range perms {
		var perm model.Permission
		if err := db.Where("code = ?", p.code).FirstOrCreate(&perm, model.Permission{Code: p.code, Name: p.name}).Error; err != nil {
			return err
		}
		permByCode[p.code] = perm
	}

	// 角色：管理员拥有全部权限；医师/护工按业务范围授权。
	roles := []struct {
		code, name, desc string
		permCodes        []string
	}{
		{"admin", "管理员", "系统管理与全部业务", []string{
			"dash:read", "elder:read", "elder:write", "task:read", "task:write",
			"care:review", "health:read", "health:write", "alert:read", "admission:read", "admission:write", "admin:all"}},
		{"doctor", "医师", "看护与评估", []string{
			"dash:read", "elder:read", "health:read", "task:read", "care:review", "alert:read", "admission:read", "admission:write"}},
		{"caregiver", "护工", "现场护理", []string{
			"dash:read", "elder:read", "health:read", "health:write",
			"task:read", "task:write", "alert:read"}},
		{"family", "家属", "仅查看绑定长者", []string{
			"elder:read", "health:read", "task:read", "alert:read"}},
	}
	for _, r := range roles {
		var role model.Role
		if err := db.Where("code = ?", r.code).FirstOrCreate(&role, model.Role{Code: r.code, Name: r.name, Description: r.desc}).Error; err != nil {
			return err
		}
		if err := db.Model(&role).Association("Permissions").Replace(permRefs(permByCode, r.permCodes)); err != nil {
			return err
		}
	}

	// 默认管理员账号 admin / 123456（生产必须改并注入密钥）。
	var admin model.User
	if err := db.Where("username = ?", "admin").First(&admin).Error; err != nil {
		hash, err2 := bcrypt.GenerateFromPassword([]byte(defaultAccountPassword), bcrypt.DefaultCost)
		if err2 != nil {
			return err2
		}
		admin = model.User{
			Base:         model.Base{},
			Username:     "admin",
			PasswordHash: string(hash),
			RealName:     "系统管理员",
			Status:       1,
		}
		if err := db.Create(&admin).Error; err != nil {
			return err
		}
		var adminRole model.Role
		if err := db.Where("code = ?", "admin").First(&adminRole).Error; err != nil {
			return err
		}
		if err := db.Model(&admin).Association("Roles").Replace([]model.Role{adminRole}); err != nil {
			return err
		}
	}
	_ = admin

	// 正式家属账号 family / 123456，角色 family
	var family model.User
	if err := db.Where("username = ?", "family").First(&family).Error; err != nil {
		hash, err2 := bcrypt.GenerateFromPassword([]byte(defaultAccountPassword), bcrypt.DefaultCost)
		if err2 != nil {
			return err2
		}
		family = model.User{Username: "family", PasswordHash: string(hash), RealName: "张伟", Phone: "13800000001", Status: 1}
		if err := db.Create(&family).Error; err != nil {
			return err
		}
		var famRole model.Role
		if err := db.Where("code = ?", "family").First(&famRole).Error; err != nil {
			return err
		}
		if err := db.Model(&family).Association("Roles").Replace([]model.Role{famRole}); err != nil {
			return err
		}
	}
	if strings.TrimSpace(family.Phone) == "" {
		if err := db.Model(&family).Update("phone", "13800000001").Error; err != nil {
			return err
		}
		family.Phone = "13800000001"
	}
	_ = family
	if strings.TrimSpace(family.Phone) == "" {
		if err := db.Model(&family).Update("phone", "13800000001").Error; err != nil {
			return err
		}
	}

	// 客户端支持的正式账号；生产环境请按机构策略修改密码。
	formalUsers := []struct {
		username, password, realName, roleCode string
	}{
		{"xiaoli", defaultAccountPassword, "护理员", "caregiver"},
		{"xiaomo", defaultAccountPassword, "医师", "doctor"},
	}
	for _, userSeed := range formalUsers {
		var u model.User
		if err := db.Where("username = ?", userSeed.username).First(&u).Error; err == nil {
			continue
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(userSeed.password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		u = model.User{Username: userSeed.username, PasswordHash: string(hash), RealName: userSeed.realName, Status: 1}
		if err := db.Create(&u).Error; err != nil {
			return err
		}
		var role model.Role
		if err := db.Where("code = ?", userSeed.roleCode).First(&role).Error; err != nil {
			return err
		}
		if err := db.Model(&u).Association("Roles").Replace([]model.Role{role}); err != nil {
			return err
		}
	}
	return nil
}

// migrateLegacyAccountNames 将旧版本的 *_demo 账号改为正式账号，并合并重复账号。
// 迁移保留旧账号的密码和业务历史；当正式账号已存在时，先将所有 user_id
// 引用合并到正式账号，再删除旧账号，避免家属绑定、消息和审计记录悬挂。
func migrateLegacyAccountNames(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		rename := func(oldName, newName string) error {
			var oldUser model.User
			if err := tx.Where("username = ?", oldName).First(&oldUser).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					return nil
				}
				return err
			}
			var newUser model.User
			if err := tx.Where("username = ?", newName).First(&newUser).Error; err == nil {
				if oldUser.ID == newUser.ID {
					return nil
				}
				if err := rebindUserReferences(tx, oldUser.ID, newUser.ID); err != nil {
					return err
				}
				return tx.Delete(&oldUser).Error
			} else if !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
			return tx.Model(&oldUser).Update("username", newName).Error
		}
		for _, names := range [][2]string{
			{"caregiver_demo", "xiaoli"},
			{"doctor_demo", "xiaomo"},
			{"family_demo", "family"},
			{"caregiver", "xiaoli"},
			{"doctor", "xiaomo"},
		} {
			if err := rename(names[0], names[1]); err != nil {
				return err
			}
		}
		// Convert admin_demo as well. If a formal admin already exists, retain its
		// audit/history references before removing the duplicate legacy account.
		var legacyAdmin model.User
		if err := tx.Where("username = ?", "admin_demo").First(&legacyAdmin).Error; err == nil {
			var admin model.User
			adminErr := tx.Where("username = ?", "admin").First(&admin).Error
			if adminErr == nil {
				if err := rebindUserReferences(tx, legacyAdmin.ID, admin.ID); err != nil {
					return err
				}
				if err := tx.Delete(&legacyAdmin).Error; err != nil {
					return err
				}
			} else if !errors.Is(adminErr, gorm.ErrRecordNotFound) {
				return adminErr
			} else if err := tx.Model(&legacyAdmin).Update("username", "admin").Error; err != nil {
				return err
			}
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		// Older deployments renamed *_demo usernames but retained their demo
		// display names. Normalize only those known seed aliases; an institution's
		// unrelated custom display name must remain untouched.
		for _, item := range []struct {
			username string
			aliases  []string
			formal   string
		}{
			{username: "xiaoli", aliases: []string{"演示护工", "演示护理员", "Demo Caregiver"}, formal: "护理员"},
			{username: "xiaomo", aliases: []string{"演示医师", "演示医生", "Demo Doctor"}, formal: "医师"},
			{username: "family", aliases: []string{"演示家属", "Demo Family"}, formal: "家属"},
		} {
			var user model.User
			if err := tx.Where("username = ?", item.username).First(&user).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					continue
				}
				return err
			}
			for _, alias := range item.aliases {
				if strings.TrimSpace(user.RealName) == alias {
					if err := tx.Model(&user).Update("real_name", item.formal).Error; err != nil {
						return err
					}
					break
				}
			}
		}
		return nil
	})
}

// rebindUserReferences merges role memberships and every persisted user-ID
// reference before a legacy account is removed. The explicit list mirrors the
// model fields rather than relying on database-specific foreign-key cascades.
func rebindUserReferences(tx *gorm.DB, oldID, newID uint) error {
	var roleIDs []uint
	if err := tx.Table("sys_user_role").Where("user_id = ?", oldID).Pluck("role_id", &roleIDs).Error; err != nil {
		return err
	}
	for _, roleID := range roleIDs {
		var existing int64
		if err := tx.Table("sys_user_role").Where("user_id = ? AND role_id = ?", newID, roleID).Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 {
			if err := tx.Exec("DELETE FROM sys_user_role WHERE user_id = ? AND role_id = ?", oldID, roleID).Error; err != nil {
				return err
			}
			continue
		}
		if err := tx.Table("sys_user_role").Where("user_id = ? AND role_id = ?", oldID, roleID).Update("user_id", newID).Error; err != nil {
			return err
		}
	}

	// FamilyElder has a unique (user_id, elder_id) key, so merge duplicate
	// bindings one row at a time before changing the user ID.
	var familyBindings []model.FamilyElder
	if err := tx.Where("user_id = ?", oldID).Find(&familyBindings).Error; err != nil {
		return err
	}
	for _, binding := range familyBindings {
		var existing int64
		if err := tx.Model(&model.FamilyElder{}).Where("user_id = ? AND elder_id = ?", newID, binding.ElderID).Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 {
			if err := tx.Delete(&binding).Error; err != nil {
				return err
			}
		} else if err := tx.Model(&model.FamilyElder{}).Where("id = ?", binding.ID).Update("user_id", newID).Error; err != nil {
			return err
		}
	}

	for _, reference := range []struct {
		model  interface{}
		column string
	}{
		{&model.AuditLog{}, "user_id"},
		{&model.AlertAction{}, "user_id"},
		{&model.Notification{}, "user_id"},
		{&model.Message{}, "sender_id"},
		{&model.Message{}, "receiver_id"},
		{&model.AIConversation{}, "user_id"},
		{&model.AIMessage{}, "user_id"},
		{&model.CareTask{}, "assignee_id"},
		{&model.CarePlan{}, "created_by"},
		{&model.CarePlanItem{}, "assignee_id"},
		{&model.CareExecution{}, "executor_id"},
		{&model.CareExecution{}, "reviewed_by"},
		{&model.Assessment{}, "assessor_id"},
		{&model.Incident{}, "owner_id"},
		{&model.AdmissionAssessment{}, "assessor_id"},
		{&model.AdmissionScreening{}, "assessor_id"},
	} {
		if err := tx.Model(reference.model).Where(reference.column+" = ?", oldID).Update(reference.column, newID).Error; err != nil {
			return err
		}
	}

	return nil
}

func permRefs(byCode map[string]model.Permission, codes []string) []model.Permission {
	out := make([]model.Permission, 0, len(codes))
	for _, c := range codes {
		if p, ok := byCode[c]; ok {
			out = append(out, p)
		}
	}
	return out
}

// seedCoreBusinessData 写入房间、床位、长者、任务和体征的关联初始数据，仅空库执行。
func seedCoreBusinessData(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		return seedCoreBusinessDataTx(tx)
	})
}

func seedCoreBusinessDataTx(db *gorm.DB) error {
	var count int64
	if err := db.Model(&model.Room{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	// 楼栋 A 一层 101/102 房间，各两床
	rooms := []model.Room{
		{Building: "A", Floor: 1, RoomNo: "101", Type: "normal", Status: "free"},
		{Building: "A", Floor: 1, RoomNo: "102", Type: "nursing", Status: "free"},
	}
	for i := range rooms {
		if err := db.Create(&rooms[i]).Error; err != nil {
			return err
		}
		for _, bedNo := range []string{"1", "2"} {
			if err := db.Create(&model.Bed{RoomID: rooms[i].ID, BedNo: bedNo, Status: "free"}).Error; err != nil {
				return err
			}
		}
	}

	beds := make([]model.Bed, 0)
	if err := db.Where("room_id IN ?", []uint{rooms[0].ID, rooms[1].ID}).Order("id").Find(&beds).Error; err != nil {
		return err
	}
	binding := []model.Elder{
		{Name: "张素英", Gender: "F", BirthDate: "1938-05-12", ContactPhone: "13800000001", CareLevel: 3, Status: 2, IDCard: "110101193805120011",
			EmergencyContacts: []model.ElderContact{{Name: "张伟", Relation: "儿子", Phone: "13800000001", IsEmergency: true}}, Allergies: []string{"青霉素"}},
		{Name: "王建国", Gender: "M", BirthDate: "1945-11-02", ContactPhone: "13800000002", CareLevel: 2, Status: 2, IDCard: "110101194511020012",
			EmergencyContacts: []model.ElderContact{{Name: "王芳", Relation: "女儿", Phone: "13800000002", IsEmergency: true}}, Allergies: []string{}},
	}
	for i := range binding {
		if err := db.Create(&binding[i]).Error; err != nil {
			return err
		}
		if i < len(beds) {
			bid := beds[i].ID
			binding[i].BedID = &bid
			if err := db.Model(&binding[i]).Update("bed_id", bid).Error; err != nil {
				return err
			}
			if err := db.Model(&beds[i]).Updates(map[string]interface{}{"status": "occupied", "elder_id": binding[i].ID}).Error; err != nil {
				return err
			}
		}
	}

	now := time.Now()
	caregiverName := formalUserDisplayName(db, "xiaoli", "护理员")
	firstDueAt := time.Date(now.Year(), now.Month(), now.Day(), 8, 30, 0, 0, now.Location())
	secondDueAt := time.Date(now.Year(), now.Month(), now.Day(), 10, 0, 0, 0, now.Location())
	tasks := []model.CareTask{{ElderID: binding[0].ID, Title: "早间翻身", Kind: "turnover", Category: "todo", Priority: "warning", Assignee: caregiverName, DueAt: &firstDueAt, Status: "todo", Remark: bootstrapTurnoverInstructions}}
	if len(binding) > 1 {
		tasks = append(tasks, model.CareTask{ElderID: binding[1].ID, Title: "服用降压药", Kind: "medication", Category: "medication", Priority: "warning", Assignee: caregiverName, DueAt: &secondDueAt, Status: "todo", Remark: bootstrapMedicationInstructions})
	}
	if err := db.Create(&tasks).Error; err != nil {
		return err
	}

	// 家属绑定：family 仅绑定长者1，用于验证数据隔离
	var fam model.User
	if err := db.Where("username = ?", "family").First(&fam).Error; err == nil {
		if err := db.FirstOrCreate(&model.FamilyElder{UserID: fam.ID, ElderID: binding[0].ID}, model.FamilyElder{UserID: fam.ID, ElderID: binding[0].ID}).Error; err != nil {
			return err
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	health := []model.HealthRecord{{ElderID: binding[0].ID, Temperature: fp(36.6), Systolic: pi(132), Diastolic: pi(82), HeartRate: pi(78), Spo2: fp(97), RespiratoryRate: pi(18), Steps: pi(3860), SleepHours: fp(6.8), Source: "manual", RecordTime: now}}
	if len(binding) > 1 {
		health = append(health, model.HealthRecord{ElderID: binding[1].ID, Temperature: fp(38.2), Systolic: pi(98), Diastolic: pi(64), HeartRate: pi(96), Spo2: fp(93), RespiratoryRate: pi(24), Steps: pi(2180), SleepHours: fp(5.2), Source: "manual", RecordTime: now})
	}
	if err := db.Create(&health).Error; err != nil {
		return err
	}
	return nil
}

// ensureBusinessRelations repairs known bootstrap rows and explicit legacy
// aliases so current business views refer to formal accounts without touching
// unrelated institution-owned records.
func ensureBusinessRelations(db *gorm.DB) error {
	var caregiver model.User
	if err := db.Where("username = ?", "xiaoli").First(&caregiver).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil
		}
		return err
	}
	staffName := strings.TrimSpace(caregiver.RealName)
	if staffName == "" {
		staffName = caregiver.Username
	}
	var doctor model.User
	if err := db.Where("username = ?", "xiaomo").First(&doctor).Error; err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	doctorName := formalUserDisplayName(db, "xiaomo", "医师")
	legacyCaregiverNames := []string{"李护工", "演示护工", "演示护理员", "Demo Caregiver"}
	legacyCaregiverCurrentNames := append(append([]string{}, legacyCaregiverNames...), "护理员")
	legacyDoctorNames := []string{"刘护工", "演示医师", "演示医生", "Demo Doctor"}
	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	workDate := now.Format("2006-01-02")

	// Only the two immutable seed identities are eligible for relation repair.
	// This keeps a similarly named resident or institution-owned task outside
	// the migration's scope.
	var bootstrapElderIDs []uint
	if err := db.Model(&model.Elder{}).
		Where("id_card IN ?", []string{"110101193805120011", "110101194511020012"}).
		Pluck("id", &bootstrapElderIDs).Error; err != nil {
		return err
	}
	var bootstrapPlanIDs []uint
	if len(bootstrapElderIDs) > 0 {
		if err := db.Model(&model.CarePlan{}).Where("elder_id IN ?", bootstrapElderIDs).Pluck("id", &bootstrapPlanIDs).Error; err != nil {
			return err
		}
	}
	var bootstrapPlanItemIDs []uint
	if len(bootstrapPlanIDs) > 0 {
		if err := db.Model(&model.CarePlanItem{}).Where("care_plan_id IN ?", bootstrapPlanIDs).Pluck("id", &bootstrapPlanItemIDs).Error; err != nil {
			return err
		}
	}
	dueByTitle := map[string]time.Time{
		"早间翻身":  startOfDay.Add(8*time.Hour + 30*time.Minute),
		"服用降压药": startOfDay.Add(10 * time.Hour),
	}
	if len(bootstrapElderIDs) > 0 {
		for title, dueAt := range dueByTitle {
			if err := db.Model(&model.CareTask{}).
				Where("elder_id IN ? AND title = ? AND status IN ? AND (assignee_id = ? OR assignee_id IS NULL) AND (assignee IN ? OR assignee = '')", bootstrapElderIDs, title, []string{"todo", "doing"}, caregiver.ID, legacyCaregiverCurrentNames).
				Updates(map[string]interface{}{"assignee_id": caregiver.ID, "assignee": staffName, "due_at": &dueAt}).Error; err != nil {
				return err
			}
		}
	}
	if err := db.Model(&model.Schedule{}).Where("staff IN ?", legacyCaregiverNames).Update("staff", staffName).Error; err != nil {
		return err
	}
	if err := db.Model(&model.Schedule{}).Where("work_date = ? AND staff = ?", workDate, "护理员").Update("staff", staffName).Error; err != nil {
		return err
	}
	if err := db.Model(&model.Schedule{}).Where("staff IN ?", legacyDoctorNames).Update("staff", doctorName).Error; err != nil {
		return err
	}
	if len(bootstrapPlanIDs) > 0 {
		if err := db.Model(&model.CarePlanItem{}).Where("care_plan_id IN ? AND (assignee_id = ? OR assignee_id IS NULL) AND assignee IN ?", bootstrapPlanIDs, caregiver.ID, legacyCaregiverCurrentNames).
			Updates(map[string]interface{}{"assignee_id": caregiver.ID, "assignee": staffName}).Error; err != nil {
			return err
		}
	}
	if len(bootstrapPlanItemIDs) > 0 {
		if err := db.Model(&model.CareExecution{}).Where("plan_item_id IN ? AND executor IN ?", bootstrapPlanItemIDs, legacyCaregiverCurrentNames).
			Updates(map[string]interface{}{"executor": staffName, "executor_id": caregiver.ID}).Error; err != nil {
			return err
		}
		if doctor.ID > 0 {
			if err := db.Model(&model.CareExecution{}).Where("plan_item_id IN ? AND executor IN ?", bootstrapPlanItemIDs, legacyDoctorNames).
				Updates(map[string]interface{}{"executor": doctorName, "executor_id": doctor.ID}).Error; err != nil {
				return err
			}
		}
	}
	if err := db.Model(&model.ShiftHandover{}).Where("from_staff IN ?", legacyCaregiverNames).Update("from_staff", staffName).Error; err != nil {
		return err
	}
	if err := db.Model(&model.ShiftHandover{}).Where("work_date = ? AND from_staff = ?", workDate, "护理员").Update("from_staff", staffName).Error; err != nil {
		return err
	}
	if err := db.Model(&model.ShiftHandover{}).Where("to_staff IN ?", legacyDoctorNames).Update("to_staff", doctorName).Error; err != nil {
		return err
	}
	var schedule model.Schedule
	if err := db.Where("staff = ? AND work_date = ?", staffName, now.Format("2006-01-02")).
		FirstOrCreate(&schedule, model.Schedule{
			Staff: staffName, WorkDate: now.Format("2006-01-02"), Shift: "morning", RoomScope: "101-102",
		}).Error; err != nil {
		return err
	}
	var doctorSchedule model.Schedule
	if err := db.Where("staff = ? AND work_date = ?", doctorName, now.Format("2006-01-02")).
		FirstOrCreate(&doctorSchedule, model.Schedule{
			Staff: doctorName, WorkDate: now.Format("2006-01-02"), Shift: "night", RoomScope: "101-102",
		}).Error; err != nil {
		return err
	}
	var handover model.ShiftHandover
	return db.Where("from_staff = ? AND to_staff = ? AND work_date = ?", staffName, doctorName, now.Format("2006-01-02")).
		FirstOrCreate(&handover, model.ShiftHandover{
			FromStaff: staffName, ToStaff: doctorName, WorkDate: now.Format("2006-01-02"),
			Summary: "长者情绪稳定，需按任务计划完成巡视与用药照护", Issues: "",
		}).Error
}

func fp(v float64) *float64 { return &v }
func pi(v int) *int         { return &v }

func formalUserDisplayName(db *gorm.DB, username, fallback string) string {
	var user model.User
	if err := db.Where("username = ?", username).First(&user).Error; err != nil {
		return fallback
	}
	if name := strings.TrimSpace(user.RealName); name != "" {
		return name
	}
	return user.Username
}

// seedBusinessData 补齐设备、告警、账单、排班等关联业务初始数据；按表幂等执行。
func seedBusinessData(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		return seedBusinessDataTx(tx)
	})
}

func seedBusinessDataTx(db *gorm.DB) error {
	var devCount int64
	if err := db.Model(&model.IotDevice{}).Count(&devCount).Error; err != nil {
		return err
	}
	now := time.Now()
	caregiverName := formalUserDisplayName(db, "xiaoli", "护理员")
	doctorName := formalUserDisplayName(db, "xiaomo", "医师")

	// 设备（绑定在院长者）
	var elders []model.Elder
	if err := db.Preload("Bed.Room").Where("status = 2").Order("id").Find(&elders).Error; err != nil {
		return err
	}
	bind := func(i int) *uint {
		if i < len(elders) {
			id := elders[i].ID
			return &id
		}
		return nil
	}
	if devCount == 0 {
		devices := []model.IotDevice{{DeviceID: "E438192587C3", Product: "fall_radar", Online: 0, Protocol: "MQTT"}}
		if elder := bind(0); elder != nil {
			device := model.IotDevice{DeviceID: "E438192584AA", Product: "fall_radar", Online: 1, ElderID: elder, Protocol: "MQTT", Battery: pi(87), LastSeen: &now}
			applyDevicePlacement(&device, elders[0])
			devices = append([]model.IotDevice{device}, devices...)
		}
		if elder := bind(1); elder != nil {
			device := model.IotDevice{DeviceID: "E438192584F5", Product: "breath_radar", Online: 1, ElderID: elder, Protocol: "MQTT", Battery: pi(76), LastSeen: &now}
			applyDevicePlacement(&device, elders[1])
			devices = append([]model.IotDevice{device}, devices...)
		}
		for i := range devices {
			if err := db.Create(&devices[i]).Error; err != nil {
				return err
			}
		}

		// 告警分级与状态，仅为实际绑定的长者生成关联告警。
		alerts := make([]model.Alert, 0, 3)
		if elder := bind(0); elder != nil {
			alerts = append(alerts,
				model.Alert{ElderID: elder, DeviceID: "E438192584AA", Type: "fall", Level: "emergency", Content: "长者[" + elderName(db, elder) + "] 检测到跌倒", Status: "new", CreateTime: now},
				model.Alert{ElderID: elder, DeviceID: "E438192584AA", Type: "offline", Level: "info", Content: "设备离线(超过60s无上报)", Status: "handled", HandledBy: "系统自动处置", CreateTime: now.Add(-3 * time.Hour)},
			)
		}
		if elder := bind(1); elder != nil {
			alerts = append(alerts, model.Alert{ElderID: elder, DeviceID: "E438192584F5", Type: "breath_abnormal", Level: "important", Content: "长者[" + elderName(db, elder) + "] 呼吸异常(次/分=28)", Status: "new", CreateTime: now.Add(-2 * time.Minute)})
		}
		for i := range alerts {
			if err := db.Create(&alerts[i]).Error; err != nil {
				return err
			}
		}
	}

	// 当月账单（在院长者）
	month := now.Format("2006-01")
	for _, e := range elders {
		var n int64
		if err := db.Model(&model.Bill{}).Where("elder_id = ? AND bill_month = ?", e.ID, month).Count(&n).Error; err != nil {
			return err
		}
		if n > 0 {
			continue
		}
		bed, nursing, meal, err := loadMonthlyBillingRates(db, e.CareLevel)
		if err != nil {
			return err
		}
		if err := db.Create(&model.Bill{ElderID: e.ID, BillMonth: month, BedFee: bed, NursingFee: nursing, MealFee: meal, Amount: bed + nursing + meal, Status: "unpaid"}).Error; err != nil {
			return err
		}
	}

	var scheduleCount int64
	if err := db.Model(&model.Schedule{}).Count(&scheduleCount).Error; err != nil {
		return err
	}
	if scheduleCount == 0 {
		if err := db.Create(&[]model.Schedule{
			{Staff: caregiverName, WorkDate: now.Format("2006-01-02"), Shift: "morning", RoomScope: "101-102"},
			{Staff: doctorName, WorkDate: now.Format("2006-01-02"), Shift: "night", RoomScope: "101-102"},
		}).Error; err != nil {
			return err
		}
		if err := db.Create(&model.ShiftHandover{FromStaff: caregiverName, ToStaff: doctorName, WorkDate: now.Format("2006-01-02"), Summary: "长者情绪稳定，张素英需两小时翻身", Issues: ""}).Error; err != nil {
			return err
		}
	}
	var iotHealthCount int64
	if err := db.Model(&model.HealthRecord{}).Where("source = ?", "iot").Count(&iotHealthCount).Error; err != nil {
		return err
	}
	if iotHealthCount == 0 && len(elders) > 0 {
		if err := db.Create(&model.HealthRecord{ElderID: elders[0].ID, Temperature: fp(36.6), Systolic: pi(132), Diastolic: pi(82), HeartRate: pi(78), Spo2: fp(97), RespiratoryRate: pi(18), Steps: pi(3860), SleepHours: fp(6.8), Source: "iot", RecordTime: now}).Error; err != nil {
			return err
		}
	}

	// 其余业务模块按表为空时初始化，重复启动不会重复插入。
	var flowCount int64
	if err := db.Model(&model.FundFlow{}).Count(&flowCount).Error; err != nil {
		return err
	}
	if flowCount == 0 && len(elders) > 0 {
		month := now.Format("2006-01")
		flows := []model.FundFlow{
			{ElderID: elders[0].ID, Direction: "in", RelatedMonth: month, Reason: "住院预缴", Amount: 10000},
			{ElderID: elders[0].ID, Direction: "out", RelatedMonth: month, Reason: "床位及护理费", Amount: 4200},
		}
		if len(elders) > 1 {
			flows = append(flows, model.FundFlow{ElderID: elders[1].ID, Direction: "in", RelatedMonth: month, Reason: "住院预缴", Amount: 8000})
		}
		if err := db.Create(&flows).Error; err != nil {
			return err
		}
	}

	var medicationCount int64
	if err := db.Model(&model.MedicationRecord{}).Count(&medicationCount).Error; err != nil {
		return err
	}
	if medicationCount == 0 && len(elders) > 0 {
		planTime := now.Add(2 * time.Hour)
		takenTime := now.Add(-2 * time.Hour)
		medications := []model.MedicationRecord{{ElderID: elders[0].ID, MedicineName: "硝苯地平缓释片", Dosage: "20mg", Frequency: "每日1次", Route: "口服", PlanTime: &planTime, TakenTime: &takenTime, TodayTotal: 1, TodayDone: 1, Status: "taken"}}
		if len(elders) > 1 {
			medications = append(medications, model.MedicationRecord{ElderID: elders[1].ID, MedicineName: "阿托伐他汀钙片", Dosage: "10mg", Frequency: "每晚1次", Route: "口服", PlanTime: &planTime, TodayTotal: 1, TodayDone: 0, Status: "pending"})
		}
		if err := db.Create(&medications).Error; err != nil {
			return err
		}
	}

	var stockCount int64
	if err := db.Model(&model.MedicineStock{}).Count(&stockCount).Error; err != nil {
		return err
	}
	if stockCount == 0 {
		stocks := []model.MedicineStock{
			{MedicineName: "硝苯地平缓释片", Spec: "20mg*30片", Batch: "KXB20260801", Qty: 86, ExpireDate: now.AddDate(1, 0, 0).Format("2006-01-02"), Storage: "常温"},
			{MedicineName: "阿托伐他汀钙片", Spec: "10mg*14片", Batch: "KXB20260715", Qty: 42, ExpireDate: now.AddDate(1, 2, 0).Format("2006-01-02"), Storage: "阴凉"},
		}
		if err := db.Create(&stocks).Error; err != nil {
			return err
		}
	}

	var diningCount int64
	if err := db.Model(&model.DiningOrder{}).Count(&diningCount).Error; err != nil {
		return err
	}
	if diningCount == 0 && len(elders) > 0 {
		orders := []model.DiningOrder{{ElderID: elders[0].ID, MealTime: "lunch", Items: "低盐软饭、清蒸鱼、时蔬", Qty: 1, UnitPrice: 28, TotalAmount: 28, Status: "ordered"}}
		if len(elders) > 1 {
			orders = append(orders, model.DiningOrder{ElderID: elders[1].ID, MealTime: "dinner", Items: "杂粮粥、鸡蛋羹、南瓜", Qty: 1, UnitPrice: 24, TotalAmount: 24, Status: "served"})
		}
		if err := db.Create(&orders).Error; err != nil {
			return err
		}
	}

	var assessmentCount int64
	if err := db.Model(&model.Assessment{}).Count(&assessmentCount).Error; err != nil {
		return err
	}
	var doctorID, caregiverID, familyID uint
	for _, item := range []struct {
		name string
		dest *uint
	}{
		{"xiaomo", &doctorID}, {"xiaoli", &caregiverID}, {"family", &familyID},
	} {
		var u model.User
		if err := db.Where("username = ?", item.name).First(&u).Error; err == nil {
			*item.dest = u.ID
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
	}
	if assessmentCount == 0 && len(elders) > 0 {
		score1 := 72.0
		assessments := []model.Assessment{{ElderID: elders[0].ID, AssessorID: doctorID, AssessmentType: "adl", Score: &score1, RiskLevel: "low", Notes: "日常活动基本独立，继续观察步态", AssessedAt: now.Add(-24 * time.Hour)}}
		if len(elders) > 1 {
			score2 := 48.0
			assessments = append(assessments, model.Assessment{ElderID: elders[1].ID, AssessorID: doctorID, AssessmentType: "fall", Score: &score2, RiskLevel: "high", Notes: "近期有跌倒风险，需加强夜间巡视", AssessedAt: now.Add(-12 * time.Hour)})
		}
		if err := db.Create(&assessments).Error; err != nil {
			return err
		}
	}

	var planCount int64
	if err := db.Model(&model.CarePlan{}).Count(&planCount).Error; err != nil {
		return err
	}
	if planCount == 0 && len(elders) > 0 {
		plans := []model.CarePlan{{ElderID: elders[0].ID, Name: "基础生活照护计划", Status: "active", StartDate: now.Format("2006-01-02"), CreatedBy: doctorID}}
		if len(elders) > 1 {
			plans = append(plans, model.CarePlan{ElderID: elders[1].ID, Name: "跌倒风险干预计划", Status: "active", StartDate: now.Format("2006-01-02"), CreatedBy: doctorID})
		}
		if err := db.Create(&plans).Error; err != nil {
			return err
		}
		items := []model.CarePlanItem{{CarePlanID: plans[0].ID, Title: "晨间生命体征测量", Kind: "health", Frequency: "每日1次", Assignee: caregiverName, RiskLevel: "low", Instructions: "记录体温、血压、心率", Active: true}}
		if len(plans) > 1 {
			items = append(items, model.CarePlanItem{CarePlanID: plans[1].ID, Title: "夜间防跌倒巡视", Kind: "round", Frequency: "每2小时", Assignee: caregiverName, RiskLevel: "high", Instructions: "确认床栏、呼叫器和地面安全", Active: true})
		}
		if err := db.Create(&items).Error; err != nil {
			return err
		}
		if err := db.Create(&model.CareExecution{PlanItemID: items[0].ID, ElderID: elders[0].ID, ExecutorID: caregiverID, Executor: caregiverName, Status: "completed", ExecutedAt: now.Add(-3 * time.Hour), Result: "体征平稳"}).Error; err != nil {
			return err
		}
	}

	var notificationCount int64
	if err := db.Model(&model.Notification{}).Count(&notificationCount).Error; err != nil {
		return err
	}
	if notificationCount == 0 {
		sent := now.Add(-10 * time.Minute)
		notifications := []model.Notification{
			{Role: "caregiver", Channel: "in_app", Type: "task", Title: "护理任务提醒", Content: "张素英的早间翻身任务待处理", Severity: "info", SentAt: &sent},
			{Role: "doctor", Channel: "in_app", Type: "alert", Title: "风险评估待复核", Content: "王建国存在跌倒风险，请查看评估记录", Severity: "warning", SentAt: &sent},
			{UserID: familyID, Channel: "in_app", Type: "health", Title: "家人健康更新", Content: "张素英今日体征已记录，请查看长者状态", Severity: "info", SentAt: &sent},
		}
		if err := db.Create(&notifications).Error; err != nil {
			return err
		}
	}

	var messageCount int64
	if err := db.Model(&model.Message{}).Count(&messageCount).Error; err != nil {
		return err
	}
	if messageCount == 0 && caregiverID > 0 && familyID > 0 && len(elders) > 0 {
		firstElder := elders[0].ID
		messages := []model.Message{
			{SenderID: familyID, ReceiverID: caregiverID, ElderID: &firstElder, Content: "您好，想了解一下张素英今天的状态。", Type: "chat", SentAt: now.Add(-35 * time.Minute)},
			{SenderID: caregiverID, ReceiverID: familyID, ElderID: &firstElder, Content: "您好，今天体征平稳，早间护理已完成，午休前会继续观察。", Type: "chat", SentAt: now.Add(-30 * time.Minute)},
		}
		if doctorID > 0 {
			messages = append(messages,
				model.Message{SenderID: caregiverID, ReceiverID: doctorID, ElderID: &firstElder, Content: "张素英今日体征已录入，请协助关注左膝酸胀情况。", Type: "care_handoff", SentAt: now.Add(-18 * time.Minute)},
				model.Message{SenderID: doctorID, ReceiverID: caregiverID, ElderID: &firstElder, Content: "收到，按基础照护计划执行，异常时及时上报。", Type: "care_handoff", SentAt: now.Add(-12 * time.Minute)},
			)
		}
		if err := db.Create(&messages).Error; err != nil {
			return err
		}
	}
	return nil
}

func elderName(db *gorm.DB, id *uint) string {
	if id == nil {
		return "未知"
	}
	var e model.Elder
	if err := db.First(&e, *id).Error; err != nil {
		return "未知"
	}
	return e.Name
}
