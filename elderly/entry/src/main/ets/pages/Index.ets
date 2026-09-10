import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { VoiceAgentClient, VoiceAgentEvent } from '../network/VoiceAgentClient';
import { VoiceAgentConfig } from '../network/VoiceAgentConfig';
import { WindowEnv } from '../util/WindowEnv';
import {
  BackendApi, BackendConfig,
  CarePlanInfo, CareTaskInfo, ComfortSessionInfo, ElderInfo
} from '../network/BackendApi';

const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';
/** Grok Ball 表情 ID（见 rawfile/grokball/grok-ball.js，编号契约永不重排）。 */
const EMOTION_IDLE: string = '02'; // 待机放空
const EMOTION_WAKING: string = '01'; // 连接/唤醒
const EMOTION_GENTLE: string = '03'; // 温和提醒（关怀提醒条显示期间）
const EMOTION_RECEIVING: string = '31'; // 接收任务（老人说话 / ASR 识别期间）
const EMOTION_LISTENING: string = '35'; // 等待输入（聆听）
const EMOTION_REPLYING: string = '39'; // 输出回复（嘴随播报开合）
const EMOTION_THINKING: string = '30'; // 思考中（生成回复）
const EMOTION_ERROR: string = '34'; // 出错/断线
/** ASR 增量停止多久后视为老人已说完，回到聆听表情。 */
const ELDER_SPEECH_QUIET_MS: number = 2200;
/** 关怀提醒节奏：首次 20 分钟，之后每 45 分钟交替提醒喝水/起身活动。 */
const CARE_REMIND_FIRST_MS: number = 20 * 60 * 1000;
const CARE_REMIND_INTERVAL_MS: number = 45 * 60 * 1000;
/** 关怀提醒条自动收起时长。 */
const CARE_REMIND_SHOW_MS: number = 30 * 1000;
/** 主动安抚：设备轮询待领取安抚会话的间隔（后端识别到悲伤表情后创建）。 */
const COMFORT_POLL_MS: number = 10 * 1000;
/** 主动安抚：开场白播完后等待老人开口的时限，超时上报护工。 */
const COMFORT_NO_RESPONSE_MS: number = 15 * 1000;
const WEEKDAY_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/**
 * 老人日常陪伴助手首页：透明 Grok 表情球居中，表情跟随对话阶段——
 * 老人说话（ASR）= 接收任务(31)，生成回复 = 思考中(30)，
 * 播报回复 = 输出回复(39)，关怀提醒 = 温和提醒(03)。
 * 陪伴层：时间问候、日期时钟、喝水/活动关怀提醒、快捷话题。
 * 文字输入是麦克风不可用时的兜底。
 */
@Entry
@ComponentV2
struct Index {
  @Local statusText: string = '正在连接小伴…';
  @Local recognizedText: string = '';
  @Local assistantText: string = '';
  @Local inputText: string = '';
  @Local connected: boolean = false;
  @Local microphoneAvailable: boolean = false;
  @Local connecting: boolean = true;
  @Local clockText: string = '';
  @Local reminderText: string = '';
  /** 已绑定的长者档案与护理安排（右上角卡片）。 */
  @Local elder: ElderInfo | null = null;
  @Local elderNextTask: CareTaskInfo | null = null;
  @Local elderTodayCount: number = 0;
  @Local elderPlanLines: string[] = [];
  @Local elderStatus: string = '未绑定老人';
  @Local elderSheet: boolean = false;
  @Local inputElderId: string = '';
  @Local elderQuickList: ElderInfo[] = [];
  private client: VoiceAgentClient = new VoiceAgentClient();
  private env: WindowEnv = WindowEnv.shared;
  private webController: webview.WebviewController = new webview.WebviewController();
  private webReady: boolean = false;
  private everConnected: boolean = false;
  private currentEmotion: string = EMOTION_IDLE;
  /** 老人正在说话（ASR 识别中）→ 接收任务表情。 */
  private elderSpeaking: boolean = false;
  /** 服务端已开始生成回复 → 思考中表情。 */
  private thinking: boolean = false;
  /** TTS 音频正在播放 → 输出回复表情。 */
  private speaking: boolean = false;
  /** 服务端已发 end，当前回复的音频全部送达。 */
  private responseEnded: boolean = false;
  private elderSpeechTimerId: number = -1;
  private speakingFallbackTimerId: number = -1;
  private clockTimerId: number = -1;
  private remindFirstTimerId: number = -1;
  private remindLoopTimerId: number = -1;
  private remindHideTimerId: number = -1;
  private nextRemindIsWater: boolean = true;
  /** 主动语音安抚（后端摄像头识别到悲伤表情后触发）。'' 为空闲，其余见 beginComfort。 */
  @Local comfortBanner: string = '';
  private comfortSessionId: number = -1;
  private comfortPhase: string = ''; // '' / greeting(开场白播报中) / awaiting(等老人回应) / responded
  private comfortAsrBuffer: string = '';
  private comfortPollTimerId: number = -1;
  private comfortNoRespTimerId: number = -1;
  private comfortPolling: boolean = false;

  aboutToAppear(): void {
    this.refreshClock();
    this.clockTimerId = setInterval((): void => {
      this.refreshClock();
    }, 30 * 1000);
    void this.start();
  }

  aboutToDisappear(): void {
    this.stopElderSpeechTimer();
    this.stopSpeakingFallbackTimer();
    this.stopCareReminders();
    this.stopComfortPolling();
    this.stopComfortNoResponseTimer();
    if (this.clockTimerId !== -1) {
      clearInterval(this.clockTimerId);
      this.clockTimerId = -1;
    }
    void this.client.close();
  }

  // ==================== 陪伴层：时钟 / 问候 / 关怀提醒 ====================

  private refreshClock(): void {
    const now: Date = new Date();
    const text: string = `${now.getMonth() + 1}月${now.getDate()}日 ${WEEKDAY_NAMES[now.getDay()]} ` +
      `${now.getHours()}:${now.getMinutes() < 10 ? '0' : ''}${now.getMinutes()}`;
    if (text !== this.clockText) {
      this.clockText = text;
    }
  }

  /** 按时段生成问候语，带上称呼。 */
  private buildGreeting(honorific: string): string {
    const hour: number = new Date().getHours();
    const who: string = honorific.length > 0 ? honorific + '，' : '';
    if (hour >= 5 && hour < 8) {
      return `早上好，${who}新的一天开始啦，今天想聊点什么？`;
    }
    if (hour >= 8 && hour < 11) {
      return `上午好，${who}吃过早饭了吗？我陪着您聊聊天。`;
    }
    if (hour >= 11 && hour < 13) {
      return `中午好，${who}记得按时吃午饭，吃完歇一会儿。`;
    }
    if (hour >= 13 && hour < 17) {
      return `下午好，${who}累了吧，咱们说说话解解闷。`;
    }
    if (hour >= 17 && hour < 19) {
      return `傍晚好，${who}晚饭吃了吗？我陪着您呢。`;
    }
    if (hour >= 19 && hour < 23) {
      return `晚上好，${who}今天过得怎么样？跟我说说吧。`;
    }
    return `${who}夜深了，聊两句就早点休息，我一直陪着您。`;
  }

  private startCareReminders(): void {
    this.stopCareReminders();
    this.remindFirstTimerId = setTimeout((): void => {
      this.remindFirstTimerId = -1;
      this.showCareReminder();
      this.remindLoopTimerId = setInterval((): void => {
        this.showCareReminder();
      }, CARE_REMIND_INTERVAL_MS);
    }, CARE_REMIND_FIRST_MS);
  }

  /** 关怀提醒只在陪伴空闲时出现，不打断对话和播报。 */
  private showCareReminder(): void {
    if (!this.connected || this.speaking || this.thinking || this.elderSpeaking) {
      return;
    }
    this.reminderText = this.nextRemindIsWater ? '该喝杯水啦，慢慢喝' : '坐久了吧，起来活动活动';
    this.nextRemindIsWater = !this.nextRemindIsWater;
    this.statusText = '小伴轻轻提醒您';
    this.syncEmotion();
    if (this.remindHideTimerId !== -1) {
      clearTimeout(this.remindHideTimerId);
    }
    this.remindHideTimerId = setTimeout((): void => {
      this.remindHideTimerId = -1;
      this.dismissReminder();
    }, CARE_REMIND_SHOW_MS);
  }

  private dismissReminder(): void {
    if (this.reminderText.length === 0) { return; }
    this.reminderText = '';
    if (this.remindHideTimerId !== -1) {
      clearTimeout(this.remindHideTimerId);
      this.remindHideTimerId = -1;
    }
    if (this.connected) {
      this.statusText = this.microphoneAvailable ? '我一直都在，您慢慢说' : '点下方输入框和我说话';
    }
    this.syncEmotion();
  }

  private stopCareReminders(): void {
    if (this.remindFirstTimerId !== -1) {
      clearTimeout(this.remindFirstTimerId);
      this.remindFirstTimerId = -1;
    }
    if (this.remindLoopTimerId !== -1) {
      clearInterval(this.remindLoopTimerId);
      this.remindLoopTimerId = -1;
    }
    this.dismissReminder();
  }

  // ==================== 主动语音安抚（悲伤表情触发） ====================

  private startComfortPolling(): void {
    if (this.comfortPollTimerId !== -1) { return; }
    this.comfortPollTimerId = setInterval((): void => {
      void this.pollComfort();
    }, COMFORT_POLL_MS);
  }

  private stopComfortPolling(): void {
    if (this.comfortPollTimerId !== -1) {
      clearInterval(this.comfortPollTimerId);
      this.comfortPollTimerId = -1;
    }
  }

  /** 已绑定长者且小伴空闲时，向后端领取待处理的安抚会话。 */
  private async pollComfort(): Promise<void> {
    if (this.comfortPolling || this.elder === null || !this.connected || this.comfortSessionId !== -1 ||
      this.speaking || this.thinking || this.elderSpeaking) {
      return;
    }
    this.comfortPolling = true;
    try {
      const session: ComfortSessionInfo | null = await BackendApi.fetchPendingComfort(this.elder.id);
      if (session !== null) {
        await this.beginComfort(session);
      }
    } catch (_error) {
      // 后端暂不可达：下个轮询周期再试。
    } finally {
      this.comfortPolling = false;
    }
  }

  /** 领取安抚会话并主动开场：小伴先开口问候，随后等老人回应。 */
  private async beginComfort(session: ComfortSessionInfo): Promise<void> {
    if (this.comfortSessionId !== -1 || this.elder === null || !this.connected) { return; }
    try {
      await BackendApi.comfortStart(session.id);
    } catch (_error) {
      return; // 领取失败（可能已被其他终端处理）：留待后端扫描器兜底。
    }
    this.comfortSessionId = session.id;
    this.comfortPhase = 'greeting';
    this.comfortAsrBuffer = '';
    const honorific: string = this.elderHonorific(this.elder);
    this.comfortBanner = `小伴注意到${honorific}心情不太好，正陪着您说说话`;
    this.syncEmotion();
    // 走既有聊天管道下发安抚开场：大模型会先说"刚才发现您心情不太好"，随后正常对话。
    const name: string = (this.elder.name ?? '').length > 0 ? this.elder.name : honorific;
    await this.sendComfortInstruction(
      `（护理系统事件：摄像头刚刚观察到${name}表情悲伤，心情可能不好。` +
      `请立刻温柔主动地关心${this.elderHonorific(this.elder)}，第一句话就说` +
      `"刚才发现您心情不太好，和我说说话吧"，语气轻柔、语速放缓，之后耐心倾听。）`);
  }

  /** 与 sendTextMessage 相同的状态切换，但不把系统指令显示成"您说"。 */
  private async sendComfortInstruction(message: string): Promise<void> {
    if (!this.connected || message.length === 0) { return; }
    this.thinking = true;
    this.elderSpeaking = false;
    this.speaking = false;
    this.responseEnded = false;
    this.assistantText = '';
    this.dismissReminder();
    this.client.pauseMicrophone();
    this.statusText = '让我想想哈…';
    this.syncEmotion();
    const sent: boolean = await this.client.sendChat(message);
    if (!sent) {
      this.thinking = false;
      this.statusText = '发送失败，请再试一次';
      this.syncEmotion();
      // 安抚开场发不出去：按无回应上报，让护工接手。
      if (this.comfortPhase === 'greeting') {
        void this.reportComfortNoResponse();
      }
    }
  }

  private stopComfortNoResponseTimer(): void {
    if (this.comfortNoRespTimerId !== -1) {
      clearTimeout(this.comfortNoRespTimerId);
      this.comfortNoRespTimerId = -1;
    }
  }

  /** 老人在时限内开口了：上报第一句回应，安抚会话完成，转入正常陪聊。 */
  private async completeComfortResponded(): Promise<void> {
    if (this.comfortPhase !== 'awaiting') { return; }
    this.comfortPhase = 'responded';
    this.stopComfortNoResponseTimer();
    const id: number = this.comfortSessionId;
    if (id === -1) { return; }
    try {
      await BackendApi.comfortRespond(id, this.comfortAsrBuffer.trim().slice(0, 500));
    } catch (_error) {
      // 上报失败不影响陪伴对话本身。
    }
    this.comfortSessionId = -1;
    this.comfortBanner = '';
  }

  /** 老人始终没有开口：上报后端，由后端通知护工前来查看。 */
  private async reportComfortNoResponse(): Promise<void> {
    this.comfortPhase = '';
    this.stopComfortNoResponseTimer();
    const id: number = this.comfortSessionId;
    if (id === -1) { return; }
    this.comfortSessionId = -1;
    try {
      await BackendApi.comfortNoResponse(id);
    } catch (_error) {
      // 上报失败时后端扫描器仍会兜底通知护工。
    }
    this.comfortBanner = '';
    this.statusText = '已经叫护理员来陪陪您啦';
    this.syncEmotion();
  }

  // ==================== 长者档案（机构后端） ====================

  private genderText(e: ElderInfo): string {
    if (e.gender === 'M') { return '男'; }
    if (e.gender === 'F') { return '女'; }
    return '';
  }

  private ageText(e: ElderInfo): string {
    const birth: string = e.birth_date ?? '';
    if (birth.length < 4) { return ''; }
    const year: number = parseInt(birth.substring(0, 4));
    if (isNaN(year) || year <= 1900) { return ''; }
    return `${new Date().getFullYear() - year}岁`;
  }

  private elderAge(e: ElderInfo): number {
    const birth: string = e.birth_date ?? '';
    if (birth.length >= 4) {
      const year: number = parseInt(birth.substring(0, 4));
      if (!isNaN(year) && year > 1900) { return new Date().getFullYear() - year; }
    }
    return 80;
  }

  /** 称呼：姓氏 + 爷爷/奶奶（60 岁以上）或叔叔/阿姨。 */
  private elderHonorific(e: ElderInfo | null): string {
    if (e === null) { return ''; }
    const female: boolean = e.gender !== 'M';
    const title: string = this.elderAge(e) >= 60 ? (female ? '奶奶' : '爷爷') : (female ? '阿姨' : '叔叔');
    const name: string = e.name ?? '';
    return (name.length > 0 ? name.substring(0, 1) : '') + title;
  }

  private careLevelText(level: number): string {
    const names: string[] = ['一级', '二级', '三级', '四级', '五级'];
    return level >= 1 && level <= 5 ? `${names[level - 1]}护理` : '';
  }

  private formatDueTime(dueAt: string | null | undefined): string {
    if (!dueAt) { return ''; }
    const d: Date = new Date(dueAt);
    if (isNaN(d.getTime())) { return ''; }
    const m: number = d.getMinutes();
    return `${d.getHours()}:${m < 10 ? '0' : ''}${m}`;
  }

  /** 按后端老人 ID 绑定：档案 + 今日护理任务 + 护理计划条目。 */
  private async bindElder(id: number): Promise<void> {
    this.elderStatus = '正在获取长者资料…';
    try {
      this.elder = await BackendApi.fetchElder(id);
      const tasks: CareTaskInfo[] = await BackendApi.fetchTasks(id);
      const todo: CareTaskInfo[] = tasks
        .filter((t: CareTaskInfo): boolean => t.status !== 'done')
        .sort((a: CareTaskInfo, b: CareTaskInfo): number =>
          (a.due_at ?? '9999').localeCompare(b.due_at ?? '9999'));
      this.elderTodayCount = todo.length;
      this.elderNextTask = todo.length > 0 ? todo[0] : null;
      const plans: CarePlanInfo[] = await BackendApi.fetchCarePlans(id);
      const lines: string[] = [];
      for (const p of plans) {
        for (const item of (p.items ?? [])) {
          if (item.active === false) { continue; }
          lines.push(`${item.title} · ${item.frequency ?? '定期'}`);
          if (lines.length >= 3) { break; }
        }
        if (lines.length >= 3) { break; }
      }
      this.elderPlanLines = lines;
      this.elderStatus = '';
      this.elderSheet = false;
      // 更新问候语并告知服务端称呼（服务端注入大模型人设）
      const honorific: string = this.elderHonorific(this.elder);
      this.assistantText = this.buildGreeting(honorific);
      if (this.connected) {
        await this.client.sendSetElder(this.elder.name, this.elder.gender ?? '', this.elderAge(this.elder));
      }
    } catch (_error) {
      this.elder = null;
      this.elderNextTask = null;
      this.elderTodayCount = 0;
      this.elderPlanLines = [];
      this.elderStatus = '获取失败，请确认老人ID或网络';
    }
  }

  private async openElderSheet(): Promise<void> {
    this.elderSheet = true;
    if (this.elderQuickList.length === 0) {
      try {
        this.elderQuickList = (await BackendApi.fetchElders()).slice(0, 8);
      } catch (_error) {
        this.elderQuickList = [];
      }
    }
  }

  private async submitElderId(): Promise<void> {
    const id: number = parseInt(this.inputElderId);
    if (isNaN(id) || id <= 0) {
      this.elderStatus = '请输入有效的老人ID';
      return;
    }
    await this.bindElder(id);
  }

  // ==================== 连接与会话 ====================

  private async start(): Promise<void> {
    await this.requestMicrophonePermission();
    await this.connect();
  }

  private async connect(): Promise<void> {
    if (this.connecting && this.everConnected) { return; }
    this.connecting = true;
    this.elderSpeaking = false;
    this.thinking = false;
    this.speaking = false;
    this.responseEnded = false;
    this.stopElderSpeechTimer();
    this.stopSpeakingFallbackTimer();
    this.statusText = '正在叫小伴…';
    this.syncEmotion();
    try {
      if (this.everConnected) {
        // 重连前彻底释放旧连接资源。
        await this.client.close();
        this.client = new VoiceAgentClient();
      }
      await this.client.connect(VoiceAgentConfig.CHAT_WS_URL, (event: VoiceAgentEvent): void => {
        this.handleEvent(event);
      }, (): void => {
        this.connected = false;
        this.stopComfortPolling();
        this.statusText = '小伴走神了，点下方按钮叫它回来';
        this.syncEmotion();
      });
      this.connected = true;
      this.everConnected = true;
      this.connecting = false;
      this.assistantText = this.buildGreeting(this.elderHonorific(this.elder));
      this.statusText = this.microphoneAvailable ? '我一直都在，您慢慢说' : '点下方输入框和我说话';
      await this.client.sendReset();
      if (this.elder !== null) {
        // 重连后重新告知陪伴对象身份
        await this.client.sendSetElder(this.elder.name, this.elder.gender ?? '', this.elderAge(this.elder));
      }
      if (this.microphoneAvailable) {
        await this.client.prepareMicrophone();
        this.microphoneAvailable = this.client.resumeMicrophone();
      }
      this.startCareReminders();
      this.startComfortPolling();
      this.syncEmotion();
    } catch (_error) {
      this.connected = false;
      this.connecting = false;
      this.statusText = '小伴没应答，点下方按钮再叫一次';
      this.syncEmotion();
    }
  }

  private async requestMicrophonePermission(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, [MICROPHONE_PERMISSION]);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.microphoneAvailable = false;
        return;
      }
      this.microphoneAvailable = true;
    } catch (_error) {
      this.microphoneAvailable = false;
    }
  }

  // ==================== 表情舞台（Grok Ball） ====================

  /** 按对话阶段推导表情 ID 并同步到 Web 舞台。
   *  优先级：断线 > 老人说话(31) > 思考中(30) > 播报回复(39) > 关怀提醒(03) > 聆听(35)。 */
  private syncEmotion(): void {
    let emotion: string = EMOTION_LISTENING;
    if (!this.connected) {
      emotion = this.everConnected ? EMOTION_ERROR : EMOTION_WAKING;
    } else if (this.elderSpeaking) {
      emotion = EMOTION_RECEIVING;
    } else if (this.thinking) {
      emotion = EMOTION_THINKING;
    } else if (this.speaking) {
      emotion = EMOTION_REPLYING;
    } else if (this.reminderText.length > 0) {
      emotion = EMOTION_GENTLE;
    } else {
      emotion = EMOTION_LISTENING;
    }
    this.applyEmotion(emotion);
  }

  private applyEmotion(id: string): void {
    if (this.currentEmotion === id) { return; }
    this.currentEmotion = id;
    if (!this.webReady) { return; }
    try {
      this.webController.runJavaScript(
        `window.stage && window.stage.setEmotion('${id}')`);
    } catch (_error) {
      // 舞台尚未就绪或已销毁；表情会在下一次阶段变化时重试。
    }
  }

  private onStageReady(): void {
    this.webReady = true;
    // 页面加载完成前可能已经历过若干阶段，这里补发当前表情。
    this.currentEmotion = '';
    this.syncEmotion();
  }

  // ==================== 老人说话静默判定 ====================

  private refreshElderSpeech(): void {
    this.elderSpeaking = true;
    if (this.elderSpeechTimerId !== -1) {
      clearTimeout(this.elderSpeechTimerId);
    }
    this.elderSpeechTimerId = setTimeout((): void => {
      this.elderSpeechTimerId = -1;
      this.elderSpeaking = false;
      this.syncEmotion();
    }, ELDER_SPEECH_QUIET_MS);
  }

  private stopElderSpeechTimer(): void {
    if (this.elderSpeechTimerId !== -1) {
      clearTimeout(this.elderSpeechTimerId);
      this.elderSpeechTimerId = -1;
    }
  }

  // ==================== 播报完成判定 ====================

  /** 回复播报真正结束：回到聆听态并恢复 ASR（小伴说完老人才可以说话）。 */
  private finishSpeaking(): void {
    this.stopSpeakingFallbackTimer();
    this.speaking = false;
    this.thinking = false;
    if (this.microphoneAvailable && !this.client.resumeMicrophone()) {
      this.microphoneAvailable = false;
    }
    this.statusText = this.microphoneAvailable ? '我一直都在呢，再聊点什么吧' : '点下方输入框和我说话';
    // 安抚开场白播完：进入"等老人回应"窗口，超时未开口则上报护工。
    if (this.comfortPhase === 'greeting') {
      this.comfortPhase = 'awaiting';
      this.comfortAsrBuffer = '';
      this.comfortNoRespTimerId = setTimeout((): void => {
        this.comfortNoRespTimerId = -1;
        void this.reportComfortNoResponse();
      }, COMFORT_NO_RESPONSE_MS);
      this.statusText = this.microphoneAvailable ? '我在听呢，和我说说话吧' : this.statusText;
    }
    this.syncEmotion();
  }

  /** 队列瞬时排空但未收到 end：短暂等待后续音频，超时且确实无声则结束。 */
  private scheduleSpeakingFallback(): void {
    if (this.speakingFallbackTimerId !== -1) { return; }
    this.speakingFallbackTimerId = setTimeout((): void => {
      this.speakingFallbackTimerId = -1;
      if (this.speaking && !this.responseEnded && !this.client.isPlaying()) {
        this.finishSpeaking();
      }
    }, 1800);
  }

  private stopSpeakingFallbackTimer(): void {
    if (this.speakingFallbackTimerId !== -1) {
      clearTimeout(this.speakingFallbackTimerId);
      this.speakingFallbackTimerId = -1;
    }
  }

  // ==================== 会话事件 ====================

  private handleEvent(event: VoiceAgentEvent): void {
    if (event.type === 'asr') {
      // 老人开口：接收任务表情；静默后自动回到聆听。
      this.refreshElderSpeech();
      const heard: string = event.text ?? '';
      this.recognizedText += heard;
      if (this.comfortPhase === 'awaiting' && heard.trim().length > 0) {
        this.comfortAsrBuffer += heard;
      }
      this.statusText = '在听呢，您慢慢说';
    } else if (event.type === 'start') {
      // 服务端开始生成回复：思考中。播报/思考期间静默麦克风——
      // 不允许插话，扬声器声音也不能被回采成“老人插话”截断 TTS。
      // 安抚等待期收到 start 说明老人这句话说完了 → 上报第一句回应。
      if (this.comfortPhase === 'awaiting' && this.comfortAsrBuffer.trim().length > 0) {
        void this.completeComfortResponded();
      }
      this.thinking = true;
      this.speaking = false;
      this.responseEnded = false;
      this.stopSpeakingFallbackTimer();
      this.elderSpeaking = false;
      this.stopElderSpeechTimer();
      this.client.pauseMicrophone();
      this.assistantText = '';
      this.statusText = '让我想想哈…';
    } else if (event.type === 'text') {
      this.assistantText += event.content ?? '';
    } else if (event.type === 'audio') {
      // 首段 TTS 到达：输出回复（嘴随播报开合）。
      this.thinking = false;
      this.speaking = true;
      this.statusText = '正在说给您听…';
    } else if (event.type === 'playback_drained') {
      // 只有收到 end（回复音频全部送达）后的排空才是真正播完。
      if (this.responseEnded) {
        this.finishSpeaking();
      } else {
        this.scheduleSpeakingFallback();
      }
    } else if (event.type === 'end') {
      this.responseEnded = true;
      if (!this.client.isPlaying()) {
        this.finishSpeaking();
      }
    } else if (event.type === 'interrupt') {
      // 老人插话打断：服务端已取消上一轮回复。
      this.speaking = false;
      this.thinking = false;
      this.responseEnded = false;
      this.stopSpeakingFallbackTimer();
      this.refreshElderSpeech();
      this.assistantText = '';
      this.statusText = '您先说，我在听';
    } else if (event.type === 'error') {
      this.client.pauseMicrophone();
      this.statusText = event.message ?? '小伴遇到了点问题，请再说一次';
      // 安抚流程被错误打断：按无回应上报，让护工接手，避免会话悬挂。
      if (this.comfortPhase === 'greeting' || this.comfortPhase === 'awaiting') {
        void this.reportComfortNoResponse();
      }
    }
    this.syncEmotion();
  }

  private async sendTextMessage(text?: string): Promise<void> {
    const message: string = (text ?? this.inputText).trim();
    if (!this.connected || message.length === 0) { return; }
    this.inputText = '';
    this.recognizedText = message;
    this.thinking = true;
    this.elderSpeaking = false;
    this.speaking = false;
    this.responseEnded = false;
    this.assistantText = '';
    this.dismissReminder();
    this.client.pauseMicrophone();
    this.statusText = '让我想想哈…';
    this.syncEmotion();
    const sent: boolean = await this.client.sendChat(message);
    if (!sent) {
      this.thinking = false;
      this.statusText = '发送失败，请再试一次';
      this.syncEmotion();
    }
  }

  // ==================== 视图 ====================

  /** 右上角长者信息卡片：姓名/等级/床号 + 下次护理时间，点按换绑。 */
  @Builder
  private elderCard() {
    Column({ space: 3 }) {
      if (this.elder !== null) {
        Row({ space: 6 }) {
          Text(this.elder.name).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor('#1B2B4D').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.careLevelText(this.elder.care_level ?? 0).length > 0) {
            Text(this.careLevelText(this.elder.care_level ?? 0))
              .fontSize(11).fontColor('#FFFFFF').padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6).backgroundColor('#4C8DFF')
          }
        }
        Text([this.genderText(this.elder), this.ageText(this.elder),
          this.elder.bed?.bed_no ? `${this.elder.bed.bed_no}床` : '']
          .filter((s: string): boolean => s.length > 0).join(' · ') + ` · ID ${this.elder.id}`)
          .fontSize(12).fontColor('#5B6E8C').maxLines(1)
        if (this.elderNextTask !== null) {
          Text(`下次护理 ${this.formatDueTime(this.elderNextTask.due_at)} ${this.elderNextTask.title}`)
            .fontSize(12).fontColor('#2E7D32').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text(`今日护理 ${this.elderTodayCount} 项`)
            .fontSize(12).fontColor('#2E7D32')
        }
        ForEach(this.elderPlanLines, (line: string, idx: number) => {
          Text(line).fontSize(11).fontColor('#8A6D2F').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }, (line: string, idx: number): string => `${idx}-${line}`)
      } else {
        Text('绑定老人').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1B2B4D')
        Text(this.elderStatus).fontSize(12).fontColor('#5B6E8C').maxLines(2)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: 220 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(14)
    .backgroundColor('#E9FFFFFF')
    .border({ width: 1, color: '#66C9D8F0' })
    .onClick((): void => { this.openElderSheet(); })
    .accessibilityText(`长者信息卡：${this.elder !== null ? this.elder.name : '未绑定'}，点按重新绑定`)
  }

  /** 绑定老人面板：输入老人 ID 查询档案，或在在住老人里点选。 */
  @Builder
  private elderSheetBuilder() {
    Column() {
      Blank().layoutWeight(1)
      Column({ space: 12 }) {
        Text('绑定老人').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1B2B4D')
        TextInput({ placeholder: '请输入老人ID（数字）', text: this.inputElderId })
          .type(InputType.Number)
          .height(48).fontSize(18)
          .backgroundColor('#F4F7FC')
          .borderRadius(12)
          .onChange((value: string): void => { this.inputElderId = value; })
          .onSubmit((): void => { void this.submitElderId(); })
          .accessibilityText('老人ID输入框')
        Button('查询并绑定')
          .width('100%').height(46).fontSize(18).borderRadius(999)
          .fontColor(Color.White).backgroundColor('#2E6BE6')
          .onClick((): void => { void this.submitElderId(); })
        if (this.elderStatus.length > 0) {
          Text(this.elderStatus).fontSize(14).fontColor('#B36B00')
        }
        if (this.elderQuickList.length > 0) {
          Divider().color('#E3EBF7')
          Text('在住老人（点选绑定）').fontSize(14).fontColor('#5B6E8C')
            .alignSelf(ItemAlign.Start)
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.elderQuickList, (e: ElderInfo) => {
              Text(`${e.id} · ${e.name}`)
                .fontSize(15).fontColor('#2E5BC0')
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .borderRadius(999).backgroundColor('#EDF3FF')
                .margin({ right: 8, bottom: 8 })
                .onClick((): void => {
                  this.inputElderId = `${e.id}`;
                  void this.bindElder(e.id);
                })
                .accessibilityText(`绑定长者${e.name}`)
            }, (e: ElderInfo): string => `${e.id}`)
          }.width('100%')
        }
        Button('关闭').width('100%').height(42).fontSize(16).borderRadius(999)
          .fontColor('#5B6E8C').backgroundColor('#F0F4FA')
          .onClick((): void => { this.elderSheet = false; })
      }
      .padding(20)
      .borderRadius(20)
      .backgroundColor('#FFFFFF')
      .margin({ left: '7%', right: '7%', bottom: this.env.keyboardHeight > 0 ? this.env.keyboardHeight + 40 : '18%' })
      Blank().layoutWeight(1)
    }
    .width('100%').height('100%')
  }

  @Builder
  private clockLine() {
    Text(this.clockText)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor('#3A4C6E')
      .margin({ top: 2 })
      .accessibilityText(`现在是${this.clockText}`)
  }

  /** 关怀提醒条：点击收起，不打断语音。 */
  @Builder
  private reminderBanner() {
    if (this.reminderText.length > 0) {
      Row({ space: 10 }) {
        Text('💛').fontSize(20)
        Text(this.reminderText)
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7A4D00')
        Text('知道啦')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(999)
          .backgroundColor('#F0A23C')
      }
      .padding({ left: 16, right: 10, top: 10, bottom: 10 })
      .borderRadius(999)
      .backgroundColor('#FFF3DC')
      .border({ width: 1, color: '#F0D9A8' })
      .onClick((): void => { this.dismissReminder(); })
      .accessibilityText(`关怀提醒：${this.reminderText}，点击收起`)
    }
  }

  /** 主动安抚提示条：小伴注意到长者情绪低落并主动陪伴时显示。 */
  @Builder
  private comfortNotice() {
    if (this.comfortBanner.length > 0) {
      Row({ space: 10 }) {
        Text('💙').fontSize(20)
        Text(this.comfortBanner)
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1B2B4D')
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .borderRadius(999)
      .backgroundColor('#E3EEFF')
      .border({ width: 1, color: '#B9D2F5' })
      .accessibilityText(`情绪陪伴：${this.comfortBanner}`)
    }
  }

  @Builder
  private elderLine() {    Text(this.recognizedText.length > 0 ? `您说：${this.recognizedText}` : ' ')
      .fontSize(20)
      .fontColor('#4A5A76')
      .maxLines(2)
      .textAlign(TextAlign.Center)
      .width('86%')
      .accessibilityText(this.recognizedText.length > 0 ? `您说：${this.recognizedText}` : '')
  }

  /** 中央表情球：透明背景，浮在页面底色上；键盘弹起时压缩高度保证输入框可见。 */
  @Builder
  private ballStage() {
    Web({ src: $rawfile('grokball/chat_stage.html'), controller: this.webController })
      .width('100%')
      .height(this.env.keyboardHeight > 0 ? '28%' : '46%')
      .javaScriptAccess(true)
      .zoomAccess(false)
      .backgroundColor(Color.Transparent)
      .onPageEnd((): void => { this.onStageReady(); })
      .accessibilityText('小伴表情')
  }

  @Builder
  private assistantLine() {
    Text(this.assistantText.length > 0 ? this.assistantText : ' ')
      .fontSize(26)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1B2B4D')
      .maxLines(4)
      .textAlign(TextAlign.Center)
      .width('88%')
      .accessibilityText(`小伴说：${this.assistantText}`)
  }

  /** 快捷话题：老人不用打字也能挑起话头。 */
  @Builder
  private topicChips() {
    if (this.connected && this.env.keyboardHeight === 0) {
      Scroll() {
        Row({ space: 12 }) {
          this.topicChip('聊聊天', '咱们随便聊聊天吧')
          this.topicChip('讲个笑话', '给我讲个笑话吧')
          this.topicChip('讲个故事', '给我讲个简短的故事吧')
          this.topicChip('说吉祥话', '给我说几句吉祥话吧')
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .constraintSize({ maxWidth: '100%' })
    }
  }

  @Builder
  private topicChip(label: string, message: string) {
    Text(label)
      .fontSize(18)
      .fontColor('#2E5BC0')
      .height(44)
      .padding({ left: 22, right: 22 })
      .borderRadius(999)
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#C9D8F0' })
      .onClick((): void => { void this.sendTextMessage(message); })
      .accessibilityText(`快捷话题${label}，点一下小伴就开始说`)
  }

  @Builder
  private composer() {
    Row({ space: 10 }) {
      TextInput({ placeholder: this.connected ? '也可以打字和我聊' : '等待连接…', text: this.inputText })
        .layoutWeight(1)
        .height(48)
        .fontSize(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(999)
        .border({ width: 1, color: '#C9D8F0' })
        .accessibilityText('文字输入框')
        .onChange((value: string): void => { this.inputText = value; })
        .onSubmit((): void => { void this.sendTextMessage(); })
      Button('发送')
        .height(48)
        .padding({ left: 24, right: 24 })
        .fontSize(18)
        .borderRadius(999)
        .fontColor(Color.White)
        .backgroundColor(this.connected && this.inputText.trim().length > 0 ? '#2E6BE6' : '#A9C4F2')
        .enabled(this.connected && this.inputText.trim().length > 0)
        .accessibilityDescription('发送文字消息')
        .onClick((): void => { void this.sendTextMessage(); })
    }
    .width('92%')
    .margin({
      bottom: this.env.keyboardHeight > 0 ? this.env.keyboardHeight :
        Math.max(this.env.naviIndicatorHeight, 12)
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text(this.statusText)
          .fontSize(16)
          .fontColor('#5B6E8C')
          .margin({ top: this.env.statusBarHeight + 12 })
          .accessibilityText(this.statusText)
        this.clockLine()
        Blank(8)
        this.reminderBanner()
        this.comfortNotice()
        this.elderLine()
        this.ballStage()
        this.assistantLine()
        Blank(12)
        if (!this.connected) {
          Button(this.connecting ? '正在叫小伴…' : '叫小伴回来')
            .height(48)
            .padding({ left: 32, right: 32 })
            .fontSize(19)
            .borderRadius(999)
            .fontColor(Color.White)
            .backgroundColor('#2E6BE6')
            .enabled(!this.connecting)
            .onClick((): void => { void this.connect(); })
          Blank(12)
        }
        this.topicChips()
        Blank(10)
        this.composer()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      // 右上角长者信息卡片浮层：不遮挡下方内容的触控。
      Column() {
        Row({ space: 8 }) {
          Blank()
          this.elderCard()
        }
        .width('100%')
        .margin({ top: this.env.statusBarHeight + 6, left: 12, right: 12 })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#E7F0FF', 0.0], ['#F7FAFF', 1.0]]
    })
    .bindContentCover(this.elderSheet, (): void => { this.elderSheetBuilder(); }, {
      modalTransition: ModalTransition.NONE,
      backgroundColor: '#66000000'
    })
  }
}
