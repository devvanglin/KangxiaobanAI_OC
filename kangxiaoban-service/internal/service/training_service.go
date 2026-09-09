// training_service.go 每日认知训练：从 MinIO 训练桶按「日」随机采样一份
// 10 分钟素材单（图片/音乐/视频混合），供护工端给阿尔茨海默老人做认知训练。
package service

import (
	"context"
	"math/rand"
	"sort"
	"time"

	"strings"
)

// 训练素材桶（与 MinIO 上实际桶一致）。
const (
	TrainingBucketPicture = "ad-training-picture"
	TrainingBucketMusic   = "ad-training-music"
	TrainingBucketVideo   = "ad-training-video"
)

// TrainingItem 是一份训练素材。
type TrainingItem struct {
	Kind        string `json:"kind"` // picture / music / video
	Bucket      string `json:"bucket"`
	Key         string `json:"key"`
	Title       string `json:"title"`
	URL         string `json:"url"`
	SuggestSecs int    `json:"suggest_seconds"` // 建议停留时长
}

// TrainingSession 是一次「每日训练」的完整素材单。
type TrainingSession struct {
	Date         string         `json:"date"`
	TotalSeconds int            `json:"total_seconds"`
	Items        []TrainingItem `json:"items"`
}

// TrainingService 采样每日训练素材。
type TrainingService struct {
	storage *StorageService
}

func NewTrainingService(storage *StorageService) *TrainingService {
	return &TrainingService{storage: storage}
}

func trainingKeys(ctx context.Context, s *StorageService, bucket string) []string {
	keys, err := s.ListAllKeys(ctx, bucket)
	if err != nil {
		return nil
	}
	return keys
}

// Daily 生成当日训练单：同一「自然日」内多次请求返回同一份素材（按日种子），
// 每天自动更换。图片 8 张（每张 45s）、音乐 3 段（每段 3min）、视频 1 个（3min）
// ≈ 10 分钟。
func (s *TrainingService) Daily(ctx context.Context) (*TrainingSession, error) {
	now := time.Now()
	date := now.Format("2006-01-02")
	seed := int64(now.Year())*1000000 + int64(now.YearDay())*1000 + 7
	rng := rand.New(rand.NewSource(seed))

	session := &TrainingSession{Date: date, TotalSeconds: 600}
	pick := func(bucket, kind string, n int, secs int, prefix string) {
		keys := trainingKeys(ctx, s.storage, bucket)
		if len(keys) == 0 {
			return
		}
		rng.Shuffle(len(keys), func(i, j int) { keys[i], keys[j] = keys[j], keys[i] })
		if n > len(keys) {
			n = len(keys)
		}
		for _, key := range keys[:n] {
			url, _, err := s.storage.PreviewURL(ctx, bucket, key)
			if err != nil {
				continue
			}
			session.Items = append(session.Items, TrainingItem{
				Kind: kind, Bucket: bucket, Key: key,
				Title: titleFromKey(key, prefix), URL: url, SuggestSecs: secs,
			})
		}
	}
	pick(TrainingBucketPicture, "picture", 8, 45, "看图记忆")
	pick(TrainingBucketMusic, "music", 3, 180, "怀旧金曲")
	pick(TrainingBucketVideo, "video", 1, 180, "影音回味")
	// 打乱混合顺序，但保证第一项是图片（开场简单）。
	sort.SliceStable(session.Items, func(i, j int) bool {
		return session.Items[i].Kind == "picture" && session.Items[j].Kind != "picture"
	})
	return session, nil
}

// titleFromKey 用对象键生成友好标题（去目录/扩展名）。
func titleFromKey(key, prefix string) string {
	idx := strings.LastIndex(key, "/")
	name := key
	if idx >= 0 {
		name = name[idx+1:]
	}
	if dot := strings.LastIndex(name, "."); dot > 0 {
		name = name[:dot]
	}
	if strings.TrimSpace(name) == "" {
		name = prefix
	}
	return name
}
