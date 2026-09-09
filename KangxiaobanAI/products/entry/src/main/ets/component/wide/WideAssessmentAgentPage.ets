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
/** Mood Mates 云宝表情 ID（见 rawfile/moodmates/data/emotions.js，编号契约永不重排）。 */
const EMOTION_IDLE: string = '02'; // 待机放空
const EMOTION_WAKING: string = '01'; // 连接/唤醒
const EMOTION_CURIOUS: string = '03'; // 倒计时即将到点的温和提醒
const EMOTION_LISTENING: string = '35'; // 等待输入（聆听）
const EMOTION_REPLYING: string = '39'; // 输出回复（嘴随播报开合）
const EMOTION_THINKING: string = '30'; // 思考中（生成报告）
const EMOTION_DONE: string = '33'; // 任务完成（撒花）
const EMOTION_ERROR: string = '34'; // 出错/断线
const COUNTDOWN_URGENT_SECONDS: number = 10;

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
  private countdownTotal: number = 0;
  private countdownTimerId: number = -1;

  private isWideLayout(): boolean {
    try {
      return BreakpointUtil.isWide(this.getUIContext().getWindowWidthBreakpoint());
    } catch (_error) {
      return false;
    }
  }

  private stageHeight(): number {
    return this.isWideLayout() ? 380 : 250;
  }

  private currentProgress(): number {
    const total: number = this.session.questions.length;
    return total > 0 ? Math.min(this.currentIndex + 1, total) : 0;
  }

  private progressPercent(): number {
    const total: number = this.session.questions.length;
    if (total <= 0) return 0;
    return Math.round(this.currentProgress() * 100 / total);
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

  aboutToAppear(): void {
    void this.connect();
  }

  aboutToDisappear(): void {
    this.stopCountdown();
    void this.client.close();
  }

  // ==================== 表情舞台（Mood Mates 云宝） ====================

  /** 按当前评估阶段推导表情 ID，并同步到 Web 舞台。 */
  private syncEmotion(): void {
    let emotion: string = EMOTION_IDLE;
    if (this.completed) {
      emotion = EMOTION_DONE;
    } else if (!this.connected) {
      emotion = this.everConnected ? EMOTION_ERROR : EMOTION_WAKING;
    } else if (this.finishing) {
      emotion = EMOTION_THINKING;
    } else if (this.listening || this.answerReady) {
      emotion = this.isCountdownUrgent() ? EMOTION_CURIOUS : EMOTION_LISTENING;
    } else if (this.assistantText.length > 0 || this.statusText.indexOf('播报') >= 0 ||
      this.statusText.indexOf('提问') >= 0) {
      emotion = EMOTION_REPLYING;
    } else if (this.statusText.indexOf('生成') >= 0) {
      emotion = EMOTION_THINKING;
    } else if (!this.everConnected) {
      emotion = EMOTION_WAKING;
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
      this.client.pauseMicrophone();
      this.statusText = '评估助手正在提问，请听完后再回答';
    } else if (event.type === 'asr') {
      const hadSpeech: boolean = this.recognizedText.length > 0;
      this.recognizedText += event.text ?? '';
      // 长者开口后服务端的静默窗口接管节奏，客户端倒计时使命结束。
      if (!hadSpeech) { this.stopCountdown(true); }
    } else if (event.type === 'start') {
      this.listening = false;
      this.answerReady = false;
      this.stopCountdown();
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
      this.startCountdown();
    } else if (event.type === 'assess_answer') {
      this.answered = Math.max(this.answered, event.index !== undefined ? event.index + 1 : this.answered);
      this.stopCountdown();
    } else if (event.type === 'assess_status') {
      this.listening = false;
      this.answerReady = false;
      this.stopCountdown();
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

  // ==================== 视图 ====================

  @Builder
  private sessionHeader() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text('语音评估').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
          Text(`${this.session.resident_name}${this.session.address}`)
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          Text(`${this.session.title} · 题库 V${this.session.question_version}`)
            .fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text(`${this.currentProgress()} / ${this.session.questions.length}`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          Text('当前进度').fontSize(11).fontColor($r('sys.color.font_tertiary'))
        }.alignItems(HorizontalAlign.End)
      }.width('100%').alignItems(VerticalAlign.Center)
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(6).borderRadius(3)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        Row().width(`${this.progressPercent()}%`).height(6).borderRadius(3)
          .backgroundColor($r('app.color.brand_blue'))
      }.width('100%').height(6)
    }.width('100%').padding(20).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .accessibilityGroup(true)
      .accessibilityText(`${this.session.resident_name}语音评估，进度${this.currentProgress()}共${this.session.questions.length}题`)
  }

  @Builder
  private questionPanel() {
    Column({ space: 20 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.questionmark_circle_fill')).fontSize(20)
          .fontColor([$r('app.color.brand_blue')])
        Text(this.currentTopic.length > 0 ? this.currentTopic : '当前问题')
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.brand_blue'))
      }.width('100%').alignItems(VerticalAlign.Center)

      Text(this.currentQuestion.length > 0 ? this.currentQuestion : '连接成功后，评估助手将自动播报第一题。')
        .width('100%').fontSize(this.isWideLayout() ? 26 : 22).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).lineHeight(this.isWideLayout() ? 40 : 33)

      if (this.assistantText.length > 0) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.speaker_wave_2_fill')).fontSize(16)
              .fontColor([$r('sys.color.icon_secondary')])
            Text('TTS 播报内容').fontSize(12).fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_secondary'))
          }.width('100%')
          Text(this.assistantText).width('100%').fontSize(14).lineHeight(23)
            .fontColor($r('sys.color.font_secondary'))
        }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12).alignItems(HorizontalAlign.Start)
      }
    }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: 240 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  /** 顶部：题目在左（weight 1），回答倒计时在右上角（固定宽）。 */
  @Builder
  private questionRow() {
    Row({ space: 16 }) {
      Column() { this.questionPanel() }.layoutWeight(1)
      Column() { this.countdownCard() }
        .width(this.isWideLayout() ? 216 : 150)
        .alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  /** 中央表情舞台：Mood Mates 云宝，表情随评估阶段实时切换。 */
  @Builder
  private expressionStage() {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width('100%').height('100%')
          .backgroundColor('#F3F7FF')
          .borderRadius(20)
        Web({ src: $rawfile('moodmates/assessment_stage.html'), controller: this.webController })
          .width('86%').height('86%')
          .javaScriptAccess(true)
          .zoomAccess(false)
          .backgroundColor(Color.Transparent)
          .onPageEnd((): void => { this.onStageReady(); })
      }.width('100%').height(this.stageHeight())
      Row({ space: 8 }) {
        Row().width(8).height(8).borderRadius(4).backgroundColor(this.phaseColor())
        Text(this.phaseLabel()).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('康小伴评估助手').fontSize(12).fontColor($r('sys.color.font_tertiary'))
          .margin({ left: 'auto' })
      }.width('100%').padding({ left: 6, right: 6 })
        .alignItems(VerticalAlign.Center)
        .accessibilityText(`评估助手表情，当前状态${this.phaseLabel()}`)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private countdownCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.timer')).fontSize(18)
          .fontColor([this.isCountdownUrgent() ? $r('app.color.doctor_workspace_warning') :
            $r('app.color.brand_blue')])
        Text('回答倒计时').fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.isCountdownActive() ? this.countdownSeconds :
            (this.countdownTotal > 0 ? this.countdownTotal : 1),
            total: this.countdownTotal > 0 ? this.countdownTotal : 1, type: ProgressType.Ring })
            .width(62).height(62).style({ strokeWidth: 7 })
            .color(this.isCountdownUrgent() ? $r('app.color.doctor_workspace_warning') :
              $r('app.color.brand_blue'))
          Text(this.isCountdownActive() ? `${this.countdownSeconds}` : '--')
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        }
        Column({ space: 3 }) {
          Text(this.isCountdownUrgent() ? '快想一想吧' : this.isCountdownActive() ? '请在倒计时内回答' : '等待播报完成')
            .fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.isCountdownUrgent() ? $r('app.color.doctor_workspace_warning') :
              $r('sys.color.font_primary'))
          Text(this.isCountdownActive() ? '超时本题将自动跳过' : '倒计时会在聆听开始后启动')
            .fontSize(11).fontColor($r('sys.color.font_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding(18)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .accessibilityGroup(true)
      .accessibilityText(this.isCountdownActive() ?
        `回答倒计时剩余${this.countdownSeconds}秒` : '倒计时尚未启动')
  }

  @Builder
  private voiceState() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row().width(34).height(34).borderRadius(17)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        SymbolGlyph(this.listening ? $r('sys.symbol.mic_fill') : $r('sys.symbol.waveform'))
          .fontSize(18).fontColor([this.phaseColor()])
      }
      Column({ space: 2 }) {
        Text(this.phaseLabel()).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.statusText).fontSize(12).fontColor($r('sys.color.font_secondary')).maxLines(2)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (!this.connected && !this.completed) {
        LoadingProgress().width(20).height(20).color($r('app.color.brand_blue'))
      } else {
        Row().width(8).height(8).borderRadius(4).backgroundColor(this.phaseColor())
      }
    }.width('100%').alignItems(VerticalAlign.Center)
      .accessibilityGroup(true).accessibilityText(`${this.phaseLabel()}，${this.statusText}`)
  }

  @Builder
  private answerPanel() {
    Column({ space: 16 }) {
      this.voiceState()
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Column({ space: 8 }) {
        Text('识别结果').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.recognizedText.length > 0 ? this.recognizedText :
          (this.answerReady ? '请开始回答，识别文字会实时显示在这里。' : '等待本题播报完成。'))
          .width('100%').fontSize(16).lineHeight(25)
          .fontColor(this.recognizedText.length > 0 ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
      }.width('100%').constraintSize({ minHeight: 110 }).padding(16)
        .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      Row({ space: 10 }) {
        TextInput({ placeholder: '麦克风不可用时，可输入文字回答', text: this.inputText })
          .layoutWeight(1).height(46).backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12).accessibilityText('文字回答输入框')
          .onChange((value: string): void => { this.inputText = value; })
          .onSubmit((): void => { void this.sendTextAnswer(); })
        Button('发送').height(46).padding({ left: 18, right: 18 }).borderRadius(12)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .enabled(this.connected && this.answerReady && this.inputText.trim().length > 0 &&
            !this.completed && !this.finishing)
          .accessibilityDescription(this.answerReady ? '提交本题文字回答' : '请等待本题播报完成')
          .onClick((): void => { void this.sendTextAnswer(); })
      }.width('100%')
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(18)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private assessmentActions() {
    if (this.isWideLayout()) {
      Row({ space: 10 }) {
        Button('保存并返回').height(44).borderRadius(12)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_secondary')).onClick(() => this.onClose())
        Button(this.finishing ? '正在生成报告…' : '提前结束并生成报告').height(44).borderRadius(12)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('app.color.doctor_workspace_warning') })
          .enabled(this.connected && !this.finishing).onClick(() => { void this.finishAssessment(); })
      }.width('100%').justifyContent(FlexAlign.End)
    } else {
      Column({ space: 10 }) {
        Button(this.finishing ? '正在生成报告…' : '提前结束并生成报告').width('100%').height(46).borderRadius(12)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('app.color.doctor_workspace_warning') })
          .enabled(this.connected && !this.finishing).onClick(() => { void this.finishAssessment(); })
        Button('保存并返回').width('100%').height(46).borderRadius(12)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_secondary')).onClick(() => this.onClose())
      }.width('100%')
    }
  }

  @Builder
  private completedCard() {
    Column({ space: 20 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(48).height(48).borderRadius(24)
            .backgroundColor($r('sys.color.comp_background_secondary'))
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(30)
            .fontColor([$r('app.color.doctor_workspace_success')])
        }
        Column({ space: 3 }) {
          Text('评估已完成').fontSize(23).fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(`已记录 ${this.answered} 题，报告已保存，等待医师复核。`)
            .fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)

      Column({ space: 10 }) {
        Text('评估摘要').fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.report.length > 0 ? this.report : '报告已保存，可进入完整评估报告查看。')
          .width('100%').fontSize(15).lineHeight(25).fontColor($r('sys.color.font_primary'))
      }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
        .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)

      if (this.packageStatus === 'assigned') {
        Text('已生成套餐建议并通知护工，请医师复核后执行。').fontSize(13)
          .fontColor($r('app.color.doctor_workspace_success')).width('100%')
      } else if (this.packageStatus === 'failed') {
        Text(`套餐建议生成失败：${this.packageError || '请稍后重试或人工选择套餐'}`).fontSize(13)
          .fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      } else if (this.assessmentId > 0) {
        Text('正在匹配护理套餐…').fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
      }

      if (this.isWideLayout()) {
        Row({ space: 10 }) {
          Button('返回工作台').height(44).borderRadius(12)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.onClose())
          if (this.assessmentId > 0) {
            Button('查看完整报告').height(44).borderRadius(12).fontColor(Color.White)
              .backgroundColor($r('app.color.brand_blue')).onClick(() => this.onViewReport(this.assessmentId))
          }
        }.width('100%').justifyContent(FlexAlign.End)
      } else {
        Column({ space: 10 }) {
          if (this.assessmentId > 0) {
            Button('查看完整报告').width('100%').height(46).borderRadius(12).fontColor(Color.White)
              .backgroundColor($r('app.color.brand_blue')).onClick(() => this.onViewReport(this.assessmentId))
          }
          Button('返回工作台').width('100%').height(46).borderRadius(12)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.onClose())
        }.width('100%')
      }
    }.width('100%').padding(28).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(18)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          this.sessionHeader()
          if (this.completed) {
            this.expressionStage()
            this.completedCard()
          } else {
            this.questionRow()
            if (this.isWideLayout()) {
              Row({ space: 16 }) {
                Column() { this.expressionStage() }.layoutWeight(1)
                Column() { this.answerPanel() }.layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
            } else {
              this.expressionStage()
              this.answerPanel()
            }
            this.assessmentActions()
          }
        }.width('100%').constraintSize({ maxWidth: 1240 })
          .padding({ left: this.isWideLayout() ? 28 : 16, right: this.isWideLayout() ? 28 : 16,
            top: 80 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
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
