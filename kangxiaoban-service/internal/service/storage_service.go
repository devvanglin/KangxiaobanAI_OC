package service

import (
	"context"
	"errors"
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

// previewTTL 预签名链接有效期：管理端预览用途，30 分钟足够且不长期暴露。
const previewTTL = 30 * time.Minute

// StorageService 管理端对象存储只读预览：列出桶、桶内对象，并生成短期预签名链接。
// 只读接口，不做任何写操作；密钥留在服务端，客户端只拿到临时 URL。
type StorageService struct {
	client *minio.Client
}

func NewStorageService(cfg config.StorageConfig) *StorageService {
	if cfg.Endpoint == "" || cfg.AccessKey == "" || cfg.SecretKey == "" {
		return &StorageService{}
	}
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.Secure,
		Region: cfg.Region,
	})
	if err != nil {
		return &StorageService{}
	}
	return &StorageService{client: client}
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

// Objects 列出桶内对象；prefix 供客户端按目录/文件名过滤，maxKeys 为返回上限。
func (s *StorageService) Objects(ctx context.Context, bucket, prefix string, maxKeys int) ([]StorageObject, error) {
	if !s.Available() {
		return nil, ErrStorageNotConfigured
	}
	// MaxKeys 只约束单次请求页大小；递归列出会继续翻页，这里在达到上限时取消遍历。
	listCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	options := minio.ListObjectsOptions{
		Prefix:    prefix,
		Recursive: true,
	}
	objects := make([]StorageObject, 0, maxKeys)
	for object := range s.client.ListObjects(listCtx, bucket, options) {
		if object.Err != nil {
			return nil, errors.Join(ErrStorageUnavailable, object.Err)
		}
		if strings.HasSuffix(object.Key, "/") {
			continue // 目录占位对象不作为内容展示。
		}
		objects = append(objects, StorageObject{Key: object.Key, Size: object.Size, LastModified: object.LastModified})
		if len(objects) >= maxKeys {
			cancel()
			break
		}
	}
	return objects, nil
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
