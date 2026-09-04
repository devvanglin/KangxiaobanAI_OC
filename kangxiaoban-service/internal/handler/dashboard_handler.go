package handler

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/operationpolicy"
)

// DashboardHandler 工作台/大屏摘要（读真实统计）。
type DashboardHandler struct {
	db *gorm.DB
}

func NewDashboardHandler(db *gorm.DB) *DashboardHandler {
	return &DashboardHandler{db: db}
}

// Summary GET /api/v1/dashboard/summary —— 全局实时指标（前端大屏/首页）。
func (h *DashboardHandler) Summary(c *gin.Context) {
	db := h.db.WithContext(c.Request.Context())
	var (
		eldersTotal, eldersInBed         int64
		devicesTotal, devicesOnline      int64
		alertsTotal, alertsNew, alertsEm int64
		tasksTodo                        int64
		unpaidCount                      int64
		unpaidSum, paidSum               float64
	)

	// 长者
	db.Model(&model.Elder{}).Count(&eldersTotal)
	db.Model(&model.Elder{}).Where("status = 2").Count(&eldersInBed)
	// 设备
	db.Model(&model.IotDevice{}).Where("discovery_status <> ? OR discovery_status IS NULL", "disabled").Count(&devicesTotal)
	db.Model(&model.IotDevice{}).Where("(discovery_status <> ? OR discovery_status IS NULL) AND online = 1", "disabled").Count(&devicesOnline)
	// 告警
	db.Model(&model.Alert{}).Count(&alertsTotal)
	db.Model(&model.Alert{}).Where("status = 'new'").Count(&alertsNew)
	db.Model(&model.Alert{}).Where("level = 'emergency' AND status != 'closed'").Count(&alertsEm)
	// 待办任务
	db.Model(&model.CareTask{}).Where("status = 'todo'").Count(&tasksTodo)
	// 账单待缴
	db.Model(&model.Bill{}).Where("status = 'unpaid' OR status = 'partial'").Select("COALESCE(SUM(amount - paid),0)").Scan(&unpaidSum)
	db.Model(&model.Bill{}).Where("status = 'unpaid' OR status = 'partial'").Where("amount > paid").Count(&unpaidCount)
	db.Model(&model.Bill{}).Select("COALESCE(SUM(paid),0)").Scan(&paidSum)

	OK(c, gin.H{
		"elders":  gin.H{"total": eldersTotal, "in_bed": eldersInBed},
		"devices": gin.H{"total": devicesTotal, "online": devicesOnline},
		"alerts":  gin.H{"total": alertsTotal, "new": alertsNew, "emergency": alertsEm},
		"tasks":   gin.H{"todo": tasksTodo},
		"bills":   gin.H{"unpaid_count": unpaidCount, "unpaid_sum": unpaidSum, "paid_sum": paidSum},
	})
}

// PublicSummary GET /api/v1/public/dashboard —— 养老院公共展示屏只读摘要。
// 仅返回全院聚合数字和脱敏状态，不返回长者姓名、身份证、房间明细或账单明细。
func (h *DashboardHandler) PublicSummary(c *gin.Context) {
	db := h.db.WithContext(c.Request.Context())
	var (
		eldersInBed, devicesTotal, devicesOnline, alertsNew, alertsEmergency, tasksTodo int64
		unpaidSum                                                                       float64
	)
	var elders []model.Elder
	if err := db.Where("status = 2").Order("id").Find(&elders).Error; err != nil {
		Fail(c, 500, 500, "查询公开长者数据失败")
		return
	}
	db.Model(&model.Elder{}).Where("status = 2").Count(&eldersInBed)
	db.Model(&model.IotDevice{}).Where("discovery_status <> ? OR discovery_status IS NULL", "disabled").Count(&devicesTotal)
	db.Model(&model.IotDevice{}).Where("(discovery_status <> ? OR discovery_status IS NULL) AND online = 1", "disabled").Count(&devicesOnline)
	db.Model(&model.Alert{}).Where("status = 'new'").Count(&alertsNew)
	db.Model(&model.Alert{}).Where("level = 'emergency' AND status != 'closed'").Count(&alertsEmergency)
	db.Model(&model.CareTask{}).Where("status = 'todo'").Count(&tasksTodo)
	db.Model(&model.Bill{}).Where("status = 'unpaid' OR status = 'partial'").Select("COALESCE(SUM(amount - paid),0)").Scan(&unpaidSum)

	var alerts []model.Alert
	if err := db.Order("create_time desc, id desc").Limit(12).Find(&alerts).Error; err != nil {
		Fail(c, 500, 500, "查询公开大屏数据失败")
		return
	}
	recentAlerts := make([]gin.H, 0, len(alerts))
	for _, alert := range alerts {
		level := "关注"
		if alert.Level == "emergency" {
			level = "紧急"
		} else if alert.Status == "closed" || alert.Status == "handled" {
			level = "完成"
		}
		recentAlerts = append(recentAlerts, gin.H{
			"create_time": alert.CreateTime,
			"level":       level,
			"type":        alertTitle(alert.Type),
			"status":      alert.Status,
		})
	}

	var devices []model.IotDevice
	if err := db.Where("discovery_status <> ? OR discovery_status IS NULL", "disabled").Order("online desc, last_seen desc, id desc").Limit(12).Find(&devices).Error; err != nil {
		Fail(c, 500, 500, "查询公开设备数据失败")
		return
	}
	publicDevices := make([]gin.H, 0, len(devices))
	for _, device := range devices {
		publicDevices = append(publicDevices, gin.H{
			"product":   deviceProductLabel(device.Product),
			"online":    device.Online == 1,
			"last_seen": device.LastSeen,
		})
	}
	gender := map[string]int{"男": 0, "女": 0}
	careLevels := map[string]int{"1级照护": 0, "2级照护": 0, "3级照护": 0, "4级照护": 0, "5级照护": 0}
	ageBuckets := map[string]int{"60岁以下": 0, "60-69岁": 0, "70-79岁": 0, "80-89岁": 0, "90岁以上": 0}
	publicElders := make([]gin.H, 0, len(elders))
	now := time.Now()
	for _, elder := range elders {
		if elder.Gender == "M" || elder.Gender == "男" {
			gender["男"]++
		} else if elder.Gender == "F" || elder.Gender == "女" {
			gender["女"]++
		}
		level := int(elder.CareLevel)
		if level < 1 {
			level = 1
		}
		if level > 5 {
			level = 5
		}
		careLevels[fmt.Sprintf("%d级照护", level)]++
		age := 0
		if birth, err := time.Parse("2006-01-02", elder.BirthDate); err == nil {
			age = now.Year() - birth.Year()
			if now.YearDay() < birth.YearDay() {
				age--
			}
		}
		switch {
		case age > 0 && age < 60:
			ageBuckets["60岁以下"]++
		case age < 70:
			ageBuckets["60-69岁"]++
		case age < 80:
			ageBuckets["70-79岁"]++
		case age < 90:
			ageBuckets["80-89岁"]++
		default:
			ageBuckets["90岁以上"]++
		}
		name := strings.TrimSpace(elder.Name)
		maskedName := "长者"
		if name != "" {
			maskedName = string([]rune(name)[0]) + "某"
		}
		publicElders = append(publicElders, gin.H{"id": fmt.Sprintf("ELD-%04d", elder.ID), "name": maskedName,
			"gender": map[string]string{"M": "男", "F": "女"}[elder.Gender], "care_level": fmt.Sprintf("%d级照护", level)})
	}

	OK(c, gin.H{
		"updated_at":  time.Now(),
		"elders":      gin.H{"in_bed": eldersInBed},
		"elder_rows":  publicElders,
		"gender":      gender,
		"care_levels": careLevels,
		"age_buckets": ageBuckets,
		"devices":     gin.H{"total": devicesTotal, "online": devicesOnline, "list": publicDevices},
		"alerts":      gin.H{"new": alertsNew, "emergency": alertsEmergency, "list": recentAlerts},
		"tasks":       gin.H{"todo": tasksTodo},
		"bills":       gin.H{"unpaid_sum": unpaidSum},
	})
}

// Policy GET /api/v1/dashboard/policy returns the tenant-owned thresholds used
// by both dashboard clients and the IoT background service.
func (h *DashboardHandler) Policy(c *gin.Context) {
	policy, err := operationpolicy.Load(h.db.WithContext(c.Request.Context()))
	if err != nil {
		Fail(c, 500, 500, "查询运营策略失败")
		return
	}
	OK(c, policy)
}

type cockpitSummary struct {
	Residents       int `json:"residents"`
	OccupiedBeds    int `json:"occupied_beds"`
	TotalBeds       int `json:"total_beds"`
	FreeBeds        int `json:"free_beds"`
	StaffOnDuty     int `json:"staff_on_duty"`
	OpenTasks       int `json:"open_tasks"`
	OpenAlerts      int `json:"open_alerts"`
	EmergencyAlerts int `json:"emergency_alerts"`
	DevicesOnline   int `json:"devices_online"`
	DevicesTotal    int `json:"devices_total"`
}

type cockpitWard struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Floor       string  `json:"floor"`
	Residents   int     `json:"residents"`
	Capacity    int     `json:"capacity"`
	Occupancy   float64 `json:"occupancy"`
	StaffOnDuty int     `json:"staff_on_duty"`
	OpenTasks   int     `json:"open_tasks"`
	RiskCount   int     `json:"risk_count"`
}

type cockpitRoom struct {
	ID            uint     `json:"id"`
	Building      string   `json:"building"`
	Floor         int      `json:"floor"`
	RoomNumber    string   `json:"room_number"`
	ResidentNames []string `json:"resident_names"`
	OccupiedBeds  int      `json:"occupied_beds"`
	TotalBeds     int      `json:"total_beds"`
	CareLevel     int8     `json:"care_level"`
	Owner         string   `json:"owner"`
	VitalStatus   string   `json:"vital_status"`
	DevicesOnline int      `json:"devices_online"`
	DevicesTotal  int      `json:"devices_total"`
	OpenTasks     int      `json:"open_tasks"`
	Alerts        int      `json:"alerts"`
	LastRound     string   `json:"last_round"`
	NextTask      string   `json:"next_task"`
	Status        string   `json:"status"`
	Tone          string   `json:"tone"`
}

type cockpitEvent struct {
	ID       uint   `json:"id"`
	Time     string `json:"time"`
	Title    string `json:"title"`
	Detail   string `json:"detail"`
	Location string `json:"location"`
	Level    string `json:"level"`
	Tone     string `json:"tone"`
}

type cockpitFacility struct {
	ID     string `json:"id"`
	Label  string `json:"label"`
	Online int    `json:"online"`
	Total  int    `json:"total"`
	Note   string `json:"note"`
}

type cockpitWorkItem struct {
	ID        string `json:"id"`
	Label     string `json:"label"`
	Owner     string `json:"owner"`
	Completed int    `json:"completed"`
	Total     int    `json:"total"`
	Overdue   int    `json:"overdue"`
}

type cockpitRisk struct {
	ID    string  `json:"id"`
	Label string  `json:"label"`
	Count int     `json:"count"`
	Ratio float64 `json:"ratio"`
	Tone  string  `json:"tone"`
}

// Cockpit GET /api/v1/dashboard/cockpit returns one tenant-scoped snapshot for KanxiaobanDS.
// Every number and row is derived from persisted business records; the display client owns no demo dataset.
func (h *DashboardHandler) Cockpit(c *gin.Context) {
	db := h.db.WithContext(c.Request.Context())
	policy, err := operationpolicy.Load(db)
	if err != nil {
		Fail(c, 500, 500, "查询运营策略失败")
		return
	}
	var rooms []model.Room
	var beds []model.Bed
	var elders []model.Elder
	var tasks []model.CareTask
	var alerts []model.Alert
	var devices []model.IotDevice
	var schedules []model.Schedule
	var records []model.HealthRecord
	var executions []model.CareExecution

	queries := []error{
		db.Order("building, floor, room_no").Find(&rooms).Error,
		db.Order("room_id, bed_no").Find(&beds).Error,
		db.Where("status = ?", 2).Order("id").Find(&elders).Error,
		db.Order("due_at, id").Find(&tasks).Error,
		db.Order("create_time desc, id desc").Find(&alerts).Error,
		db.Where("discovery_status <> ? OR discovery_status IS NULL", "disabled").Order("building, room, bed").Find(&devices).Error,
		db.Where("work_date = ?", time.Now().Format("2006-01-02")).Order("staff").Find(&schedules).Error,
		db.Order("record_time desc, id desc").Find(&records).Error,
		db.Order("executed_at desc, id desc").Find(&executions).Error,
	}
	for _, err := range queries {
		if err != nil {
			Fail(c, 500, 500, "查询驾驶舱数据失败")
			return
		}
	}

	bedByID := make(map[uint]model.Bed, len(beds))
	bedsByRoom := make(map[uint][]model.Bed)
	for _, bed := range beds {
		bedByID[bed.ID] = bed
		bedsByRoom[bed.RoomID] = append(bedsByRoom[bed.RoomID], bed)
	}
	elderByID := make(map[uint]model.Elder, len(elders))
	roomByElder := make(map[uint]uint, len(elders))
	eldersByRoom := make(map[uint][]model.Elder)
	for _, elder := range elders {
		elderByID[elder.ID] = elder
		if elder.BedID != nil {
			if bed, ok := bedByID[*elder.BedID]; ok {
				eldersByRoom[bed.RoomID] = append(eldersByRoom[bed.RoomID], elder)
				roomByElder[elder.ID] = bed.RoomID
			}
		}
	}
	openTasksByElder := make(map[uint][]model.CareTask)
	for _, task := range tasks {
		if task.Status != "done" {
			openTasksByElder[task.ElderID] = append(openTasksByElder[task.ElderID], task)
		}
	}
	openAlertsByElder := make(map[uint][]model.Alert)
	for _, alert := range alerts {
		if alert.ElderID != nil && alert.Status != "closed" && alert.Status != "handled" {
			openAlertsByElder[*alert.ElderID] = append(openAlertsByElder[*alert.ElderID], alert)
		}
	}
	latestRecord := make(map[uint]model.HealthRecord)
	for _, record := range records {
		if _, ok := latestRecord[record.ElderID]; !ok {
			latestRecord[record.ElderID] = record
		}
	}
	latestExecution := make(map[uint]model.CareExecution)
	for _, execution := range executions {
		if _, ok := latestExecution[execution.ElderID]; !ok {
			latestExecution[execution.ElderID] = execution
		}
	}

	roomRows := make([]cockpitRoom, 0, len(rooms))
	wardRows := make([]cockpitWard, 0)
	wardIndex := make(map[string]int)
	for _, room := range rooms {
		roomElders := eldersByRoom[room.ID]
		row := cockpitRoom{ID: room.ID, Building: room.Building, Floor: room.Floor, RoomNumber: room.RoomNo,
			TotalBeds: len(bedsByRoom[room.ID]), Status: "正常", Tone: "success", VitalStatus: "暂无体征记录"}
		for _, elder := range roomElders {
			row.ResidentNames = append(row.ResidentNames, elder.Name)
			row.OccupiedBeds++
			if elder.CareLevel > row.CareLevel {
				row.CareLevel = elder.CareLevel
			}
			elderTasks := openTasksByElder[elder.ID]
			row.OpenTasks += len(elderTasks)
			if row.Owner == "" && len(elderTasks) > 0 {
				row.Owner = elderTasks[0].Assignee
			}
			if len(elderTasks) > 0 && elderTasks[0].DueAt != nil {
				row.NextTask = elderTasks[0].DueAt.Format("15:04") + " " + elderTasks[0].Title
			}
			for _, alert := range openAlertsByElder[elder.ID] {
				row.Alerts++
				if alert.Level == "emergency" {
					row.Status, row.Tone = "紧急", "danger"
				} else if row.Tone != "danger" {
					row.Status, row.Tone = "关注", "warning"
				}
			}
			if record, ok := latestRecord[elder.ID]; ok {
				if record.IsAbnormal {
					row.VitalStatus = "生命体征需关注"
					if row.Tone != "danger" {
						row.Status, row.Tone = "关注", "warning"
					}
				} else if row.VitalStatus == "暂无体征记录" {
					row.VitalStatus = "生命体征已记录"
				}
			}
			if execution, ok := latestExecution[elder.ID]; ok {
				if row.LastRound == "" || execution.ExecutedAt.Format("15:04") > row.LastRound {
					row.LastRound = execution.ExecutedAt.Format("15:04")
				}
			}
		}
		for _, device := range devices {
			matchesRoom := device.Building == room.Building && device.Room == room.RoomNo
			if !matchesRoom && device.ElderID != nil {
				matchesRoom = roomByElder[*device.ElderID] == room.ID
			}
			if matchesRoom {
				row.DevicesTotal++
				if device.Online == 1 {
					row.DevicesOnline++
				}
			}
		}
		if row.Owner == "" {
			row.Owner = "未分派"
		}
		if row.LastRound == "" {
			row.LastRound = "暂无"
		}
		if row.NextTask == "" {
			row.NextTask = "暂无待办"
		}
		roomRows = append(roomRows, row)

		wardKey := fmt.Sprintf("%s-%d", room.Building, room.Floor)
		idx, ok := wardIndex[wardKey]
		if !ok {
			idx = len(wardRows)
			wardIndex[wardKey] = idx
			wardRows = append(wardRows, cockpitWard{ID: wardKey, Name: room.Building, Floor: fmt.Sprintf("%d 层", room.Floor)})
		}
		wardRows[idx].Residents += row.OccupiedBeds
		wardRows[idx].Capacity += row.TotalBeds
		wardRows[idx].OpenTasks += row.OpenTasks
		wardRows[idx].RiskCount += row.Alerts
	}
	staffByScope := make(map[string]map[string]bool)
	for _, schedule := range schedules {
		for wardKey, idx := range wardIndex {
			ward := &wardRows[idx]
			if strings.Contains(schedule.RoomScope, ward.Name) || strings.Contains(schedule.RoomScope, strings.TrimSuffix(ward.Floor, " 层")) || schedule.RoomScope == "" {
				if staffByScope[wardKey] == nil {
					staffByScope[wardKey] = make(map[string]bool)
				}
				staffByScope[wardKey][schedule.Staff] = true
			}
		}
	}
	for i := range wardRows {
		wardRows[i].StaffOnDuty = len(staffByScope[wardRows[i].ID])
		if wardRows[i].Capacity > 0 {
			wardRows[i].Occupancy = float64(wardRows[i].Residents) * 100 / float64(wardRows[i].Capacity)
		}
	}

	openAlertCount, emergencyCount := 0, 0
	for _, alert := range alerts {
		if alert.Status == "closed" || alert.Status == "handled" {
			continue
		}
		openAlertCount++
		if alert.Level == "emergency" {
			emergencyCount++
		}
	}
	openTaskCount := 0
	for _, task := range tasks {
		if task.Status != "done" {
			openTaskCount++
		}
	}
	devicesOnline := 0
	for _, device := range devices {
		if device.Online == 1 {
			devicesOnline++
		}
	}
	staffNames := make(map[string]bool)
	for _, schedule := range schedules {
		staffNames[schedule.Staff] = true
	}

	eventRows := make([]cockpitEvent, 0, minInt(20, len(alerts)))
	for _, alert := range alerts {
		if len(eventRows) >= 20 {
			break
		}
		location := "全院"
		if alert.ElderID != nil {
			if elder, ok := elderByID[*alert.ElderID]; ok && elder.BedID != nil {
				if bed, ok := bedByID[*elder.BedID]; ok {
					for _, room := range rooms {
						if room.ID == bed.RoomID {
							location = fmt.Sprintf("%s %d层 %s房", room.Building, room.Floor, room.RoomNo)
							break
						}
					}
				}
			}
		}
		if alert.DeviceID != "" {
			for _, device := range devices {
				if device.DeviceID == alert.DeviceID && (device.Building != "" || device.Room != "") {
					location = strings.TrimSpace(device.Building + " " + device.Room + "房")
					break
				}
			}
		}
		level, tone := "关注", "warning"
		if alert.Level == "emergency" {
			level, tone = "紧急", "danger"
		} else if alert.Status == "closed" || alert.Status == "handled" {
			level, tone = "完成", "success"
		}
		eventRows = append(eventRows, cockpitEvent{ID: alert.ID, Time: alert.CreateTime.Format("15:04"),
			Title: alertTitle(alert.Type), Detail: alert.Content, Location: location, Level: level, Tone: tone})
	}

	facilityMap := make(map[string]*cockpitFacility)
	for _, device := range devices {
		key := strings.TrimSpace(device.Product)
		if key == "" {
			key = "other"
		}
		item := facilityMap[key]
		if item == nil {
			item = &cockpitFacility{ID: key, Label: deviceProductLabel(key)}
			facilityMap[key] = item
		}
		item.Total++
		if device.Online == 1 {
			item.Online++
		}
	}
	facilityRows := make([]cockpitFacility, 0, len(facilityMap))
	for _, item := range facilityMap {
		item.Note = fmt.Sprintf("%d 台离线", item.Total-item.Online)
		facilityRows = append(facilityRows, *item)
	}
	sort.Slice(facilityRows, func(i, j int) bool { return facilityRows[i].ID < facilityRows[j].ID })

	workRows := buildCockpitWorkItems(tasks)
	riskRows := buildCockpitRisks(alerts)
	occupiedBeds, freeBeds := 0, 0
	for _, bed := range beds {
		if bed.Status == "occupied" || bed.ElderID != nil {
			occupiedBeds++
		} else if bed.Status == "free" {
			freeBeds++
		}
	}
	summary := cockpitSummary{Residents: len(elders), OccupiedBeds: occupiedBeds, TotalBeds: len(beds),
		FreeBeds: freeBeds, StaffOnDuty: len(staffNames), OpenTasks: openTaskCount,
		OpenAlerts: openAlertCount, EmergencyAlerts: emergencyCount, DevicesOnline: devicesOnline, DevicesTotal: len(devices)}
	OK(c, gin.H{"updated_at": time.Now(), "policy": policy, "summary": summary, "wards": wardRows, "rooms": roomRows,
		"events": eventRows, "facilities": facilityRows, "work_items": workRows, "risks": riskRows})
}

func buildCockpitWorkItems(tasks []model.CareTask) []cockpitWorkItem {
	items := make(map[string]*cockpitWorkItem)
	now := time.Now()
	for _, task := range tasks {
		key := strings.TrimSpace(task.Kind)
		if key == "" {
			key = "other"
		}
		item := items[key]
		if item == nil {
			item = &cockpitWorkItem{ID: key, Label: taskKindLabel(key), Owner: task.Assignee}
			items[key] = item
		}
		item.Total++
		if task.Status == "done" {
			item.Completed++
		} else if task.DueAt != nil && task.DueAt.Before(now) {
			item.Overdue++
		}
		if item.Owner == "" && task.Assignee != "" {
			item.Owner = task.Assignee
		}
	}
	result := make([]cockpitWorkItem, 0, len(items))
	for _, item := range items {
		if item.Owner == "" {
			item.Owner = "未分派"
		}
		result = append(result, *item)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].ID < result[j].ID })
	return result
}

func buildCockpitRisks(alerts []model.Alert) []cockpitRisk {
	counts := make(map[string]int)
	total := 0
	for _, alert := range alerts {
		if alert.Status == "closed" || alert.Status == "handled" {
			continue
		}
		key := strings.TrimSpace(alert.Type)
		if key == "" {
			key = "other"
		}
		counts[key]++
		total++
	}
	result := make([]cockpitRisk, 0, len(counts))
	for key, count := range counts {
		ratio := 0.0
		if total > 0 {
			ratio = float64(count) * 100 / float64(total)
		}
		tone := "warning"
		if strings.Contains(key, "fall") || strings.Contains(key, "sos") {
			tone = "danger"
		}
		result = append(result, cockpitRisk{ID: key, Label: alertTitle(key), Count: count, Ratio: ratio, Tone: tone})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Count > result[j].Count })
	return result
}

func taskKindLabel(kind string) string {
	labels := map[string]string{"medication": "用药照护", "feeding": "膳食与饮水", "meal": "膳食与饮水",
		"turnover": "翻身与体位", "health": "生命体征", "round": "巡视照护", "rehab": "康复训练",
		"daily_living": "生活照护", "clean": "清洁与环境", "other": "其他任务"}
	if label, ok := labels[kind]; ok {
		return label
	}
	return kind
}

func alertTitle(kind string) string {
	labels := map[string]string{"fall": "跌倒风险", "sos": "紧急呼叫", "leave_bed": "离床预警", "vital": "生命体征异常",
		"device_offline": "设备离线", "environment": "环境异常", "other": "其他告警"}
	if label, ok := labels[kind]; ok {
		return label
	}
	return kind
}

func deviceProductLabel(product string) string {
	labels := map[string]string{"breath_radar": "生命体征监测", "fall_radar": "跌倒监测", "call": "床旁呼叫设备",
		"access": "门禁与定位", "environment": "环境传感设备", "other": "其他设备"}
	if label, ok := labels[product]; ok {
		return label
	}
	return product
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
