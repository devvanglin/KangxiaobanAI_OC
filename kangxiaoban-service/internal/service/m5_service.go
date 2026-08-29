package service

import (
	"context"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

// SupplyService 药物库存 + 餐饮订餐。
type SupplyService struct{ repo *repository.SupplyRepository }

func NewSupplyService(repo *repository.SupplyRepository) *SupplyService {
	return &SupplyService{repo: repo}
}

func (s *SupplyService) ListStock(ctx context.Context, keyword string, page, size int) ([]model.MedicineStock, int64, error) {
	return s.repo.ListStock(ctx, keyword, page, size)
}
func (s *SupplyService) CreateStock(ctx context.Context, st *model.MedicineStock) error {
	return s.repo.CreateStock(ctx, st)
}
func (s *SupplyService) AdjustStock(ctx context.Context, id uint, delta int) error {
	return s.repo.AdjustStock(ctx, id, delta)
}
func (s *SupplyService) ListDining(ctx context.Context, elderID uint, mealTime string, page, size int) ([]model.DiningOrder, int64, error) {
	return s.repo.ListDining(ctx, elderID, mealTime, page, size)
}
func (s *SupplyService) CreateDining(ctx context.Context, d *model.DiningOrder) error {
	return s.repo.CreateDining(ctx, d)
}
