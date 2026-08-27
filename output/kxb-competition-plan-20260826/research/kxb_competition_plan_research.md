# 研究快照：KangxiaobanAI 比赛方案素材（本地扫描）

日期：2026-08-26。信息源：本地工作区扫描，非网络检索。

## 1. KangxiaobanAI（主产品，D:\Coding\KangxiaobanAI_OC\KangxiaobanAI）

- HarmonyOS NEXT 原生 App，bundleName `com.gxoc.kxbai`，deviceTypes: phone/tablet/2in1，API 24（AGENTS.md 基线）。
- 模块 `kanxiaoban`，Ability `KanxiaobanAbility`，无权限声明（未声明 INTERNET）。
- 页面清单（products/entry/src/main/ets/）：
  - pages/：LoginPage、MainPage、AiChatPage（1676 行）、HealthExpandPage、ResidentDetailPage、MineDetailPage
  - component/wide/：WideDoctorWorkspace、WideDoctorAdmission（1797 行）、WideCaregiverWorkspace、WideAdminWorkspace、WideHomePage、WideResidentPage、WideMessagePage
  - component/：DeviceListCard、HealthListCard、EventListCard、ResidentSummaryCard、PhoneMessageChatPage、AiTitleLabel、CollapsibleSectionCard
- 关键现状：
  - AiChatPage：本地确定性回复（定时器）+ Preference 历史存储（AppStorageV2），预设 prompt 含"当班护理工作计划"。无真实模型接入。
  - WideDoctorAdmission：已实现"入住初筛"多维度评估（0-4 分级：完好/轻度/中度/重度/完全丧失）、AdmissionCarePlan 计划结构、CarePlanSuggestion 建议、recommendedPlanId 推荐计划、planConsentConfirmed 知情确认。即"评估→建议→计划选择"UI 骨架完整。
  - 全部数据为本地 mock。无网络层、无真实后端、无签名配置。

## 2. MTQQ（毫米波雷达资料库，D:\Coding\KangxiaobanAI_OC\MTQQ）

- 设备：海凌科 60GHz 毫米波雷达。
  - R60ABD1（睡眠呼吸心率雷达，装卧室）：breathValue 0~40 次/min（正常 10~25）、heartRateValue 60~120 次/min、sleepStatus（深睡/浅睡/清醒/离床）、sleepScore、呼吸暂停次数、breathWave/heartRateWave 波形（5 字节/s）等约 40 个 MQTT 属性。
  - R60AFD1（跌倒检测雷达，装卫生间）：fallStatus（0/1）、fallPosition {x,y}、fallSensitivity 0~3、fallDuration、residentStatus 静止驻留、humanDistance。
- MQTT 协议：topic `/Radar60SP/{设备ID}/sys/property/post`（睡眠）与 `/Radar60FL/{设备ID}/sys/property/post`（跌倒）；set 命令下发 sceneMode（卧室=2 卫生间=3 客厅=1）与 installHeight。
- 已有代码：mqtt_bridge_demo.py（设备→房间路由 Demo）、monitor_fall.py、monitor_sleep.py（paho-mqtt 订阅打印）、room_device_map.json、养老院房间映射表.csv、init_commands.txt。
- 部署架构（README 明确）：雷达 → EMQX Broker（docker，1883/18083）→ 后端订阅路由 → 前端按房间展示。README 点名 KangxiaobanAI 可用 `@ohos.net.webSocket` 接入，mock 字段名与雷达协议完全同名。
- 注意：数值字段为字符串传输需转换；高频属性可 limit_set 屏蔽；内网测试 Broker 192.168.100.110。

## 3. hermes（AI 对话客户端参考，D:\Coding\KangxiaobanAI_OC\hermes）

- Hermes Studio 的 HarmonyOS 原生移植：ArkUI V2 + HDS、phone/tablet/2in1。
- 已实现 Repository 边界的真实 HTTP 集成：密码登录、会话列表加载、分页消息、`POST /api/chat-run/runs` 非流式桥接。Socket.IO 流式为 Planned。
- 安全模式可参考：token 仅进程内存，不落盘；HTTP 明文仅限可信局域网并在 UI 显式警告。
- 依赖方向：Entry shell → feature page → store/viewmodel → use case → repository interface → fake/HTTP data source。KangxiaobanAI 接真实 AI 时照此模式。

## 4. 工作区基线（AGENTS.md）

- 产品定位：HarmonyOS NEXT 智慧养老工作台，服务照护者 + 宽屏医生/管理员工作区；医生角色是养老照护与评估角色。
- 完成度标签体系：Implemented / Build-verified / Device-verified / Service-verified / Planned。比赛文档沿用此体系。

## 5. 外部知识（模型与公开数据集，写作时以模型官方发布为准）

- VL 模型候选：Qwen2.5-VL（Apache 2.0 开源，3B/7B/72B，支持图像+视频理解、中文强）、InternVL2.5、MiniCPM-V 2.6（端侧友好）。
- 公开数据集：NTU RGB+D 60/120（动作识别基准）、UR Fall Detection（RGB+深度，跌倒）、Le2i Fall（模拟房间跌倒）、Toyota Smarthome（老年人家庭日常活动，越域协议）、MultiMoDA（多模态跌倒：深度+毫米波+红外）。
- 合规：个人信息保护法、数据安全法、GB/T 35273-2020 个人信息安全规范；养老机构视频监控知情同意与最小必要原则。
