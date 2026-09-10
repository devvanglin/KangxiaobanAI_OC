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
	Expression     string    `gorm:"size:64" json:"expression"`                // 最终表情（qwen 复审优先）
	ExpressionSrc  string    `gorm:"size:24" json:"expression_source"`         // emotieff / qwen
	EmotieffLabel  string    `gorm:"size:64" json:"emotieff_label"`            // EmotiEffLib 原始标签
	Similarity     float64   `json:"similarity"`                               // 人脸比对余弦相似度
	FaceCropObject string    `gorm:"size:255" json:"face_crop_object"`         // 裁切脸图对象键
	VideoObject    string    `gorm:"size:255" json:"video_object"`             // 监控片段对象键
	Source         string    `gorm:"size:24;default:camera" json:"source"`     // camera / manual
	Error          string    `gorm:"size:255" json:"error,omitempty"`          // 片段/复审失败原因（不影响事件本身）
	Abnormal       bool      `gorm:"default:false" json:"abnormal"`            // JoyAI 行为文本命中确定性异常规则
	AbnormalReason string    `gorm:"size:64" json:"abnormal_reason,omitempty"` // 命中的异常关键词
}

func (BehaviorEvent) TableName() string { return "behavior_events" }

// ComfortSession 是摄像头识别到悲伤表情后触发的主动语音安抚会话。
// 生命周期：pending（待老人端设备领取）→ talking（设备已开场并等待老人回应）→
// responded（老人有回应，继续对话）/ reported（无回应或超时未领取，已通知护工）；
// closed 由后台扫描器清理陈旧会话，不产生通知。
type ComfortSession struct {
	Base
	ElderID         uint       `gorm:"index" json:"elder_id"`
	DeviceID        string     `gorm:"size:64;index" json:"device_id"`
	AreaID          *uint      `json:"area_id"`
	BehaviorEventID uint       `json:"behavior_event_id"` // 触发本次安抚的行为事件
	Trigger         string     `gorm:"size:32;default:sad_emotion" json:"trigger"`
	Expression      string     `gorm:"size:32" json:"expression"` // 触发时的最终表情
	Similarity      float64    `json:"similarity"`
	Status          string     `gorm:"size:16;default:pending;index" json:"status"`
	Transcript      string     `gorm:"size:512" json:"transcript,omitempty"` // 老人第一句语音回应（ASR）
	RespondedAt     *time.Time `json:"responded_at,omitempty"`
	ReportedAt      *time.Time `json:"reported_at,omitempty"`
	Error           string     `gorm:"size:255" json:"error,omitempty"`
}

func (ComfortSession) TableName() string { return "comfort_sessions" }
