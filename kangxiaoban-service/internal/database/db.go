package database

import (
	"errors"
	"fmt"
	"time"

	mysqlDriver "gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/glebarez/sqlite"
	"golang.org/x/crypto/bcrypt"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
)

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
	return db, nil
}

// AutoMigrateAndSeed 建表并注入基础种子数据（角色/权限/管理员）。
func AutoMigrateAndSeed(db *gorm.DB) error {
	if err := model.AutoMigrateAll(db); err != nil {
		return fmt.Errorf("auto migrate: %w", err)
	}
	if err := seed(db); err != nil {
		return err
	}
	return seedBusiness(db)
}

func seed(db *gorm.DB) error {
	// 权限：M0-M1 核心权限集；后续里程碑扩展。
	perms := []struct{ code, name string }{
		{"dash:read", "工作台查看"},
		{"elder:read", "长者档案查看"},
		{"elder:write", "长者档案编辑"},
		{"task:read", "任务查看"},
		{"task:write", "任务处理"},
		{"health:read", "体征查看"},
		{"health:write", "体征录入"},
		{"alert:read", "告警查看"},
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
			"health:read", "health:write", "alert:read", "admin:all"}},
		{"doctor", "医师", "看护与评估", []string{
			"dash:read", "elder:read", "health:read", "task:read", "alert:read"}},
		{"caregiver", "护工", "现场护理", []string{
			"dash:read", "elder:read", "health:read", "health:write",
			"task:read", "task:write", "alert:read"}},
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

	// 默认管理员账号 admin / Admin@123456（生产必须改并注入密钥）。
	var admin model.User
	if err := db.Where("username = ?", "admin").First(&admin).Error; err != nil {
		hash, err2 := bcrypt.GenerateFromPassword([]byte("Admin@123456"), bcrypt.DefaultCost)
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

// seedBusiness 注入演示业务数据（房间/床位/长者/任务/体征），仅当库为空时写入。
func seedBusiness(db *gorm.DB) error {
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
		db.Create(&model.Bed{RoomID: rooms[i].ID, BedNo: "1", Status: "free"})
		db.Create(&model.Bed{RoomID: rooms[i].ID, BedNo: "2", Status: "free"})
	}

	beds := make([]model.Bed, 0)
	db.Where("room_id IN ?", []uint{rooms[0].ID, rooms[1].ID}).Order("id").Find(&beds)
	binding := []model.Elder{
		{Name: "张素英", Gender: "F", BirthDate: "1938-05-12", ContactPhone: "13800000001", CareLevel: 3, Status: 2, IDCard: "110101193805120011",
			EmergencyContacts: []model.ElderContact{{Name: "张伟", Relation: "儿子", Phone: "13800000001", IsEmergency: true}}},
		{Name: "王建国", Gender: "M", BirthDate: "1945-11-02", ContactPhone: "13800000002", CareLevel: 2, Status: 2, IDCard: "110101194511020012",
			EmergencyContacts: []model.ElderContact{{Name: "王芳", Relation: "女儿", Phone: "13800000002", IsEmergency: true}}},
	}
	for i := range binding {
		if err := db.Create(&binding[i]).Error; err != nil {
			return err
		}
		if i < len(beds) {
			bid := beds[i].ID
			binding[i].BedID = &bid
			db.Model(&binding[i]).Update("bed_id", bid)
			db.Model(&beds[i]).Updates(map[string]interface{}{"status": "occupied", "elder_id": binding[i].ID})
		}
	}

	db.Create(&model.CareTask{ElderID: binding[0].ID, Title: "早间翻身", Kind: "turnover", Assignee: "李护工", Status: "todo", Remark: "两小时一次"})
	db.Create(&model.CareTask{ElderID: binding[1].ID, Title: "服用降压药", Kind: "medication", Assignee: "刘护工", Status: "todo"})

	now := time.Now()
	db.Create(&model.HealthRecord{ElderID: binding[0].ID, Temperature: fp(36.6), Systolic: pi(132), Diastolic: pi(82), HeartRate: pi(78), Spo2: fp(97), Source: "manual", RecordTime: now, IsAbnormal: false})
	db.Create(&model.HealthRecord{ElderID: binding[1].ID, Temperature: fp(38.2), Systolic: pi(98), Diastolic: pi(64), HeartRate: pi(96), Spo2: fp(93), Source: "manual", RecordTime: now, IsAbnormal: true})
	return nil
}

func fp(v float64) *float64      { return &v }
func pi(v int) *int              { return &v }