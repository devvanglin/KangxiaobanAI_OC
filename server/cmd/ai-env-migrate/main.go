// ai-env-migrate 是一次性迁移工具：把数据库 ai_connections 行中保存的
// 模型服务（NewAPI/vLLM）与 Dify RAG 连接（含 AES 加密密钥的解密值）写入
// 目标 .env 文件，使连接配置改为与 MinIO 相同的服务端环境变量持有方式。
//
// 密钥全程不打印、不写日志；输出只包含「变量名已写入（长度 N）」式掩码确认。
// 运行示例（服务器部署目录下）：
//
//	KXB_AI_CONFIG_KEY=... ./ai-env-migrate -db /data/kangxiaoban.db -env .env
//
// 幂等：重复运行会原位更新同名变量，其余行与注释保持不变。
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/glebarez/sqlite"
	godotenv "github.com/joho/godotenv"
	"gorm.io/gorm"

	"kangxiaoban-service/internal/security"
)

type connectionRow struct {
	Provider           string
	BaseURL            sql.NullString
	APIKeyEncrypted    sql.NullString
	RAGEnabled         bool
	RAGBaseURL         sql.NullString
	RAGDatasetID       sql.NullString
	RAGAPIKeyEncrypted sql.NullString
}

func main() {
	dbPath := flag.String("db", "kangxiaoban.db", "SQLite 数据库路径")
	envPath := flag.String("env", ".env", "目标 .env 文件路径")
	flag.Parse()

	// 允许解密密钥直接写在同目录 .env 中；已导出的环境变量优先，不被覆盖。
	_ = godotenv.Load(*envPath)
	configKey := strings.TrimSpace(os.Getenv("KXB_AI_CONFIG_KEY"))
	if configKey == "" {
		configKey = strings.TrimSpace(os.Getenv("KXB_JWT_SECRET"))
	}
	if configKey == "" {
		fail("缺少解密密钥：请通过环境变量注入 KXB_AI_CONFIG_KEY")
	}

	gormDB, err := gorm.Open(sqlite.Open(*dbPath), &gorm.Config{})
	if err != nil {
		fail("打开数据库失败: %v", err)
	}
	var row connectionRow
	result := gormDB.Raw(
		`SELECT provider, base_url, api_key_encrypted, rag_enabled, rag_base_url, rag_dataset_id, rag_api_key_encrypted
		 FROM ai_connections ORDER BY id ASC LIMIT 1`).Scan(&row)
	if result.Error != nil {
		fail("读取 ai_connections 失败: %v", result.Error)
	}
	if row.Provider == "" && row.BaseURL.String == "" && row.RAGBaseURL.String == "" {
		fmt.Println("ai_connections 无已保存连接，未做任何修改")
		return
	}

	targets := map[string]string{}
	targets["KXB_AI_PROVIDER"] = strings.TrimSpace(row.Provider)
	targets["KXB_AI_BASE_URL"] = strings.TrimSpace(row.BaseURL.String)
	if apiKey, err := security.Decrypt(configKey, row.APIKeyEncrypted.String); err == nil {
		targets["KXB_AI_API_KEY"] = strings.TrimSpace(apiKey)
	} else if row.APIKeyEncrypted.String != "" {
		fmt.Println("警告: 模型服务密钥解密失败，已跳过 KXB_AI_API_KEY（请人工核对）")
	}
	if row.RAGEnabled {
		targets["KXB_DIFY_BASE_URL"] = strings.TrimSpace(row.RAGBaseURL.String)
		targets["KXB_DIFY_DATASET_ID"] = strings.TrimSpace(row.RAGDatasetID.String)
		if ragKey, err := security.Decrypt(configKey, row.RAGAPIKeyEncrypted.String); err == nil {
			targets["KXB_DIFY_API_KEY"] = strings.TrimSpace(ragKey)
		} else if row.RAGAPIKeyEncrypted.String != "" {
			fmt.Println("警告: Dify 密钥解密失败，已跳过 KXB_DIFY_API_KEY（请人工核对）")
		}
	}

	if err := upsertEnv(*envPath, targets); err != nil {
		fail("写入 %s 失败: %v", *envPath, err)
	}
}

// upsertEnv 原位替换同名变量、追加缺失变量；空值跳过。
func upsertEnv(envPath string, targets map[string]string) error {
	raw, err := os.ReadFile(envPath)
	if err != nil {
		if !os.IsNotExist(err) {
			return err
		}
		raw = nil
	}
	lines := strings.Split(string(raw), "\n")
	// 与 godotenv 同语义的既有键集合（注释行忽略）。
	existing := map[string]int{}
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		if idx := strings.Index(trimmed, "="); idx > 0 {
			key := strings.TrimSpace(trimmed[:idx])
			if _, seen := existing[key]; !seen {
				existing[key] = i
			}
		}
	}
	var appended []string
	for key, value := range targets {
		if value == "" {
			fmt.Printf("%s 源值为空，跳过\n", key)
			continue
		}
		if idx, ok := existing[key]; ok {
			lines[idx] = key + "=" + value
		} else {
			appended = append(appended, key+"="+value)
		}
		fmt.Printf("%s 已写入（长度 %d）\n", key, len(value))
	}
	if len(appended) > 0 {
		if len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) != "" {
			lines = append(lines, "")
		}
		lines = append(lines, appended...)
	}
	output := strings.Join(lines, "\n")
	if !strings.HasSuffix(output, "\n") {
		output += "\n"
	}
	return os.WriteFile(envPath, []byte(output), 0o600)
}

func fail(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ai-env-migrate: "+format+"\n", args...)
	os.Exit(1)
}
