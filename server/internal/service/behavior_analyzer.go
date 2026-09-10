// behavior_analyzer.go 周期性分析绑定到走廊/区域的摄像头画面：
// InsightFace 认人 → 裁脸入 MinIO → JoyAI 行为 → Qwen 视觉复审表情 →
// 行为事件落库。识别/行为/复审任一失败都不产生垃圾事件，只记日志。
package service

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"os/exec"
	"strings"
	"sync"
	"time"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/face"
	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

const cctvBucket = "cctv-footage-storage"

// BehaviorAnalyzer 单实例轮询分析器。
type BehaviorAnalyzer struct {
	db          *gorm.DB
	faceClient  *face.Client
	aiCfg       *config.AIConfig
	storage     *StorageService
	interval    time.Duration
	cooldown    time.Duration
	reviewModel string
	ffmpegPath  string
	stop        chan struct{}
	once        sync.Once
}

func NewBehaviorAnalyzer(db *gorm.DB, faceCfg config.FaceConfig, aiCfg *config.AIConfig,
	storage *StorageService, ffmpegPath string) *BehaviorAnalyzer {
	return &BehaviorAnalyzer{
		db: db, faceClient: face.New(faceCfg.BaseURL),
		aiCfg: aiCfg, storage: storage,
		interval: 10 * time.Second, cooldown: 90 * time.Second,
		reviewModel: envString("KXB_FACE_REVIEW_MODEL", "Qwen3-VL-4B-Instruct"),
		ffmpegPath:  ffmpegPath,
		stop:        make(chan struct{}),
	}
}

func envString(key, def string) string {
	if v := strings.TrimSpace(getEnv(key)); v != "" {
		return v
	}
	return def
}

// Start 启动后台轮询；进程生命周期内只允许一次。
func (a *BehaviorAnalyzer) Start() {
	a.once.Do(func() {
		go func() {
			ticker := time.NewTicker(a.interval)
			defer ticker.Stop()
			for {
				select {
				case <-a.stop:
					return
				case <-ticker.C:
					a.analyzeOnce()
				}
			}
		}()
	})
}

func (a *BehaviorAnalyzer) Stop() { close(a.stop) }

type cameraTarget struct {
	DeviceID  string
	StreamURL string
	AreaID    *uint
}

// analyzeOnce 每个 tick 分析一个绑定了区域的在线摄像头（轮询均摊负载；
// 人脸服务的 RTSP 取帧是全局单路）。
func (a *BehaviorAnalyzer) analyzeOnce() {
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	var cameras []model.IotDevice
	if err := a.db.WithContext(ctx).
		Where("device_type = ? AND area_id IS NOT NULL AND stream_url <> '' AND discovery_status = ?",
			"camera", "claimed").
		Order("updated_at ASC").Limit(1).Find(&cameras).Error; err != nil || len(cameras) == 0 {
		return
	}
	cam := cameras[0]
	// 触碰 updated_at 之外的排序键没有意义；用 immediately+延迟字段旋转轮询顺序。
	a.db.WithContext(ctx).Model(&model.IotDevice{}).Where("id = ?", cam.ID).
		UpdateColumn("updated_at", time.Now())

	frame, err := a.grabFrame(ctx, cam.StreamURL)
	if err != nil {
		log.Printf("[behavior] grab frame %s: %v", cam.DeviceID, err)
		return
	}
	faces, err := a.faceClient.Recognize(ctx, frame)
	if err != nil {
		log.Printf("[behavior] recognize %s: %v", cam.DeviceID, err)
		return
	}
	now := time.Now()
	for _, f := range faces {
		if !f.Known || f.PersonID == nil || !strings.HasPrefix(*f.PersonID, "elder-") {
			continue
		}
		var elderID uint
		if _, err := fmt.Sscanf(*f.PersonID, "elder-%d", &elderID); err != nil || elderID == 0 {
			continue
		}
		if a.recentlyRecorded(ctx, elderID, cam.DeviceID, now) {
			continue
		}
		a.processFace(ctx, cam, f, elderID, frame, now)
	}
}

func (a *BehaviorAnalyzer) recentlyRecorded(ctx context.Context, elderID uint, deviceID string, now time.Time) bool {
	var count int64
	a.db.WithContext(ctx).Model(&model.BehaviorEvent{}).
		Where("elder_id = ? AND device_id = ? AND detected_at > ?", elderID, deviceID, now.Add(-a.cooldown)).
		Count(&count)
	return count > 0
}

// grabFrame 用人脸服务的 RTSP 取帧（全局单路：start → frame → stop）。
func (a *BehaviorAnalyzer) grabFrame(ctx context.Context, rtspURL string) ([]byte, error) {
	if err := a.faceClient.RTSPStart(ctx, rtspURL); err != nil {
		return nil, err
	}
	time.Sleep(1200 * time.Millisecond) // 等首帧解码
	defer a.faceClient.RTSPStop(context.Background())
	return a.faceClient.RTSPFrame(ctx)
}

func (a *BehaviorAnalyzer) processFace(ctx context.Context, cam model.IotDevice, f face.Face,
	elderID uint, frame []byte, now time.Time) {
	event := model.BehaviorEvent{
		ElderID: elderID, DeviceID: cam.DeviceID, AreaID: cam.AreaID,
		DetectedAt: now, Similarity: f.Similarity, Source: "camera",
	}
	if f.Emotion != nil {
		event.EmotieffLabel = f.Emotion.Label
		event.Expression = emotionChinese(f.Emotion.Label)
		event.ExpressionSrc = "emotieff"
	}

	// 1) 裁脸入 MinIO（失败不阻断后续步骤）。
	crop := cropFace(frame, f.BBox)
	if len(crop) > 0 {
		key := fmt.Sprintf("faces/tenant-%d/%s/%d.jpg", cam.TenantID, cam.DeviceID, now.UnixMilli())
		if err := a.storage.UploadObject(ctx, cctvBucket, key, bytes.NewReader(crop), int64(len(crop)), "image/jpeg"); err == nil {
			event.FaceCropObject = key
		} else {
			event.Error = "脸图上传失败: " + err.Error()
		}
	}

	// 2) Qwen 视觉复审表情（有裁脸图才复审，结果覆盖最终表情）。
	if len(crop) > 0 {
		if label, err := a.reviewExpression(ctx, crop); err == nil && label != "" {
			event.Expression = label
			event.ExpressionSrc = "qwen"
		} else if err != nil {
			event.Error = strings.TrimPrefix(event.Error+"；", "；") + "复审失败: " + err.Error()
		}
	}

	// 3) JoyAI 行为描述。
	if result, err := a.faceClient.Behavior(ctx, frame); err == nil && strings.TrimSpace(result.Behavior) != "" {
		event.Behavior = strings.TrimSpace(result.Behavior)
	} else if err != nil {
		event.Error = strings.TrimPrefix(event.Error+"；", "；") + "行为识别失败: " + err.Error()
	}

	// 4) 监控片段（需要容器内 ffmpeg；缺失则记原因）。
	if key, err := a.cutClip(ctx, cam.StreamURL, now, elderID); err == nil {
		event.VideoObject = key
	} else {
		event.Error = strings.TrimPrefix(event.Error+"；", "；") + "片段失败: " + err.Error()
	}

	if err := a.db.WithContext(ctx).Create(&event).Error; err != nil {
		log.Printf("[behavior] insert event: %v", err)
	}
}

// cutClip 用 ffmpeg 从 RTSP 录 8 秒片段并上传 MinIO。
func (a *BehaviorAnalyzer) cutClip(ctx context.Context, rtspURL string, now time.Time, elderID uint) (string, error) {
	if strings.TrimSpace(a.ffmpegPath) == "" {
		return "", fmt.Errorf("ffmpeg 未配置")
	}
	if _, err := exec.LookPath(a.ffmpegPath); err != nil {
		return "", fmt.Errorf("ffmpeg 不可用")
	}
	out := &bytes.Buffer{}
	cmd := exec.CommandContext(ctx, a.ffmpegPath, "-y", "-rtsp_transport", "tcp", "-i", rtspURL,
		"-t", "8", "-c:v", "libx264", "-preset", "ultrafast", "-an", "-f", "mp4", "-movflags", "frag_keyframe+empty_moov", "-")
	cmd.Stdout = out
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return "", err
	}
	key := fmt.Sprintf("clips/tenant-1/%s/%d-elder-%d.mp4", "cam", now.UnixMilli(), elderID)
	if err := a.storage.UploadObject(ctx, cctvBucket, key, bytes.NewReader(out.Bytes()), int64(out.Len()), "video/mp4"); err != nil {
		return "", err
	}
	return key, nil
}

// reviewExpression 用 NewAPI 的 qwen 视觉模型对裁切脸图做表情复审。
func (a *BehaviorAnalyzer) reviewExpression(ctx context.Context, crop []byte) (string, error) {
	if strings.TrimSpace(a.aiCfg.BaseURL) == "" {
		return "", fmt.Errorf("视觉复审未配置模型服务")
	}
	dataURL := "data:image/jpeg;base64," + base64.StdEncoding.EncodeToString(crop)
	body := map[string]interface{}{
		"model": a.reviewModel,
		"messages": []map[string]interface{}{{
			"role": "user",
			"content": []map[string]interface{}{
				{"type": "text", "text": "这张人脸照片的表情是什么？只输出一个中文词：中性、高兴、悲伤、愤怒、惊讶、恐惧或厌恶。"},
				{"type": "image_url", "image_url": map[string]string{"url": dataURL}},
			},
		}},
		"max_tokens": 8, "temperature": 0,
	}
	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := postChatJSON(ctx, a.aiCfg.BaseURL, a.aiCfg.APIKey, body, &out); err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", fmt.Errorf("空回复")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}
