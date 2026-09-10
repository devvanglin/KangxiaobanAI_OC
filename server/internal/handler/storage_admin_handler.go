package handler

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"

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
// （HTTP 头不能直接携带中文，客户端须 encodeURIComponent）。
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

// sanitizePrefix 校验目录前缀：去首尾空白与开头斜杠，拒绝路径穿越，保留结尾斜杠。
func sanitizePrefix(raw string) string {
	prefix := strings.TrimSpace(raw)
	prefix = strings.Trim(prefix, "/")
	if prefix == "" {
		return ""
	}
	for _, segment := range strings.Split(prefix, "/") {
		segment = strings.TrimSpace(segment)
		if segment == "" || segment == "." || segment == ".." {
			return ""
		}
	}
	return prefix + "/"
}

// Objects GET /api/v1/admin/storage/buckets/:bucket/objects?prefix=&max_keys=
// 按目录层级列出：prefix 为当前目录（空为桶根），返回该层的子文件夹与文件。
func (h *StorageAdminHandler) Objects(c *gin.Context) {
	bucket := c.Param("bucket")
	if bucket == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	prefix := sanitizePrefix(c.Query("prefix"))
	if c.Query("prefix") != "" && prefix == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误：目录前缀不合法")
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
	listing, err := h.svc.List(c.Request.Context(), bucket, prefix, maxKeys)
	if err != nil {
		h.failStorage(c, err, "对象列表获取失败")
		return
	}
	OK(c, gin.H{"bucket": bucket, "prefix": listing.Prefix,
		"folders": listing.Folders, "objects": listing.Objects})
}

// rawPathPrefix 客户端拿到的是相对路径（不含 /api/v1 前缀），须自行拼上 API 基地址。
const rawPathPrefix = "/admin/storage/raw"

// buildRawPath 生成带签名令牌的代理播放/下载相对 URL。
func (h *StorageAdminHandler) buildRawPath(bucket, key string) string {
	token, exp := h.svc.SignRawToken(bucket, key, service.RawTokenTTL)
	return fmt.Sprintf("%s?bucket=%s&key=%s&exp=%d&token=%s",
		rawPathPrefix, url.QueryEscape(bucket), url.QueryEscape(key), exp, token)
}

// Preview GET /api/v1/admin/storage/buckets/:bucket/preview?key=对象名
// 返回后端代理流地址（带签名令牌），客户端不必直连 MinIO。
func (h *StorageAdminHandler) Preview(c *gin.Context) {
	bucket := c.Param("bucket")
	key := c.Query("key")
	if bucket == "" || key == "" {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	if !h.svc.Available() {
		Fail(c, http.StatusServiceUnavailable, 503, "对象存储未配置，请先在服务端 .env 设置 KXB_MINIO_ENDPOINT/ACCESS_KEY/SECRET_KEY")
		return
	}
	OK(c, gin.H{"url": h.buildRawPath(bucket, key), "expires_in": int64(service.RawTokenTTL.Seconds())})
}

type storagePreviewsReq struct {
	Keys []string `json:"keys"`
}

// Previews POST /api/v1/admin/storage/buckets/:bucket/previews  body: {"keys": [...]}
// 批量换取缩略图/播放用的代理地址；单个失败不阻塞整批。
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
	urls := make(map[string]string, len(req.Keys))
	for _, key := range req.Keys {
		urls[key] = h.buildRawPath(bucket, key)
	}
	OK(c, gin.H{"urls": urls})
}

// RawObject GET /api/v1/admin/storage/raw?bucket=&key=&exp=&token=
// 未鉴权路由：播放器/Image/下载器不带 Authorization 头，改用 HMAC 签名令牌
// 校验 桶+对象+过期时间（与摄像头 HLS 预览的签名思路一致）。只读转发。
func (h *StorageAdminHandler) RawObject(c *gin.Context) {
	bucket := c.Query("bucket")
	rawKey, err := url.QueryUnescape(c.Query("key"))
	if err != nil {
		rawKey = c.Query("key")
	}
	exp, _ := strconv.ParseInt(c.Query("exp"), 10, 64)
	token := c.Query("token")
	key := service.SanitizeObjectKey(rawKey)
	if bucket == "" || key == "" || !h.svc.VerifyRawToken(token, bucket, key, exp) {
		Fail(c, http.StatusUnauthorized, 401, "链接无效或已过期，请刷新列表后重试")
		return
	}
	stat, err := h.svc.StatObject(c.Request.Context(), bucket, key)
	if err != nil {
		h.failStorage(c, err, "对象读取失败")
		return
	}
	contentType := stat.ContentType
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	// 解析 Range 头（AVPlayer 等播放器以 206 分片方式拉流）。
	status := http.StatusOK
	start, end := int64(0), stat.Size-1
	rng := c.GetHeader("Range")
	if strings.HasPrefix(rng, "bytes=") {
		if parsedStart, parsedEnd, ok := parseByteRange(rng[len("bytes="):], stat.Size); ok {
			start, end, status = parsedStart, parsedEnd, http.StatusPartialContent
		}
	}
	obj, err := h.svc.OpenObjectRange(c.Request.Context(), bucket, key, start, end)
	if err != nil {
		h.failStorage(c, err, "对象读取失败")
		return
	}
	defer obj.Close()
	c.Header("Content-Type", contentType)
	c.Header("Content-Length", strconv.FormatInt(end-start+1, 10))
	c.Header("Content-Disposition", fmt.Sprintf("inline; filename*=UTF-8''%s", url.PathEscape(key)))
	if status == http.StatusPartialContent {
		c.Header("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, stat.Size))
		c.Header("Accept-Ranges", "bytes")
	}
	c.Status(status)
	_, _ = io.Copy(c.Writer, obj)
}

// parseByteRange 解析单区间 "bytes=start-end"/"bytes=start-"；不支持多区间与后缀区间。
func parseByteRange(spec string, total int64) (int64, int64, bool) {
	spec = strings.TrimSpace(spec)
	dash := strings.Index(spec, "-")
	if dash <= 0 {
		return 0, 0, false
	}
	start, err := strconv.ParseInt(strings.TrimSpace(spec[:dash]), 10, 64)
	if err != nil || start < 0 || start >= total {
		return 0, 0, false
	}
	endText := strings.TrimSpace(spec[dash+1:])
	if endText == "" {
		return start, total - 1, true
	}
	end, err := strconv.ParseInt(endText, 10, 64)
	if err != nil || end < start {
		return 0, 0, false
	}
	if end >= total {
		end = total - 1
	}
	return start, end, true
}
