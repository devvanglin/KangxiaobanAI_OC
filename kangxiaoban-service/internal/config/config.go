package config

import (
	"os"

	"github.com/joho/godotenv"
)

// Config 应用配置，由环境变量 / .env 注入，区分开发与生产。
type Config struct {
	Server   ServerConfig
	Database DBConfig
	JWT      JWTConfig
}

type ServerConfig struct {
	Port string
}

type DBConfig struct {
	// Driver: dev 用 sqlite，生产用 mysql（DSN 切换，零改代码）
	Driver string
	// SQLite DSN（Driver=sqlite 时生效）
	SQLitePath string
	// MySQL DSN（Driver=mysql 时生效）
	MySQLDSN string
}

type JWTConfig struct {
	Secret string
	Expire int64 // 秒
}

// Load 从环境变量读取配置；存在 .env 则自动加载。
func Load() *Config {
	_ = godotenv.Load()
	return &Config{
		Server: ServerConfig{
			Port: env("KXB_SERVER_PORT", "8080"),
		},
		Database: DBConfig{
			Driver:     env("KXB_DB_DRIVER", "sqlite"), // 默认 sqlite，开发即跑
			SQLitePath: env("KXB_DB_SQLITE_PATH", "kangxiaoban.db"),
			MySQLDSN:   env("KXB_DB_MYSQL_DSN", "root:password@tcp(127.0.0.1:3306)/kangxiaoban?charset=utf8mb4&parseTime=True&loc=Local"),
		},
		JWT: JWTConfig{
			Secret: env("KXB_JWT_SECRET", "change-me-in-production"),
			Expire: int64(envInt("KXB_JWT_EXPIRE", 86400)),
		},
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	n := 0
	for _, c := range v {
		if c < '0' || c > '9' {
			n = 0
			break
		}
		n = n*10 + int(c-'0')
	}
	if n == 0 {
		return def
	}
	return n
}