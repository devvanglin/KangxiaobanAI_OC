package handler

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
)

type CarePackageHandler struct{ db *gorm.DB }

func NewCarePackageHandler(db *gorm.DB) *CarePackageHandler { return &CarePackageHandler{db: db} }

func (h *CarePackageHandler) ListTemplates(c *gin.Context) {
	query := h.db.WithContext(c.Request.Context()).Preload("Items").Model(&model.CarePackageTemplate{})
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("status = ?", status)
	}
	var items []model.CarePackageTemplate
	if err := query.Order("id desc").Find(&items).Error; err != nil {
		Fail(c, 500, 500, "查询护理套餐失败")
		return
	}
	OK(c, gin.H{"list": items})
}

type carePackageTemplateInput struct {
	Code                string  `json:"code" binding:"required"`
	Name                string  `json:"name" binding:"required"`
	Description         string  `json:"description"`
	ApplicableCareLevel *int8   `json:"applicable_care_level"`
	MonthlyPrice        float64 `json:"monthly_price"`
	Currency            string  `json:"currency"`
	Status              string  `json:"status"`
}

func (h *CarePackageHandler) CreateTemplate(c *gin.Context) {
	var input carePackageTemplateInput
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Code) == "" || strings.TrimSpace(input.Name) == "" {
		Fail(c, 400, 400, "套餐编码和名称必填")
		return
	}
	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = "draft"
	}
	currency := strings.TrimSpace(input.Currency)
	if currency == "" {
		currency = "CNY"
	}
	template := &model.CarePackageTemplate{Code: strings.TrimSpace(input.Code), Name: strings.TrimSpace(input.Name), Description: strings.TrimSpace(input.Description), ApplicableCareLevel: input.ApplicableCareLevel, MonthlyPrice: input.MonthlyPrice, Currency: currency, Status: status, Version: 1}
	if err := h.db.WithContext(c.Request.Context()).Create(template).Error; err != nil {
		Fail(c, 409, 409, "套餐编码已存在或创建失败")
		return
	}
	OK(c, template)
}

func (h *CarePackageHandler) UpdateTemplate(c *gin.Context) {
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input carePackageTemplateInput
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Code) == "" || strings.TrimSpace(input.Name) == "" {
		Fail(c, 400, 400, "套餐编码和名称必填")
		return
	}
	db := h.db.WithContext(c.Request.Context())
	var template model.CarePackageTemplate
	if err := db.First(&template, uint(id)).Error; err != nil {
		Fail(c, 404, 404, "套餐不存在")
		return
	}
	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = template.Status
	}
	currency := strings.TrimSpace(input.Currency)
	if currency == "" {
		currency = template.Currency
	}
	if err := db.Model(&template).Updates(map[string]interface{}{"code": strings.TrimSpace(input.Code), "name": strings.TrimSpace(input.Name), "description": strings.TrimSpace(input.Description), "applicable_care_level": input.ApplicableCareLevel, "monthly_price": input.MonthlyPrice, "currency": currency, "status": status, "version": gorm.Expr("version + 1")}).Error; err != nil {
		Fail(c, 409, 409, "套餐更新失败")
		return
	}
	db.Preload("Items").First(&template, uint(id))
	OK(c, template)
}

type carePackageItemInput struct {
	Title        string `json:"title" binding:"required"`
	Kind         string `json:"kind"`
	Frequency    string `json:"frequency"`
	Instructions string `json:"instructions"`
	RiskLevel    string `json:"risk_level"`
	AssigneeRole string `json:"assignee_role"`
	SortOrder    int    `json:"sort_order"`
	Enabled      *bool  `json:"enabled"`
}

func (h *CarePackageHandler) AddTemplateItem(c *gin.Context) {
	templateID, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input carePackageItemInput
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Title) == "" {
		Fail(c, 400, 400, "护理项目名称必填")
		return
	}
	var template model.CarePackageTemplate
	db := h.db.WithContext(c.Request.Context())
	if err := db.First(&template, uint(templateID)).Error; err != nil {
		Fail(c, 404, 404, "套餐不存在")
		return
	}
	enabled := true
	if input.Enabled != nil {
		enabled = *input.Enabled
	}
	item := &model.CarePackageItem{TemplateID: uint(templateID), Title: strings.TrimSpace(input.Title), Kind: strings.TrimSpace(input.Kind), Frequency: strings.TrimSpace(input.Frequency), Instructions: strings.TrimSpace(input.Instructions), RiskLevel: strings.TrimSpace(input.RiskLevel), AssigneeRole: strings.TrimSpace(input.AssigneeRole), SortOrder: input.SortOrder, Enabled: enabled}
	if err := db.Create(item).Error; err != nil {
		Fail(c, 409, 409, "护理项目保存失败")
		return
	}
	OK(c, item)
}

// DeleteTemplateItem removes a service item from a template. Care plans
// already generated for subscribers keep their own copies, so removal only
// affects future subscriptions.
func (h *CarePackageHandler) DeleteTemplateItem(c *gin.Context) {
	templateID, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	itemID, _ := strconv.ParseUint(c.Param("itemId"), 10, 64)
	db := h.db.WithContext(c.Request.Context())
	var template model.CarePackageTemplate
	if err := db.First(&template, uint(templateID)).Error; err != nil {
		Fail(c, 404, 404, "套餐不存在")
		return
	}
	var item model.CarePackageItem
	if err := db.Where("id = ? AND template_id = ?", uint(itemID), uint(templateID)).First(&item).Error; err != nil {
		Fail(c, 404, 404, "护理项目不存在")
		return
	}
	if err := db.Delete(&item).Error; err != nil {
		Fail(c, 409, 409, "护理项目删除失败")
		return
	}
	OK(c, gin.H{"id": item.ID})
}

type subscriptionInput struct {
	TemplateID uint   `json:"template_id" binding:"required"`
	StartDate  string `json:"start_date"`
	EndDate    string `json:"end_date"`
}

func (h *CarePackageHandler) ListSubscriptions(c *gin.Context) {
	elderID, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var items []model.ElderCarePackageSubscription
	if err := h.db.WithContext(c.Request.Context()).Where("elder_id = ?", uint(elderID)).Order("id desc").Find(&items).Error; err != nil {
		Fail(c, 500, 500, "查询长者护理套餐失败")
		return
	}
	OK(c, gin.H{"list": items})
}

func (h *CarePackageHandler) CreateSubscription(c *gin.Context) {
	elderID, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	var input subscriptionInput
	if err := c.ShouldBindJSON(&input); err != nil || input.TemplateID == 0 {
		Fail(c, 400, 400, "template_id 必填")
		return
	}
	start := strings.TrimSpace(input.StartDate)
	if start == "" {
		start = time.Now().Format("2006-01-02")
	}
	claims, _ := middleware.ClaimsFrom(c)
	var assignedBy uint
	if claims != nil {
		assignedBy = claims.UserID
	}
	db := h.db.WithContext(c.Request.Context())
	var subscription model.ElderCarePackageSubscription
	err := db.Transaction(func(tx *gorm.DB) error {
		var elder model.Elder
		if err := tx.First(&elder, uint(elderID)).Error; err != nil {
			return gorm.ErrRecordNotFound
		}
		var template model.CarePackageTemplate
		if err := tx.Preload("Items").Where("id = ? AND status = ?", input.TemplateID, "active").First(&template).Error; err != nil {
			return err
		}
		plan := model.CarePlan{ElderID: uint(elderID), TemplateID: &template.ID, Name: template.Name, Status: "active", StartDate: start, EndDate: input.EndDate, CreatedBy: assignedBy}
		if err := tx.Create(&plan).Error; err != nil {
			return err
		}
		for _, item := range template.Items {
			if !item.Enabled {
				continue
			}
			planItem := model.CarePlanItem{CarePlanID: plan.ID, Title: item.Title, Kind: item.Kind, Frequency: item.Frequency, Instructions: item.Instructions, RiskLevel: item.RiskLevel, Assignee: item.AssigneeRole, Active: true}
			if err := tx.Create(&planItem).Error; err != nil {
				return err
			}
			task := model.CareTask{ElderID: uint(elderID), PlanItemID: &planItem.ID, Title: item.Title, Kind: item.Kind, Priority: item.RiskLevel, Category: "todo", Assignee: item.AssigneeRole, Status: "todo"}
			if err := tx.Create(&task).Error; err != nil {
				return err
			}
		}
		subscription = model.ElderCarePackageSubscription{ElderID: uint(elderID), TemplateID: template.ID, CarePlanID: &plan.ID, TemplateName: template.Name, TemplateVersion: template.Version, StartDate: start, EndDate: input.EndDate, Status: "active", MonthlyPrice: template.MonthlyPrice, Currency: template.Currency, AssignedBy: assignedBy}
		return tx.Create(&subscription).Error
	})
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			Fail(c, 404, 404, "长者或启用中的套餐不存在")
		} else {
			Fail(c, http.StatusConflict, 409, "订阅套餐失败")
		}
		return
	}
	OK(c, subscription)
}
