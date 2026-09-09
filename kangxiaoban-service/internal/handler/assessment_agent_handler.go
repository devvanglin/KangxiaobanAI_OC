package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"kangxiaoban-service/internal/auth"
	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/service"
)

type AssessmentAgentHandler struct {
	svc         *service.AssessmentAgentService
	users       *repository.UserRepository
	jwtSecret   string
	upstreamURL string
	proxyToken  string
}

func NewAssessmentAgentHandler(svc *service.AssessmentAgentService, users *repository.UserRepository, jwtSecret, upstreamURL, proxyToken string) *AssessmentAgentHandler {
	return &AssessmentAgentHandler{svc: svc, users: users, jwtSecret: jwtSecret,
		upstreamURL: strings.TrimSpace(upstreamURL), proxyToken: strings.TrimSpace(proxyToken)}
}

func (h *AssessmentAgentHandler) CurrentQuestionBank(c *gin.Context) {
	bank, err := h.svc.CurrentQuestionBank(c.Request.Context())
	if err != nil {
		h.fail(c, err, "查询评估题库失败")
		return
	}
	OK(c, bank)
}

func (h *AssessmentAgentHandler) UpdateQuestionBank(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	var input service.AssessmentAgentQuestionBankInput
	if err := c.ShouldBindJSON(&input); err != nil {
		Fail(c, http.StatusBadRequest, 400, "题库 JSON 格式错误")
		return
	}
	bank, err := h.svc.UpdateQuestionBank(c.Request.Context(), claims.UserID, input)
	if err != nil {
		h.fail(c, err, "保存评估题库失败")
		return
	}
	OK(c, bank)
}

func (h *AssessmentAgentHandler) CreateSession(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	var input struct {
		IntakeID uint `json:"intake_id"`
	}
	if err := c.ShouldBindJSON(&input); err != nil || input.IntakeID == 0 {
		Fail(c, http.StatusBadRequest, 400, "intake_id 必填")
		return
	}
	session, err := h.svc.CreateSession(c.Request.Context(), claims.UserID, input.IntakeID)
	if err != nil {
		h.fail(c, err, "创建评估会话失败")
		return
	}
	OK(c, session)
}

func (h *AssessmentAgentHandler) GetSession(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	session, err := h.svc.GetSession(c.Request.Context(), claims.UserID, c.Param("key"))
	if err != nil {
		h.fail(c, err, "查询评估会话失败")
		return
	}
	OK(c, session)
}

func (h *AssessmentAgentHandler) SessionForIntake(c *gin.Context) {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		Fail(c, http.StatusUnauthorized, 401, "未登录")
		return
	}
	intakeID, err := strconv.ParseUint(c.Param("intake_id"), 10, 64)
	if err != nil || intakeID == 0 {
		Fail(c, http.StatusBadRequest, 400, "入住办理 ID 无效")
		return
	}
	session, err := h.svc.SessionForIntake(c.Request.Context(), claims.UserID, uint(intakeID))
	if err != nil {
		h.fail(c, err, "查询评估会话失败")
		return
	}
	OK(c, session)
}

func containsPermission(items []string, required string) bool {
	for _, item := range items {
		if item == "*" || item == required {
			return true
		}
	}
	return false
}

func assessmentAgentUpstream(raw string) (string, error) {
	if raw == "" {
		return "", errors.New("assessment agent upstream is not configured")
	}
	parsed, err := url.Parse(raw)
	if err != nil || (parsed.Scheme != "ws" && parsed.Scheme != "wss") || parsed.Host == "" {
		return "", errors.New("assessment agent upstream URL is invalid")
	}
	return parsed.String(), nil
}

// ServeSession proxies one authenticated native session to AsLive. The client
// never receives the upstream address, and AsLive never receives a JWT or
// institutional database access.
func (h *AssessmentAgentHandler) ServeSession(c *gin.Context) {
	token := strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
	claims, err := auth.ParseToken(token, h.jwtSecret)
	if err != nil {
		Fail(c, http.StatusUnauthorized, 401, "令牌无效")
		return
	}
	if claims.TenantID == 0 {
		claims.TenantID = 1
	}
	ctx := context.WithValue(c.Request.Context(), model.TenantContextKey, claims.TenantID)
	permissions, err := h.users.PermissionsByRoleCodesContext(ctx, claims.Roles)
	if err != nil || !containsPermission(permissions, "health:write") {
		Fail(c, http.StatusForbidden, 403, "无权执行长者评估")
		return
	}
	session, err := h.svc.MarkStarted(ctx, claims.UserID, c.Param("key"))
	if err != nil {
		h.fail(c, err, "评估会话不可用")
		return
	}
	upstreamURL, err := assessmentAgentUpstream(h.upstreamURL)
	if err != nil {
		Fail(c, http.StatusServiceUnavailable, 503, "评估语音服务未配置")
		return
	}
	if h.proxyToken == "" {
		Fail(c, http.StatusServiceUnavailable, 503, "评估语音服务鉴权未配置")
		return
	}
	header := http.Header{}
	header.Set("X-Assessment-Proxy-Token", h.proxyToken)
	upstream, _, err := websocket.DefaultDialer.DialContext(ctx, upstreamURL, header)
	if err != nil {
		Fail(c, http.StatusBadGateway, 502, "评估语音服务不可用")
		return
	}
	defer upstream.Close()
	downstream, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	defer downstream.Close()

	start := map[string]interface{}{
		"type": "assessment_start",
		"profile": map[string]interface{}{
			"name": session.ResidentName, "gender": session.Gender, "address": session.Address,
		},
		"question_bank": map[string]interface{}{
			"title": session.Title, "no_answer_timeout": session.NoAnswerTimeout,
			"questions": session.QuestionSnapshot,
		},
		"resume_records": session.Answers,
	}
	if err := upstream.WriteJSON(start); err != nil {
		return
	}

	done := make(chan struct{}, 2)
	go func() {
		defer func() { done <- struct{}{} }()
		for {
			messageType, payload, readErr := downstream.ReadMessage()
			if readErr != nil {
				return
			}
			if messageType != websocket.TextMessage && messageType != websocket.BinaryMessage {
				continue
			}
			if writeErr := upstream.WriteMessage(messageType, payload); writeErr != nil {
				return
			}
		}
	}()
	go func() {
		defer func() { done <- struct{}{} }()
		for {
			messageType, payload, readErr := upstream.ReadMessage()
			if readErr != nil {
				return
			}
			if messageType == websocket.TextMessage {
				var envelope struct {
					Type       string                        `json:"type"`
					RecordID   string                        `json:"record_id"`
					Report     string                        `json:"report"`
					Records    []model.AssessmentAgentAnswer `json:"records"`
					Answered   int                           `json:"answered"`
					Total      int                           `json:"total"`
					Index      int                           `json:"index"`
					ID         string                        `json:"id"`
					Topic      string                        `json:"topic"`
					Question   string                        `json:"question"`
					Answer     string                        `json:"answer"`
					Skipped    bool                          `json:"skipped"`
					NoResponse bool                          `json:"no_response"`
				}
				if json.Unmarshal(payload, &envelope) == nil && envelope.Type == "assess_answer" {
					if progressErr := h.svc.SaveProgress(ctx, claims.UserID, session.SessionKey, model.AssessmentAgentAnswer{
						QuestionID: envelope.ID, Topic: envelope.Topic, Question: envelope.Question,
						Answer: envelope.Answer, Skipped: envelope.Skipped, NoResponse: envelope.NoResponse,
					}, envelope.Index); progressErr != nil {
						return
					}
				} else if envelope.Type == "assess_summary" {
					_, completeErr := h.svc.CompleteSession(ctx, claims.UserID, session.SessionKey, service.AssessmentAgentCompletion{
						ExternalRecordID: envelope.RecordID, Report: envelope.Report, Answers: envelope.Records,
						Answered: envelope.Answered, Total: envelope.Total,
					})
					if completeErr != nil {
						failure, _ := json.Marshal(map[string]string{"type": "error", "message": "评估结果保存失败，请联系工作人员"})
						_ = downstream.WriteMessage(websocket.TextMessage, failure)
						return
					}
				}
			}
			if writeErr := downstream.WriteMessage(messageType, payload); writeErr != nil {
				return
			}
		}
	}()
	select {
	case <-done:
	case <-time.After(45 * time.Minute):
	}
}

func (h *AssessmentAgentHandler) fail(c *gin.Context, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrAssessmentAgentNotFound):
		Fail(c, http.StatusNotFound, 404, "评估资源不存在")
	case errors.Is(err, service.ErrAssessmentAgentForbidden):
		Fail(c, http.StatusForbidden, 403, "无权执行该操作")
	case errors.Is(err, service.ErrAssessmentAgentValidation):
		Fail(c, http.StatusBadRequest, 400, err.Error())
	case errors.Is(err, service.ErrAssessmentAgentInvalidState):
		Fail(c, http.StatusConflict, 409, "评估会话状态不允许该操作")
	default:
		Fail(c, http.StatusInternalServerError, 500, fallback)
	}
}
