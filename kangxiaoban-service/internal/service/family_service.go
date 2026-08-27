package service

import "kangxiaoban-service/internal/repository"

// FamilyService 家属绑定。
type FamilyService struct{ repo *repository.FamilyRepository }

func NewFamilyService(repo *repository.FamilyRepository) *FamilyService {
	return &FamilyService{repo: repo}
}

// BoundElderIDs 该家属可查看的长者 id 集合。
func (s *FamilyService) BoundElderIDs(userID uint) ([]uint, error) {
	return s.repo.BoundElderIDs(userID)
}