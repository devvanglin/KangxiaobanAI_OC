package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

type MessageHandler struct {
	svc    *service.MessageService
	family *service.FamilyService
	hub    interface {
		SendToUser(uint, string, interface{})
	}
	users interface {
		ListContacts(uint, uint) ([]model.User, error)
	}
}

func NewMessageHandler(svc *service.MessageService, family *service.FamilyService, hub interface {
	SendToUser(uint, string, interface{})
}, users interface {
	ListContacts(uint, uint) ([]model.User, error)
}) *MessageHandler {
	return &MessageHandler{svc: svc, family: family, hub: hub, users: users}
}

func (h *MessageHandler) Contacts(c *gin.Context) {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, 401, 401, "未登录")
		return
	}
	items, err := h.users.ListContacts(cl.TenantID, cl.UserID)
	if err != nil {
		Fail(c, 500, 500, "查询联系人失败")
		return
	}
	OK(c, gin.H{"list": items})
}

func (h *MessageHandler) List(c *gin.Context) {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, 401, 401, "未登录")
		return
	}
	peer, err := strconv.ParseUint(c.Query("peer_id"), 10, 64)
	if err != nil || peer == 0 {
		Fail(c, 400, 400, "peer_id 必填")
		return
	}
	page, size := parsePage(c)
	var elderID *uint
	if raw := c.Query("elder_id"); raw != "" {
		id, e := strconv.ParseUint(raw, 10, 64)
		if e != nil || id == 0 {
			Fail(c, 400, 400, "elder_id 参数错误")
			return
		}
		v := uint(id)
		elderID = &v
		if !requireElderAccess(c, h.family, v) {
			return
		}
	}
	items, total, err := h.svc.List(c.Request.Context(), cl.UserID, uint(peer), elderID, page, size)
	if err != nil {
		if errors.Is(err, service.ErrMessagePeerUnavailable) {
			Fail(c, http.StatusNotFound, 404, "联系人不存在")
			return
		}
		Fail(c, 500, 500, "查询消息失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

type sendMessageReq struct {
	ReceiverID uint   `json:"receiver_id" binding:"required"`
	ElderID    *uint  `json:"elder_id"`
	Content    string `json:"content" binding:"required"`
	Type       string `json:"type"`
}

func (h *MessageHandler) Send(c *gin.Context) {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, 401, 401, "未登录")
		return
	}
	var req sendMessageReq
	if err := c.ShouldBindJSON(&req); err != nil || req.Content == "" {
		Fail(c, 400, 400, "receiver_id 与 content 必填")
		return
	}
	if req.ReceiverID == cl.UserID {
		Fail(c, 400, 400, "不能给自己发送消息")
		return
	}
	if req.ElderID != nil && !requireElderAccess(c, h.family, *req.ElderID) {
		return
	}
	msg, err := h.svc.Send(c.Request.Context(), cl.UserID, req.ReceiverID, req.ElderID, req.Content, req.Type)
	if err != nil {
		if errors.Is(err, service.ErrMessagePeerUnavailable) {
			Fail(c, http.StatusNotFound, 404, "联系人不存在")
			return
		}
		Fail(c, 500, 500, "发送消息失败")
		return
	}
	h.hub.SendToUser(req.ReceiverID, "message.created", msg)
	OK(c, msg)
}

func (h *MessageHandler) MarkRead(c *gin.Context) {
	cl, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, 401, 401, "未登录")
		return
	}
	id, _ := strconv.ParseUint(c.Param("id"), 10, 64)
	if err := h.svc.MarkRead(c.Request.Context(), cl.UserID, uint(id)); err != nil {
		Fail(c, http.StatusNotFound, 404, "消息不存在")
		return
	}
	OK(c, gin.H{"id": id, "read": true})
}
