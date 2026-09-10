// comfort_handler.go 主动语音安抚会话（悲伤表情触发，老人端设备领取与状态回报）。
package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

// ComfortHandler 老人端安抚会话接口。
type ComfortHandler struct {
	svc *service.ComfortService
}

func NewComfortHandler(svc *service.ComfortService) *ComfortHandler {
	return &ComfortHandler{svc: svc}
}

// Pending GET /api/v1/comfort/pending?elder_id=
// 返回该长者最早一个待领取的安抚会话；没有待领取会话时 data 为 null。
func (h *ComfortHandler) Pending(c *gin.Context) {
	elderID, err := strconv.ParseUint(c.Query("elder_id"), 10, 64)
	if err != nil || elderID == 0 {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	session, err := h.svc.PendingForElder(c.Request.Context(), uint(elderID))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "安抚会话查询失败")
		return
	}
	OK(c, session)
}

// Start POST /api/v1/comfort/sessions/:id/start —— 设备领取并开始开场白。
func (h *ComfortHandler) Start(c *gin.Context) {
	session, ok := h.transition(c, func() (*model.ComfortSession, error) {
		id, err := comfortSessionID(c)
		if err != nil {
			return nil, err
		}
		return h.svc.MarkTalking(c.Request.Context(), id)
	})
	if ok {
		OK(c, session)
	}
}

type comfortRespondReq struct {
	Transcript string `json:"transcript"`
}

// Respond POST /api/v1/comfort/sessions/:id/respond —— 老人有语音回应。
func (h *ComfortHandler) Respond(c *gin.Context) {
	var req comfortRespondReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	session, ok := h.transition(c, func() (*model.ComfortSession, error) {
		id, err := comfortSessionID(c)
		if err != nil {
			return nil, err
		}
		return h.svc.MarkResponded(c.Request.Context(), id, req.Transcript)
	})
	if ok {
		OK(c, session)
	}
}

// NoResponse POST /api/v1/comfort/sessions/:id/no-response —— 老人无回应，通知护工。
func (h *ComfortHandler) NoResponse(c *gin.Context) {
	session, ok := h.transition(c, func() (*model.ComfortSession, error) {
		id, err := comfortSessionID(c)
		if err != nil {
			return nil, err
		}
		return h.svc.MarkNoResponse(c.Request.Context(), id)
	})
	if ok {
		OK(c, session)
	}
}

func (h *ComfortHandler) transition(c *gin.Context, act func() (*model.ComfortSession, error)) (*model.ComfortSession, bool) {
	session, err := act()
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			Fail(c, http.StatusNotFound, 404, "安抚会话不存在")
			return nil, false
		}
		Fail(c, http.StatusConflict, 409, err.Error())
		return nil, false
	}
	return session, true
}

func comfortSessionID(c *gin.Context) (uint, error) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		return 0, errors.New("参数错误")
	}
	return uint(id), nil
}
