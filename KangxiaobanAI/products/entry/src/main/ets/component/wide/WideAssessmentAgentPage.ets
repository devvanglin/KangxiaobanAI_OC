import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import {
  HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TitleBarStyleOptions, hdsMaterial
} from '@kit.UIDesignKit';
import { AssessmentAgentApi, AssessmentAgentSession } from '../../network/AssessmentAgentApi';
import { AssessmentAgentClient, AssessmentAgentEvent } from '../../network/AssessmentAgentClient';
import { BusinessStore } from '../../network/BusinessStore';

const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

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
  private client: AssessmentAgentClient = new AssessmentAgentClient();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    void this.connect();
  }

  aboutToDisappear(): void {
    void this.client.close();
  }

  private async connect(): Promise<void> {
    try {
      await this.requestMicrophonePermission();
      await this.client.connect(this.session.session_key, (event: AssessmentAgentEvent): void => {
        this.handleEvent(event);
      }, (): void => {
        this.connected = false;
        if (!this.completed) { this.statusText = '连接已断开，可返回后重新进入评估'; }
      });
      this.connected = true;
      this.statusText = '评估服务已连接';
      if (this.microphoneAvailable) {
        await this.client.prepareMicrophone();
      }
    } catch (_error) {
      this.statusText = '评估服务连接失败，请检查网络后重试';
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
      this.client.pauseMicrophone();
      this.statusText = '评估助手正在提问，请听完后再回答';
    } else if (event.type === 'asr') {
      this.recognizedText += event.text ?? '';
    } else if (event.type === 'start') {
      this.listening = false;
      this.answerReady = false;
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
    } else if (event.type === 'assess_answer') {
      this.answered = Math.max(this.answered, event.index !== undefined ? event.index + 1 : this.answered);
    } else if (event.type === 'assess_status') {
      this.listening = false;
      this.answerReady = false;
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
      void this.refreshCompletedAssessment();
    } else if (event.type === 'error') {
      this.statusText = event.message ?? '评估服务发生错误';
    }
  }

  private async refreshCompletedAssessment(): Promise<void> {
    try {
      const response = await AssessmentAgentApi.getSession(this.session.session_key);
      if (response.code === 0 && response.data !== undefined) {
        this.assessmentId = response.data.assessment_id ?? 0;
        if (response.data.report.length > 0) { this.report = response.data.report; }
      }
      await BusinessStore.getShared().load(true);
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
    this.client.pauseMicrophone();
    this.inputText = '';
    this.recognizedText = text;
    await this.client.sendText(text);
  }

  private async finishAssessment(): Promise<void> {
    if (!this.connected || this.completed || this.finishing) { return; }
    this.finishing = true;
    this.statusText = '正在结束评估并生成报告…';
    await this.client.stopAssessment();
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
      scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR }
    };
  }

  @Builder
  private progressCard() {
    Row({ space: 16 }) {
      Column({ space: 4 }) {
        Text(`${this.session.resident_name}${this.session.address}`).fontSize(19).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(`${this.session.title} · V${this.session.question_version}`)
          .fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(`${Math.min(this.currentIndex + 1, this.session.questions.length)} / ${this.session.questions.length}`)
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_blue'))
    }.width('100%').padding(20).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private questionCard() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.waveform')).fontSize(22).fontColor([$r('app.color.brand_blue')])
        Text(this.currentTopic.length > 0 ? this.currentTopic : '准备评估')
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.brand_blue'))
      }.width('100%')
      Text(this.currentQuestion.length > 0 ? this.currentQuestion : '评估服务连接后将自动播报第一题。')
        .width('100%').fontSize(26).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).lineHeight(40)
      if (this.assistantText.length > 0) {
        Text(this.assistantText).width('100%').fontSize(15).fontColor($r('sys.color.font_secondary'))
          .padding(14).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)
      }
    }.width('100%').padding(28).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(18)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private answerCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        SymbolGlyph(this.listening ? $r('sys.symbol.mic_fill') : $r('sys.symbol.keyboard'))
          .fontSize(20).fontColor([this.listening ? $r('app.color.doctor_workspace_success') : $r('sys.color.icon_secondary')])
        Text(this.statusText).fontSize(14).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
      }.width('100%')
      Text(this.recognizedText.length > 0 ? this.recognizedText : '长者的语音识别文字会显示在这里')
        .width('100%').fontSize(18).fontColor(this.recognizedText.length > 0 ?
          $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
        .padding(16).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)
      Row({ space: 10 }) {
        TextInput({ placeholder: '也可以输入文字回答', text: this.inputText })
          .layoutWeight(1).height(44).backgroundColor($r('sys.color.comp_background_secondary'))
          .onChange((value: string): void => { this.inputText = value; })
          .onSubmit((): void => { void this.sendTextAnswer(); })
        Button('发送').height(44).borderRadius(12).fontColor(Color.White)
          .backgroundColor($r('app.color.brand_blue'))
          .enabled(this.connected && this.answerReady && this.inputText.trim().length > 0 && !this.completed && !this.finishing)
          .onClick((): void => { void this.sendTextAnswer(); })
      }.width('100%')
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private completedCard() {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(48).fontColor([$r('app.color.doctor_workspace_success')])
      Text('评估已完成').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(`已记录 ${this.answered} 题，完整报告已进入“长者评估”，请医师复核后使用。`)
        .fontSize(14).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      Scroll() {
        Text(this.report).width('100%').fontSize(14).fontColor($r('sys.color.font_primary')).lineHeight(24)
      }.width('100%').constraintSize({ maxHeight: 360 }).padding(16)
        .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)
      Button('返回工作台').height(44).borderRadius(12).fontColor(Color.White)
        .backgroundColor($r('app.color.brand_blue')).onClick(() => this.onClose())
      if (this.assessmentId > 0) {
        Button('查看完整评估报告').height(44).borderRadius(12)
          .fontColor($r('app.color.brand_blue')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.onViewReport(this.assessmentId))
      }
    }.width('100%').padding(28).alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(18)
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.completed) {
            this.completedCard()
          } else {
            this.progressCard()
            this.questionCard()
            this.answerCard()
            Row({ space: 10 }) {
              Button('保存状态并返回').height(44).borderRadius(12)
                .backgroundColor($r('sys.color.comp_background_secondary')).onClick(() => this.onClose())
              Button(this.finishing ? '正在生成报告…' : '提前结束并生成报告').height(44).borderRadius(12)
                .fontColor(Color.White).backgroundColor($r('app.color.doctor_workspace_warning'))
                .enabled(this.connected && !this.finishing).onClick(() => { void this.finishAssessment(); })
            }.width('100%').justifyContent(FlexAlign.End)
          }
        }.width('100%').constraintSize({ maxWidth: 1120 })
          .padding({ left: 28, right: 28, top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }
    .hideBackButton(false)
    .onBackPressed((): boolean => { this.onClose(); return true; })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: '长者语音评估' } }, style: this.titleBarStyle() })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
