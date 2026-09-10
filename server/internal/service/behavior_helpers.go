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

// emotionChinese 把 EmotiEffLib 英文表情标签映射为中文。覆盖 AffectNet 7/8 类
// 模型的实际输出词形（Anger/Happiness/Sadness/Surprise/Contempt 等，见
// EmotiEffLib facial_analysis.py 的 idx_to_emotion_class）以及历史小写别名；
// 未知标签原样返回。
func emotionChinese(label string) string {
	known := map[string]string{
		"neutral":   "中性",
		"happiness": "高兴", "happy": "高兴",
		"sadness": "悲伤", "sad": "悲伤",
		"anger": "愤怒", "angry": "愤怒",
		"surprise": "惊讶", "surprised": "惊讶",
		"fear": "恐惧", "disgust": "厌恶",
		"contempt": "轻蔑",
	}
	if zh, ok := known[strings.ToLower(strings.TrimSpace(label))]; ok {
		return zh
	}
	return label
}

// abnormalBehaviorRules 是 JoyAI 行为文本的确定性异常规则：任一关键词命中即判
// 异常并立即通知护工。保持保守，只收明确危险/激烈的行为词，避免把日常活动
// （撕纸、看电视等）误报；生成式输出只做辅助，不在此扩展。
var abnormalBehaviorRules = []string{
	"摔倒", "跌倒", "倒地", "扑倒", "摔东西", "砸",
	"张牙舞爪", "攻击", "打人", "推搡", "抓人", "咬人",
	"挣扎", "自残", "撞头", "撞墙", "攀爬", "翻越",
	"哭喊", "嘶吼", "尖叫", "大喊大叫",
}

// classifyAbnormal 返回命中的异常关键词；未命中返回空串。
func classifyAbnormal(behavior string) string {
	text := strings.TrimSpace(behavior)
	if text == "" {
		return ""
	}
	for _, keyword := range abnormalBehaviorRules {
		if strings.Contains(text, keyword) {
			return keyword
		}
	}
	return ""
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
