package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/middleware"
	"kangxiaoban-service/internal/service"
)

// AdmissionHandler exposes the persisted A/B/C admission assessment workflow.
type AdmissionHandler struct {
	svc    *service.AdmissionService
	photos *service.AdmissionPhotoService
}

// The binary image itself is capped at 5 MiB by the service. Leave a small
// allowance for multipart headers while preventing an attacker from making
// Gin parse an arbitrarily large request before that validation runs.
const maxAdmissionPhotoRequestBytes int64 = 6 << 20

func NewAdmissionHandler(svc *service.AdmissionService, photos ...*service.AdmissionPhotoService) *AdmissionHandler {
	h := &AdmissionHandler{svc: svc}
	if len(photos) > 0 {
		h.photos = photos[0]
	}
	return h
}

func (h *AdmissionHandler) UploadIntakePhoto(c *gin.Context) {
	if h.photos == nil {
		Fail(c, http.StatusNotImplemented, 501, "照片上传未配置")
		return
	}
	if c.Request.ContentLength > maxAdmissionPhotoRequestBytes {
		Fail(c, http.StatusRequestEntityTooLarge, 413, "照片请求过大")
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxAdmissionPhotoRequestBytes)
	header, err := c.FormFile("file")
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "请上传图片文件")
		return
	}
	key := c.GetHeader("X-Upload-Key")
	kind := c.GetHeader("X-Photo-Kind")
	photo, err := h.photos.UploadPending(c.Request.Context(), admissionActor(c), key, kind, header)
	if err != nil {
		h.failPhoto(c, err)
		return
	}
	OK(c, service.AdmissionPhotoViewFromModel(*photo))
}

// DeletePendingIntakePhoto DELETE /api/v1/admission-intakes/photos
//
// The upload key and slot kind may be sent in the same headers used by the
// multipart upload (`X-Upload-Key`/`X-Photo-Kind`) or as query parameters
// (`upload_key`/`kind`).  Header support keeps the native client contract
// symmetric with upload; query support makes the endpoint easy to exercise
// from maintenance tools without putting opaque keys in a request body.
// Only pending rows owned by the authenticated user in the current tenant can
// be removed.  The service treats an already absent row as an idempotent
// success, so a repeated cleanup does not surface a spurious error.
func (h *AdmissionHandler) DeletePendingIntakePhoto(c *gin.Context) {
	if h.photos == nil {
		Fail(c, http.StatusNotImplemented, 501, "照片上传未配置")
		return
	}
	key := strings.TrimSpace(c.GetHeader("X-Upload-Key"))
	if key == "" {
		key = strings.TrimSpace(c.Query("upload_key"))
	}
	kind := strings.TrimSpace(c.GetHeader("X-Photo-Kind"))
	if kind == "" {
		kind = strings.TrimSpace(c.Query("kind"))
	}
	if key == "" || kind == "" {
		Fail(c, http.StatusBadRequest, 400, "upload_key 与 kind 必填")
		return
	}
	deleted, err := h.photos.DeletePending(c.Request.Context(), admissionActor(c), key, kind)
	if err != nil {
		h.failPhoto(c, err)
		return
	}
	OK(c, gin.H{"deleted": deleted, "upload_key": key, "kind": kind})
}

func (h *AdmissionHandler) ListIntakePhotos(c *gin.Context) {
	if h.photos == nil {
		Fail(c, http.StatusNotImplemented, 501, "照片上传未配置")
		return
	}
	id, ok := admissionID(c)
	if !ok {
		return
	}
	photos, err := h.photos.List(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.failPhoto(c, err)
		return
	}
	OK(c, service.AdmissionPhotoViewsFromModels(photos))
}

func (h *AdmissionHandler) IntakePhotoContent(c *gin.Context) {
	if h.photos == nil {
		Fail(c, http.StatusNotImplemented, 501, "照片上传未配置")
		return
	}
	id, ok := admissionID(c)
	if !ok {
		return
	}
	content, err := h.photos.Content(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.failPhoto(c, err)
		return
	}
	// Identity documents are sensitive; do not let browser or intermediary
	// caches retain a copy after the authenticated response.
	c.Header("Cache-Control", "no-store")
	c.Header("X-Content-Type-Options", "nosniff")
	c.Header("Content-Disposition", "inline")
	c.Header("Content-Type", content.Photo.ContentType)
	http.ServeFile(c.Writer, c.Request, content.Path)
}

func (h *AdmissionHandler) failPhoto(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrAdmissionPhotoNotFound), errors.Is(err, service.ErrAdmissionNotFound):
		Fail(c, http.StatusNotFound, 404, "照片或入住记录不存在")
	case errors.Is(err, service.ErrAdmissionForbidden):
		Fail(c, http.StatusForbidden, 403, "无权限操作照片")
	case errors.Is(err, service.ErrAdmissionPhotoConflict):
		Fail(c, http.StatusConflict, 409, "照片已绑定，不能重复上传")
	case errors.Is(err, service.ErrAdmissionInvalidState):
		Fail(c, http.StatusConflict, 409, "入住记录当前状态不允许上传照片")
	case errors.Is(err, service.ErrAdmissionPhotoInvalid):
		Fail(c, http.StatusBadRequest, 400, err.Error())
	default:
		Fail(c, http.StatusInternalServerError, 500, "照片处理失败")
	}
}

func (h *AdmissionHandler) CurrentTemplate(c *gin.Context) {
	bundle, err := h.svc.TemplateBundle(c.Request.Context())
	if err != nil {
		h.fail(c, err, "查询入住评估模板失败")
		return
	}
	OK(c, bundle)
}

func (h *AdmissionHandler) ScreeningTemplates(c *gin.Context) {
	templates, err := h.svc.ScreeningTemplates(c.Request.Context())
	if err != nil {
		h.fail(c, err, "查询入住筛查模板失败")
		return
	}
	OK(c, templates)
}

func (h *AdmissionHandler) List(c *gin.Context) {
	page, size := parsePage(c)
	items, total, err := h.svc.List(c.Request.Context(), admissionActor(c), c.Query("status"), c.Query("mine") == "true", page, size)
	if err != nil {
		h.fail(c, err, "查询入住评估失败")
		return
	}
	OK(c, gin.H{"list": items, "page": page, "size": size, "total": total})
}

func (h *AdmissionHandler) Create(c *gin.Context) {
	var req service.AdmissionDraftInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	created, err := h.svc.Create(c.Request.Context(), admissionActor(c), req)
	if err != nil {
		h.fail(c, err, "创建入住评估草稿失败")
		return
	}
	OK(c, created)
}

func (h *AdmissionHandler) Get(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	item, err := h.svc.Get(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.fail(c, err, "查询入住评估失败")
		return
	}
	OK(c, item)
}

func (h *AdmissionHandler) Update(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	var req service.AdmissionDraftInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	updated, err := h.svc.Update(c.Request.Context(), admissionActor(c), id, req)
	if err != nil {
		h.fail(c, err, "保存入住评估草稿失败")
		return
	}
	OK(c, updated)
}

func (h *AdmissionHandler) Preview(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	var req struct {
		Answers []service.AdmissionAnswerInput `json:"answers"`
	}
	if c.Request.ContentLength > 0 {
		if err := c.ShouldBindJSON(&req); err != nil {
			Fail(c, http.StatusBadRequest, 400, "请求格式错误")
			return
		}
	}
	preview, err := h.svc.Preview(c.Request.Context(), admissionActor(c), id, req.Answers)
	if err != nil {
		h.fail(c, err, "预览评估结果失败")
		return
	}
	OK(c, preview)
}

func (h *AdmissionHandler) Submit(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	result, err := h.svc.Submit(c.Request.Context(), admissionActor(c), id)
	if err != nil {
		h.fail(c, err, "提交入住评估失败")
		return
	}
	OK(c, result)
}

func (h *AdmissionHandler) ListScreenings(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	items, err := h.svc.ListScreenings(c.Request.Context(), id)
	if err != nil {
		h.fail(c, err, "查询入住筛查记录失败")
		return
	}
	OK(c, items)
}

func (h *AdmissionHandler) SaveScreening(c *gin.Context) {
	id, ok := admissionID(c)
	if !ok {
		return
	}
	var req service.AdmissionScreeningInput
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "请求格式错误")
		return
	}
	result, err := h.svc.SaveScreening(c.Request.Context(), admissionActor(c), id, c.Param("template_code"), req)
	if err != nil {
		h.fail(c, err, "保存入住筛查失败")
		return
	}
	OK(c, result)
}

func admissionActor(c *gin.Context) service.AdmissionActor {
	claims, ok := middleware.ClaimsFrom(c)
	if !ok {
		return service.AdmissionActor{}
	}
	return service.AdmissionActor{UserID: claims.UserID, IsAdmin: hasRole(claims.Roles, "admin")}
}

func admissionID(c *gin.Context) (uint, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		Fail(c, http.StatusBadRequest, 400, "入住评估 ID 无效")
		return 0, false
	}
	return uint(id), true
}

func (h *AdmissionHandler) fail(c *gin.Context, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrAdmissionNotFound):
		Fail(c, http.StatusNotFound, 404, "入住评估不存在")
	case errors.Is(err, service.ErrAdmissionForbidden):
		Fail(c, http.StatusForbidden, 403, "无权限操作该入住评估")
	case errors.Is(err, service.ErrAdmissionInvalidState):
		Fail(c, http.StatusConflict, 409, "入住评估当前状态不允许该操作")
	case errors.Is(err, service.ErrAdmissionBedConflict):
		Fail(c, http.StatusConflict, 409, "目标床位不存在或已被占用")
	case errors.Is(err, service.ErrAdmissionElderConflict):
		Fail(c, http.StatusConflict, 409, "长者已入住或身份信息与现有档案冲突")
	case errors.Is(err, service.ErrAdmissionIdempotencyConflict):
		Fail(c, http.StatusConflict, 409, "幂等键已用于另一份入住申请，请更换幂等键")
	case errors.Is(err, service.ErrAdmissionPhotoConflict):
		Fail(c, http.StatusConflict, 409, "照片已绑定，不能重复上传")
	case errors.Is(err, service.ErrAdmissionPhotoInvalid):
		Fail(c, http.StatusBadRequest, 400, err.Error())
	case errors.Is(err, service.ErrAdmissionIncomplete), errors.Is(err, service.ErrAdmissionValidation):
		Fail(c, http.StatusBadRequest, 400, err.Error())
	default:
		Fail(c, http.StatusInternalServerError, 500, fallback)
	}
}
