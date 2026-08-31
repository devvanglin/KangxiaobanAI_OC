package database

import (
	"path/filepath"
	"strings"
	"testing"

	"kangxiaoban-service/internal/config"
)

func TestConnectConfiguresSQLiteForBoundedConcurrentAccess(t *testing.T) {
	path := filepath.Join(t.TempDir(), "kxb.db")
	db, err := Connect(&config.DBConfig{Driver: "sqlite", SQLitePath: path})
	if err != nil {
		t.Fatalf("Connect() error = %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("DB() error = %v", err)
	}
	defer sqlDB.Close()

	var busyTimeout int
	if err := db.Raw("PRAGMA busy_timeout").Scan(&busyTimeout).Error; err != nil {
		t.Fatalf("read busy_timeout: %v", err)
	}
	if busyTimeout != sqliteBusyTimeout {
		t.Fatalf("busy_timeout = %d, want %d", busyTimeout, sqliteBusyTimeout)
	}
	var journalMode string
	if err := db.Raw("PRAGMA journal_mode").Scan(&journalMode).Error; err != nil {
		t.Fatalf("read journal_mode: %v", err)
	}
	if !strings.EqualFold(journalMode, "wal") {
		t.Fatalf("journal_mode = %q, want WAL", journalMode)
	}
	if stats := sqlDB.Stats(); stats.MaxOpenConnections != 1 {
		t.Fatalf("MaxOpenConnections = %d, want 1", stats.MaxOpenConnections)
	}
}

func TestConnectSupportsSharedMemorySQLite(t *testing.T) {
	db, err := Connect(&config.DBConfig{Driver: "sqlite", SQLitePath: "file:kxb_connect_test?mode=memory&cache=shared"})
	if err != nil {
		t.Fatalf("Connect() memory error = %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("DB() memory error = %v", err)
	}
	defer sqlDB.Close()
	var busyTimeout int
	if err := db.Raw("PRAGMA busy_timeout").Scan(&busyTimeout).Error; err != nil {
		t.Fatalf("read memory busy_timeout: %v", err)
	}
	if busyTimeout != sqliteBusyTimeout {
		t.Fatalf("memory busy_timeout = %d, want %d", busyTimeout, sqliteBusyTimeout)
	}
}
