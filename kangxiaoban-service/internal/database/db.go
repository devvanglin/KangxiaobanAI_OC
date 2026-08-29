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
	if err := migrateDemoAccounts(db); err != nil {
		return err
	}
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

	// 正式家属账号 family / Family@123456，角色 family
	var family model.User
	if err := db.Where("username = ?", "family").First(&family).Error; err != nil {
		hash, err2 := bcrypt.GenerateFromPassword([]byte("Family@123456"), bcrypt.DefaultCost)
		if err2 != nil {
			return err2
		}
		family = model.User{Username: "family", PasswordHash: string(hash), RealName: "张伟", Status: 1}
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

	// 客户端角色选择对应的正式账号；生产环境请按机构策略修改密码。
	formalUsers := []struct {
		username, password, realName, roleCode string
	}{
		{"caregiver", "123456", "护理员", "caregiver"},
		{"doctor", "123456", "医师", "doctor"},
	}
	for _, demo := range formalUsers {
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

// migrateDemoAccounts 将旧版本的 *_demo 账号改为正式账号，并删除重复的 admin_demo。
// 只迁移用户名，不重置密码，保留既有账号凭据和家属绑定关系。
func migrateDemoAccounts(db *gorm.DB) error {
	rename := func(oldName, newName string) error {
		var oldUser model.User
		if err := db.Where("username = ?", oldName).First(&oldUser).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil
			}
			return err
		}
		var newUser model.User
		if err := db.Where("username = ?", newName).First(&newUser).Error; err == nil {
			_ = db.Model(&oldUser).Association("Roles").Clear()
			return db.Delete(&oldUser).Error
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		return db.Model(&oldUser).Update("username", newName).Error
	}
	if err := rename("caregiver_demo", "caregiver"); err != nil {
		return err
	}
	if err := rename("doctor_demo", "doctor"); err != nil {
		return err
	}
	if err := rename("family_demo", "family"); err != nil {
		return err
	}
	var adminDemo model.User
	if err := db.Where("username = ?", "admin_demo").First(&adminDemo).Error; err == nil {
		_ = db.Model(&adminDemo).Association("Roles").Clear()
		if err := db.Delete(&adminDemo).Error; err != nil {
			return err
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
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

	// 家属绑定：family 仅绑定长者1，用于验证数据隔离
	var fam model.User
	if err := db.Where("username = ?", "family").First(&fam).Error; err == nil {
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
	if devCount == 0 {
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

	var scheduleCount int64
	if err := db.Model(&model.Schedule{}).Count(&scheduleCount).Error; err != nil {
		return err
	}
	if scheduleCount == 0 {
		if err := db.Create(&[]model.Schedule{
			{Staff: "李护工", WorkDate: now.Format("2006-01-02"), Shift: "morning", RoomScope: "101-102"},
			{Staff: "刘护工", WorkDate: now.Format("2006-01-02"), Shift: "night", RoomScope: "103"},
		}).Error; err != nil {
			return err
		}
		if err := db.Create(&model.ShiftHandover{FromStaff: "李护工", ToStaff: "刘护工", WorkDate: now.Format("2006-01-02"), Summary: "长者情绪稳定，张素英需两小时翻身", Issues: ""}).Error; err != nil {
			return err
		}
	}
	var iotHealthCount int64
	if err := db.Model(&model.HealthRecord{}).Where("source = ?", "iot").Count(&iotHealthCount).Error; err != nil {
		return err
	}
	if iotHealthCount == 0 && len(elders) > 0 {
		if err := db.Create(&model.HealthRecord{ElderID: elders[0].ID, Temperature: fp(36.6), Systolic: pi(132), Diastolic: pi(82), HeartRate: pi(78), Spo2: fp(97), Source: "iot", RecordTime: now, IsAbnormal: false}).Error; err != nil {
			return err
		}
	}

	// 其余模块的可运行演示数据分别按表为空时播种，重复启动不会重复插入。
	var flowCount int64
	if err := db.Model(&model.FundFlow{}).Count(&flowCount).Error; err != nil {
		return err
	}
	if flowCount == 0 && len(elders) > 0 {
		month := now.Format("2006-01")
		flows := []model.FundFlow{
			{ElderID: elders[0].ID, Direction: "in", RelatedMonth: month, Reason: "住院预缴", Amount: 10000},
			{ElderID: elders[0].ID, Direction: "out", RelatedMonth: month, Reason: "床位及护理费", Amount: 4200},
			{ElderID: elders[1].ID, Direction: "in", RelatedMonth: month, Reason: "住院预缴", Amount: 8000},
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
		medications := []model.MedicationRecord{
			{ElderID: elders[0].ID, MedicineName: "硝苯地平缓释片", Dosage: "20mg 口服", PlanTime: &planTime, TakenTime: &takenTime, Status: "taken"},
			{ElderID: elders[1].ID, MedicineName: "阿托伐他汀钙片", Dosage: "10mg 口服", PlanTime: &planTime, Status: "pending"},
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
		orders := []model.DiningOrder{
			{ElderID: elders[0].ID, MealTime: "lunch", Items: "低盐软饭、清蒸鱼、时蔬", Qty: 1, UnitPrice: 28, TotalAmount: 28, Status: "ordered"},
			{ElderID: elders[1].ID, MealTime: "dinner", Items: "杂粮粥、鸡蛋羹、南瓜", Qty: 1, UnitPrice: 24, TotalAmount: 24, Status: "served"},
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
		{"doctor", &doctorID}, {"caregiver", &caregiverID}, {"family", &familyID},
	} {
		var u model.User
		if err := db.Where("username = ?", item.name).First(&u).Error; err == nil {
			*item.dest = u.ID
		}
	}
	if assessmentCount == 0 && len(elders) > 0 {
		score1, score2 := 72.0, 48.0
		assessments := []model.Assessment{
			{ElderID: elders[0].ID, AssessorID: doctorID, AssessmentType: "adl", Score: &score1, RiskLevel: "low", Notes: "日常活动基本独立，继续观察步态", AssessedAt: now.Add(-24 * time.Hour)},
			{ElderID: elders[1].ID, AssessorID: doctorID, AssessmentType: "fall", Score: &score2, RiskLevel: "high", Notes: "近期有跌倒风险，需加强夜间巡视", AssessedAt: now.Add(-12 * time.Hour)},
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
		plans := []model.CarePlan{
			{ElderID: elders[0].ID, Name: "基础生活照护计划", Status: "active", StartDate: now.Format("2006-01-02"), CreatedBy: doctorID},
			{ElderID: elders[1].ID, Name: "跌倒风险干预计划", Status: "active", StartDate: now.Format("2006-01-02"), CreatedBy: doctorID},
		}
		if err := db.Create(&plans).Error; err != nil {
			return err
		}
		items := []model.CarePlanItem{
			{CarePlanID: plans[0].ID, Title: "晨间生命体征测量", Kind: "health", Frequency: "每日1次", Assignee: "李护工", RiskLevel: "low", Instructions: "记录体温、血压、心率", Active: true},
			{CarePlanID: plans[1].ID, Title: "夜间防跌倒巡视", Kind: "round", Frequency: "每2小时", Assignee: "刘护工", RiskLevel: "high", Instructions: "确认床栏、呼叫器和地面安全", Active: true},
		}
		if err := db.Create(&items).Error; err != nil {
			return err
		}
		if err := db.Create(&model.CareExecution{PlanItemID: items[0].ID, ElderID: elders[0].ID, ExecutorID: caregiverID, Executor: "李护工", Status: "completed", ExecutedAt: now.Add(-3 * time.Hour), Result: "体征平稳"}).Error; err != nil {
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
