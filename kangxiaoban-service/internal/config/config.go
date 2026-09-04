package config

import (
	"os"
	"time"

	"github.com/joho/godotenv"
)

// Config 应用配置，由环境变量 / .env 注入，区分开发与生产。
type Config struct {
	Server   ServerConfig
	Database DBConfig
	JWT      JWTConfig
	MQTT     MQTTConfig
	AI       AIConfig
	Stream   StreamConfig
}

type ServerConfig struct {
	Port string
	// UploadDir stores private user-uploaded media. Files are served through
	// authenticated API handlers rather than the public static shell.
	UploadDir string
	// SeedBusiness 首次启动是否写入一套互相关联的业务初始数据，默认 true。
	SeedBusiness bool
}

// AIConfig AI 对话网关（可插拔 provider）。
type AIConfig struct {
	Enabled      bool
	Provider     string // local / http（http 走 BaseURL 真实模型）
	BaseURL      string
	Model        string
	APIKey       string
	ConfigKey    string // 用于数据库中 AI 密钥的加密；生产环境应显式注入
	SystemPrompt string
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

// StreamConfig 摄像头 RTSP→HLS 转码预览配置。
type StreamConfig struct {
	Enabled    bool
	FfmpegPath string        // ffmpeg 可执行文件路径；为空则用 PATH 中的 ffmpeg
	Dir        string        // HLS 分片输出根目录
	TokenTTL   time.Duration // 预览令牌有效期
	IdleTTL    time.Duration // 会话空闲多久后自动回收转码进程
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
			Port:         env("KXB_SERVER_PORT", "8080"),
			UploadDir:    env("KXB_UPLOAD_DIR", "uploads"),
			SeedBusiness: seedBusinessEnabled(),
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
		AI: AIConfig{
			Enabled:      env("KXB_AI_ENABLED", "true") == "true",
			Provider:     env("KXB_AI_PROVIDER", "local"),
			BaseURL:      env("KXB_AI_BASE_URL", ""),
			Model:        env("KXB_AI_MODEL", "kxb-local"),
			APIKey:       os.Getenv("KXB_AI_API_KEY"),
			ConfigKey:    env("KXB_AI_CONFIG_KEY", env("KXB_JWT_SECRET", "change-me-in-production")),
			SystemPrompt: env("KXB_AI_SYSTEM_PROMPT", "你是康小伴智慧康养护理平台的照护助理，回答须谨慎、贴题、仅作参考，不做临床诊断。"),
		},
		Stream: StreamConfig{
			Enabled:    env("KXB_STREAM_ENABLED", "true") == "true",
			FfmpegPath: env("KXB_FFMPEG_PATH", ""),
			Dir:        env("KXB_STREAM_DIR", "streams"),
			TokenTTL:   time.Duration(envInt("KXB_STREAM_TOKEN_TTL_SECONDS", 7200)) * time.Second,
			IdleTTL:    time.Duration(envInt("KXB_STREAM_IDLE_TTL_SECONDS", 120)) * time.Second,
		},
	}
}

func seedBusinessEnabled() bool {
	if value := os.Getenv("KXB_SEED_BUSINESS"); value != "" {
		return value == "true"
	}
	// 兼容旧部署变量；新部署统一使用 KXB_SEED_BUSINESS。
	return env("KXB_SEED_DEMO", "true") == "true"
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
