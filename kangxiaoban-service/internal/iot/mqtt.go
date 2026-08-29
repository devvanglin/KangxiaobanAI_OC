package iot

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"kangxiaoban-service/internal/config"
	"kangxiaoban-service/internal/model"
)

// StartMQTT 连接 Broker 并订阅睡眠/跌倒雷达 topic（自动重连；失败仅记日志不阻塞服务）。
func (s *IotService) StartMQTT(cfg config.MQTTConfig) {
	opts := mqtt.NewClientOptions().
		SetClientID(cfg.ClientID).
		AddBroker(cfg.URL).
		SetAutoReconnect(true).
		SetConnectRetry(true).
		SetConnectRetryInterval(3 * time.Second).
		SetOnConnectHandler(func(c mqtt.Client) {
			log.Printf("[MQTT] connected to %s, subscribing...", cfg.URL)
			c.Subscribe(cfg.TopicSP, 0, nil)
			c.Subscribe(cfg.TopicFL, 0, nil)
		})
	if cfg.Username != "" {
		opts.SetUsername(cfg.Username)
		opts.SetPassword(cfg.Password)
	}
	client := mqtt.NewClient(opts)
	handler := func(_ mqtt.Client, msg mqtt.Message) {
		s.onMQTTMessage(msg.Topic(), msg.Payload())
	}
	client.AddRoute(cfg.TopicSP, handler)
	client.AddRoute(cfg.TopicFL, handler)

	if token := client.Connect(); token.Wait() && token.Error() != nil {
		log.Printf("[MQTT] connect failed (will retry): %v", token.Error())
	}
}

func (s *IotService) onMQTTMessage(topic string, payload []byte) {
	// topic 形如 /Radar60SP/{deviceId}/sys/property/post
	parts := strings.Split(topic, "/")
	var deviceID, product string
	if len(parts) >= 3 {
		deviceID = parts[2]
		switch parts[1] {
		case "Radar60SP":
			product = "breath_radar"
		case "Radar60FL":
			product = "fall_radar"
		}
	}
	if deviceID == "" {
		return
	}
	var raw map[string]interface{}
	if err := json.Unmarshal(payload, &raw); err != nil {
		log.Printf("[MQTT] bad payload from %s: %v", deviceID, err)
		return
	}
	values := extractFields(raw)
	if err := s.IngestContext(s.contextForDevice(deviceID), deviceID, product, values); err != nil {
		log.Printf("[IoT] ingest %s failed: %v", deviceID, err)
	}
}

// extractFields 从雷达消息中提取字段：取 data/params 对象 + 顶层非对象字段。
func extractFields(raw map[string]interface{}) map[string]interface{} {
	out := map[string]interface{}{}
	absorb := func(m map[string]interface{}) {
		for k, v := range m {
			out[k] = v
		}
	}
	if d, ok := raw["data"].(map[string]interface{}); ok {
		absorb(d)
	}
	if p, ok := raw["params"].(map[string]interface{}); ok {
		absorb(p)
	}
	for k, v := range raw {
		switch v.(type) {
		case map[string]interface{}:
			continue
		case []interface{}:
			continue
		}
		if _, dup := out[k]; !dup {
			out[k] = v
		}
	}
	return out
}

// StartOfflineScanner 周期检测设备离线并告警（去重）。
func (s *IotService) StartOfflineScanner() {
	ticker := time.NewTicker(30 * time.Second)
	for range ticker.C {
		now := time.Now()
		for _, tenantID := range s.tenantIDs() {
			ctx := context.WithValue(context.Background(), model.TenantContextKey, tenantID)
			db := s.db.WithContext(ctx)
			var devs []model.IotDevice
			if err := db.Where("online = 1").Find(&devs).Error; err != nil {
				continue
			}
			for _, d := range devs {
				if d.LastSeen != nil && now.Sub(*d.LastSeen) > offlineAfter {
					if err := db.Model(&d).Update("online", 0).Error; err != nil {
						continue
					}
					if s.okCooldown("offline", d.DeviceID, now) {
						s.createAlert(db, d, "offline", "info", "设备离线(超过"+offlineWindow+"无上报)", now)
					}
				}
			}
		}
	}
}

const (
	offlineAfter    = 60 * time.Second
	offlineWindow   = "60s"
	escalationAfter = 60 * time.Second
)
