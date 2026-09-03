package handler

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

type AreaHandler struct{ db *gorm.DB }

func NewAreaHandler(db *gorm.DB) *AreaHandler { return &AreaHandler{db: db} }

func (h *AreaHandler) List(c *gin.Context) {
	query := h.db.WithContext(c.Request.Context()).Model(&model.Area{})
	if value := strings.TrimSpace(c.Query("type")); value != "" {
		query = query.Where("type = ?", value)
	}
	if floor := parseInt(c, "floor", 0); floor > 0 {
		query = query.Where("floor_no = ?", floor)
	}
	var areas []model.Area
	if err := query.Order("floor_no asc, sort_order asc, id asc").Find(&areas).Error; err != nil {
		Fail(c, 500, 500, "查询区域失败")
		return
	}
	OK(c, gin.H{"list": areas})
}

type areaInput struct {
	ParentID    *uint  `json:"parent_id"`
	Type        string `json:"type" binding:"required"`
	Code        string `json:"code" binding:"required"`
	Name        string `json:"name" binding:"required"`
	Building    string `json:"building"`
	FloorNo     int    `json:"floor_no"`
	Status      string `json:"status"`
	SortOrder   int    `json:"sort_order"`
	Description string `json:"description"`
}

func validateAreaType(value string) bool {
	switch model.AreaType(strings.TrimSpace(value)) {
	case model.AreaTypeFloor, model.AreaTypeRoom, model.AreaTypeCorridor, model.AreaTypeStair, model.AreaTypeCommon, model.AreaTypeOther:
		return true
	default:
		return false
	}
}

func (h *AreaHandler) Create(c *gin.Context) {
	var input areaInput
	if err := c.ShouldBindJSON(&input); err != nil || !validateAreaType(input.Type) || strings.TrimSpace(input.Code) == "" || strings.TrimSpace(input.Name) == "" {
		Fail(c, http.StatusBadRequest, 400, "区域类型、编码和名称必填")
		return
	}
	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = "active"
	}
	area := &model.Area{ParentID: input.ParentID, Type: model.AreaType(input.Type), Code: strings.TrimSpace(input.Code), Name: strings.TrimSpace(input.Name), Building: strings.TrimSpace(input.Building), FloorNo: input.FloorNo, Status: status, SortOrder: input.SortOrder, Description: strings.TrimSpace(input.Description)}
	if err := h.db.WithContext(c.Request.Context()).Create(area).Error; err != nil {
		Fail(c, http.StatusConflict, 409, "区域编码已存在或创建失败")
		return
	}
	OK(c, area)
}

func (h *AreaHandler) Update(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input areaInput
	if err := c.ShouldBindJSON(&input); err != nil || !validateAreaType(input.Type) || strings.TrimSpace(input.Code) == "" || strings.TrimSpace(input.Name) == "" {
		Fail(c, 400, 400, "区域类型、编码和名称必填")
		return
	}
	var area model.Area
	db := h.db.WithContext(c.Request.Context())
	if err := db.First(&area, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "区域不存在")
		return
	}
	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = area.Status
	}
	updates := map[string]interface{}{"parent_id": input.ParentID, "type": input.Type, "code": strings.TrimSpace(input.Code), "name": strings.TrimSpace(input.Name), "building": strings.TrimSpace(input.Building), "floor_no": input.FloorNo, "status": status, "sort_order": input.SortOrder, "description": strings.TrimSpace(input.Description)}
	if err := db.Model(&area).Updates(updates).Error; err != nil {
		Fail(c, 409, 409, "区域更新失败")
		return
	}
	if err := db.First(&area, uint(id)).Error; err != nil {
		Fail(c, 500, 500, "读取更新后的区域失败")
		return
	}
	OK(c, area)
}

func (h *AreaHandler) Delete(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	db := h.db.WithContext(c.Request.Context())
	var childCount int64
	db.Model(&model.Area{}).Where("parent_id = ?", uint(id)).Count(&childCount)
	if childCount > 0 {
		Fail(c, 409, 409, "区域仍有下级区域，不能删除")
		return
	}
	var area model.Area
	if err := db.First(&area, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "区域不存在")
		return
	}
	if err := db.Delete(&area).Error; err != nil {
		Fail(c, 500, 500, "删除区域失败")
		return
	}
	OK(c, gin.H{"deleted": true})
}
