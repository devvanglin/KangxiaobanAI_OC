package handler

import (
	"github.com/gin-gonic/gin"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
	"net/http"
	"strconv"
)

type NotificationHandler struct{ svc *service.NotificationService }

func NewNotificationHandler(svc *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

func (h *NotificationHandler) List(c *gin.Context) {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, 401, 401, "未登录")
		return
	}
	page, size := parsePage(c)
	items, total, err := h.svc.List(c.Request.Context(), cl.UserID, cl.Roles, c.Query("unread") == "1", page, size)
	if err != nil {
		Fail(c, 500, 500, "查询通知失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *NotificationHandler) MarkRead(c *gin.Context) {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, 401, 401, "未登录")
		return
	}
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.svc.MarkRead(c.Request.Context(), uint(id), cl.UserID, cl.Roles); err != nil {
		Fail(c, http.StatusNotFound, 404, "通知不存在")
		return
	}
	OK(c, gin.H{"id": id, "read": true})
}
