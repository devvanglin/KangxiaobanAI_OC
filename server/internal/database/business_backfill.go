package database

import (
	"context"
	"errors"
	"strings"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/healthrisk"
	"kangxiaoban-service/internal/model"
)

const (
	bootstrapTurnoverInstructions   = "核对长者体位与皮肤受压情况\n协助翻身并使用软枕保护骨突部位\n记录执行时间、皮肤情况及后续观察事项"
	bootstrapMedicationInstructions = "核对长者、医嘱、药名、剂量与给药时间\n确认血压及进食情况符合医嘱要求\n协助服药并观察反应，完成用药记录"
)

// backfillBusinessFields upgrades rows created before the server-owned business fields existed.
func backfillBusinessFields(db *gorm.DB) error {
	var tenants []model.Tenant
	if err := db.Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		if err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			if err := backfillElderAllergies(tx); err != nil {
				return err
			}
			if err := backfillCareTasks(tx); err != nil {
				return err
			}
			if err := backfillHealthRecords(tx); err != nil {
				return err
			}
			if err := backfillIotDevices(tx); err != nil {
				return err
			}
			return backfillMedications(tx)
		}); err != nil {
			return err
		}
	}
	return nil
}

func backfillElderAllergies(db *gorm.DB) error {
	var elders []model.Elder
	if err := db.Find(&elders).Error; err != nil {
		return err
	}
	for i := range elders {
		if elders[i].Allergies != nil {
			continue
		}
		allergies := []string{}
		if elders[i].Name == "张素英" {
			allergies = []string{"青霉素"}
		}
		if err := db.Model(&elders[i]).Select("Allergies").Updates(&model.Elder{Allergies: allergies}).Error; err != nil {
			return err
		}
	}
	return nil
}

func backfillCareTasks(db *gorm.DB) error {
	var tasks []model.CareTask
	if err := db.Find(&tasks).Error; err != nil {
		return err
	}
	for i := range tasks {
		category := taskCategoryForKind(tasks[i].Kind)
		priority := tasks[i].Priority
		remark := tasks[i].Remark
		if tasks[i].PlanItemID != nil {
			var item model.CarePlanItem
			if err := db.First(&item, *tasks[i].PlanItemID).Error; err == nil {
				priority = taskPriorityForRisk(item.RiskLevel)
				if strings.TrimSpace(remark) == "" && strings.TrimSpace(item.Instructions) != "" {
					remark = item.Instructions
				}
			} else if !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
		}
		switch {
		case tasks[i].Title == "早间翻身" && tasks[i].Kind == "turnover" &&
			(strings.TrimSpace(remark) == "" || strings.TrimSpace(remark) == "两小时一次"):
			remark = bootstrapTurnoverInstructions
		case tasks[i].Title == "服用降压药" && tasks[i].Kind == "medication" && strings.TrimSpace(remark) == "":
			remark = bootstrapMedicationInstructions
		}
		if priority == "" {
			priority = "normal"
		}
		if tasks[i].Category == category && tasks[i].Priority == priority && tasks[i].Remark == remark {
			continue
		}
		if err := db.Model(&tasks[i]).Updates(map[string]interface{}{
			"category": category,
			"priority": priority,
			"remark":   remark,
		}).Error; err != nil {
			return err
		}
	}
	return nil
}

func backfillHealthRecords(db *gorm.DB) error {
	var thresholds []model.HealthThreshold
	if err := db.Order("sort_order, id").Find(&thresholds).Error; err != nil {
		return err
	}
	var elders []model.Elder
	if err := db.Find(&elders).Error; err != nil {
		return err
	}
	elderNames := make(map[uint]string, len(elders))
	for _, elder := range elders {
		elderNames[elder.ID] = elder.Name
	}
	var records []model.HealthRecord
	if err := db.Find(&records).Error; err != nil {
		return err
	}
	for i := range records {
		applyBootstrapHealthMetrics(&records[i], elderNames[records[i].ElderID])
		level, summary, err := healthrisk.Evaluate(&records[i], thresholds)
		if err != nil {
			return err
		}
		records[i].RiskLevel = level
		records[i].RiskSummary = summary
		records[i].IsAbnormal = level != "normal"
		if err := db.Model(&records[i]).Select(
			"RespiratoryRate", "Steps", "SleepHours", "RiskLevel", "RiskSummary", "IsAbnormal",
		).Updates(&records[i]).Error; err != nil {
			return err
		}
	}
	return nil
}

func applyBootstrapHealthMetrics(record *model.HealthRecord, elderName string) {
	// IoT records are projections of real MQTT frames. Never fill missing
	// metrics with the caregiver demo values during startup backfill.
	if record.Source == "iot" {
		return
	}
	if record.RespiratoryRate != nil || record.Steps != nil || record.SleepHours != nil {
		return
	}
	switch elderName {
	case "张素英":
		record.RespiratoryRate = intPointer(18)
		record.Steps = intPointer(3860)
		record.SleepHours = floatPointer(6.8)
	case "王建国":
		record.RespiratoryRate = intPointer(24)
		record.Steps = intPointer(2180)
		record.SleepHours = floatPointer(5.2)
	}
}

func backfillIotDevices(db *gorm.DB) error {
	var devices []model.IotDevice
	if err := db.Find(&devices).Error; err != nil {
		return err
	}
	for i := range devices {
		updates := make(map[string]interface{})
		if devices[i].ElderID != nil && (devices[i].Building == "" || devices[i].Room == "" || devices[i].Bed == "") {
			var elder model.Elder
			if err := db.Preload("Bed.Room").First(&elder, *devices[i].ElderID).Error; err == nil && elder.Bed != nil {
				if devices[i].Building == "" && elder.Bed.Room != nil {
					updates["building"] = elder.Bed.Room.Building
				}
				if devices[i].Room == "" && elder.Bed.Room != nil {
					updates["room"] = elder.Bed.Room.RoomNo
				}
				if devices[i].Bed == "" {
					updates["bed"] = elder.Bed.BedNo
				}
			} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
		}
		if len(updates) > 0 {
			if err := db.Model(&devices[i]).Updates(updates).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func backfillMedications(db *gorm.DB) error {
	var medications []model.MedicationRecord
	if err := db.Find(&medications).Error; err != nil {
		return err
	}
	for i := range medications {
		if strings.TrimSpace(medications[i].Frequency) == "" {
			medications[i].Frequency = "按医嘱"
		}
		if strings.TrimSpace(medications[i].Route) == "" {
			if strings.Contains(medications[i].Dosage, "口服") {
				medications[i].Route = "口服"
			} else {
				medications[i].Route = "按医嘱"
			}
		}
		if medications[i].TodayTotal <= 0 {
			medications[i].TodayTotal = 1
		}
		if medications[i].Status == "taken" && medications[i].TodayDone == 0 {
			medications[i].TodayDone = medications[i].TodayTotal
		}
		if medications[i].TodayDone > medications[i].TodayTotal {
			medications[i].TodayDone = medications[i].TodayTotal
		}
		if err := db.Model(&medications[i]).Select(
			"Frequency", "Route", "TodayTotal", "TodayDone",
		).Updates(&medications[i]).Error; err != nil {
			return err
		}
	}
	return nil
}

func taskCategoryForKind(kind string) string {
	switch kind {
	case "medication":
		return "medication"
	case "health", "vital", "assessment":
		return "record"
	case "report":
		return "report"
	default:
		return "todo"
	}
}

func taskPriorityForRisk(risk string) string {
	switch risk {
	case "critical", "high", "danger":
		return "danger"
	case "medium", "warning":
		return "warning"
	default:
		return "normal"
	}
}

func applyDevicePlacement(device *model.IotDevice, elder model.Elder) {
	if elder.Bed == nil {
		return
	}
	device.Bed = elder.Bed.BedNo
	if elder.Bed.Room != nil {
		device.Building = elder.Bed.Room.Building
		device.Room = elder.Bed.Room.RoomNo
	}
}

func intPointer(value int) *int           { return &value }
func floatPointer(value float64) *float64 { return &value }
