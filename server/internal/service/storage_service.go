package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/url"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"kangxiaoban-service/internal/config"
)

// ErrStorageNotConfigured 服务端未配置 MinIO/S3 连接时返回，handler 转成 503 提示。
var ErrStorageNotConfigured = errors.New("对象存储未配置")

// ErrStorageUnavailable 连接 MinIO 失败（地址/密钥错误或网络不可达）。
var ErrStorageUnavailable = errors.New("对象存储不可用")

// ErrObjectTooLarge 上传内容超过管理端单文件上限。
var ErrObjectTooLarge = errors.New("对象大小超出上限")

// previewTTL 预签名链接有效期：管理端预览用途，30 分钟足够且不长期暴露。
const previewTTL = 30 * time.Minute

// StorageService 管理端对象存储只读预览：列出桶、桶内对象，并生成短期预签名链接。
// 只读接口，不做任何写操作；密钥留在服务端，客户端只拿到临时 URL。
type StorageService struct {
	client *minio.Client
	secret string // 签名代理下载令牌的 HMAC 密钥，与 JWT 密钥同源
}

func NewStorageService(cfg config.StorageConfig, signSecret string) *StorageService {
	if cfg.Endpoint == "" || cfg.AccessKey == "" || cfg.SecretKey == "" {
		return &StorageService{secret: signSecret}
	}
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.Secure,
		Region: cfg.Region,
	})
	if err != nil {
		return &StorageService{secret: signSecret}
	}
	return &StorageService{client: client, secret: signSecret}
}

// Available 报告是否已配置可用的 MinIO 客户端。
func (s *StorageService) Available() bool {
	return s != nil && s.client != nil
}

// StorageBucket 桶概览：对象数量与总字节在列出时统计。
type StorageBucket struct {
	Name         string    `json:"name"`
	CreationDate time.Time `json:"creation_date"`
	ObjectCount  int64     `json:"object_count"`
	TotalSize    int64     `json:"total_size"`
}

// StorageObject 对象条目；类型由客户端根据扩展名推断。
type StorageObject struct {
	Key          string    `json:"key"`
	Size         int64     `json:"size"`
	LastModified time.Time `json:"last_modified"`
}

// Buckets 列出全部桶并统计每个桶的对象数与总字节。管理端桶数量有限，逐桶遍历可接受。
func (s *StorageService) Buckets(ctx context.Context) ([]StorageBucket, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	infoList, err := s.client.ListBuckets(ctx)
	if err != nil {
		return nil, errors.Join(ErrStorageUnavailable, err)
	}
	buckets := make([]StorageBucket, 0, len(infoList))
	for _, info := range infoList {
		bucket := StorageBucket{Name: info.Name, CreationDate: info.CreationDate}
		for object := range s.client.ListObjects(ctx, info.Name, minio.ListObjectsOptions{Recursive: true}) {
			if object.Err != nil {
				return nil, errors.Join(ErrStorageUnavailable, object.Err)
			}
			bucket.ObjectCount++
			bucket.TotalSize += object.Size
		}
		buckets = append(buckets, bucket)
	}
	return buckets, nil
}

// StorageListing 桶内某一层级的浏览结果：子文件夹与当前层级的文件。
type StorageListing struct {
	Prefix  string          `json:"prefix"`
	Folders []StorageFolder `json:"folders"`
	Objects []StorageObject `json:"objects"`
}

// StorageFolder 子文件夹项；Prefix 为含尾斜杠的完整前缀，进入时直接作为列表前缀。
type StorageFolder struct {
	Name   string `json:"name"`
	Prefix string `json:"prefix"`
}

// List 按层级列出桶内容：prefix 为当前目录前缀（空为桶根），使用 '/' 分隔符，
// 返回当前层级的子文件夹与文件，不递归展开。
func (s *StorageService) List(ctx context.Context, bucket, prefix string, maxKeys int) (*StorageListing, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	// MaxKeys 只约束单次请求页大小；非递归列出也会继续翻页，这里在达到上限时取消遍历。
	listCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	options := minio.ListObjectsOptions{
		Prefix:    prefix,
		Recursive: false, // 使用 '/' 分隔符：子文件夹以「前缀/」形式出现在结果里。
	}
	listing := &StorageListing{Prefix: prefix, Folders: []StorageFolder{}, Objects: []StorageObject{}}
	count := 0
	for object := range s.client.ListObjects(listCtx, bucket, options) {
		if object.Err != nil {
			return nil, errors.Join(ErrStorageUnavailable, object.Err)
		}
		count++
		if count > maxKeys*10 {
			cancel()
			break
		}
		if strings.HasSuffix(object.Key, "/") {
			name := strings.TrimSuffix(object.Key, "/")
			if strings.HasPrefix(name, prefix) {
				name = strings.TrimPrefix(name, prefix)
			}
			if name == "" {
				continue
			}
			listing.Folders = append(listing.Folders, StorageFolder{Name: name, Prefix: object.Key})
			continue
		}
		listing.Objects = append(listing.Objects,
			StorageObject{Key: object.Key, Size: object.Size, LastModified: object.LastModified})
		if len(listing.Objects) >= maxKeys {
			cancel()
			break
		}
	}
	return listing, nil
}

// PreviewURL 为单个对象生成短期 GET 预签名链接，客户端用它在 Image/Video 组件直连 MinIO。
func (s *StorageService) PreviewURL(ctx context.Context, bucket, key string) (string, int64, error) {
	if !s.Available() {
		return "", 0, ErrStorageNotConfigured
	}
	presigned, err := s.client.PresignedGetObject(ctx, bucket, key, previewTTL, url.Values{})
	if err != nil {
		return "", 0, errors.Join(ErrStorageUnavailable, err)
	}
	return presigned.String(), int64(previewTTL.Seconds()), nil
}

// PreviewURLs 批量生成预签名链接，返回 key -> url 映射；单个失败不阻塞整批。
func (s *StorageService) PreviewURLs(ctx context.Context, bucket string, keys []string) (map[string]string, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	urls := make(map[string]string, len(keys))
	for _, key := range keys {
		presigned, err := s.client.PresignedGetObject(ctx, bucket, key, previewTTL, url.Values{})
		if err != nil {
			continue // 单个 key 失效只跳过，不拖垮整批缩略图。
		}
		urls[key] = presigned.String()
	}
	return urls, nil
}

// maxUploadBytes 管理端单次上传上限（200MB），防止误传超大文件拖垮容器。
const maxUploadBytes int64 = 200 << 20

// SanitizeObjectKey 校验并规范化对象键：去首尾斜杠、拒绝空键与路径穿越。
// 返回空字符串表示键不合法。
func SanitizeObjectKey(raw string) string {
	key := strings.TrimSpace(raw)
	key = strings.Trim(key, "/")
	if key == "" {
		return ""
	}
	for _, segment := range strings.Split(key, "/") {
		segment = strings.TrimSpace(segment)
		if segment == "" || segment == "." || segment == ".." {
			return ""
		}
	}
	return key
}

// ListAllKeys 列出桶内全部对象键（训练素材采样用；桶规模小，全量可接受）。
func (s *StorageService) ListAllKeys(ctx context.Context, bucket string) ([]string, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	keys := make([]string, 0, 64)
	for object := range s.client.ListObjects(ctx, bucket, minio.ListObjectsOptions{Recursive: true}) {
		if object.Err != nil || object.Key == "" {
			continue
		}
		keys = append(keys, object.Key)
	}
	return keys, nil
}

// UploadObject 上传/覆盖对象；size<0 表示未知长度，由 SDK 走分片上传。
func (s *StorageService) UploadObject(ctx context.Context, bucket, key string,
	reader io.Reader, size int64, contentType string) error {
	if !s.Available() {
		return ErrStorageNotConfigured
	}
	if size > maxUploadBytes {
		return ErrObjectTooLarge
	}
	_, err := s.client.PutObject(ctx, bucket, key, reader, size,
		minio.PutObjectOptions{ContentType: contentType})
	if err != nil {
		return errors.Join(ErrStorageUnavailable, err)
	}
	return nil
}

// DeleteObject 删除单个对象；对象不存在时 S3 幂等成功。
func (s *StorageService) DeleteObject(ctx context.Context, bucket, key string) error {
	if !s.Available() {
		return ErrStorageNotConfigured
	}
	if err := s.client.RemoveObject(ctx, bucket, key, minio.RemoveObjectOptions{}); err != nil {
		return errors.Join(ErrStorageUnavailable, err)
	}
	return nil
}

// RenameObject 重命名对象：S3 无原生改名，用 复制+删除 原子性较弱地等价实现。
// 复制成功后才删除旧对象，失败时保留旧数据。
func (s *StorageService) RenameObject(ctx context.Context, bucket, fromKey, toKey string) error {
	if !s.Available() {
		return ErrStorageNotConfigured
	}
	src := minio.CopySrcOptions{Bucket: bucket, Object: fromKey}
	dst := minio.CopyDestOptions{Bucket: bucket, Object: toKey}
	if _, err := s.client.CopyObject(ctx, dst, src); err != nil {
		return errors.Join(ErrStorageUnavailable, err)
	}
	if err := s.client.RemoveObject(ctx, bucket, fromKey, minio.RemoveObjectOptions{}); err != nil {
		return errors.Join(ErrStorageUnavailable, err)
	}
	return nil
}

// rawTokenTTL 代理播放/下载令牌有效期，与预签名链接保持一致。
const rawTokenTTL = 30 * time.Minute

// RawTokenTTL 供 handler 生成 expires_in 字段。
var RawTokenTTL = rawTokenTTL

// SignRawToken 生成后端代理流“桶/对象/过期时间”的 HMAC 令牌。
// 播放器与下载器不带 Authorization 头，改用带过期时间的路径令牌
// （与摄像头 HLS 预览的签名思路一致）。
func (s *StorageService) SignRawToken(bucket, key string, ttl time.Duration) (token string, expiresAt int64) {
	expiresAt = time.Now().Add(ttl).Unix()
	mac := hmac.New(sha256.New, []byte(s.secret))
	fmt.Fprintf(mac, "%s\n%s\n%d", bucket, key, expiresAt)
	return hex.EncodeToString(mac.Sum(nil)), expiresAt
}

// VerifyRawToken 校验代理令牌：重算 HMAC 并检查过期时间。
func (s *StorageService) VerifyRawToken(token, bucket, key string, expiresAt int64) bool {
	if s.secret == "" || expiresAt <= 0 || time.Now().Unix() > expiresAt {
		return false
	}
	mac := hmac.New(sha256.New, []byte(s.secret))
	fmt.Fprintf(mac, "%s\n%s\n%d", bucket, key, expiresAt)
	expected := mac.Sum(nil)
	got, err := hex.DecodeString(token)
	if err != nil || len(got) != len(expected) {
		return false
	}
	return hmac.Equal(got, expected)
}

// OpenObject 打开对象只读流，由 handler 代理转发给播放器/下载器。
func (s *StorageService) OpenObject(ctx context.Context, bucket, key string) (*minio.Object, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	obj, err := s.client.GetObject(ctx, bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, errors.Join(ErrStorageUnavailable, err)
	}
	return obj, nil
}

// OpenObjectRange 打开对象字节区间 [start, end]（end<0 表示读到末尾）。
// AVPlayer 等播放器要求服务端支持 Range 分片请求。
func (s *StorageService) OpenObjectRange(ctx context.Context, bucket, key string,
	start, end int64) (*minio.Object, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	opts := minio.GetObjectOptions{}
	if err := opts.SetRange(start, end); err != nil {
		return nil, errors.Join(ErrStorageUnavailable, err)
	}
	obj, err := s.client.GetObject(ctx, bucket, key, opts)
	if err != nil {
		return nil, errors.Join(ErrStorageUnavailable, err)
	}
	return obj, nil
}

// StatObject 读取对象元信息（大小与类型）。
func (s *StorageService) StatObject(ctx context.Context, bucket, key string) (minio.ObjectInfo, error) {
	if !s.Available() {
		return minio.ObjectInfo{}, ErrStorageNotConfigured
	}
	info, err := s.client.StatObject(ctx, bucket, key, minio.StatObjectOptions{})
	if err != nil {
		return minio.ObjectInfo{}, errors.Join(ErrStorageUnavailable, err)
	}
	return info, nil
}
