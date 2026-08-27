package iot

import (
	"encoding/json"
	"log"
	"strconv"
	"sync"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/ws"
)

// 别名映射：雷达字段 -> 归一化信号类型（白名单，未命中忽略）。
var fieldTypes = map[string]string{
	"someoneExists":  "presence",
	"sleepStatus":    "sleep_status",
	"getIntoBed":     "in_bed",
	"breathValue":    "breath_rate",
	"heartRateValue": "heart_rate",
	"movementSigns":  "movement",
	"motionStatus":   "motion_status",
	"humanDistance":  "distance_cm",
	"humanPosition":  "position_cm",
	"fallStatus":     "fall_status",
	"fallPosition":   "fall_position",
	"online":         "online",
}

// cooldownWindow 同类告警去重窗口。
const cooldownWindow = 60 * time.Second

// IotService 设备接入：MQTT 订阅 + 归一化 + 规则引擎 + 告警。
type IotService struct {
	db       *gorm.DB
	hub      *ws.Hub
	cooldown sync.Map // key=type:deviceID -> lastTime
}

func NewIotService(db *gorm.DB, hub *ws.Hub) *IotService {
	return &IotService{db: db, hub: hub}
}

// Ingest 处理一帧设备数据（字段扁平）。
func (s *IotService) Ingest(deviceID, product string, values map[string]interface{}) error {
	if deviceID == "" {
		return nil
	}
	now := time.Now()

	var dev model.IotDevice
	if err := s.db.Where("device_id = ?", deviceID).First(&dev).Error; err != nil {
		// 设备未知：登记
		dev = model.IotDevice{DeviceID: deviceID, Product: product, Protocol: "MQTT", Online: 1}
		if dev.Product == "" {
			dev.Product = "unknown"
		}
		t := now
		dev.LastSeen = &t
		if err := s.db.Create(&dev).Error; err != nil {
			return err
		}
	} else {
		updates := map[string]interface{}{"online": 1, "last_seen": now}
		if product != "" && dev.Product == "" {
			updates["product"] = product
		}
		if err := s.db.Model(&dev).Updates(updates).Error; err != nil {
			return err
		}
	}

	// 写入信号记录
	for k, v := range values {
		typ := fieldTypes[k]
		if typ == "" {
			continue
		}
		sr := model.SignalRecord{DeviceID: deviceID, ElderID: dev.ElderID, Type: typ, Value: toStr(v), TS: now}
		if err := s.db.Create(&sr).Error; err != nil {
			log.Printf("write signal failed: %v", err)
		}
	}

	s.evaluate(dev, values, now)
	return nil
}

// evaluate 规则引擎：按阈值产生分级告警（带去重），并经 WS 广播。
func (s *IotService) evaluate(dev model.IotDevice, values map[string]interface{}, now time.Time) {
	type alertDef struct {
		typ  string
		lvl  string
		cond bool
		msg  string
	}

	breath := toFloat(values["breathValue"])
	heart := toFloat(values["heartRateValue"])

	defs := []alertDef{
		{"fall", "emergency", inStrings(values["fallStatus"], "1", "2", "3"), "检测到跌倒"},
		{"breath_abnormal", "important", breath != 0 && (breath < 10 || breath > 25),
			"呼吸异常(次/分=" + toStr(values["breathValue"]) + ")"},
		{"heart_abnormal", "important", heart != 0 && (heart < 40 || heart > 120),
			"心率异常(bpm=" + toStr(values["heartRateValue"]) + ")"},
	}
	for _, d := range defs {
		if !d.cond {
			continue
		}
		if !s.okCooldown(d.typ, dev.DeviceID, now) {
			continue
		}
		s.createAlert(dev, d.typ, d.lvl, d.msg, now)
	}
}

func (s *IotService) createAlert(dev model.IotDevice, typ, lvl, content string, now time.Time) {
	content = "[" + dev.DeviceID + "] " + content
	if dev.ElderID != nil {
		var elder model.Elder
		if err := s.db.First(&elder, *dev.ElderID).Error; err == nil {
			content = "长者[" + elder.Name + "] " + content
		}
	}
	a := model.Alert{
		ElderID:    dev.ElderID,
		DeviceID:   dev.DeviceID,
		Type:       typ,
		Level:      lvl,
		Content:    content,
		Status:     "new",
		CreateTime: now,
	}
	if err := s.db.Create(&a).Error; err == nil {
		s.hub.BroadcastEvent("alert.new", a)
	}
}

func (s *IotService) okCooldown(typ, deviceID string, now time.Time) bool {
	key := typ + ":" + deviceID
	if t, ok := s.cooldown.Load(key); ok {
		last := t.(time.Time)
		if now.Sub(last) < cooldownWindow {
			return false
		}
	}
	s.cooldown.Store(key, now)
	return true
}

// StartEscalationScanner 应急自动升级：紧急/重要告警 new 超时未被处置 → escalated 并广播。
func (s *IotService) StartEscalationScanner() {
	ticker := time.NewTicker(15 * time.Second)
	for range ticker.C {
		cutoff := time.Now().Add(-escalationAfter)
		var alerts []model.Alert
		if err := s.db.Where("level IN ? AND status = 'new' AND create_time < ?", []string{"emergency", "important"}, cutoff).Find(&alerts).Error; err != nil {
			continue
		}
		for i := range alerts {
			s.db.Model(&alerts[i]).Update("status", "escalated")
			alerts[i].Status = "escalated"
			s.hub.BroadcastEvent("alert.escalated", alerts[i])
		}
	}
}

// ListDevices 设备列表。
func (s *IotService) ListDevices(page, size int) ([]model.IotDevice, int64, error) {
	var total int64
	if err := s.db.Model(&model.IotDevice{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.IotDevice
	err := s.db.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

// ListAlerts 告警列表（可按状态/级别筛）。
func (s *IotService) ListAlerts(status, level string, page, size int) ([]model.Alert, int64, error) {
	return s.ListAlertsScoped(status, level, page, size, nil)
}

// ListAlertsScoped 告警列表；allowed 非空时仅返回绑定长者告警（用于家属隔离）。
func (s *IotService) ListAlertsScoped(status, level string, page, size int, allowed []uint) ([]model.Alert, int64, error) {
	q := s.db.Model(&model.Alert{})
	if len(allowed) > 0 {
		q = q.Where("elder_id IN ?", allowed)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if level != "" {
		q = q.Where("level = ?", level)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.Alert
	err := q.Order("create_time desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

// HandleAlert 处置告警（转 handled/closed）。
func (s *IotService) HandleAlert(id uint, by string, closeIt bool) error {
	var a model.Alert
	if err := s.db.First(&a, id).Error; err != nil {
		return err
	}
	status := "handled"
	if closeIt {
		status = "closed"
	}
	now := time.Now()
	updates := map[string]interface{}{"status": status, "handled_by": by}
	if closeIt {
		updates["close_time"] = now
	}
	return s.db.Model(&a).Updates(updates).Error
}

// toStr 任意值转字符串。
func toStr(v interface{}) string {
	if v == nil {
		return ""
	}
	if b, ok := v.(json.Number); ok {
		return b.String()
	}
	if s, ok := v.(string); ok {
		return s
	}
	bs, _ := json.Marshal(v)
	return string(bs)
}

func toFloat(v interface{}) float64 {
	switch t := v.(type) {
	case json.Number:
		f, _ := t.Float64()
		return f
	case float64:
		return t
	case float32:
		return float64(t)
	case int:
		return float64(t)
	case int64:
		return float64(t)
	case string:
		f, _ := strconv.ParseFloat(t, 64)
		return f
	}
	return 0
}

func inStrings(v interface{}, want ...string) bool {
	s := toStr(v)
	for _, w := range want {
		if s == w {
			return true
		}
	}
	return false
}