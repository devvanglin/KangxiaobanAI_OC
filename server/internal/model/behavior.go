package model

import "time"

// BehaviorEvent 是一次摄像头侧识别的完整结果：谁（InsightFace）、什么表情
// （EmotiEffLib + Qwen 视觉复审）、什么行为（JoyAI），以及裁切脸图与监控片段
// 在 MinIO cctv-footage-storage 桶中的对象键。
type BehaviorEvent struct {
	Base
	ElderID        uint      `gorm:"index" json:"elder_id"`
	DeviceID       string    `gorm:"size:64;index" json:"device_id"`
	AreaID         *uint     `gorm:"index" json:"area_id"`
	DetectedAt     time.Time `gorm:"index" json:"detected_at"`
	Behavior       string    `gorm:"size:512" json:"behavior"`
	Expression     string    `gorm:"size:64" json:"expression"`            // 最终表情（qwen 复审优先）
	ExpressionSrc  string    `gorm:"size:24" json:"expression_source"`     // emotieff / qwen
	EmotieffLabel  string    `gorm:"size:64" json:"emotieff_label"`        // EmotiEffLib 原始标签
	Similarity     float64   `json:"similarity"`                           // 人脸比对余弦相似度
	FaceCropObject string    `gorm:"size:255" json:"face_crop_object"`     // 裁切脸图对象键
	VideoObject    string    `gorm:"size:255" json:"video_object"`         // 监控片段对象键
	Source         string    `gorm:"size:24;default:camera" json:"source"` // camera / manual
	Error          string    `gorm:"size:255" json:"error,omitempty"`      // 片段/复审失败原因（不影响事件本身）
}

func (BehaviorEvent) TableName() string { return "behavior_events" }
