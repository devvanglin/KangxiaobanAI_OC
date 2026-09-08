package handler

import (
	"errors"
	"net/http"
	"net/url"
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
	if errors.Is(err, service.ErrObjectTooLarge) {
		Fail(c, http.StatusRequestEntityTooLarge, 413, "文件超出 200MB 上传上限")
		return
	}
	if errors.Is(err, service.ErrStorageUnavailable) {
		Fail(c, http.StatusBadGateway, 502, "对象存储连接失败，请检查 MinIO 地址与密钥")
		return
	}
	Fail(c, http.StatusInternalServerError, 500, fallback)
}

// UploadObject POST /api/v1/admin/storage/buckets/:bucket/objects
// multipart 上传：表单字段 file 承载内容，X-Object-Key 头携带 URL 编码后的目标对象键
//（HTTP 头不能直接携带中文，客户端须 encodeURIComponent）。
func (h *StorageAdminHandler) UploadObject(c *gin.Context) {
	bucket := c.Param("bucket")
	rawKey, err := url.PathUnescape(c.GetHeader("X-Object-Key"))
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误：对象名编码无效")
		return
	}
	key := service.SanitizeObjectKey(rawKey)
	if bucket == "" || key == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误：缺少桶名或对象名")
		return
	}
	fileHeader, err := c.FormFile("file")
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误：缺少文件内容")
		return
	}
	if fileHeader.Size > 200<<20 {
		Fail(c, http.StatusRequestEntityTooLarge, 413, "文件超出 200MB 上传上限")
		return
	}
	contentType := fileHeader.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	reader, err := fileHeader.Open()
	if err != nil {
		Fail(c, http.StatusBadRequest, 400, "文件内容读取失败")
		return
	}
	defer reader.Close()
	if err := h.svc.UploadObject(c.Request.Context(), bucket, key, reader, fileHeader.Size, contentType); err != nil {
		h.failStorage(c, err, "上传失败")
		return
	}
	OK(c, gin.H{"bucket": bucket, "key": key, "size": fileHeader.Size})
}

// DeleteObject DELETE /api/v1/admin/storage/buckets/:bucket/objects?key=对象名
func (h *StorageAdminHandler) DeleteObject(c *gin.Context) {
	bucket := c.Param("bucket")
	key := service.SanitizeObjectKey(c.Query("key"))
	if bucket == "" || key == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误：缺少桶名或对象名")
		return
	}
	if err := h.svc.DeleteObject(c.Request.Context(), bucket, key); err != nil {
		h.failStorage(c, err, "删除失败")
		return
	}
	OK(c, gin.H{"bucket": bucket, "key": key})
}

type storageRenameReq struct {
	FromKey string `json:"from_key"`
	ToKey   string `json:"to_key"`
}

// RenameObject POST /api/v1/admin/storage/buckets/:bucket/objects/rename
func (h *StorageAdminHandler) RenameObject(c *gin.Context) {
	bucket := c.Param("bucket")
	var req storageRenameReq
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	fromKey := service.SanitizeObjectKey(req.FromKey)
	toKey := service.SanitizeObjectKey(req.ToKey)
	if bucket == "" || fromKey == "" || toKey == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误：缺少桶名或对象名")
		return
	}
	if fromKey == toKey {
		Fail(c, http.StatusBadRequest, 400, "新名称与原名相同")
		return
	}
	if err := h.svc.RenameObject(c.Request.Context(), bucket, fromKey, toKey); err != nil {
		h.failStorage(c, err, "重命名失败")
		return
	}
	OK(c, gin.H{"bucket": bucket, "from_key": fromKey, "to_key": toKey})
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
