package main

import (
	"errors"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/iot"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/router"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/ws"
)

// mountStatic 以 NoRoute 提供展示壳静态文件；目录/未命中回退 index.html。
func mountStatic(r *gin.Engine, dir string) {
	r.NoRoute(func(c *gin.Context) {
		p := filepath.Join(dir, filepath.Clean(c.Request.URL.Path))
		if info, err := os.Stat(p); err != nil || info.IsDir() {
			p = filepath.Join(dir, "index.html")
		}
		http.ServeFile(c.Writer, c.Request, p)
	})
}

func main() {
	cfg := config.Load()

	db, err := database.Connect(&cfg.Database)
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	if err := database.AutoMigrateAndSeed(db, cfg.Server.SeedBusiness); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}

	userRepo := repository.NewUserRepository(db)
	elderRepo := repository.NewElderRepository(db)
	resourceRepo := repository.NewResourceRepository(db)
	taskRepo := repository.NewTaskRepository(db)
	healthRepo := repository.NewHealthRepository(db)
	scheduleRepo := repository.NewScheduleRepository(db)
	financeRepo := repository.NewFinanceRepository(db)
	medicationRepo := repository.NewMedicationRepository(db)
	auditRepo := repository.NewAuditRepository(db)
	supplyRepo := repository.NewSupplyRepository(db)
	familyRepo := repository.NewFamilyRepository(db)
	careRepo := repository.NewCareRepository(db)
	notificationRepo := repository.NewNotificationRepository(db)
	messageRepo := repository.NewMessageRepository(db)

	hub := ws.NewHub()
	go hub.Run()

	authSvc := service.NewAuthService(userRepo, &cfg.JWT)
	elderSvc := service.NewElderService(elderRepo)
	resourceSvc := service.NewResourceService(resourceRepo)
	taskSvc := service.NewTaskService(taskRepo)
	healthSvc := service.NewHealthService(healthRepo)
	scheduleSvc := service.NewScheduleService(scheduleRepo)
	financeSvc := service.NewFinanceService(db, financeRepo, elderRepo)
	medicationSvc := service.NewMedicationService(medicationRepo)
	auditSvc := service.NewAuditService(auditRepo)
	supplySvc := service.NewSupplyService(supplyRepo)
	familySvc := service.NewFamilyService(familyRepo, db)
	careSvc := service.NewCareService(careRepo)
	admissionSvc := service.NewAdmissionService(db, hub)
	notificationSvc := service.NewNotificationService(notificationRepo)
	messageSvc := service.NewMessageService(messageRepo)
	aiSvc := service.NewAIService(&cfg.AI, db)

	iotSvc := iot.NewIotService(db, hub)
	iotSvc.SetTenantNotifier(notificationSvc.CreateRoleNotificationContext)
	if cfg.MQTT.Enable {
		go iotSvc.StartMQTT(cfg.MQTT)
	}
	go iotSvc.StartOfflineScanner()
	go iotSvc.StartEscalationScanner()

	r := router.New(db, cfg, hub, iotSvc, userRepo, authSvc, elderSvc, resourceSvc, taskSvc, healthSvc,
		scheduleSvc, financeSvc, medicationSvc, auditSvc, auditRepo, supplySvc, familySvc, careSvc, admissionSvc, notificationSvc, messageSvc, aiSvc)

	// 展示壳静态托管：落地页(/)与大屏(/dashboard.html)（API 路由优先，未匹配路径回落到静态）
	if cfg.Server.StaticDir != "" {
		mountStatic(r, cfg.Server.StaticDir)
	}

	log.Printf("Kangxiaoban 后端服务启动: http://0.0.0.0:%s (db=%s)", cfg.Server.Port, cfg.Database.Driver)
	server := &http.Server{
		Addr:              ":" + cfg.Server.Port,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       35 * time.Second,
		WriteTimeout:      35 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("服务启动失败: %v", err)
	}
}
