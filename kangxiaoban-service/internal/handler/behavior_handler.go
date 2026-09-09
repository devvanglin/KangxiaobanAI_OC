// behavior_handler.go 长者行为事件（时间条回放数据源）。
package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/service"
)

const cctvBucketName = "cctv-footage-storage"

// BehaviorHandler 查询长者行为事件与配对人脸注册状态。
type BehaviorHandler struct {
	db      *gorm.DB
	storage *service.StorageService
	face    *service.FaceEnrollService
}

func NewBehaviorHandler(db *gorm.DB, storage *service.StorageService,
	face *service.FaceEnrollService) *BehaviorHandler {
	return &BehaviorHandler{db: db, storage: storage, face: face}
}

type behaviorEventView struct {
	model.BehaviorEvent
	FaceCropURL string `json:"face_crop_url,omitempty"`
	VideoURL    string `json:"video_url,omitempty"`
}

// ListByElder GET /api/v1/elders/:id/behavior-events?page=1&size=20
// 返回按时间倒序的行为事件，附 2 小时有效的脸图/视频预签名 URL。
func (h *BehaviorHandler) ListByElder(c *gin.Context) {
	elderID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || elderID == 0 {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}
	var total int64
	var rows []model.BehaviorEvent
	q := h.db.WithContext(c.Request.Context()).Model(&model.BehaviorEvent{}).
		Where("elder_id = ?", elderID)
	q.Count(&total)
	if err := q.Order("detected_at DESC").Offset((page - 1) * size).Limit(size).Find(&rows).Error; err != nil {
		Fail(c, http.StatusInternalServerError, 500, "行为事件加载失败")
		return
	}
	views := make([]behaviorEventView, 0, len(rows))
	for _, row := range rows {
		view := behaviorEventView{BehaviorEvent: row}
		if row.FaceCropObject != "" {
			if url, _, err := h.storage.PreviewURL(c.Request.Context(), cctvBucketName, row.FaceCropObject); err == nil {
				view.FaceCropURL = url
			}
		}
		if row.VideoObject != "" {
			// 视频给更长有效期，保证回放期间链接不过期。
			if url, _, err := h.storage.PreviewURL(c.Request.Context(), cctvBucketName, row.VideoObject); err == nil {
				view.VideoURL = url
			}
		}
		views = append(views, view)
	}
	respond(c, http.StatusOK, 0, "ok", gin.H{"list": views, "total": total})
}

// FaceEnrollment GET /api/v1/elders/:id/face-enrollment
func (h *BehaviorHandler) FaceEnrollment(c *gin.Context) {
	elderID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || elderID == 0 {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	view, err := h.face.Enrollment(c.Request.Context(), uint(elderID))
	if err != nil {
		Fail(c, http.StatusInternalServerError, 500, "人脸注册状态加载失败")
		return
	}
	OK(c, view)
}

// FaceReEnroll POST /api/v1/elders/:id/face-enrollment
// 用最近一张人像照重新注册（同步执行，最长 ~30s）。
func (h *BehaviorHandler) FaceReEnroll(c *gin.Context) {
	elderID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || elderID == 0 {
		Fail(c, http.StatusBadRequest, 400, "参数错误")
		return
	}
	done := make(chan *service.FaceEnrollmentView, 1)
	go func() { done <- h.face.EnrollElderFromPortrait(c.Request.Context(), uint(elderID)) }()
	select {
	case view := <-done:
		OK(c, view)
	case <-time.After(35 * time.Second):
		Fail(c, http.StatusGatewayTimeout, 504, "人脸注册超时，请稍后查看状态")
	}
}
