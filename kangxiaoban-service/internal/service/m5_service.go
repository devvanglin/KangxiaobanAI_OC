package service

import (
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// SupplyService 药物库存 + 餐饮订餐。
type SupplyService struct{ repo *repository.SupplyRepository }

func NewSupplyService(repo *repository.SupplyRepository) *SupplyService {
	return &SupplyService{repo: repo}
}

func (s *SupplyService) ListStock(keyword string, page, size int) ([]model.MedicineStock, int64, error) {
	return s.repo.ListStock(keyword, page, size)
}
func (s *SupplyService) CreateStock(st *model.MedicineStock) error { return s.repo.CreateStock(st) }
func (s *SupplyService) AdjustStock(id uint, delta int) error       { return s.repo.AdjustStock(id, delta) }
func (s *SupplyService) ListDining(elderID uint, mealTime string, page, size int) ([]model.DiningOrder, int64, error) {
	return s.repo.ListDining(elderID, mealTime, page, size)
}
func (s *SupplyService) CreateDining(d *model.DiningOrder) error { return s.repo.CreateDining(d) }