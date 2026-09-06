package main

import (
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"

	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/database"
	"kangxiaoban-service/internal/iot"
	"kangxiaoban-service/internal/repository"
	"kangxiaoban-service/internal/router"
	"kangxiaoban-service/internal/service"
	"kangxiaoban-service/internal/system"
	"kangxiaoban-service/internal/ws"
)

func main() {
	cfg := config.Load()

	// 监控页部署信息真实化：版本取构建注入值（可被 KXB_APP_VERSION 覆盖）；
	// 部署模式优先取 KXB_DEPLOY_MODE 显式值（production/dev/demo），否则跟随 Gin 运行模式。
	if value := os.Getenv("KXB_APP_VERSION"); value != "" {
		system.AppVersion = value
	}
	if value := os.Getenv("KXB_DEPLOY_MODE"); value != "" {
		system.SetDeployMode(value)
	} else {
		system.SetDeployMode(gin.Mode())
	}

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
		scheduleSvc, financeSvc, medicationSvc, auditSvc, auditRepo, supplySvc, careSvc, admissionSvc, notificationSvc, messageSvc, aiSvc)

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
