import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import {
  HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TitleBarStyleOptions, hdsMaterial
} from '@kit.UIDesignKit';
import { AssessmentAgentApi, AssessmentAgentSession } from '../../network/AssessmentAgentApi';
import { AssessmentAgentClient, AssessmentAgentEvent } from '../../network/AssessmentAgentClient';
import { BusinessStore } from '../../network/BusinessStore';
import { BreakpointUtil } from '../../util/BreakpointSystem';

const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';
/** Grok Ball 表情 ID（见 rawfile/grokball/grok-ball.js，编号契约永不重排）。 */
const EMOTION_IDLE: string = '02'; // 待机放空
const EMOTION_WAKING: string = '01'; // 连接/唤醒
const EMOTION_CURIOUS: string = '03'; // 倒计时即将到点的温和提醒
const EMOTION_RECEIVING: string = '31'; // 接收任务（长者说话/ASR 识别期间）
const EMOTION_LISTENING: string = '35'; // 等待输入（聆听）
const EMOTION_REPLYING: string = '39'; // 输出回复（嘴随播报开合）
const EMOTION_THINKING: string = '30'; // 思考中（回答结束/生成报告）
const EMOTION_SEARCHING: string = '40'; // 检索资料（长者超时未回答）
const EMOTION_DONE: string = '33'; // 任务完成（撒花）
const EMOTION_ERROR: string = '34'; // 出错/断线
const COUNTDOWN_URGENT_SECONDS: number = 10;
const AI_BUBBLE_BG: string = '#F0F5FF';
const ELDER_BUBBLE_BG: string = '#1D63ED';

@ComponentV2
export struct WideAssessmentAgentPage {
  @Param @Require session: AssessmentAgentSession;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};
  @Event onViewReport: (assessmentId: number) => void = (_assessmentId: number) => {};
  @Local statusText: string = '正在连接评估服务…';
  @Local currentIndex: number = 0;
  @Local currentTopic: string = '';
  @Local currentQuestion: string = '';
  @Local assistantText: string = '';
  @Local recognizedText: string = '';
  @Local inputText: string = '';
  @Local connected: boolean = false;
  @Local listening: boolean = false;
  @Local microphoneAvailable: boolean = false;
  @Local answerReady: boolean = false;
  @Local finishing: boolean = false;
  @Local completed: boolean = false;
  @Local report: string = '';
  @Local answered: number = 0;
  @Local assessmentId: number = 0;
  @Local packageStatus: string = '';
  @Local packageError: string = '';
  /** 本题回答倒计时（秒）；-1 表示倒计时未启动（播报中/已作答）。 */
  @Local countdownSeconds: number = -1;
  private client: AssessmentAgentClient = new AssessmentAgentClient();
  private scroller: Scroller = new Scroller();
  private webController: webview.WebviewController = new webview.WebviewController();
  private webReady: boolean = false;
  private everConnected: boolean = false;
  private currentEmotion: string = EMOTION_IDLE;
  /** 长者正在说话（ASR 识别中）→ 接收任务表情。 */
  private elderSpeaking: boolean = false;
  /** 长者超时未回答 → 检索资料表情。 */
  private timedOut: boolean = false;
  private countdownTotal: number = 0;
  private countdownTimerId: number = -1;

  private isWideLayout(): boolean {
    try {
      return BreakpointUtil.isWide(this.getUIContext().getWindowWidthBreakpoint());
    } catch (_error) {
      return false;
    }
  }

  private ballHeight(): number {
    return this.isWideLayout() ? 320 : 240;
  }

  private phaseLabel(): string {
    if (this.completed) return '已完成';
    if (!this.connected) return this.everConnected ? '连接断开' : '连接中';
    if (this.finishing || this.statusText.indexOf('生成') >= 0) return '处理中';
    if (this.listening) return '聆听中';
    if (this.answerReady) return this.microphoneAvailable ? '等待回答' : '文字回答';
    if (this.statusText.indexOf('提问') >= 0 || this.statusText.indexOf('播报') >= 0 ||
      this.assistantText.length > 0) return 'TTS 播报';
    return this.microphoneAvailable ? '等待回答' : '文字回答';
  }

  private phaseColor(): ResourceColor {
    if (this.completed) return $r('app.color.doctor_workspace_success');
    if (this.listening) return $r('app.color.doctor_workspace_success');
    if (this.finishing) return $r('app.color.doctor_workspace_warning');
    return $r('app.color.brand_blue');
  }

  /** 状态行文案：出错类信息优先展示，其余展示“姓名 · 阶段”。 */
  private statusLineText(): string {
    const errorState: boolean = !this.connected || this.microphoneAvailable === false ||
      this.statusText.indexOf('断开') >= 0 || this.statusText.indexOf('失败') >= 0 ||
      this.statusText.indexOf('错误') >= 0 || this.statusText.indexOf('异常') >= 0 ||
      this.statusText.indexOf('未授权') >= 0 || this.statusText.indexOf('不可用') >= 0;
    return errorState ? this.statusText : `${this.session.resident_name} · ${this.phaseLabel()}`;
  }

  private isStatusWarning(): boolean {
    return !this.connected || this.statusText.indexOf('断开') >= 0 || this.statusText.indexOf('失败') >= 0 ||
      this.statusText.indexOf('错误') >= 0 || this.statusText.indexOf('异常') >= 0 ||
      this.statusText.indexOf('未授权') >= 0 || this.statusText.indexOf('不可用') >= 0;
  }

  aboutToAppear(): void {
    void this.connect();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
    void this.client.close();
  }

  // ==================== 表情舞台（Grok Ball） ====================

  /** 按当前评估阶段推导表情 ID，并同步到 Web 舞台。
   *  优先级：完成 > 断线 > 长者说话(31) > 超时未答(40) > 生成报告(30)
   *  > 聆听(35/03) > TTS 播报(39) > 唤醒/待机。 */
  private syncEmotion(): void {
    let emotion: string = EMOTION_IDLE;
    if (this.completed) {
      emotion = EMOTION_DONE;
    } else if (!this.connected) {
      emotion = this.everConnected ? EMOTION_ERROR : EMOTION_WAKING;
    } else if (this.elderSpeaking) {
      emotion = EMOTION_RECEIVING;
    } else if (this.timedOut) {
      emotion = EMOTION_SEARCHING;
    } else if (this.finishing || this.statusText.indexOf('生成') >= 0 ||
      this.statusText.indexOf('确认完整回答') >= 0) {
      emotion = EMOTION_THINKING;
    } else if (this.listening || this.answerReady) {
      emotion = this.isCountdownUrgent() ? EMOTION_CURIOUS : EMOTION_LISTENING;
    } else if (this.assistantText.length > 0 || this.statusText.indexOf('播报') >= 0 ||
      this.statusText.indexOf('提问') >= 0) {
      emotion = EMOTION_REPLYING;
    } else if (!this.everConnected) {
      emotion = EMOTION_WAKING;
    }
    this.applyEmotion(emotion);
  }

  /** 进入新一轮问答交互时清除上一轮的说话/超时状态。 */
  private resetTurnInteractionState(): void {
    this.elderSpeaking = false;
    this.timedOut = false;
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

  // ==================== 回答倒计时 ====================

  private isCountdownActive(): boolean {
    return this.countdownSeconds >= 0;
  }

  private isCountdownUrgent(): boolean {
    return this.isCountdownActive() && this.countdownSeconds <= COUNTDOWN_URGENT_SECONDS;
  }

  /** 聆听窗口开启：按题库的 no_answer_timeout 启动倒计时。 */
  private startCountdown(): void {
    this.stopCountdown();
    const timeout: number = Math.round(this.session.no_answer_timeout);
    if (timeout <= 0) { return; }
    this.countdownTotal = timeout;
    this.countdownSeconds = timeout;
    this.countdownTimerId = setInterval((): void => {
      if (this.countdownSeconds <= 0) {
        this.stopCountdown();
        this.countdownSeconds = 0;
        // 超时未回答：检索资料表情，等待服务端跳转下一题。
        this.timedOut = true;
        this.elderSpeaking = false;
        this.statusText = '未检测到回答，即将进入下一题';
        this.syncEmotion();
        return;
      }
      this.countdownSeconds -= 1;
      if (this.countdownSeconds === COUNTDOWN_URGENT_SECONDS) {
        this.syncEmotion();
      }
    }, 1000);
  }

  private stopCountdown(holdRemainder: boolean = false): void {
    if (this.countdownTimerId !== -1) {
      clearInterval(this.countdownTimerId);
      this.countdownTimerId = -1;
    }
    if (!holdRemainder) {
      this.countdownSeconds = -1;
      this.countdownTotal = 0;
    }
  }

  // ==================== 会话流程 ====================

  private async connect(): Promise<void> {
    try {
      await this.requestMicrophonePermission();
      await this.client.connect(this.session.session_key, (event: AssessmentAgentEvent): void => {
        this.handleEvent(event);
      }, (): void => {
        this.connected = false;
        if (!this.completed) { this.statusText = '连接已断开，可返回后重新进入评估'; }
        this.stopCountdown();
        this.syncEmotion();
      });
      this.connected = true;
      this.everConnected = true;
      this.statusText = '评估服务已连接';
      this.syncEmotion();
      if (this.microphoneAvailable) {
        await this.client.prepareMicrophone();
      }
    } catch (_error) {
      this.statusText = '评估服务连接失败，请检查网络后重试';
      this.syncEmotion();
    }
  }

  private handleEvent(event: AssessmentAgentEvent): void {
    if (event.type === 'assess_begin') {
      this.statusText = `评估开始 · 共 ${event.total ?? this.session.questions.length} 题`;
    } else if (event.type === 'assess_question') {
      this.currentIndex = event.index ?? 0;
      this.currentTopic = event.topic ?? '';
      this.currentQuestion = event.question ?? '';
      this.assistantText = '';
      this.recognizedText = '';
      this.listening = false;
      this.answerReady = false;
      this.stopCountdown();
      this.resetTurnInteractionState();
      this.client.pauseMicrophone();
      this.statusText = '评估助手正在提问，请听完后再回答';
    } else if (event.type === 'asr') {
      const hadSpeech: boolean = this.recognizedText.length > 0;
      this.recognizedText += event.text ?? '';
      // 长者开口：接收任务表情；客户端倒计时使命结束（静默窗口交给服务端）。
      this.elderSpeaking = true;
      if (!hadSpeech) { this.stopCountdown(true); }
    } else if (event.type === 'start') {
      this.listening = false;
      this.answerReady = false;
      this.stopCountdown();
      this.resetTurnInteractionState();
      this.client.pauseMicrophone();
      this.assistantText = '';
      this.statusText = '评估助手正在播报…';
    } else if (event.type === 'text') {
      this.assistantText += event.content ?? '';
    } else if (event.type === 'end') {
      this.statusText = '正在完成问题播报…';
    } else if (event.type === 'await_playback') {
      this.statusText = '正在完成问题播报…';
    } else if (event.type === 'listen_ready') {
      this.statusText = this.microphoneAvailable ? '正在开启聆听…' : '正在准备文字回答…';
      void this.armAnswerCapture(event.turn_id ?? '');
    } else if (event.type === 'listening') {
      this.statusText = this.microphoneAvailable ? '现在可以回答，正在聆听…' : '现在可以使用文字回答';
      this.listening = this.microphoneAvailable;
      this.answerReady = true;
      this.timedOut = false;
      this.startCountdown();
    } else if (event.type === 'assess_answer') {
      this.answered = Math.max(this.answered, event.index !== undefined ? event.index + 1 : this.answered);
      this.stopCountdown();
    } else if (event.type === 'assess_status') {
      this.listening = false;
      this.answerReady = false;
      this.stopCountdown();
      this.resetTurnInteractionState();
      this.client.pauseMicrophone();
      this.statusText = event.status === 'generating' ? '正在生成并保存评估报告…' :
        event.status === 'recognizing' ? '正在确认完整回答…' : this.statusText;
    } else if (event.type === 'assess_summary') {
      this.completed = true;
      this.finishing = false;
      this.report = event.report ?? '';
      this.answered = event.answered ?? this.answered;
      this.statusText = '评估已完成，结果已保存到长者评估';
      void this.client.stopMicrophone();
      this.listening = false;
      this.stopCountdown();
      this.resetTurnInteractionState();
      void this.refreshCompletedAssessment(0);
    } else if (event.type === 'error') {
      this.statusText = event.message ?? '评估服务发生错误';
      this.stopCountdown();
    }
    this.syncEmotion();
  }

  private async refreshCompletedAssessment(attempt: number = 0): Promise<void> {
    try {
      const response = await AssessmentAgentApi.getSession(this.session.session_key);
      if (response.code === 0 && response.data !== undefined) {
        this.assessmentId = response.data.assessment_id ?? 0;
        this.packageStatus = response.data.package_recommendation_status ?? 'pending';
        this.packageError = response.data.package_recommendation_error ?? '';
        if (response.data.report.length > 0) { this.report = response.data.report; }
      }
      await BusinessStore.getShared().load(true);
      if (this.packageStatus === 'pending' && attempt < 10) {
        setTimeout(() => { void this.refreshCompletedAssessment(attempt + 1); }, 2000);
      }
    } catch (_error) {
      // The report remains visible from the completion event. The ledger will
      // retry its normal server load when the doctor opens it again.
    }
  }

  private async requestMicrophonePermission(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, [MICROPHONE_PERMISSION]);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.microphoneAvailable = false;
        this.statusText = '麦克风未授权，可在下方使用文字回答';
        return;
      }
      this.microphoneAvailable = true;
    } catch (_error) {
      this.microphoneAvailable = false;
      this.statusText = '麦克风不可用，可在下方使用文字回答';
    }
  }

  private async armAnswerCapture(turnId: string): Promise<void> {
    if (turnId.length === 0) { return; }
    if (this.microphoneAvailable) {
      try {
        await this.client.prepareMicrophone();
        this.listening = this.client.resumeMicrophone();
        if (!this.listening) { this.microphoneAvailable = false; }
      } catch (_error) {
        this.microphoneAvailable = false;
        this.listening = false;
        this.statusText = '麦克风启动失败，本题可使用文字回答';
      }
    }
    try {
      await this.client.confirmCaptureReady(turnId);
    } catch (_error) {
      this.statusText = '评估连接异常，请返回后重新进入';
    }
  }

  private async sendTextAnswer(): Promise<void> {
    const text: string = this.inputText.trim();
    if (!this.connected || !this.answerReady || text.length === 0 || this.completed || this.finishing) { return; }
    this.answerReady = false;
    this.listening = false;
    this.stopCountdown();
    this.client.pauseMicrophone();
    this.inputText = '';
    this.recognizedText = text;
    // 文字回答同样视为“回答已提交”，直到服务端进入确认/生成阶段。
    this.elderSpeaking = true;
    this.timedOut = false;
    this.syncEmotion();
    await this.client.sendText(text);
  }

  private async finishAssessment(): Promise<void> {
    if (!this.connected || this.completed || this.finishing) { return; }
    this.finishing = true;
    this.stopCountdown();
    this.statusText = '正在结束评估并生成报告…';
    this.syncEmotion();
    await this.client.stopAssessment();
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
      scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR }
    };
  }

  // ==================== 视图（简洁对话式） ====================

  /** 右上角迷你倒计时：环形表盘 + 秒数，无卡片。 */
  @Builder
  private countdownPill() {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Progress({
          value: this.isCountdownActive() ? this.countdownSeconds :
            (this.countdownTotal > 0 ? this.countdownTotal : 1),
          total: this.countdownTotal > 0 ? this.countdownTotal : 1, type: ProgressType.Ring
        })
          .width(38).height(38).style({ strokeWidth: 5 })
          .color(this.isCountdownUrgent() ? $r('app.color.doctor_workspace_warning') :
            $r('app.color.brand_blue'))
        Text(this.isCountdownActive() ? `${this.countdownSeconds}` : '--')
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      }
      Text(this.isCountdownUrgent() ? '快想一想吧' : this.isCountdownActive() ? '超时将跳过本题' : '回答倒计时')
        .fontSize(12).fontColor(this.isCountdownUrgent() ? $r('app.color.doctor_workspace_warning') :
        $r('sys.color.font_tertiary'))
    }
    .padding({ left: 12, right: 14, top: 8, bottom: 8 })
    .borderRadius(999)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .accessibilityText(this.isCountdownActive() ?
      `回答倒计时剩余${this.countdownSeconds}秒` : '回答倒计时尚未启动')
  }

  /** AI 气泡：评估助手说的话（当前问题或正在播报的内容）。 */
  @Builder
  private aiBubble() {
    Row() {
      Column({ space: 4 }) {
        if (this.currentTopic.length > 0) {
          Text(this.currentTopic).fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
        }
        Text(this.assistantText.length > 0 ? this.assistantText :
          (this.currentQuestion.length > 0 ? this.currentQuestion : '连接成功后，我会开始提问，请听我说完再回答。'))
          .fontSize(17).lineHeight(28)
          .fontColor($r('sys.color.font_primary'))
      }.alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '82%' })
      .padding({ left: 18, right: 18, top: 14, bottom: 14 })
      .backgroundColor(AI_BUBBLE_BG)
      .borderRadius(20)
    }.width('100%').justifyContent(FlexAlign.Start)
      .accessibilityGroup(true)
      .accessibilityText(`评估助手说：${this.assistantText.length > 0 ? this.assistantText : this.currentQuestion}`)
  }

  /** 长人气泡：识别到的回答；聆听中未开口时显示省略号占位。 */
  @Builder
  private elderBubble() {
    if (!this.completed && (this.recognizedText.length > 0 || this.listening)) {
      Row() {
        Text(this.recognizedText.length > 0 ? this.recognizedText : '……')
          .fontSize(17).lineHeight(28)
          .fontColor(Color.White)
          .constraintSize({ maxWidth: '82%' })
          .padding({ left: 18, right: 18, top: 14, bottom: 14 })
          .backgroundColor(ELDER_BUBBLE_BG)
          .borderRadius(20)
      }.width('100%').justifyContent(FlexAlign.End)
      .accessibilityGroup(true)
      .accessibilityText(`老人回答：${this.recognizedText.length > 0 ? this.recognizedText : '正在聆听'}`)
    }
  }

  /** 中央表情球：透明背景，直接浮在页面底色上。 */
  @Builder
  private ballStage() {
    Column({ space: 6 }) {
      Web({ src: $rawfile('grokball/assessment_stage.html'), controller: this.webController })
        .width('100%').height(this.ballHeight())
        .javaScriptAccess(true)
        .zoomAccess(false)
        .backgroundColor(Color.Transparent)
        .onPageEnd((): void => { this.onStageReady(); })
      Text(this.statusLineText())
        .fontSize(12).fontColor(this.isStatusWarning() ?
          $r('app.color.doctor_workspace_warning') : $r('sys.color.font_tertiary'))
        .textAlign(TextAlign.Center).maxLines(2)
        .accessibilityText(this.statusLineText())
    }.width('100%').alignItems(HorizontalAlign.Center)
  }

  /** 文字回答输入行（麦克风不可用时的兜底 + 主动补录）。 */
  @Builder
  private composer() {
    if (!this.completed) {
      Row({ space: 10 }) {
        TextInput({ placeholder: this.answerReady ? '也可以在这里输入文字回答' : '等待本题播报完成后可输入',
          text: this.inputText })
          .layoutWeight(1).height(44).backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(999).border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .accessibilityText('文字回答输入框')
          .onChange((value: string): void => { this.inputText = value; })
          .onSubmit((): void => { void this.sendTextAnswer(); })
        Button('发送').height(44).padding({ left: 20, right: 20 }).borderRadius(999)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .enabled(this.connected && this.answerReady && this.inputText.trim().length > 0 &&
            !this.completed && !this.finishing)
          .accessibilityDescription(this.answerReady ? '提交本题文字回答' : '请等待本题播报完成')
          .onClick((): void => { void this.sendTextAnswer(); })
      }.width('100%')
    }
  }

  @Builder
  private assessmentActions() {
    if (this.completed) {
      if (this.isWideLayout()) {
        Row({ space: 10 }) {
          Button('返回工作台').height(44).borderRadius(12)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            .onClick(() => this.onClose())
          if (this.assessmentId > 0) {
            Button('查看完整报告').height(44).borderRadius(12).fontColor(Color.White)
              .backgroundColor($r('app.color.brand_blue')).onClick(() => this.onViewReport(this.assessmentId))
          }
        }.width('100%').justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          if (this.assessmentId > 0) {
            Button('查看完整报告').width('100%').height(46).borderRadius(12).fontColor(Color.White)
              .backgroundColor($r('app.color.brand_blue')).onClick(() => this.onViewReport(this.assessmentId))
          }
          Button('返回工作台').width('100%').height(46).borderRadius(12)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            .onClick(() => this.onClose())
        }.width('100%')
      }
    } else if (this.isWideLayout()) {
      Row({ space: 10 }) {
        Button('保存并返回').height(40).borderRadius(999)
          .fontColor($r('sys.color.font_secondary'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onClick(() => this.onClose())
        Button(this.finishing ? '正在生成报告…' : '提前结束并生成报告').height(40).borderRadius(999)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('app.color.doctor_workspace_warning') })
          .enabled(this.connected && !this.finishing).onClick(() => { void this.finishAssessment(); })
      }.width('100%').justifyContent(FlexAlign.Center)
    } else {
      Column({ space: 10 }) {
        Button(this.finishing ? '正在生成报告…' : '提前结束并生成报告').width('100%').height(44).borderRadius(999)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('app.color.doctor_workspace_warning') })
          .enabled(this.connected && !this.finishing).onClick(() => { void this.finishAssessment(); })
        Button('保存并返回').width('100%').height(44).borderRadius(999)
          .fontColor($r('sys.color.font_secondary'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onClick(() => this.onClose())
      }.width('100%')
    }
  }

  /** 完成态的 AI 气泡内容：结果摘要（替代原完成卡片）。 */
  @Builder
  private completedBubble() {
    Row() {
      Column({ space: 8 }) {
        Text('评估已完成').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_success'))
        Text(`已记录 ${this.answered} 题，报告已保存，等待医师复核。`)
          .fontSize(17).lineHeight(28).fontColor($r('sys.color.font_primary'))
        if (this.packageStatus === 'assigned') {
          Text('已根据评估生成护理套餐建议并通知护工，请复核后执行。')
            .fontSize(13).fontColor($r('app.color.doctor_workspace_success'))
        } else if (this.packageStatus === 'failed') {
          Text(`套餐建议生成失败：${this.packageError || '请稍后重试或人工选择套餐'}`)
            .fontSize(13).fontColor($r('app.color.doctor_workspace_danger'))
        } else if (this.assessmentId > 0) {
          Text('正在匹配护理套餐…').fontSize(13).fontColor($r('sys.color.font_tertiary'))
        }
      }.alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '82%' })
      .padding({ left: 18, right: 18, top: 14, bottom: 14 })
      .backgroundColor(AI_BUBBLE_BG)
      .borderRadius(20)
    }.width('100%').justifyContent(FlexAlign.Start)
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 10 }) {
          if (!this.completed) {
            Row() {
              Blank()
              this.countdownPill()
            }.width('100%')
          }
          if (this.completed) {
            this.completedBubble()
          } else {
            this.aiBubble()
          }
          this.ballStage()
          this.elderBubble()
          Blank().height(4)
          this.composer()
          this.assessmentActions()
        }
        .constraintSize({ maxWidth: 780 })
        .width('100%')
        .padding({ left: this.isWideLayout() ? 28 : 16, right: this.isWideLayout() ? 28 : 16,
          top: 72 + this.statusBarHeight, bottom: 20 + this.naviIndicatorHeight })
        .alignItems(HorizontalAlign.Center)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .hideBackButton(false)
    .onBackPressed((): boolean => { this.onClose(); return true; })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: '语音评估' } }, style: this.titleBarStyle() })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
