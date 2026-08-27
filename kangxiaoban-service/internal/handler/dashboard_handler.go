package handler

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
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
	var (
		eldersTotal, eldersInBed         int64
		devicesTotal, devicesOnline      int64
		alertsTotal, alertsNew, alertsEm int64
		tasksTodo                        int64
		unpaidCount                      int64
		unpaidSum, paidSum               float64
	)

	// 长者
	h.db.Model(&model.Elder{}).Count(&eldersTotal)
	h.db.Model(&model.Elder{}).Where("status = 2").Count(&eldersInBed)
	// 设备
	h.db.Model(&model.IotDevice{}).Count(&devicesTotal)
	h.db.Model(&model.IotDevice{}).Where("online = 1").Count(&devicesOnline)
	// 告警
	h.db.Model(&model.Alert{}).Count(&alertsTotal)
	h.db.Model(&model.Alert{}).Where("status = 'new'").Count(&alertsNew)
	h.db.Model(&model.Alert{}).Where("level = 'emergency' AND status != 'closed'").Count(&alertsEm)
	// 待办任务
	h.db.Model(&model.CareTask{}).Where("status = 'todo'").Count(&tasksTodo)
	// 账单待缴
	h.db.Model(&model.Bill{}).Where("status = 'unpaid' OR status = 'partial'").Select("COALESCE(SUM(amount - paid),0)").Scan(&unpaidSum)
	h.db.Model(&model.Bill{}).Where("status = 'unpaid' OR status = 'partial'").Where("amount > paid").Count(&unpaidCount)
	h.db.Model(&model.Bill{}).Select("COALESCE(SUM(paid),0)").Scan(&paidSum)

	OK(c, gin.H{
		"elders": gin.H{"total": eldersTotal, "in_bed": eldersInBed},
		"devices": gin.H{"total": devicesTotal, "online": devicesOnline},
		"alerts": gin.H{"total": alertsTotal, "new": alertsNew, "emergency": alertsEm},
		"tasks": gin.H{"todo": tasksTodo},
		"bills": gin.H{"unpaid_count": unpaidCount, "unpaid_sum": unpaidSum, "paid_sum": paidSum},
	})
}