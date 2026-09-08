package service

import (
	"context"
	"errors"

	"golang.org/x/crypto/bcrypt"

	"kangxiaoban-service/internal/auth"
	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
	"kangxiaoban-service/internal/repository"
)

var (
	// ErrInvalidCredentials 账号不存在或密码错误。
	ErrInvalidCredentials = errors.New("用户名或密码错误")
	// ErrUserDisabled 账号被禁用。
	ErrUserDisabled = errors.New("账号已被禁用")
)

// AuthService 登录/签发 Token。
type AuthService struct {
	repo *repository.UserRepository
	cfg  *config.JWTConfig
}

func NewAuthService(repo *repository.UserRepository, cfg *config.JWTConfig) *AuthService {
	return &AuthService{repo: repo, cfg: cfg}
}

// Login 校验凭据并签发 access token；失败返回业务错误。
func (s *AuthService) Login(username, password string) (string, *model.User, error) {
	user, err := s.repo.FindByUsername(username)
	if err != nil || user.ID == 0 {
		return "", nil, ErrInvalidCredentials
	}
	if user.Status != 1 {
		return "", nil, ErrUserDisabled
	}
	if !auth.CheckPassword(user.PasswordHash, password) {
		return "", nil, ErrInvalidCredentials
	}
	if len(user.Roles) == 0 {
		return "", nil, ErrInvalidCredentials
	}
	roles := make([]string, 0, len(user.Roles))
	workspace := ""
	workspaceRank := 99
	for _, r := range user.Roles {
		roles = append(roles, r.Code)
		rank := 2
		if r.WorkspaceCode == "admin" {
			rank = 0
		} else if r.WorkspaceCode == "doctor" {
			rank = 1
		}
		if rank < workspaceRank {
			workspace = r.WorkspaceCode
			workspaceRank = rank
		}
	}
	permissionContext := context.WithValue(context.Background(), model.TenantContextKey, user.TenantID)
	permissions, err := s.repo.PermissionsByRoleCodesContext(permissionContext, roles)
	if err != nil {
		return "", nil, err
	}
	token, err := auth.GenerateToken(s.cfg.Secret, s.cfg.Expire, user.ID, user.Username, roles)
	if err != nil {
		return "", nil, err
	}
	// 不返回哈希
	user.PasswordHash = ""
	// Expose effective capabilities and the default workspace for the client shell.
	user.WorkspaceCode = workspace
	user.Permissions = permissions
	return token, user, nil
}

// Permissions 取用户角色对应的权限码集合。
func (s *AuthService) Permissions(roles []string) ([]string, error) {
	return s.repo.PermissionsByRoleCodes(roles)
}

// HashPassword 暴露给种子/管理用（可选）。
func HashPassword(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	return string(b), err
}
