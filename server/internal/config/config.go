package config

import (
	"os"
	"time"

	"github.com/joho/godotenv"
)

// Config 应用配置，由环境变量 / .env 注入，区分开发与生产。
type Config struct {
	Server          ServerConfig
	Database        DBConfig
	JWT             JWTConfig
	MQTT            MQTTConfig
	AI              AIConfig
	Face            FaceConfig
	Sandbox         SandboxConfig
	AssessmentAgent AssessmentAgentConfig
	Stream          StreamConfig
	Storage         StorageConfig
}

// SandboxConfig points to the separately deployed OpenSandbox control plane.
// The API key remains server-side and is never exposed to the model or client.
type SandboxConfig struct {
	Enabled  bool
	Domain   string
	Protocol string
	APIKey   string
	Image    string
}

// StorageConfig MinIO/S3 对象存储（管理端「存储」预览）。
// 密钥只保存在服务端环境变量，客户端通过 admin 接口间接访问。
type StorageConfig struct {
	Endpoint  string // 例如 10.10.1.13:9000
	AccessKey string
	SecretKey string
	Secure    bool   // true 走 https
	Region    string // 留空使用客户端默认
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
	RAG          DifyConfig // Dify RAG 知识库连接；留空表示未启用
}

// FaceConfig DGX 人脸/表情识别服务（InsightFace + EmotiEffLib + JoyAI）。
// 内网自签 HTTPS；密钥不需要——保护靠内网隔离与服务端 token 化调用。
type FaceConfig struct {
	Enabled bool
	BaseURL string
}

// DifyConfig Dify RAG 连接，与 MinIO 同款：密钥只保存在服务端环境变量，
// 客户端只能通过 admin 接口间接访问，永远拿不到地址与密钥。
type DifyConfig struct {
	BaseURL   string // 例如 http://10.10.1.13/v1 之外的主机根地址（不含 /v1）
	DatasetID string // 聊天检索默认知识库；留空则仅允许管理端代理浏览
	APIKey    string
}

// AssessmentAgentConfig points at the isolated AsLive speech runtime. Native
// clients use the authenticated Kangxiaoban proxy instead of this address.
type AssessmentAgentConfig struct {
	WebSocketURL string
	ProxyToken   string
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
			RAG: DifyConfig{
				BaseURL:   env("KXB_DIFY_BASE_URL", ""),
				DatasetID: env("KXB_DIFY_DATASET_ID", ""),
				APIKey:    os.Getenv("KXB_DIFY_API_KEY"),
			},
		},
		Face: FaceConfig{
			Enabled: env("KXB_FACE_ENABLED", "true") == "true",
			BaseURL: env("KXB_FACE_SERVICE_URL", "https://10.10.1.1:8088"),
		},
		Sandbox: SandboxConfig{
			Enabled:  env("KXB_SANDBOX_ENABLED", "false") == "true",
			Domain:   env("KXB_SANDBOX_DOMAIN", "127.0.0.1:18081"),
			Protocol: env("KXB_SANDBOX_PROTOCOL", "http"),
			APIKey:   os.Getenv("KXB_SANDBOX_API_KEY"),
			Image:    env("KXB_SANDBOX_IMAGE", "python:3.12-slim"),
		},
		AssessmentAgent: AssessmentAgentConfig{
			WebSocketURL: env("KXB_ASSESSMENT_AGENT_WS_URL", "ws://10.10.1.11:8000/assessment-ws"),
			ProxyToken:   os.Getenv("KXB_ASSESSMENT_AGENT_TOKEN"),
		},
		Stream: StreamConfig{
			Enabled:    env("KXB_STREAM_ENABLED", "true") == "true",
			FfmpegPath: env("KXB_FFMPEG_PATH", ""),
			Dir:        env("KXB_STREAM_DIR", "streams"),
			TokenTTL:   time.Duration(envInt("KXB_STREAM_TOKEN_TTL_SECONDS", 7200)) * time.Second,
			IdleTTL:    time.Duration(envInt("KXB_STREAM_IDLE_TTL_SECONDS", 120)) * time.Second,
		},
		Storage: StorageConfig{
			Endpoint:  env("KXB_MINIO_ENDPOINT", ""),
			AccessKey: env("KXB_MINIO_ACCESS_KEY", ""),
			SecretKey: os.Getenv("KXB_MINIO_SECRET_KEY"),
			Secure:    env("KXB_MINIO_SECURE", "false") == "true",
			Region:    env("KXB_MINIO_REGION", ""),
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
