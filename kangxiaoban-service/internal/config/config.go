package config

import (
	"os"

	"github.com/joho/godotenv"
)

// Config 应用配置，由环境变量 / .env 注入，区分开发与生产。
type Config struct {
	Server ServerConfig
	Database DBConfig
	JWT      JWTConfig
	MQTT     MQTTConfig
}

type ServerConfig struct {
	Port string
	// StaticDir 展示壳静态目录（落地页/大屏），空则不托管。
	StaticDir string
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

// MQTTConfig 物联网 Broker 接入（雷达等设备）。
type MQTTConfig struct {
	Enable   bool
	URL      string
	ClientID string
	Username string
	Password string
	TopicSP  string // 睡眠雷达
	TopicFL  string // 跌倒雷达
}

// Load 从环境变量读取配置；存在 .env 则自动加载。
func Load() *Config {
	_ = godotenv.Load()
	return &Config{
		Server: ServerConfig{
			Port:      env("KXB_SERVER_PORT", "8080"),
			StaticDir: env("KXB_STATIC_DIR", "../showcase"),
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
		MQTT: MQTTConfig{
			Enable:   env("KXB_MQTT_ENABLE", "true") == "true",
			URL:      env("KXB_MQTT_URL", "tcp://192.168.100.110:1883"),
			ClientID: env("KXB_MQTT_CLIENT_ID", "kxb-backend"),
			Username: os.Getenv("KXB_MQTT_USERNAME"),
			Password: os.Getenv("KXB_MQTT_PASSWORD"),
			TopicSP:  "/Radar60SP/+/sys/property/post",
			TopicFL:  "/Radar60FL/+/sys/property/post",
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