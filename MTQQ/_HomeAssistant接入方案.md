# 60G 毫米波雷达接入 Home Assistant 落地方案

> 适用设备:R60ABD1(睡眠监护)、R60AFD1(跌倒检测),WiFi + MQTT 版本
> 场景定位:养老看护(康小伴 / 居家养老)
> 方案版本:v1.0,2026-08-16
> 关联资料:同目录《_使用手册.md》

---

## 0. 方案结论(TL;DR)

**纯 MQTT 直连,不刷固件、不加硬件。** 设备自带 WiFi 模组 + 标准 MQTT/JSON 协议,Home Assistant 原生 MQTT 集成即可解析。核心工作量 = 写一份 YAML 配置 + 两条自动化。

- 消息链路:雷达 → MQTT Broker → Home Assistant → 手机通知/音箱/自动化
- Broker 选型:Mosquitto(HA 官方 add-on,最省事),备选 EMQX
- 实体产出:存在感应、入床离床、呼吸/心率数值、睡眠状态、跌倒报警等 20+ 实体

---

## 1. 目标与范围

| 项 | 内容 |
|---|---|
| 目标 | 把两个雷达的监测数据接入 HA,实现可视化 + 异常告警自动化 |
| 覆盖 | R60ABD1 睡眠数据、R60AFD1 跌倒数据 |
| 不覆盖 | 数据上云、微信小程序(后续可扩展)、算法定制 |
| 前置条件 | 已有一台跑 HA 的主机(Raspberry Pi / NUC / 软路由 / 群晖均可)、一个内网环境 |

---

## 2. 总体架构

```
┌─────────────┐   MQTT(JSON)   ┌──────────────┐   MQTT订阅    ┌───────────────┐
│ R60ABD1 睡眠 │ ─────────────► │              │ ────────────► │  Home         │
│ (WiFi 模组)  │                │  MQTT Broker │               │  Assistant    │
└─────────────┘                │  (Mosquitto) │               │  (MQTT集成)   │
┌─────────────┐   MQTT(JSON)   │  tcp://IP:1883│               │               │
│ R60AFD1 跌倒 │ ─────────────► │              │               │  ┌─────────┐  │
│ (WiFi 模组)  │                └──────────────┘               │  │ 自动化   │  │
└─────────────┘                                               │  │ 告警     │  │
                                                              │  └────┬────┘  │
                                                              └───────┼───────┘
                                                                      ▼
                                                       手机App / 智能音箱 / 微信推送
```

**关键点**:雷达、Broker、HA 必须在同一网络可互达;雷达配网时填的 broker 地址就是上图这个 broker。

---

## 3. 选型决策

### 3.1 接入路径选型

| 路径 | 说明 | 结论 |
|---|---|---|
| A. 纯 MQTT 直连 | 设备自带 WiFi+MQTT,HA 原生解析 | ✅ **采用** |
| B. ESPHome+UART | 裸 UART 模块才需要,需加 ESP32C6 | ❌ 不适用(你的设备带 WiFi) |
| C. Node-RED 桥接 | 消息需复杂加工才需要 | ⏸ 仅数组字段拆分时可选 |

### 3.2 Broker 选型

| Broker | 优点 | 缺点 | 结论 |
|---|---|---|---|
| **Mosquitto** | HA 官方 add-on,一键装,轻量 | 集群弱 | ✅ 首选 |
| EMQX | 功能强,可视化后台 | 资源占用高,自建麻烦 | 备选 |

> 文档默认的 `tcp://broker.emqx.io:1883` 是公共测试 broker,生产**必须替换为自建 broker**。

---

## 4. 分阶段实施

### Phase 1:部署 MQTT Broker(10 分钟)

HA 用户最省事路径:

1. HA 界面 → 设置 → 加载项 → 加载项商店 → 搜索 **Mosquitto broker** → 安装
2. 配置里设置用户名/密码(雷达配网时要填)
3. 启动,确认监听 `1883` 端口
4. 记下 HA 主机内网 IP(如 `192.168.1.100`)

### Phase 2:雷达配网(每台 5 分钟)

按《雷达设备静态IP配网教程》操作,注意两个关键填写:

1. **MQTT 配置页**(长按 10s 起 AP → 192.168.0.1):
   - 服务器地址:`tcp://192.168.1.100:1883`(改成你的 HA 主机 IP,不是公共 broker)
   - clientID / 用户名 / 密码:填 Mosquitto 里设置的那套
2. **WiFi 配网**(长按 5s 起 BLE):连 2.4G 内网 WiFi(和 HA 同一网段)

### Phase 3:HA 接入 MQTT(5 分钟)

1. HA → 设置 → 设备与服务 → 添加集成 → **MQTT**
2. 填 broker 地址、端口 1883、用户名/密码(同 Phase 1)
3. 确认连接成功

### Phase 4:配置实体(粘贴模板)

见第 5 节,把 YAML 粘贴到 `configuration.yaml`,重启 HA 或重载 YAML。

### Phase 5:配置自动化

见第 6 节。

---

## 5. 配置模板(核心)

> 放到 `configuration.yaml`。注意:`mqtt:` 节点如果已通过 UI 添加集成,只需保留 `sensor:` / `binary_sensor:` 部分,不要重复写 `broker`。

### 5.1 R60ABD1 睡眠雷达(前缀 `/Radar60SP/`)

```yaml
mqtt:
  sensor:
    # ---- 人体与运动 ----
    - name: "睡眠雷达_人体距离"
      unique_id: r60abd1_distance
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.humanDistance }}"
      unit_of_measurement: "cm"
      state_class: measurement
    - name: "睡眠雷达_体动幅度"
      unique_id: r60abd1_movement
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.movementSigns }}"
      state_class: measurement
    - name: "睡眠雷达_运动状态"
      unique_id: r60abd1_motion
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.motionStatus }}"

    # ---- 呼吸 ----
    - name: "睡眠雷达_呼吸数值"
      unique_id: r60abd1_breath
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.breathValue }}"
      unit_of_measurement: "次/分"
      state_class: measurement

    # ---- 心率 ----
    - name: "睡眠雷达_心率"
      unique_id: r60abd1_heart
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.heartRateValue }}"
      unit_of_measurement: "次/分"
      state_class: measurement

    # ---- 睡眠 ----
    - name: "睡眠雷达_睡眠状态"
      unique_id: r60abd1_sleep
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.sleepStatus }}"
    - name: "睡眠雷达_睡眠评分"
      unique_id: r60abd1_score
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.sleepScore }}"
      state_class: measurement
    - name: "睡眠雷达_清醒时长"
      unique_id: r60abd1_awake
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.awakeDuration }}"
      unit_of_measurement: "分钟"
      state_class: measurement

  binary_sensor:
    - name: "睡眠雷达_有人"
      unique_id: r60abd1_presence
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.someoneExists }}"
      payload_on: "1"
      payload_off: "0"
      device_class: occupancy
    - name: "睡眠雷达_已上床"
      unique_id: r60abd1_inbed
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.getIntoBed }}"
      payload_on: "1"
      payload_off: "0"
    - name: "睡眠雷达_在线"
      unique_id: r60abd1_online
      state_topic: "/Radar60SP/+/sys/property/post"
      value_template: "{{ value_json.params.online }}"
      payload_on: "1"
      payload_off: "0"
      device_class: connectivity
```

### 5.2 R60AFD1 跌倒雷达(前缀 `/Radar60FL/`)

```yaml
mqtt:
  sensor:
    - name: "跌倒雷达_跌倒位置X"
      unique_id: r60afd1_fallx
      state_topic: "/Radar60FL/+/sys/property/post"
      value_template: "{{ value_json.params.fallPosition.x }}"
      unit_of_measurement: "cm"

  binary_sensor:
    - name: "跌倒雷达_跌倒报警"
      unique_id: r60afd1_fall
      state_topic: "/Radar60FL/+/sys/property/post"
      value_template: "{{ value_json.params.fallStatus }}"
      payload_on: "1"
      payload_off: "0"
      device_class: safety
    - name: "跌倒雷达_静止驻留"
      unique_id: r60afd1_resident
      state_topic: "/Radar60FL/+/sys/property/post"
      value_template: "{{ value_json.params.residentStatus }}"
      payload_on: "1"
      payload_off: "0"
    - name: "跌倒雷达_有人"
      unique_id: r60afd1_presence
      state_topic: "/Radar60FL/+/sys/property/post"
      value_template: "{{ value_json.params.someoneExists }}"
      payload_on: "1"
      payload_off: "0"
      device_class: occupancy
```

> 通配符 `+` 订阅所有设备。若只有单台,可把 `+` 换成具体设备 ID 以隔离多设备。

---

## 6. 告警自动化

### 6.1 跌倒报警(最高优先级)

```yaml
automation:
  - alias: "跌倒立即报警"
    trigger:
      - platform: state
        entity_id: binary_sensor.r60afd1_fall
        to: "on"
    action:
      - service: notify.mobile_app_你的手机
        data:
          title: "⚠️ 跌倒告警"
          message: "检测到跌倒,请立即查看!"
      - service: media_player.play_media
        data:
          entity_id: media_player.智能音箱
          media_content_id: "语音警报"
          media_content_type: "music"
    mode: single
```

### 6.2 离床超时提醒(夜间久离床)

```yaml
automation:
  - alias: "夜间离床超时提醒"
    trigger:
      - platform: state
        entity_id: binary_sensor.r60abd1_inbed
        to: "off"
        for: "00:10:00"
    condition:
      - condition: time
        after: "22:00:00"
        before: "06:00:00"
    action:
      - service: notify.mobile_app_你的手机
        data:
          title: "离床提醒"
          message: "老人已离床超过 10 分钟"
```

### 6.3 呼吸异常告警

```yaml
automation:
  - alias: "呼吸异常告警"
    trigger:
      - platform: numeric_state
        entity_id: sensor.r60abd1_breath
        above: 25
      - platform: numeric_state
        entity_id: sensor.r60abd1_breath
        below: 10
    action:
      - service: notify.mobile_app_你的手机
        data:
          title: "呼吸异常"
          message: "当前呼吸频率 {{ states('sensor.r60abd1_breath') }} 次/分"
```

---

## 7. 验证清单

| # | 验证项 | 通过标准 |
|---|---|---|
| 1 | Broker 连接 | HA 的 MQTT 集成显示"已连接" |
| 2 | 雷达上线 | 用 MQTT 客户端订阅 `/Radar60SP/#` 能看到 `online:"1"` |
| 3 | 实体生成 | HA 设置→设备与服务→实体 里出现 `r60abd1_*` |
| 4 | 有人感应 | 人进出房间,`有人` 实体 0/1 变化 |
| 5 | 跌倒告警 | 触发跌倒,手机收到通知 |
| 6 | 历史记录 | 呼吸/心率实体有曲线 |

---

## 8. 注意事项(必读)

1. **数值是字符串**:雷达报 `"1"` 不是 `1`,binary_sensor 必须写 `payload_on: "1"`,不能漏引号。
2. **Topic 前导斜杠不能丢**:是 `/Radar60SP/...` 不是 `Radar60SP/...`。
3. **单属性单消息**:状态变化上报一条消息只带一个字段,`value_template` 抠不到字段返回 null,HA 自动忽略、保持上次值,安全。
4. **查询响应混入无影响**:上报 topic 同时承载查询响应,但都有 `params` 字段,模板兼容。
5. **数组字段需特殊处理**:`breathWave`/`heartRateWave`/`sleepComprehensiveStatus` 是数组,HA 原生 sensor 存不了,需 Node-RED 拆包或忽略(主线方案不含,按需扩展)。
6. **公共 broker 仅测试**:生产必须自建,否则数据走公网、断连不可控。
7. **WiFi 仅 2.4G**:配网路由器必须 2.4G 频段。
8. **隐私合规**:雷达采集的是生理数据,部署到老人房间前需明确告知(详见《_使用手册.md》伦理部分)。

---

## 9. 后续扩展

| 方向 | 说明 |
|---|---|
| 接入 KangxiaobanAI | 把 MQTT 字段映射为 ArkTS DTO,替换主产品 mock 数据,实现护工端真实数据 |
| 微信推送 | 用 HA 的 WeChat/Sever酱 通知服务替换手机 App 通知 |
| 多房间扩展 | 每房一台,用具体设备 ID 区分实体 |
| 睡眠报告 | Node-RED 拆 `sleepQualityAnalysis` 12B 数据,生成日报 |

---

_方案结束。实施顺序:Phase 1 → 2 → 3 → 4 → 5,全程约 30 分钟可跑通基础链路。_
