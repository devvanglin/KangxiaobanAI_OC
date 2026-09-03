package iot

import (
	"context"
	"encoding/json"
	"log"
	"math"
	"strconv"
	"sync"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/healthrisk"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/operationpolicy"
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
	"battery":        "battery",
	"batteryLevel":   "battery",
	"batteryPercent": "battery",
}

type alertDef struct {
	typ  string
	lvl  string
	cond bool
	msg  string
}

// IotService 设备接入：MQTT 订阅 + 归一化 + 规则引擎 + 告警。
type IotService struct {
	db       *gorm.DB
	hub      *ws.Hub
	cooldown sync.Map // key=type:deviceID -> lastTime
	notify   func(context.Context, uint, string, string, string, string, string) error
}

func NewIotService(db *gorm.DB, hub *ws.Hub) *IotService {
	return &IotService{db: db, hub: hub}
}

// SetNotifier keeps the original callback shape for integrations compiled
// against earlier releases. New code should use SetTenantNotifier so the
// notification write carries the originating tenant.
func (s *IotService) SetNotifier(fn func(role, typ, title, content, severity string) error) {
	if fn == nil {
		s.notify = nil
		return
	}
	s.notify = func(_ context.Context, _ uint, role, typ, title, content, severity string) error {
		return fn(role, typ, title, content, severity)
	}
}

// SetTenantNotifier injects a tenant-aware notification provider.
func (s *IotService) SetTenantNotifier(fn func(context.Context, uint, string, string, string, string, string) error) {
	s.notify = fn
}

// Ingest 处理一帧设备数据（字段扁平）。
func (s *IotService) Ingest(deviceID, product string, values map[string]interface{}) error {
	return s.IngestContext(context.Background(), deviceID, product, values)
}

func (s *IotService) IngestContext(ctx context.Context, deviceID, product string, values map[string]interface{}) error {
	if deviceID == "" {
		return nil
	}
	db := s.db.WithContext(ctx)
	now := time.Now()
	battery := batteryFromValues(values)

	var dev model.IotDevice
	if err := db.Where("device_id = ?", deviceID).First(&dev).Error; err != nil {
		// 设备未知：登记
		dev = model.IotDevice{DeviceID: deviceID, Product: product, Protocol: "MQTT", Online: 1, Battery: battery}
		if dev.Product == "" {
			dev.Product = "unknown"
		}
		t := now
		dev.LastSeen = &t
		if err := db.Create(&dev).Error; err != nil {
			return err
		}
	} else {
		updates := map[string]interface{}{"online": 1, "last_seen": now}
		if product != "" && dev.Product == "" {
			updates["product"] = product
		}
		if battery != nil {
			updates["battery"] = *battery
			dev.Battery = battery
		}
		if err := db.Model(&dev).Updates(updates).Error; err != nil {
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
		if err := db.Create(&sr).Error; err != nil {
			log.Printf("write signal failed: %v", err)
		}
	}

	s.evaluate(db, dev, values, now)
	return nil
}

// evaluate 规则引擎：按阈值产生分级告警（带去重），并经 WS 广播。
func (s *IotService) evaluate(db *gorm.DB, dev model.IotDevice, values map[string]interface{}, now time.Time) {
	policy := operationpolicy.LoadOrDefault(db)
	cooldownWindow := operationpolicy.Seconds(policy.AlertCooldownSeconds)
	defs := []alertDef{
		{"fall", "emergency", inStrings(values["fallStatus"], "1", "2", "3"), "检测到跌倒"},
	}
	var thresholds []model.HealthThreshold
	if err := db.Order("sort_order, id").Find(&thresholds).Error; err != nil {
		log.Printf("load health thresholds for IoT evaluation failed: %v", err)
	} else {
		defs = appendHealthMetricAlert(defs, thresholds, values, "breathValue", "respiratory_rate", "breath_abnormal")
		defs = appendHealthMetricAlert(defs, thresholds, values, "heartRateValue", "heart_rate", "heart_abnormal")
	}
	for _, d := range defs {
		if !d.cond {
			continue
		}
		if !s.okCooldown(d.typ, dev.DeviceID, now, cooldownWindow) {
			continue
		}
		s.createAlert(db, dev, d.typ, d.lvl, d.msg, now)
	}
}

func appendHealthMetricAlert(defs []alertDef, thresholds []model.HealthThreshold, values map[string]interface{}, sourceKey, metric, alertType string) []alertDef {
	value, ok := toFloatOK(values[sourceKey])
	if !ok || value <= 0 {
		return defs
	}
	level, summary, err := healthrisk.EvaluateMetric(metric, value, thresholds)
	if err != nil {
		log.Printf("evaluate IoT health metric %s failed: %v", metric, err)
		return defs
	}
	if level == "normal" {
		return defs
	}
	return append(defs, alertDef{typ: alertType, lvl: "important", cond: true, msg: summary})
}

func (s *IotService) createAlert(db *gorm.DB, dev model.IotDevice, typ, lvl, content string, now time.Time) {
	content = "[" + dev.DeviceID + "] " + content
	if dev.ElderID != nil {
		var elder model.Elder
		if err := db.First(&elder, *dev.ElderID).Error; err == nil {
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
	if err := db.Create(&a).Error; err == nil {
		s.hub.SendToTenant(a.TenantID, "alert.new", a)
		if s.notify != nil {
			for _, role := range []string{"admin", "caregiver", "doctor"} {
				_ = s.notify(db.Statement.Context, a.TenantID, role, "alert", "新的照护告警", content, lvl)
			}
		}
	}
}

func (s *IotService) okCooldown(typ, deviceID string, now time.Time, window time.Duration) bool {
	key := typ + ":" + deviceID
	if t, ok := s.cooldown.Load(key); ok {
		last := t.(time.Time)
		if now.Sub(last) < window {
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
		for _, tenantID := range s.tenantIDs() {
			ctx := context.WithValue(context.Background(), model.TenantContextKey, tenantID)
			db := s.db.WithContext(ctx)
			policy := operationpolicy.LoadOrDefault(db)
			cutoff := time.Now().Add(-operationpolicy.Seconds(policy.AlertEscalationSeconds))
			var alerts []model.Alert
			if err := db.Where("level IN ? AND status = 'new' AND create_time < ?", []string{"emergency", "important"}, cutoff).Find(&alerts).Error; err != nil {
				continue
			}
			for i := range alerts {
				if err := db.Model(&alerts[i]).Where("status = ?", "new").Update("status", "escalated").Error; err != nil {
					continue
				}
				alerts[i].Status = "escalated"
				s.hub.SendToTenant(tenantID, "alert.escalated", alerts[i])
			}
		}
	}
}

// tenantIDs reads the tenant registry (which is intentionally global) so
// background scanners process every institution instead of silently using
// tenant 1.
func (s *IotService) tenantIDs() []uint {
	var tenants []model.Tenant
	if err := s.db.Find(&tenants).Error; err != nil {
		return []uint{1}
	}
	ids := make([]uint, 0, len(tenants))
	for _, tenant := range tenants {
		if tenant.ID > 0 {
			ids = append(ids, tenant.ID)
		}
	}
	if len(ids) == 0 {
		return []uint{1}
	}
	return ids
}

func (s *IotService) contextForDevice(deviceID string) context.Context {
	var tenantID uint
	// Device IDs are globally unique in the current schema, so the raw lookup
	// can resolve an MQTT frame to its owning tenant before tenant scoping is
	// applied. Unknown devices are registered in the default tenant for
	// backward compatibility with existing topic formats.
	if err := s.db.Raw("SELECT tenant_id FROM iot_devices WHERE device_id = ? AND deleted_at IS NULL", deviceID).Scan(&tenantID).Error; err != nil || tenantID == 0 {
		tenantID = 1
	}
	return context.WithValue(context.Background(), model.TenantContextKey, tenantID)
}

// ListDevices 设备列表。
func (s *IotService) ListDevices(page, size int) ([]model.IotDevice, int64, error) {
	ctx := context.Background()
	q := s.db.WithContext(ctx).Model(&model.IotDevice{})
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var items []model.IotDevice
	err := q.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error
	return items, total, err
}

func (s *IotService) CreateDevice(ctx context.Context, device *model.IotDevice) error {
	return s.db.WithContext(ctx).Create(device).Error
}

func (s *IotService) DeleteDevice(ctx context.Context, id uint) error {
	return s.db.WithContext(ctx).Delete(&model.IotDevice{}, id).Error
}

func (s *IotService) GetAlert(ctx context.Context, id uint) (*model.Alert, error) {
	var a model.Alert
	if err := s.db.WithContext(ctx).First(&a, id).Error; err != nil {
		return nil, err
	}
	return &a, nil
}

// ListAlerts 告警列表（可按状态/级别筛）。
func (s *IotService) ListAlerts(status, level string, page, size int) ([]model.Alert, int64, error) {
	ctx := context.Background()
	q := s.db.WithContext(ctx).Model(&model.Alert{})
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
func (s *IotService) HandleAlert(ctx context.Context, id uint, by string, closeIt bool) error {
	db := s.db.WithContext(ctx)
	var a model.Alert
	if err := db.First(&a, id).Error; err != nil {
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
	if err := db.Model(&a).Updates(updates).Error; err != nil {
		return err
	}
	action := "acknowledge"
	if closeIt {
		action = "close"
	}
	return s.RecordAlertAction(ctx, id, 0, action, "")
}

// RecordAlertAction 记录告警处置时间线，便于复盘和质控。
func (s *IotService) RecordAlertAction(ctx context.Context, alertID, userID uint, action, note string) error {
	return s.db.WithContext(ctx).Create(&model.AlertAction{AlertID: alertID, UserID: userID, Action: action, Note: note}).Error
}

// ListAlertActions 查询告警处置时间线。
func (s *IotService) ListAlertActions(ctx context.Context, alertID uint, page, size int) ([]model.AlertAction, int64, error) {
	q := s.db.WithContext(ctx).Model(&model.AlertAction{}).Where("alert_id = ?", alertID)
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var out []model.AlertAction
	err := q.Order("id asc").Offset((page - 1) * size).Limit(size).Find(&out).Error
	return out, total, err
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

func batteryFromValues(values map[string]interface{}) *int {
	for _, key := range []string{"battery", "batteryLevel", "batteryPercent"} {
		value, exists := values[key]
		if !exists {
			continue
		}
		parsed, ok := toFloatOK(value)
		if !ok {
			return nil
		}
		battery := int(math.Round(parsed))
		if battery < 0 {
			battery = 0
		}
		if battery > 100 {
			battery = 100
		}
		return &battery
	}
	return nil
}

func toFloatOK(v interface{}) (float64, bool) {
	switch t := v.(type) {
	case json.Number:
		f, err := t.Float64()
		return f, err == nil
	case float64:
		return t, true
	case float32:
		return float64(t), true
	case int:
		return float64(t), true
	case int64:
		return float64(t), true
	case string:
		f, err := strconv.ParseFloat(t, 64)
		return f, err == nil
	default:
		return 0, false
	}
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
