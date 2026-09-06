package handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// MedicationHandler 管理端药物目录维护：机构在用药品的增删改查。
type MedicationHandler struct{ db *gorm.DB }

func NewMedicationHandler(db *gorm.DB) *MedicationHandler { return &MedicationHandler{db: db} }

func (h *MedicationHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	query := h.db.WithContext(c.Request.Context()).Model(&model.Medication{})
	if keyword := strings.TrimSpace(c.Query("keyword")); keyword != "" {
		like := "%" + keyword + "%"
		query = query.Where("name LIKE ? OR manufacturer LIKE ?", like, like)
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("status = ?", status)
	}
	var total int64
	if err := query.Count(&total).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询药物失败")
		return
	}
	var items []model.Medication
	if err := query.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "查询药物失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

type medicationInput struct {
	Name          string `json:"name" binding:"required"`
	Category      string `json:"category"`
	Specification string `json:"specification"`
	Manufacturer  string `json:"manufacturer"`
	UsageMethod   string `json:"usage_method"`
	Stock         *int   `json:"stock"`
	Unit          string `json:"unit"`
	Status        string `json:"status"`
	Note          string `json:"note"`
}

func (h *MedicationHandler) Create(c *gin.Context) {
	var input medicationInput
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Name) == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: name 必填")
		return
	}
	item := &model.Medication{
		Name:          strings.TrimSpace(input.Name),
		Category:      defaultText(input.Category, "西药"),
		Specification: strings.TrimSpace(input.Specification),
		Manufacturer:  strings.TrimSpace(input.Manufacturer),
		UsageMethod:   defaultText(input.UsageMethod, "口服"),
		Stock:         derefInt(input.Stock),
		Unit:          defaultText(input.Unit, "盒"),
		Status:        defaultText(input.Status, "in_use"),
		Note:          strings.TrimSpace(input.Note),
	}
	if err := h.db.WithContext(c.Request.Context()).Create(item).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "创建药物失败")
		return
	}
	OK(c, item)
}

func (h *MedicationHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input medicationInput
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Name) == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误: name 必填")
		return
	}
	db := h.db.WithContext(c.Request.Context())
	var item model.Medication
	if err := db.First(&item, uint(id)).Error; err != nil {
		Fail(c, http.StatusNotFound, 404, "药物不存在")
		return
	}
	item.Name = strings.TrimSpace(input.Name)
	item.Category = defaultText(input.Category, item.Category)
	item.Specification = strings.TrimSpace(input.Specification)
	item.Manufacturer = strings.TrimSpace(input.Manufacturer)
	item.UsageMethod = defaultText(input.UsageMethod, item.UsageMethod)
	if input.Stock != nil {
		item.Stock = *input.Stock
	}
	item.Unit = defaultText(input.Unit, item.Unit)
	if strings.TrimSpace(input.Status) != "" {
		item.Status = strings.TrimSpace(input.Status)
	}
	item.Note = strings.TrimSpace(input.Note)
	if err := db.Save(&item).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "更新药物失败")
		return
	}
	OK(c, item)
}

func (h *MedicationHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.db.WithContext(c.Request.Context()).Delete(&model.Medication{}, uint(id)).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "删除药物失败")
		return
	}
	OK(c, gin.H{"id": id})
}

func defaultText(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return strings.TrimSpace(value)
}

func derefInt(value *int) int {
	if value == nil {
		return 0
	}
	return *value
}
