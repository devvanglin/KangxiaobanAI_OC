package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/service"
)

// StorageAdminHandler 管理端「存储」预览接口：桶列表、桶内对象列表、预签名预览链接。
// 全部只读，挂在 admin:all 权限之后；MinIO 密钥不出服务端。
type StorageAdminHandler struct {
	svc *service.StorageService
}

func NewStorageAdminHandler(svc *service.StorageService) *StorageAdminHandler {
	return &StorageAdminHandler{svc: svc}
}

// failStorage 把存储服务的错误映射成带原因的管理端提示。
func (h *StorageAdminHandler) failStorage(c *gin.Context, err error, fallback string) {
	if errors.Is(err, service.ErrStorageNotConfigured) {
		Fail(c, http.StatusServiceUnavailable, 503, "对象存储未配置，请先在服务端 .env 设置 KXB_MINIO_ENDPOINT/ACCESS_KEY/SECRET_KEY")
		return
	}
	if errors.Is(err, service.ErrStorageUnavailable) {
		Fail(c, http.StatusBadGateway, 502, "对象存储连接失败，请检查 MinIO 地址与密钥")
		return
	}
	Fail(c, http.StatusInternalServerError, 500, fallback)
}

// Buckets GET /api/v1/admin/storage/buckets
// 未配置时返回 HTTP 200 + configured=false，管理端据此展示引导态而非报错。
func (h *StorageAdminHandler) Buckets(c *gin.Context) {
	buckets, err := h.svc.Buckets(c.Request.Context())
	if errors.Is(err, service.ErrStorageNotConfigured) {
		OK(c, gin.H{"configured": false, "buckets": []gin.H{}})
		return
	}
	if err != nil {
		h.failStorage(c, err, "桶列表获取失败")
		return
	}
	OK(c, gin.H{"configured": true, "buckets": buckets})
}

// Objects GET /api/v1/admin/storage/buckets/:bucket/objects?prefix=&max_keys=
func (h *StorageAdminHandler) Objects(c *gin.Context) {
	bucket := c.Param("bucket")
	if bucket == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	maxKeys := 200
	if raw := c.Query("max_keys"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			maxKeys = parsed
		}
	}
	if maxKeys > 1000 {
		maxKeys = 1000
	}
	objects, err := h.svc.Objects(c.Request.Context(), bucket, c.Query("prefix"), maxKeys)
	if err != nil {
		h.failStorage(c, err, "对象列表获取失败")
		return
	}
	OK(c, gin.H{"bucket": bucket, "objects": objects})
}

// Preview GET /api/v1/admin/storage/buckets/:bucket/preview?key=对象名
func (h *StorageAdminHandler) Preview(c *gin.Context) {
	bucket := c.Param("bucket")
	key := c.Query("key")
	if bucket == "" || key == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	rawURL, expiresIn, err := h.svc.PreviewURL(c.Request.Context(), bucket, key)
	if err != nil {
		h.failStorage(c, err, "预览链接生成失败")
		return
	}
	OK(c, gin.H{"url": rawURL, "expires_in": expiresIn})
}

type storagePreviewsReq struct {
	Keys []string `json:"keys"`
}

// Previews POST /api/v1/admin/storage/buckets/:bucket/previews  body: {"keys": [...]}
// 批量换取缩略图/播放用的预签名链接；单 key 失败跳过，最多 100 个。
func (h *StorageAdminHandler) Previews(c *gin.Context) {
	bucket := c.Param("bucket")
	if bucket == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	var req storagePreviewsReq
	if err := c.ShouldBindJSON(&req); err != nil || len(req.Keys) == 0 {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if len(req.Keys) > 100 {
		req.Keys = req.Keys[:100]
	}
	urls, err := h.svc.PreviewURLs(c.Request.Context(), bucket, req.Keys)
	if err != nil {
		h.failStorage(c, err, "预览链接生成失败")
		return
	}
	OK(c, gin.H{"urls": urls})
}
