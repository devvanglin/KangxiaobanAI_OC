# 康养毫米波雷达接入指南(从零开始)

> 一句话:雷达发 MQTT → 中间一个 Broker 汇聚 → 你的后端订阅 → 你的平台按房间展示数值。
> **不需要 Home Assistant。**

---

## 一、先搞清:目标与架构

**目标**:养老院每个房间装雷达(睡眠/跌倒),在自己的平台里"房间绑定设备 → 看到呼吸/心率/睡眠/跌倒数值"。

**架构**(就三个环节,缺一不可):

```
雷达(每房间)  →  MQTT Broker  →  你的后端  →  你的前端(护工端)
                 (EMQX)          (订阅+路由)    (按房间展示)
```

| 环节 | 必须? | 作用 |
|---|---|---|
| 雷达 | ✅ | 采集数据,发 MQTT |
| MQTT Broker | ✅ | 消息汇聚的"邮局",唯一不能省的中间件 |
| 你的后端 | ✅ | 订阅数据、按房间路由、推给前端 |
| Home Assistant | ❌ | 不需要,只是众多订阅者之一 |

---

## 二、准备清单

| 物料 | 说明 |
|---|---|
| 雷达设备 | R60ABD1(睡眠)装卧室、R60AFD1(跌倒)装卫生间 |
| 一台服务器 | 跑 Broker + 后端。树莓派/NUC/云服务器/你办公电脑均可 |
| 一台安卓手机 | 配网必须安卓(iPhone 不行) |
| 2.4G WiFi | 雷达只认 2.4G,5G 连不上 |

---

## 三、从零开始:7 步走完

### 第 1 步:部署 MQTT Broker

有 Docker 的机器上一条命令(推荐 EMQX,养老院设备多,并发强):

```bash
docker run -d --name emqx -p 1883:1883 -p 18083:18083 emqx/emqx
```

- 浏览器开 `http://<服务器IP>:18083` 是 EMQX 后台,默认账号 `admin / public`
- **记下两个东西**:`服务器IP`、`1883` 端口(雷达配网要填)

> 没有 Docker 就装 Mosquitto(更轻),或直接在 Windows 装 EMQX,效果一样。

### 第 2 步:雷达配网(每台 5 分钟)

雷达两种模式,**长按时间不同,别搞混**:

| 长按 | 出现 | 用途 |
|---|---|---|
| **10 秒以上** | WiFi 热点 `RadarConfig-xxxx` | 填 MQTT 服务器地址 |
| **5 秒左右** | 蓝牙 `Radar_BLE` | 连 WiFi |

**2.1 先填 MQTT 地址:**

1. 长按 **10 秒以上** → 手机连热点 `RadarConfig-xxxx`
2. 浏览器开 `192.168.0.1`
3. 填服务器地址:`tcp://<第1步的服务器IP>:1883`
4. 填 clientID / 用户名 / 密码(EMQX 后台建的,或先留默认)
5. 点「修改」→「设置完成,退出」

**2.2 再连 WiFi:**

1. 长按 **5 秒左右** → LED 灯闪烁
2. 安卓装 `BK_BLE5.apk`(把 `.apk.1` 改名为 `.apk` 再装)
3. APP 里选蓝牙 `Radar_BLE` → 选你家 2.4G WiFi → 填密码 → 配网
4. 提示 `Network configuration successful` = 成功

**2.3 抄设备 ID:**

配网时 `192.168.0.1` 页面顶部那串就是设备 ID(如 `RadarID_ABC123`)。**配一台、抄一个、立刻登记**。

### 第 3 步:登记台账(唯一真相源)

打开 `养老院房间映射表.csv`,每台设备填一行:

| 设备ID | 房间号 | 楼层 | 雷达型号 | 场景模式 | 安装高度cm | 安装角度 | 护工 |
|---|---|---|---|---|---|---|---|
| RadarID_ABC123 | 101 | 1F | R60ABD1 | 2 | 220 | 0 | 张护工 |
| RadarID_GHI789 | 101卫生间 | 1F | R60AFD1 | 3 | 220 | 0 | 张护工 |

- 场景模式:卧室=2,卫生间=3,客厅=1
- 加房间 = 加一行,**其他什么都别动**

### 第 4 步:下发场景参数(让算法匹配房间,降误报)

每台设备上线后,发一条 set 命令告诉雷达"你在卧室/卫生间、装多高"。参考 `init_commands.txt` 的清单,用 MQTT 客户端(MQTTX 或 EMQX 后台)逐条发,或让后端在设备上线时自动发:

```json
topic:   /Radar60SP/RadarID_ABC123/sys/property/set
payload: {"version":"1.0","method":"set","params":{"sceneMode":"2","installHeight":"220"}}
```

> 这步不做好,数据接进来也不准,尤其卫生间场景容易误报。

### 第 5 步:验证数据通了

跑路由 Demo,确认数据能按房间归类:

```bash
# 先看逻辑(无 broker,本地模拟)
python mqtt_bridge_demo.py --mock

# 真连你的 broker
python mqtt_bridge_demo.py --host <服务器IP>
```

看到类似输出 = 成功:

```
[101] (张三) R60ABD1 呼吸数值 = 18
[101卫生间]  R60AFD1 跌倒报警 = 1
```

### 第 6 步:写后端(订阅 + 路由 + 推送)

`mqtt_bridge_demo.py` 里的 `route()` 函数就是后端核心逻辑,生产环境在它基础上加两块:

1. **绑定表换数据库**——把 `room_device_map.json` 换成 MySQL 的 `room_device` 表(房间绑定设备就是插/删一行)
2. **推送前端**——把 `print()` 换成 WebSocket 推送

后端语言任选(Python/Node/Java/Go 都行),逻辑就三句:
```
订阅 topic → 从 topic 取设备ID → 查绑定表定位房间 → 推给前端
```

### 第 7 步:接前端

- **Web 后台**:WebSocket 订阅后端,按房间渲染
- **KangxiaobanAI(HarmonyOS)**:用 `@ohos.net.webSocket` 订阅,把 `humanDistance`/`humanPosition`/`motionStatus` 等 mock 字段换成真实推送(字段名与雷达协议**完全同名**,改起来很省)

---

## 四、文件索引(看哪些、忽略哪些)

| 文件 | 职责 | 你要不要看 |
|---|---|---|
| `README.md`(本文件) | **总入口 + 步骤** | ✅ 只看这个就够 |
| `养老院房间映射表.csv` | 台账,唯一真相源 | ✅ 唯一要维护的 |
| `mqtt_bridge_demo.py` | 数据→房间路由 Demo | ✅ 主线代码 |
| `room_device_map.json` | Demo 用绑定表 | ✅ 主线 |
| `init_commands.txt` | 场景参数命令清单 | ✅ 第 4 步用 |
| `生成HA配置.py` / `gen_ha_config.py` | 生成 HA 配置(两个重复) | ⚠️ 接 HA 才用,**可忽略** |
| `configuration_rooms.yaml` | 已生成的 HA 配置 | ⚠️ 可忽略 |
| `_使用手册.md` | 协议字段详解 | 📚 查字段时翻 |
| `_平台接入方案.md` | 平台接入详细方案 | 📚 第 6 步展开看 |
| `_HomeAssistant接入方案.md` | HA 方案 | ⚠️ 不接 HA 就忽略 |
| `_养老院多房间部署方案.md` | 养老院部署细节 | 📚 参考 |
| 5 个 PDF + APK | 厂商原始资料 | 📚 协议源头,按需查 |

---

## 五、三个最容易踩的坑

1. **设备 ID 漏登记** → 后面 `RadarID_ABC123` 到底是 101 还是 107 对不上。铁律:配一台、抄一个、立刻填 CSV。
2. **雷达连不上网** → 路由器是 5G,雷达只认 2.4G。
3. **收到数据但数值乱** → 第 4 步的场景参数(`sceneMode`/`installHeight`)没设,算法不匹配房间环境。

---

_主线就这三样:CSV 台账 + Broker + 后端路由。其余文档按需查,不用全看。_
