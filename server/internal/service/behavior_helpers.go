// behavior_helpers.go：分析器的纯函数与 HTTP 小助手。
package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

func getEnv(key string) string { return os.Getenv(key) }

// cropFace 按 bbox（四周留 25% 边距）裁出人脸 JPEG；帧或 bbox 无效返回空。
func cropFace(frame []byte, bbox []float64) []byte {
	if len(bbox) != 4 {
		return nil
	}
	img, err := jpeg.Decode(bytes.NewReader(frame))
	if err != nil {
		return nil
	}
	bounds := img.Bounds()
	x1, y1 := int(bbox[0]), int(bbox[1])
	x2, y2 := int(bbox[2]), int(bbox[3])
	if x2 <= x1 || y2 <= y1 {
		return nil
	}
	padX := (x2 - x1) / 4
	padY := (y2 - y1) / 4
	x1, y1 = maxInt(0, x1-padX), maxInt(0, y1-padY)
	x2, y2 = minInt(bounds.Dx(), x2+padX), minInt(bounds.Dy(), y2+padY)
	if x2 <= x1 || y2 <= y1 {
		return nil
	}
	type subImager interface {
		SubImage(r image.Rectangle) image.Image
	}
	sub, ok := img.(subImager)
	if !ok {
		return nil
	}
	out := &bytes.Buffer{}
	if err := jpeg.Encode(out, sub.SubImage(image.Rect(
		bounds.Min.X+x1, bounds.Min.Y+y1, bounds.Min.X+x2, bounds.Min.Y+y2,
	)), &jpeg.Options{Quality: 88}); err != nil {
		return nil
	}
	return out.Bytes()
}

// cropForReview 复审输入与裁切脸图一致。
func cropForReview(frame []byte, bbox []float64) []byte { return cropFace(frame, bbox) }

// emotionChinese 把 EmotiEffLib 英文表情标签映射为中文；未知标签原样返回。
func emotionChinese(label string) string {
	known := map[string]string{
		"neutral": "中性", "happy": "高兴", "sad": "悲伤", "angry": "愤怒",
		"surprised": "惊讶", "surprise": "惊讶", "fear": "恐惧", "disgust": "厌恶",
	}
	if zh, ok := known[strings.ToLower(strings.TrimSpace(label))]; ok {
		return zh
	}
	return label
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// postChatJSON 调用 OpenAI 兼容 chat completions 并解码响应。
func postChatJSON(ctx context.Context, baseURL, apiKey string, payload map[string]interface{}, out interface{}) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	base := strings.TrimRight(strings.TrimSpace(baseURL), "/")
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/v1/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("复审请求 HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return json.Unmarshal(body, out)
}
