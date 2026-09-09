// Package face 是康小伴人脸/表情服务（DGX 上的 FaceCare Console）的 Go 客户端。
// 服务为 HTTPS 自签证书，请求体为 JSON、图像字段为 data URL。
package face

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Face 是一次识别中单张人脸的结果。
type Face struct {
	PersonID   *string   `json:"person_id"`
	Known      bool      `json:"known"`
	Similarity float64   `json:"similarity"`
	BBox       []float64 `json:"bbox"` // [x1,y1,x2,y2] 像素坐标，可用于裁脸
	Emotion    *Emotion  `json:"emotion,omitempty"`
}

// Emotion 是 EmotiEffLib 的表情分类结果（label 为英文标签）。
type Emotion struct {
	Label string  `json:"label"`
	Score float64 `json:"score,omitempty"`
}

// BehaviorResult 是 JoyAI 行为描述接口的响应。
type BehaviorResult struct {
	OK       bool   `json:"ok"`
	Behavior string `json:"behavior"`
	People   []Face `json:"people"`
	Model    string `json:"model"`
	Error    string `json:"error,omitempty"`
}

type healthResult struct {
	OK        bool    `json:"ok"`
	Enrolled  int     `json:"enrolled_people"`
	Threshold float64 `json:"match_threshold"`
}

// Client 调用人脸/表情服务。baseURL 形如 https://10.10.1.1:8088。
type Client struct {
	baseURL string
	hc      *http.Client
}

// New 创建客户端；证书为自签，跳过校验（受信内网）。
func New(baseURL string) *Client {
	return &Client{
		baseURL: strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		hc: &http.Client{
			Timeout: 60 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			},
		},
	}
}

func (c *Client) postJSON(ctx context.Context, path string, payload map[string]interface{}, out interface{}) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.hc.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("face service %s HTTP %d: %s", path, resp.StatusCode, strings.TrimSpace(string(raw)))
	}
	return json.Unmarshal(raw, out)
}

// dataURL 把 JPEG 字节包装成服务要求的 data URL。
func dataURL(jpeg []byte) string {
	return "data:image/jpeg;base64," + base64.StdEncoding.EncodeToString(jpeg)
}

// Health 探测服务可用性。
func (c *Client) Health(ctx context.Context) (bool, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/health", nil)
	if err != nil {
		return false, err
	}
	resp, err := c.hc.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	var result healthResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return false, err
	}
	return result.OK, nil
}

// Enroll 注册（覆盖式）一个人的人脸特征；image 必须只含一张人脸。
func (c *Client) Enroll(ctx context.Context, personID string, image []byte) error {
	var out struct {
		OK    bool `json:"ok"`
		Faces int  `json:"faces"`
	}
	err := c.postJSON(ctx, "/enroll", map[string]interface{}{
		"person_id": personID, "image": dataURL(image),
	}, &out)
	if err != nil {
		return err
	}
	if !out.OK {
		return fmt.Errorf("enroll failed for %s", personID)
	}
	return nil
}

// Recognize 识别一帧里所有人脸的身份与表情。
func (c *Client) Recognize(ctx context.Context, image []byte) ([]Face, error) {
	var out struct {
		OK    bool   `json:"ok"`
		Faces []Face `json:"faces"`
	}
	if err := c.postJSON(ctx, "/recognize", map[string]interface{}{"image": dataURL(image)}, &out); err != nil {
		return nil, err
	}
	return out.Faces, nil
}

// Behavior 让 JoyAI 描述画面中老人的行为（服务内部会先做人脸身份/表情识别）。
func (c *Client) Behavior(ctx context.Context, image []byte) (*BehaviorResult, error) {
	var out BehaviorResult
	if err := c.postJSON(ctx, "/behavior", map[string]interface{}{"image": dataURL(image)}, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// RTSPStart 让服务开始读取一路 RTSP 流（服务端全局单路，多摄像头需轮询）。
func (c *Client) RTSPStart(ctx context.Context, rtspURL string) error {
	var out struct {
		OK bool `json:"ok"`
	}
	return c.postJSON(ctx, "/rtsp/start", map[string]interface{}{"url": rtspURL}, &out)
}

// RTSPStop 停止当前 RTSP 取帧。
func (c *Client) RTSPStop(ctx context.Context) error {
	var out struct {
		OK bool `json:"ok"`
	}
	return c.postJSON(ctx, "/rtsp/stop", map[string]interface{}{}, &out)
}

// RTSPFrame 返回当前帧的 JPEG 字节。
func (c *Client) RTSPFrame(ctx context.Context) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/rtsp/frame", nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("rtsp frame HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}
