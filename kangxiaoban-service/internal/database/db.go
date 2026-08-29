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
	if err := RegisterTenantScope(db); err != nil {
		return nil, fmt.Errorf("register tenant scope: %w", err)
	}
	return db, nil
}

// AutoMigrateAndSeed 建表并注入基础种子数据（角色/权限/管理员）；seedDemo 时再播演示业务数据。
func AutoMigrateAndSeed(db *gorm.DB, seedDemo bool) error {
	if err := model.AutoMigrateAll(db); err != nil {
		return fmt.Errorf("auto migrate: %w", err)
	}
	// 单机构历史库统一迁移到默认租户，避免新增 tenant_id 后出现不可见数据。
	if err := ensureDefaultTenant(db); err != nil {
		return fmt.Errorf("ensure default tenant: %w", err)
	}
	if err := seed(db); err != nil {
		return err
	}
	if err := seedBusiness(db); err != nil {
		return err
	}
	if seedDemo {
		return seedDemoData(db)
	}
	return nil
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
	for _, table := range []interface{}{&model.User{}, &model.Role{}, &model.Permission{}, &model.AuditLog{}, &model.Elder{}, &model.Room{}, &model.Bed{}, &model.CareTask{}, &model.HealthRecord{}, &model.Assessment{}, &model.CarePlan{}, &model.CarePlanItem{}, &model.CareExecution{}, &model.Incident{}, &model.IotDevice{}, &model.SignalRecord{}, &model.Alert{}, &model.AlertAction{}, &model.Notification{}, &model.Schedule{}, &model.ShiftHandover{}, &model.Bill{}, &model.FundFlow{}, &model.MedicationRecord{}, &model.MedicineStock{}, &model.DiningOrder{}, &model.FamilyElder{}} {
		if err := db.Model(table).Where("tenant_id = 0").Update("tenant_id", 1).Error; err != nil {
			return err
		}
	}
	return nil
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

	// 演示家属账号 family_demo / Family@123456，角色 family
	var family model.User
	if err := db.Where("username = ?", "family_demo").First(&family).Error; err != nil {
		hash, err2 := bcrypt.GenerateFromPassword([]byte("Family@123456"), bcrypt.DefaultCost)
		if err2 != nil {
			return err2
		}
		family = model.User{Username: "family_demo", PasswordHash: string(hash), RealName: "张伟", Status: 1}
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
	_ = family

	// 客户端角色选择对应的演示账号，便于测试真实后端权限；生产环境应立即改密或删除。
	demoUsers := []struct {
		username, password, realName, roleCode string
	}{
		{"caregiver_demo", "123456", "演示护工", "caregiver"},
		{"doctor_demo", "123456", "演示医师", "doctor"},
		{"admin_demo", "123456", "演示管理员", "admin"},
	}
	for _, demo := range demoUsers {
		var u model.User
		if err := db.Where("username = ?", demo.username).First(&u).Error; err == nil {
			continue
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(demo.password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		u = model.User{Username: demo.username, PasswordHash: string(hash), RealName: demo.realName, Status: 1}
		if err := db.Create(&u).Error; err != nil {
			return err
		}
		var role model.Role
		if err := db.Where("code = ?", demo.roleCode).First(&role).Error; err != nil {
			return err
		}
		if err := db.Model(&u).Association("Roles").Replace([]model.Role{role}); err != nil {
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

	// 家属演示绑定：family_demo 仅绑定长者1，用于验证数据隔离
	var fam model.User
	if err := db.Where("username = ?", "family_demo").First(&fam).Error; err == nil {
		db.FirstOrCreate(&model.FamilyElder{UserID: fam.ID, ElderID: binding[0].ID}, model.FamilyElder{UserID: fam.ID, ElderID: binding[0].ID})
	}

	now := time.Now()
	db.Create(&model.HealthRecord{ElderID: binding[0].ID, Temperature: fp(36.6), Systolic: pi(132), Diastolic: pi(82), HeartRate: pi(78), Spo2: fp(97), Source: "manual", RecordTime: now, IsAbnormal: false})
	db.Create(&model.HealthRecord{ElderID: binding[1].ID, Temperature: fp(38.2), Systolic: pi(98), Diastolic: pi(64), HeartRate: pi(96), Spo2: fp(93), Source: "manual", RecordTime: now, IsAbnormal: true})
	return nil
}

func fp(v float64) *float64 { return &v }
func pi(v int) *int         { return &v }

// seedDemoData 播演示业务数据（设备/告警/账单/任务），仅空库首次启动时执行，让展示壳开即有数据。
func seedDemoData(db *gorm.DB) error {
	var devCount int64
	if err := db.Model(&model.IotDevice{}).Count(&devCount).Error; err != nil {
		return err
	}
	if devCount > 0 {
		return nil // 已播种过
	}
	now := time.Now()

	// 设备（绑定在院长者）
	var elders []model.Elder
	db.Where("status = 2").Order("id").Find(&elders)
	bind := func(i int) *uint {
		if i < len(elders) {
			id := elders[i].ID
			return &id
		}
		return nil
	}
	devices := []model.IotDevice{
		{DeviceID: "E438192584AA", Product: "fall_radar", Online: 1, ElderID: bind(0), Protocol: "MQTT", LastSeen: &now},
		{DeviceID: "E438192584F5", Product: "breath_radar", Online: 1, ElderID: bind(1), Protocol: "MQTT", LastSeen: &now},
		{DeviceID: "E438192587C3", Product: "fall_radar", Online: 0, Protocol: "MQTT"},
	}
	for i := range devices {
		if err := db.Create(&devices[i]).Error; err != nil {
			return err
		}
	}

	// 告警（演示分级与状态）
	alerts := []model.Alert{
		{ElderID: bind(0), DeviceID: "E438192584AA", Type: "fall", Level: "emergency", Content: "长者[" + elderName(db, bind(0)) + "] 检测到跌倒", Status: "new", CreateTime: now},
		{ElderID: bind(1), DeviceID: "E438192584F5", Type: "breath_abnormal", Level: "important", Content: "长者[" + elderName(db, bind(1)) + "] 呼吸异常(次/分=28)", Status: "new", CreateTime: now.Add(-2 * time.Minute)},
		{ElderID: bind(0), DeviceID: "E438192584AA", Type: "offline", Level: "info", Content: "设备离线(超过60s无上报)", Status: "handled", HandledBy: "演示", CreateTime: now.Add(-3 * time.Hour)},
	}
	for i := range alerts {
		if err := db.Create(&alerts[i]).Error; err != nil {
			return err
		}
	}

	// 当月账单（在院长者）
	month := now.Format("2006-01")
	for _, e := range elders {
		var n int64
		if err := db.Model(&model.Bill{}).Where("elder_id = ? AND bill_month = ?", e.ID, month).Count(&n).Error; err != nil || n > 0 {
			continue
		}
		nursing := nursingFee(int(e.CareLevel))
		db.Create(&model.Bill{ElderID: e.ID, BillMonth: month, BedFee: 1500, NursingFee: nursing, MealFee: 900, Amount: 1500 + nursing + 900, Status: "unpaid"})
	}

	// 排班 + 交接 + 体征演示
	db.Create(&model.Schedule{Staff: "李护工", WorkDate: now.Format("2006-01-02"), Shift: "morning", RoomScope: "101-102"})
	db.Create(&model.Schedule{Staff: "刘护工", WorkDate: now.Format("2006-01-02"), Shift: "night", RoomScope: "103"})
	db.Create(&model.ShiftHandover{FromStaff: "李护工", ToStaff: "刘护工", WorkDate: now.Format("2006-01-02"), Summary: "长者情绪稳定，张素英需两小时翻身", Issues: ""})
	if len(elders) > 0 {
		db.Create(&model.HealthRecord{ElderID: elders[0].ID, Temperature: fp(36.6), Systolic: pi(132), Diastolic: pi(82), HeartRate: pi(78), Spo2: fp(97), Source: "iot", RecordTime: now, IsAbnormal: false})
	}
	return nil
}

func nursingFee(level int) float64 {
	switch level {
	case 1:
		return 1200
	case 2:
		return 1800
	case 3:
		return 2400
	case 4:
		return 3000
	default:
		return 3600
	}
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
