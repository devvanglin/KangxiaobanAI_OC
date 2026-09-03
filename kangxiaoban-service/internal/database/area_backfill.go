package database

import (
	"fmt"

	"gorm.io/gorm"
	"kangxiaoban-service/internal/model"
)

// backfillAreas mirrors historical rooms into the new area tree. It is
// idempotent and deliberately keeps rooms/room_id for older clients.
func backfillAreas(db *gorm.DB) error {
	var rooms []model.Room
	if err := db.Find(&rooms).Error; err != nil {
		return err
	}
	for _, room := range rooms {
		floorCode := fmt.Sprintf("%s-floor-%d", room.Building, room.Floor)
		floor := model.Area{}
		if err := db.Where("code = ?", floorCode).First(&floor).Error; err != nil {
			if err != gorm.ErrRecordNotFound {
				return err
			}
			floor = model.Area{Type: model.AreaTypeFloor, Code: floorCode, Name: fmt.Sprintf("%s %d 楼", room.Building, room.Floor), Building: room.Building, FloorNo: room.Floor, Status: "active"}
			if err := db.Create(&floor).Error; err != nil {
				return err
			}
		}
		roomCode := fmt.Sprintf("%s-room-%s", room.Building, room.RoomNo)
		area := model.Area{}
		if err := db.Where("code = ?", roomCode).First(&area).Error; err != nil {
			if err != gorm.ErrRecordNotFound {
				return err
			}
			area = model.Area{ParentID: &floor.ID, Type: model.AreaTypeRoom, Code: roomCode, Name: room.RoomNo, Building: room.Building, FloorNo: room.Floor, Status: room.Status}
			if err := db.Create(&area).Error; err != nil {
				return err
			}
		}
		if err := db.Model(&model.Bed{}).Where("room_id = ? AND area_id IS NULL", room.ID).Update("area_id", area.ID).Error; err != nil {
			return err
		}
	}
	return nil
}
