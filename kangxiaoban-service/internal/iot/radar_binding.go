// radar_binding.go 毫米波雷达与房间/长者的自动绑定。
// 产品语义：雷达由 EMQX 自动接入 → 管理端把它分配到某房间 →
// 该房间有在住长者时，雷达自动成为长者的设备（【长者】→【设备】可见，
// 数据写入长者体征/告警）。
package iot

import (
	"context"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// SyncMillimeterRadarBindingForElder 长者方向：把长者（经床位）所在房间的
// 未绑定雷达绑到长者，并解除该长者已不在的其他房间的雷达绑定。
func SyncMillimeterRadarBindingForElder(ctx context.Context, db *gorm.DB, elder *model.Elder) {
	if db == nil || elder == nil || elder.ID == 0 || elder.BedID == nil {
		return
	}
	var bed model.Bed
	if err := db.Where("id = ?", *elder.BedID).First(&bed).Error; err != nil {
		return
	}
	var room model.Room
	if err := db.Where("id = ?", bed.RoomID).First(&room).Error; err != nil || room.RoomNo == "" {
		return
	}
	db.Model(&model.IotDevice{}).
		Where("device_type = ? AND elder_id = ? AND room <> ?", "millimeter_wave", elder.ID, room.RoomNo).
		Update("elder_id", nil)
	db.Model(&model.IotDevice{}).
		Where("device_type = ? AND room = ? AND elder_id IS NULL", "millimeter_wave", room.RoomNo).
		Update("elder_id", elder.ID)
}

// SyncElderForRadarRoom 雷达方向：雷达被分配到某房间且该房间有在住长者时，
// 自动把雷达绑给该长者。
func SyncElderForRadarRoom(ctx context.Context, db *gorm.DB, device *model.IotDevice) {
	if db == nil || device == nil || device.ID == 0 || device.DeviceType != "millimeter_wave" || device.Room == "" {
		return
	}
	var elder model.Elder
	err := db.Joins("JOIN beds ON beds.elder_id = elders.id AND beds.status = ?", "occupied").
		Joins("JOIN rooms ON rooms.id = beds.room_id AND rooms.room_no = ?", device.Room).
		Where("elders.status = ?", 2).
		Order("elders.id ASC").First(&elder).Error
	if err != nil {
		return
	}
	db.Model(&model.IotDevice{}).Where("id = ?", device.ID).
		Update("elder_id", elder.ID)
	device.ElderID = &elder.ID
}
