import { HermesChatModel, HermesMessage, HermesSession } from '../model/HermesModels';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  SuffixIcon,
  SuffixText
} from '@kit.UIDesignKit';

@ComponentV2
export struct HermesChatPage {
  @Param split: boolean = false;
  @Param @Require model: HermesChatModel;
  @Event onSend: (model: HermesChatModel, content: string, timeLabel: string) => Promise<void> =
    (_model: HermesChatModel, _content: string, _timeLabel: string): Promise<void> => Promise.resolve();
  @Event onSelectSession: (sessionId: string) => void = (_sessionId: string) => {};
  @Event onRetrySessions: () => void = () => {};
  @Event onRetryMessages: () => void = () => {};
  @Event onLoadOlderMessages: (model: HermesChatModel) => Promise<number> =
    (_model: HermesChatModel): Promise<number> => Promise.resolve(0);
  @Event onSessionExpired: () => void = () => {};
  private messageScroller: ListScroller = new ListScroller();

  private nowLabel(): string {
    const date: Date = new Date();
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private scrollToLatest(): void {
    setTimeout(() => {
      if (this.model.messages.length > 0) {
        this.messageScroller.scrollToIndex(this.model.messages.length - 1, true, ScrollAlign.END);
      }
    }, 40);
  }

  private activeSession(): HermesSession | undefined {
    return this.model.sessions.find((session: HermesSession) => session.id === this.model.activeSessionId);
  }

  private activeSessionTitle(): string {
    return this.activeSession()?.title || (this.model.remoteMode ? '新会话' : 'HarmonyOS 移植计划');
  }

  private activeSessionModel(): string {
    return this.activeSession()?.model || '未指定模型';
  }

  private composerEnabled(): boolean {
    return !this.model.sending && this.model.messageLoadState !== 'unauthorized' &&
      this.model.messageLoadState !== 'loading';
  }

  private isUserMessage(message: HermesMessage): boolean {
    return message.role === 'user';
  }

  private messageRoleLabel(message: HermesMessage): string {
    if (message.role === 'user') {
      return '你';
    }
    if (message.role === 'assistant' || message.role === 'moa') {
      return 'Hermes';
    }
    if (message.role === 'tool') {
      return '工具';
    }
    if (message.role === 'command') {
      return '命令';
    }
    return '系统';
  }

  private async sendMessage(): Promise<void> {
    const content: string = this.model.inputText.trim();
    if (content.length === 0 || this.model.sending) {
      return;
    }
    const timeLabel: string = this.nowLabel();
    await this.onSend(this.model, content, timeLabel);
    this.scrollToLatest();
  }

  private async loadOlderMessages(): Promise<void> {
    if (this.model.loadingOlderMessages || !this.model.hasMoreMessages) {
      return;
    }
    const previousFirstId: string = this.model.messages.length > 0 ? this.model.messages[0].id : '';
    const addedCount: number = await this.onLoadOlderMessages(this.model);
    if (addedCount <= 0 || previousFirstId.length === 0) {
      return;
    }
    setTimeout(() => {
      const previousFirstIndex: number = this.model.messages.findIndex((message: HermesMessage) =>
        message.id === previousFirstId);
      if (previousFirstIndex >= 0) {
        this.messageScroller.scrollToIndex(previousFirstIndex, false, ScrollAlign.START);
      }
    }, 40);
  }

  @Builder
  private sessionLoadState() {
    if (this.model.sessionLoadState === 'loading') {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.hermes_text_secondary'))
        Text('正在加载真实会话…')
          .fontSize($r('app.float.hermes_text_body'))
          .fontColor($r('app.color.hermes_text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.model.sessionLoadState === 'empty') {
      Column({ space: 8 }) {
        Text('暂无会话')
          .fontSize($r('app.float.hermes_text_title'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hermes_text_primary'))
        Text('真实服务器已连接，但当前 Profile 没有可显示的会话。')
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .padding(20)
      .justifyContent(FlexAlign.Center)
    } else if (this.model.sessionLoadState === 'error' || this.model.sessionLoadState === 'unauthorized') {
      Column({ space: 12 }) {
        Text(this.model.sessionLoadState === 'unauthorized' ? '登录已失效' : '会话加载失败')
          .fontSize($r('app.float.hermes_text_title'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hermes_text_primary'))
        Text(this.model.sessionErrorText)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_error'))
          .textAlign(TextAlign.Center)
        Button(this.model.sessionLoadState === 'unauthorized' ? '返回登录' : '重试')
          .height(36)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_on_accent'))
          .backgroundColor($r('app.color.hermes_accent'))
          .borderRadius($r('app.float.hermes_radius_small'))
          .onClick(() => {
            if (this.model.sessionLoadState === 'unauthorized') {
              this.onSessionExpired();
            } else {
              this.onRetrySessions();
            }
          })
      }
      .width('100%')
      .layoutWeight(1)
      .padding(20)
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private messageLoadState() {
    if (this.model.messageLoadState === 'loading') {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.hermes_text_secondary'))
        Text('正在加载会话消息…')
          .fontSize($r('app.float.hermes_text_body'))
          .fontColor($r('app.color.hermes_text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.model.messageLoadState === 'empty') {
      Column({ space: 8 }) {
        Text('这个会话还没有消息')
          .fontSize($r('app.float.hermes_text_title'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hermes_text_primary'))
        Text('可以直接从下方输入框开始。')
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.model.messageLoadState === 'error' || this.model.messageLoadState === 'unauthorized') {
      Column({ space: 12 }) {
        Text(this.model.messageLoadState === 'unauthorized' ? '登录已失效' : '历史消息加载失败')
          .fontSize($r('app.float.hermes_text_title'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hermes_text_primary'))
        Text(this.model.messageErrorText)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_error'))
          .textAlign(TextAlign.Center)
        Button(this.model.messageLoadState === 'unauthorized' ? '返回登录' : '重试')
          .height(36)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_on_accent'))
          .backgroundColor($r('app.color.hermes_accent'))
          .borderRadius($r('app.float.hermes_radius_small'))
          .onClick(() => {
            if (this.model.messageLoadState === 'unauthorized') {
              this.onSessionExpired();
            } else {
              this.onRetryMessages();
            }
          })
      }
      .width('100%')
      .layoutWeight(1)
      .padding(20)
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private sessionList() {
    Column() {
      HdsListItemCard({
        textItem: {
          primaryText: { text: '会话' },
          secondaryText: { text: this.model.remoteMode ? 'Hermes Server' : '本地预览' }
        },
        suffixItem: new SuffixText({ text: `${this.model.sessions.length}` }),
        cardHeight: 58,
        cardBorderRadius: 0,
        hoverBorderRadius: 0,
        cardPrefixMargin: 0,
        cardSuffixMargin: 8,
        cardBackgroundColor: Color.Transparent,
        accessibilityOptions: {
          accessibilityText: `会话，共 ${this.model.sessions.length} 个`,
          accessibilityLevel: 'yes'
        }
      })
      .width('100%')
      .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border') })

      TextInput({ placeholder: '搜索会话' })
        .height(36)
        .margin({ left: 10, right: 10, top: 10, bottom: 6 })
        .fontSize($r('app.float.hermes_text_body'))
        .backgroundColor($r('app.color.hermes_bg_surface'))
        .border({ width: 1, color: $r('app.color.hermes_border') })
        .borderRadius($r('app.float.hermes_radius_small'))

      if (this.model.sessionLoadState === 'loading' || this.model.sessionLoadState === 'empty' ||
        this.model.sessionLoadState === 'error' || this.model.sessionLoadState === 'unauthorized') {
        this.sessionLoadState()
      } else {
        List({ space: 4 }) {
          ForEach(this.model.sessions, (session: HermesSession) => {
            ListItem() {
              HdsListItemCard({
                textItem: {
                  primaryText: { text: session.title },
                  secondaryText: { text: `${session.preview} · ${session.model}` }
                },
                suffixItem: new SuffixText({ text: session.updatedAt }),
                cardHeight: 78,
                cardBorderRadius: 8,
                cardPrefixMargin: 2,
                cardSuffixMargin: 0,
                hoverBorderRadius: 8,
                cardBackgroundColor: this.model.activeSessionId === session.id ?
                  $r('app.color.hermes_bg_surface') : Color.Transparent,
                cardId: `session-${session.id}`,
                accessibilityOptions: {
                  accessibilityText: `${session.title}，${session.updatedAt}，${session.preview}`,
                  accessibilityDescription: `模型 ${session.model}`,
                  accessibilityLevel: 'yes',
                  accessibilityRole: AccessibilityRoleType.BUTTON,
                  accessibilitySelected: this.model.activeSessionId === session.id
                },
                onClick: () => {
                  this.onSelectSession(session.id);
                  if (!this.split) {
                    this.model.showSessions = false;
                  }
                }
              })
              .width('100%')
              .focusable(true)
              .focusOnTouch(true)
            }
          }, (session: HermesSession) => session.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 8, right: 8, bottom: 8 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_sidebar'))
  }

  @Builder
  private messageBubble(message: HermesMessage) {
    Row() {
      if (message.role === 'assistant' || message.role === 'moa') {
        Image($r('app.media.hermes_logo'))
          .width(28)
          .height(28)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .margin({ right: 8 })
          .accessibilityText('Hermes')
      }

      Column({ space: 7 }) {
        Row() {
          Text(this.messageRoleLabel(message))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.hermes_text_secondary'))
            .layoutWeight(1)
          Text(message.time)
            .fontSize(10)
            .fontColor($r('app.color.hermes_text_muted'))
        }
        .width('100%')

        if (message.pending) {
          Row({ space: 7 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color($r('app.color.hermes_text_secondary'))
            Text(message.content)
              .fontSize($r('app.float.hermes_text_body'))
              .fontColor($r('app.color.hermes_text_primary'))
              .lineHeight(22)
              .layoutWeight(1)
          }
          .width('100%')
        } else {
          Text(message.content)
            .fontSize($r('app.float.hermes_text_body'))
            .fontColor(message.failed ? $r('app.color.hermes_error') : $r('app.color.hermes_text_primary'))
            .lineHeight(22)
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width(this.split ? 680 : '82%')
      .padding({ left: 13, right: 13, top: 10, bottom: 10 })
      .backgroundColor(this.isUserMessage(message) ? $r('app.color.hermes_message_bubble') :
        $r('app.color.hermes_bg_surface'))
      .border({ width: 1, color: $r('app.color.hermes_border_light') })
      .borderRadius($r('app.float.hermes_radius_medium'))
    }
    .width('100%')
    .justifyContent(this.isUserMessage(message) ? FlexAlign.End : FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
    .accessibilityGroup(true)
    .accessibilityText(`${this.messageRoleLabel(message)}，${message.content}`)
  }

  @Builder
  private chatSurface() {
    Column() {
      HdsListItemCard({
        textItem: {
          primaryText: { text: this.activeSessionTitle() },
          secondaryText: { text: `${this.model.remoteMode ? '真实服务' : 'default'} · ${this.activeSessionModel()}` }
        },
        suffixItem: this.split ? new SuffixText({ text: '工具轨迹' }) : new SuffixIcon({
          iconValue: {
            symbol: new SymbolGlyphModifier($r('sys.symbol.chevron_right'))
              .fontColor([$r('app.color.hermes_text_primary')])
          },
          onClick: () => {
            this.model.showSessions = true;
          },
          accessibilityOptions: {
            accessibilityText: '打开会话列表',
            accessibilityRole: AccessibilityRoleType.BUTTON
          }
        }),
        cardHeight: 64,
        cardBorderRadius: 0,
        hoverBorderRadius: 0,
        cardPrefixMargin: 0,
        cardSuffixMargin: 8,
        cardBackgroundColor: $r('app.color.hermes_bg_surface'),
        accessibilityOptions: {
          accessibilityText: `${this.activeSessionTitle()}，${this.activeSessionModel()}`,
          accessibilityLevel: 'yes'
        }
      })
      .width('100%')
      .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border') })

      if (this.model.messageLoadState === 'loading' || this.model.messageLoadState === 'empty' ||
        this.model.messageLoadState === 'error' || this.model.messageLoadState === 'unauthorized') {
        this.messageLoadState()
      } else {
        List({ space: 12, scroller: this.messageScroller }) {
          if (this.model.hasMoreMessages || this.model.loadingOlderMessages ||
            this.model.olderMessageErrorText.length > 0) {
            ListItem() {
              Column({ space: 8 }) {
                if (this.model.loadingOlderMessages) {
                  Row({ space: 8 }) {
                    LoadingProgress()
                      .width(18)
                      .height(18)
                      .color($r('app.color.hermes_text_secondary'))
                    Text('正在加载更早消息…')
                      .fontSize($r('app.float.hermes_text_caption'))
                      .fontColor($r('app.color.hermes_text_secondary'))
                  }
                } else {
                  Button(this.model.olderMessageErrorText.length > 0 ? '重试加载更早消息' : '加载更早消息')
                    .height(34)
                    .fontSize($r('app.float.hermes_text_caption'))
                    .fontColor($r('app.color.hermes_text_primary'))
                    .backgroundColor($r('app.color.hermes_bg_secondary'))
                    .border({ width: 1, color: $r('app.color.hermes_border') })
                    .borderRadius($r('app.float.hermes_radius_small'))
                    .enabled(!this.model.loadingOlderMessages)
                    .onClick(() => this.loadOlderMessages())
                }
                if (this.model.olderMessageErrorText.length > 0) {
                  Text(this.model.olderMessageErrorText)
                    .fontSize(11)
                    .fontColor($r('app.color.hermes_error'))
                    .textAlign(TextAlign.Center)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .padding({ top: 4, bottom: 4 })
            }
          }
          ListItem() {
            Text(this.model.remoteMode ? '真实服务模式 · 会话与历史消息来自服务器；新消息当前使用 HTTP runOnce' :
              $r('app.string.mock_data_notice'))
              .fontSize(11)
              .fontColor($r('app.color.hermes_warning'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 8, bottom: 8 })
          }
          ForEach(this.model.messages, (message: HermesMessage) => {
            ListItem() {
              this.messageBubble(message)
            }
          }, (message: HermesMessage) => message.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: this.split ? 24 : 12, right: this.split ? 24 : 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.hermes_bg_primary'))
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(18)
              .fontColor([$r('app.color.hermes_text_primary')])
          }
            .width(34)
            .height(34)
            .fontSize(20)
            .fontColor($r('app.color.hermes_text_primary'))
            .backgroundColor($r('app.color.hermes_bg_secondary'))
            .borderRadius($r('app.float.hermes_radius_small'))
            .accessibilityText('添加附件')
          TextArea({ placeholder: $r('app.string.chat_placeholder'), text: this.model.inputText })
            .layoutWeight(1)
            .height(72)
            .fontSize($r('app.float.hermes_text_body'))
            .fontColor($r('app.color.hermes_text_primary'))
            .placeholderColor($r('app.color.hermes_text_muted'))
            .backgroundColor($r('app.color.hermes_bg_surface'))
            .border({ width: 1, color: $r('app.color.hermes_border') })
            .borderRadius($r('app.float.hermes_radius_medium'))
            .enabled(this.composerEnabled())
            .onChange((value: string) => this.model.inputText = value)
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            if (this.model.sending) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color($r('app.color.hermes_text_on_accent'))
            } else {
              SymbolGlyph($r('sys.symbol.arrow_up'))
                .fontSize(18)
                .fontColor([$r('app.color.hermes_text_on_accent')])
            }
          }
            .width(42)
            .height(42)
            .fontSize(18)
            .fontColor($r('app.color.hermes_text_on_accent'))
            .backgroundColor(this.model.inputText.trim().length > 0 && this.composerEnabled() ?
              $r('app.color.hermes_accent') :
              $r('app.color.hermes_text_muted'))
            .borderRadius(21)
            .enabled(this.model.inputText.trim().length > 0 && this.composerEnabled())
            .accessibilityText(this.model.sending ? '正在发送' : '发送消息')
            .onClick(() => this.sendMessage())
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Row() {
          Text(this.model.remoteMode ? '真实 HTTP runOnce · Socket.IO 流式与取消仍在适配' :
            'Enter 发送 · Shift+Enter 换行 · 本地预览')
            .fontSize(10)
            .fontColor($r('app.color.hermes_text_muted'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: this.split ? 24 : 10, right: this.split ? 24 : 10, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.hermes_bg_surface'))
      .border({ width: { top: 1 }, color: $r('app.color.hermes_border') })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (this.split) {
      Row() {
        Column() {
          this.sessionList()
        }
        .width(272)
        .height('100%')
        .border({ width: { right: 1 }, color: $r('app.color.hermes_border') })

        Column() {
          this.chatSurface()
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
    } else if (this.model.showSessions) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.sessionList()
        Button('返回对话')
          .height(34)
          .margin({ top: 12, right: 12 })
          .align(Alignment.TopEnd)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_primary'))
          .backgroundColor($r('app.color.hermes_bg_surface'))
          .border({ width: 1, color: $r('app.color.hermes_border') })
          .borderRadius($r('app.float.hermes_radius_small'))
          .onClick(() => this.model.showSessions = false)
      }
      .width('100%')
      .height('100%')
    } else {
      this.chatSurface()
    }
  }
}
