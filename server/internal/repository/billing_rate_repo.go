package repository

import (
	"context"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// BillingRateRepository reads tenant-scoped current fee configuration.
type BillingRateRepository struct{ db *gorm.DB }

func NewBillingRateRepository(db *gorm.DB) *BillingRateRepository {
	return &BillingRateRepository{db: db}
}

func (r *BillingRateRepository) ListEnabled(ctx context.Context) ([]model.BillingRate, error) {
	var rates []model.BillingRate
	err := r.db.WithContext(ctx).
		Where("enabled = ?", true).
		Order("kind, care_level, id").
		Find(&rates).Error
	return rates, err
}
