package auth

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims JWT 载荷：携带用户身份与角色，便于 RBAC 与后续鉴权。
type Claims struct {
	UserID   uint     `json:"uid"`
	TenantID uint     `json:"tenant_id"`
	Username string   `json:"username"`
	Roles    []string `json:"roles"`
	jwt.RegisteredClaims
}

// GenerateToken 签发 access token。
func GenerateToken(secret string, expireSec int64, userID uint, username string, roles []string) (string, error) {
	return GenerateTokenForTenant(secret, expireSec, userID, 1, username, roles)
}

// GenerateTokenForTenant 为指定机构签发令牌。tenantID 为 0 时回退到默认租户 1，
// 兼容历史单机构账号。
func GenerateTokenForTenant(secret string, expireSec int64, userID, tenantID uint, username string, roles []string) (string, error) {
	if tenantID == 0 {
		tenantID = 1
	}
	now := time.Now()
	claims := Claims{
		UserID:   userID,
		TenantID: tenantID,
		Username: username,
		Roles:    roles,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Duration(expireSec) * time.Second)),
			Issuer:    "kangxiaoban",
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

// ParseToken 校验并解析 token，返回其中身份。
func ParseToken(tokenStr, secret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}
	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}
	return nil, err
}
