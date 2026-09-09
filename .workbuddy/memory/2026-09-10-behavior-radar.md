# 2026-09-10 · 行为识别 + 毫米波设备 大任务作战记录

> 本文是重置上下文后的接续入口。任务由用户 2026-09-10 凌晨下达，跨度大、分阶段实施。
> **每完成一步：更新本文的进度清单 → git 提交 → 推送远端。**

## 任务总目标（用户原话归纳）

### A. 人脸/行为识别管线（核心）
1. GPU 服务器（10.10.1.1 或 10.10.1.2，二选一，用户忘了在哪台）上已部署 **InsightFace + EmotiEffLib + joyai**，
   有 web 页面，人脸识别、表情识别、行为识别均已实测可用。SSH：用户名 `nvidia`，密码在
   `.codex/private/fleet-ssh.json`（勿打印勿提交）。
2. **入住建档**上传的【人像照】（现有 admission-intake-photos）→ 作为 InsightFace 人脸比对底照（注册/入库）。
3. 摄像头（设备管理手动添加，RTSP）→ **绑定走廊**（区域体系已有 corridor 类型）。
4. 摄像头画面出现人 → 三模型分析：InsightFace 认人（比对注册底照）+ EmotiEffLib 表情 + joyai 行为；
   **人脸要裁切**出脸部小图。
5. 表情再用 **NewAPI 里的 qwen 视觉模型复审**一次（最终表情以复审为准，记录两个来源）。
6. 结果写入【长者】→【行为】页：谁、什么行为、什么表情、裁切脸图、**视频回放**（存 MinIO
   `cctv-footage-storage` 桶），**带时间条，类似监控回放**。

### B. 毫米波雷达（EMQX 自动接入）
1. 设备管理【添加设备】**只允许手动添加摄像头**（毫米波从 UI 手动添加入口中移除）。
2. 毫米波雷达通过 **EMQX** 网关自动上报 → 自动注册进设备列表（参考 MTQQ/ 目录协议：
   `/Radar60SP/+/sys/property/post` 睡眠/呼吸心率，`/Radar60FL/+/sys/property/post` 跌倒）。
3. 自动注册的雷达要能**手动指定类型**：呼吸心率检测设备 或 防跌倒检测设备。
4. 雷达可**分配到房间**；房间被长者入住后 → 该雷达成为长者的设备，显示在【长者】→【设备】。
5. 雷达数据落到【长者】对应位置：呼吸心率 → 体征/健康记录；跌倒 → 告警。

## 环境事实（已核实）
- 后端 Go：`kangxiaoban-service`，部署 10.10.1.12 docker（compose 目录
  `/opt/kangxiaoban/kangxiaoban-service`，SSH api@…见 `.codex/private/backend-ssh.json`）。
  部署脚本模式：上传 linux 二进制到 ~ → 备份旧二进制(.bak-<purpose>-<ts>) → install → docker build → compose up -d。
- 前端 ArkTS：`KangxiaobanAI/products/entry`（V2 + HDS），构建：
  DEVECO_SDK_HOME=DevEco sdk + jbr JAVA_HOME，hvigorw assembleHap（debug）。
- MinIO：`10.10.1.13:9000`（.env KXB_MINIO_*；2026-09-10 凌晨曾挂过一次被用户修复；
  新桶需求：`cctv-footage-storage`，可能需要创建）。
- NewAPI：10.10.1.12:3030（OpenAI 兼容，qwen 视觉模型已在模型列表：Qwen3-VL-4B-Instruct 曾用于对话冒烟）。
- 设备/告警后端：`internal/iot`（MQTT 订阅已存在：cfg.TopicSP=`/Radar60SP/+/sys/property/post`、
  TopicFL=`/Radar60FL/+/sys/property/post`；`iot.ingest` HTTP 上报；设备离线扫描/告警升级协程）。
- 入住照片：`admission_intakes` + `admission_intake_photos`，私有目录存储，有 `GET /admission-intake-photos/:id/content`。
- 区域：`areas` 表含 corridor 等类型， WideAreaManagement 有 2D 摆位。
- 【长者】详情页：`WideResidentPage`（护工）/`WideDoctorResidentPage`（医师），tab 结构里已有健康/风险等。
- 服务器 .env 有历史遗留坏行（第 29 行附近游离 token，是 KXB_SANDBOX_API_KEY 值被截断），别用 godotenv
  严格解析它；沙箱现在管理端 UI 可配置（ai_sandbox_settings，DB 优先 env 回退）。

## 侦察结论（2026-09-10 凌晨，已核实）

### AI 服务全在 10.10.1.1（spark-998d，DGX Spark，SSH nvidia@）
- **FaceCare Console 人脸/表情服务：`http://10.10.1.1:8088`**（FastAPI，0.0.0.0:8088）
  - `GET /health`；`GET /` 人脸登记/识别 UI（face_ui.html）
  - `POST /enroll` `{"person_id":"resident-001","image":"data:image/jpeg;base64,..."}` → 只存特征向量
    （person_id 约定用 `elder-<ID>`；特征库 `data/face_registry.json`）
  - `POST /recognize` `{"image":"data:image/jpeg;base64,..."}` → 人脸框、身份余弦相似度
    （阈值 0.45，未过阈值 known=false）、EmotiEffLib 表情标签+分数
  - `POST /behavior` → 转发图像给 JoyAI-VL，返回老人行为+场景描述（看护摄像头人设）
  - `POST /session/reset`
  - 组件：InsightFace buffalo_l(SCRFD+w600k_r50 ArcFace) CUDA、EmotiEffLib enet_b0_8_best_vgaf CUDA
  - 服务目录 `/home/nvidia/JoyAI-VL-Interaction/face_identity_emotion/`（face_service.py + start.sh，
    systemd --user 单元 face-identity-emotion.service）
- **vLLM：`http://10.10.1.1:8065`**（OpenAI 兼容 /v1/chat/completions，跑 Qwen3-VL-4B-Instruct，
  本地模型库 ~/models）；NewAPI(10.10.1.12:3030) 也聚合了视觉模型，qwen 复审走 NewAPI 即可。
- 8070 另有 python 服务（未确认用途）；JoyAI-VL-Interaction 仓库在 ~/JoyAI-VL-Interaction
  （services/{asr,tts,webinfer,webui,background-agent}，jdopensource/JoyAI-VL-Interaction 项目，
  行为识别走 /behavior 转发即可，不用直接碰）。
- 参考测试素材：~/elderly-video-test/elderly-fashion.webm。

### 视频方案决定
- Go 后端跑在 FROM scratch 容器里没有 ffmpeg → 在服务器放一个**静态 ffmpeg**，compose 挂载进容器并设
  `KXB_FFMPEG_PATH=/usr/local/bin/ffmpeg`；事件触发时 `ffmpeg -t 8 -i rtsp://... ` 切 8 秒 mp4
  传 MinIO `cxtv→cctv-footage-storage` 桶（注意桶名拼写 cctv-footage-storage）；后续可升级环形分段。
- 人脸裁切：/recognize 返回人脸框 → Go 侧裁 JPEG → 传 MinIO 同桶 `faces/` 前缀。

### FaceCare API 精确契约（已读源码核实；HTTPS 自签证书，Go 客户端须 InsecureSkipVerify）
- `POST /enroll` `{person_id, image:"data:image/jpeg;base64,.."}` → `{ok,person_id,faces:1}`；
  **必须恰好 1 张脸**否则 400；**embeddings 被整体替换**（一人一模板，重复 enroll=覆盖）。
- `POST /recognize` `{image}` → `{ok, faces:[{person_id|null, known, similarity, bbox:[x1,y1,x2,y2], emotion:{label..}}]}`
  （emotion 为 EmotiEffLib 英文标签，服务内有 EMOTION_NAMES 英→中映射；bbox 可直接用于裁脸）。
- `POST /behavior` `{image}` → 内部自带身份+表情识别并喂给 JoyAI adapter（127.0.0.1:7060 主模型
  jdopensource/JoyAI-VL-Interaction；8070=live_adapter；8065=vLLM Qwen3-VL 摘要）
  → `{ok, behavior:"<文字>", people:[...], model, timing, session_id, stateless}`。
- `POST /track` `{image}` → 仅人脸框+身份（低延迟）。
- `/rtsp/start {url:rtsp://..}`（**全局仅 1 路**，多摄像头需轮询 start/frame/stop）、
  `GET /rtsp/frame`（返回当前帧 JPEG 字节流）、`POST /rtsp/stop`。
- 服务从 .12 实测可达（curl -sk https://10.10.1.1:8088/health → ok，enrolled_people=2，device=cuda）。
- 源码：/home/nvidia/JoyAI-VL-Interaction/face_identity_emotion/face_service.py（aiohttp，非 FastAPI）。
- 已决定：底照 person_id = `elder-<elders.id>`；表情复审 qwen 走 NewAPI(10.10.1.12:3030) 视觉模型。

## 设计决策（实施中确定，随时补充）
- 行为事件表 `behavior_events`（tenant, elder_id, device_id, area_id, detected_at,
  face_crop_object, video_object, expression_emotieff, expression_qwen, expression_final,
  behavior, confidence, match_score, review…）视频+脸图存 MinIO `cctv-footage-storage`。
- 摄像头↔走廊绑定：iot_devices 加 area_id（或新绑定表）。
- 人脸底照：入住人像照 → GPU 服务注册（embedding 库在 GPU 侧），elder_id ↔ 人脸 ID 映射落库。
- 雷达：iot_devices 加 source(emqx_auto/manual)、radar_kind(breathing_hr/fall)、room 绑定走 area/room。

- [x] 后端 A2：BehaviorEvent 表（internal/model/behavior.go）✅
- [x] 后端 A3：BehaviorAnalyzer（internal/service/behavior_analyzer.go + behavior_helpers.go，
      main.go 启动接线）✅ 注意：ffmpeg 片段依赖容器内 ffmpeg（见下）
- [x] 后端 A4：GET /elders/:id/behavior-events（含脸图/视频预签名 URL）+
      GET/POST /elders/:id/face-enrollment（internal/handler/behavior_handler.go）✅
- [x] 后端 B1：CreateDevice 仅允许摄像头 ✅
- [x] 后端 B2：iot/radar_binding.go 双向绑定（长者 create/update/intake + 雷达分配房间）✅
- [ ] 后端 B3（可选完善）：健康/告警链路已有（iot.Ingest 内 ElderID→HealthRecord+阈值告警），
      缺「呼吸心率 SignalRecord → 长者体征 tab 展示」确认（可能已覆盖）
- [ ] 前端 F1：设备添加对话框只留摄像头；pending 雷达的 类型指定(Product)/房间分配 UI
- [ ] 前端 F2：【长者】行为 tab：GET /elders/:id/behavior-events 时间条 + video 播放器
      （video_url/face_crop_url 预签名）+ 表情/行为/相似度展示；挂 WideResidentPage + WideDoctorResidentPage
- [ ] 前端 F3：【长者】设备 tab：按 elder_id 过滤 BusinessStore.devices
- [ ] 部署：服务器需要静态 ffmpeg（johnvansickle static build）+ compose 挂载到容器
      /usr/local/bin/ffmpeg + KXB_FFMPEG_PATH=/usr/local/bin/ffmpeg，否则片段失败但事件仍入库
- [ ] 部署：MinIO 建 cctv-footage-storage 桶
- [ ] 设备端验证 + AGENTS.md 更新

## 剩余主任务快照（行为/雷达部分，训练任务已完成）
- 前端 F1：WideDeviceManagement 添加设备只留摄像头；pending 雷达的 类型(product)/房间(room) 分配 UI
- 前端 F2：WideResidentPage + WideDoctorResidentPage 加「行为」tab（GET /elders/:id/behavior-events，
  时间条 + video_url 回放 + face_crop_url + expression/behavior 展示）
- 前端 F3：【长者】设备 tab 按 elder_id 过滤 BusinessStore.devices
- 部署：后端最新二进制（含 behavior/radar/training 接口，已完成训练部分部署，
  behavior/radar 同一二进制已在 2026-09-10 训练部署时一并上线）
- 部署：静态 ffmpeg 进容器 + KXB_FFMPEG_PATH（否则行为事件无视频片段）；MinIO 建 cctv-footage-storage 桶（已存在）
- 设备端行为/雷达实测

## 下一步（重置后从这里继续）
1. 前端 F1：WideDeviceManagement.ets 添加设备对话框删毫米波选项；设备列表 pending 雷达加
   「类型」选择（breath_radar/fall_radar→PUT /iot/devices/:id {product}）+「房间」分配
   （{room, building}）。后端 UpdateDevice 已支持任意字段（room 变更自动触发绑定）。
2. 前端 F2：WideResidentPage 加「行为」tab：调 GET /elders/:id/behavior-events，
   时间条（日期+小时刻度，事件点），点击事件弹出 video 播放（video_url）+ 脸图（face_crop_url）
   + 表情（expression + 来源）+ 行为描述。医师端 WideDoctorResidentPage 同步加。
3. 部署后端：本地 go build linux → 服务器替换 → docker build → compose up（脚本模式照旧）。
4. MinIO 建桶：用 storage admin API 或 mc 命令建 cctv-footage-storage。

## 关键坑位备忘
- 前端构建必须带 DEVECO_SDK_HOME/JAVA_HOME/PATH（见仓库根 _build-with-java.bat）。
- 服务器 .env 第 29 行游离 token；docker compose 环境传递靠 ${VAR:-default} 插值。
- 远端 sudo 命令引号嵌套易碎：用 SFTP 传 .sh 再 `sudo bash` 执行。
- hdc 需要绝对路径 + Windows 路径 install；截图用 snapshot_display + bat 包装 file recv。
- git 禁止把 bin/ 构建产物、.env、密钥文件提交入库（bin/ 已 gitignore）。

## 新增任务（2026-09-10 凌晨，随行为任务下达）
护工端首页快捷操作【申请协助】改为【每日训练】：阿尔茨海默老人每日 10 分钟认知训练，
素材从 MinIO 训练桶随机抽取。桶已核实：ad-training-picture(198)/ad-training-music(112)/
ad-training-video(1)。方案：后端 GET /api/v1/training/daily（按日随机种子采样三桶混合 +
预签名 URL），前端首页按钮改名并打开全屏训练面板（10 分钟倒计时 + 图片/音频/视频卡片流）。
- [x] 后端 T1：GET /training/daily（按日随机种子、8图+3音乐+1视频、预签名 URL）已部署冒烟
- [x] 前端 T2：DailyTrainingPanel（10 分钟倒计时/图片/音乐 AVPlayer/视频 Video 组件）+
       WideHomePage「申请协助」→「每日训练」按钮，已构建并装设备
- [x] 部署验证（training/daily 线上 12 项素材实测通过）
