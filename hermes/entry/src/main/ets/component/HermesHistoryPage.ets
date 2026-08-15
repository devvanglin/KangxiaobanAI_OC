import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixIcon,
  SuffixText
} from '@kit.UIDesignKit';
import {
  buildHistoryOutline,
  filterHistorySessions,
  groupHistorySessions,
  HermesOutlineItem,
  HermesSessionGroup,
  historySourceLabel
} from '../data/HermesHistorySupport';
import { HermesChatModel, HermesMessage, HermesSession } from '../model/HermesModels';

@ComponentV2
export struct HermesHistoryPage {
  @Param split: boolean = false;
  @Param outlinePane: boolean = false;
  @Param @Require model: HermesChatModel;
  @Event onSelectSession: (sessionId: string) => void = (_sessionId: string) => {};
  @Event onRetrySessions: () => void = () => {};
  @Event onRetryMessages: () => void = () => {};
  @Event onLoadOlderMessages: (model: HermesChatModel) => Promise<number> =
    (_model: HermesChatModel): Promise<number> => Promise.resolve(0);
  @Event onSessionExpired: () => void = () => {};
  @Event onOpenChat: () => void = () => {};
  @Local searchText: string = '';
  @Local sourceFilter: string = 'all';
  @Local showList: boolean = true;
  @Local showOutline: boolean = false;
  @Local collapsedSources: string = '';
  private messageScroller: ListScroller = new ListScroller();

  private activeSession(): HermesSession | undefined {
    return this.model.sessions.find((session: HermesSession) => session.id === this.model.activeSessionId);
  }

  private activeSessionTitle(): string {
    return this.activeSession()?.title || '选择一个历史会话';
  }

  private filteredSessions(query: string, sourceFilter: string): HermesSession[] {
    return filterHistorySessions(this.model.sessions, query, sourceFilter);
  }

  private groups(query: string, sourceFilter: string): HermesSessionGroup[] {
    return groupHistorySessions(this.filteredSessions(query, sourceFilter));
  }

  private availableSources(): string[] {
    const values: string[] = [];
    this.model.sessions.forEach((session: HermesSession) => {
      if (!values.includes(session.source)) {
        values.push(session.source);
      }
    });
    return values;
  }

  private sourceToken(source: string): string {
    return `|${source}|`;
  }

  private isSourceCollapsed(source: string): boolean {
    return this.collapsedSources.includes(this.sourceToken(source));
  }

  private toggleSource(source: string): void {
    const token: string = this.sourceToken(source);
    if (this.collapsedSources.includes(token)) {
      this.collapsedSources = this.collapsedSources.replace(token, '');
    } else {
      this.collapsedSources = `${this.collapsedSources}${token}`;
    }
  }

  private selectSession(sessionId: string): void {
    this.onSelectSession(sessionId);
    if (!this.split) {
      this.showList = false;
      this.showOutline = false;
    }
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

  private outlineItems(): HermesOutlineItem[] {
    return buildHistoryOutline(this.model.messages);
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
        this.messageScroller.scrollToIndex(previousFirstIndex + 2, false, ScrollAlign.START);
      }
    }, 40);
  }

  private navigateOutline(item: HermesOutlineItem): void {
    const messageIndex: number = this.model.messages.findIndex((message: HermesMessage) => message.id === item.messageId);
    if (messageIndex >= 0) {
      const leadingItems: number = this.model.hasMoreMessages || this.model.loadingOlderMessages ||
        this.model.olderMessageErrorText.length > 0 ? 2 : 1;
      this.messageScroller.scrollToIndex(messageIndex + leadingItems, true, ScrollAlign.START);
    }
    if (!this.split) {
      this.showOutline = false;
    }
  }

  @Builder
  private sessionState() {
    if (this.model.sessionLoadState === 'loading') {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.hermes_text_secondary'))
        Text('正在加载历史会话…')
          .fontSize($r('app.float.hermes_text_body'))
          .fontColor($r('app.color.hermes_text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.model.sessionLoadState === 'empty') {
      Column({ space: 8 }) {
        Text('暂无历史会话')
          .fontSize($r('app.float.hermes_text_title'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hermes_text_primary'))
        Text('当前 Profile 没有可浏览的会话记录。')
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
        Text(this.model.sessionLoadState === 'unauthorized' ? '登录已失效' : '历史会话加载失败')
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
  private historyHeader() {
    Column() {
      HdsListItemCard({
        textItem: {
          primaryText: { text: '历史记录' },
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
          accessibilityText: `历史记录，共 ${this.model.sessions.length} 个会话`,
          accessibilityLevel: 'yes'
        }
      })
      .width('100%')
      .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border') })

      Row({ space: 8 }) {
        TextInput({ text: $$this.searchText, placeholder: '搜索标题、模型或 Profile' })
          .layoutWeight(1)
          .height(36)
          .fontSize($r('app.float.hermes_text_body'))
          .fontColor($r('app.color.hermes_text_primary'))
          .placeholderColor($r('app.color.hermes_text_muted'))
          .backgroundColor($r('app.color.hermes_bg_surface'))
          .border({ width: 1, color: $r('app.color.hermes_border') })
          .borderRadius($r('app.float.hermes_radius_small'))
        Button('新对话')
          .height(36)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_primary'))
          .backgroundColor($r('app.color.hermes_bg_surface'))
          .border({ width: 1, color: $r('app.color.hermes_border') })
          .borderRadius($r('app.float.hermes_radius_small'))
          .onClick(() => this.onOpenChat())
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 6 })

      Scroll() {
        Row({ space: 6 }) {
          Button('全部')
            .height(30)
            .fontSize(11)
            .fontColor(this.sourceFilter === 'all' ? $r('app.color.hermes_text_on_accent') :
              $r('app.color.hermes_text_secondary'))
            .backgroundColor(this.sourceFilter === 'all' ? $r('app.color.hermes_accent') :
              $r('app.color.hermes_bg_surface'))
            .borderRadius($r('app.float.hermes_radius_small'))
            .onClick(() => this.sourceFilter = 'all')
          ForEach(this.availableSources(), (source: string) => {
            Button(historySourceLabel(source))
              .height(30)
              .fontSize(11)
              .fontColor(this.sourceFilter === source ? $r('app.color.hermes_text_on_accent') :
                $r('app.color.hermes_text_secondary'))
              .backgroundColor(this.sourceFilter === source ? $r('app.color.hermes_accent') :
                $r('app.color.hermes_bg_surface'))
              .borderRadius($r('app.float.hermes_radius_small'))
              .onClick(() => this.sourceFilter = source)
          }, (source: string) => source)
        }
        .padding({ left: 10, right: 10, bottom: 8 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
  }

  @Builder
  private groupHeader(group: HermesSessionGroup) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SMALL_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(this.isSourceCollapsed(group.source) ?
            $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_down'))
            .fontColor([$r('app.color.hermes_text_secondary')])
        }
      }),
      textItem: { primaryText: { text: group.label } },
      suffixItem: new SuffixText({ text: `${group.sessions.length}` }),
      cardHeight: 38,
      cardBorderRadius: 0,
      hoverBorderRadius: 0,
      cardPrefixMargin: 0,
      cardSuffixMargin: 4,
      cardBackgroundColor: Color.Transparent,
      accessibilityOptions: {
        accessibilityText: `${group.label}，${group.sessions.length} 个会话`,
        accessibilityDescription: this.isSourceCollapsed(group.source) ? '已折叠' : '已展开',
        accessibilityLevel: 'yes',
        accessibilityRole: AccessibilityRoleType.BUTTON
      },
      onClick: () => this.toggleSource(group.source)
    })
    .width('100%')
  }

  @Builder
  private sessionRow(session: HermesSession) {
    HdsListItemCard({
      textItem: {
        primaryText: { text: session.title },
        secondaryText: {
          text: `${session.profile} · ${session.model} · ${session.messageCount > 0 ? session.messageCount : '—'} 条消息`
        }
      },
      suffixItem: new SuffixText({ text: session.updatedAt }),
      cardHeight: 72,
      cardBorderRadius: 8,
      hoverBorderRadius: 8,
      cardPrefixMargin: 2,
      cardSuffixMargin: 0,
      cardBackgroundColor: this.model.activeSessionId === session.id ?
        $r('app.color.hermes_bg_surface') : Color.Transparent,
      cardId: `history-session-${session.id}`,
      accessibilityOptions: {
        accessibilityText: `${session.title}，${session.updatedAt}，${historySourceLabel(session.source)}`,
        accessibilityDescription: `Profile ${session.profile}，模型 ${session.model}，${session.messageCount} 条消息`,
        accessibilityLevel: 'yes',
        accessibilityRole: AccessibilityRoleType.BUTTON,
        accessibilitySelected: this.model.activeSessionId === session.id
      },
      onClick: () => this.selectSession(session.id)
    })
    .width('100%')
    .focusable(true)
    .focusOnTouch(true)
  }

  @Builder
  private sessionList() {
    Column() {
      this.historyHeader()
      if (this.model.sessionLoadState === 'loading' || this.model.sessionLoadState === 'empty' ||
        this.model.sessionLoadState === 'error' || this.model.sessionLoadState === 'unauthorized') {
        this.sessionState()
      } else if (this.filteredSessions(this.searchText, this.sourceFilter).length === 0) {
        Column({ space: 8 }) {
          Text('没有匹配的会话')
            .fontSize($r('app.float.hermes_text_title'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.hermes_text_primary'))
          Text('请调整搜索内容或来源筛选。')
            .fontSize($r('app.float.hermes_text_caption'))
            .fontColor($r('app.color.hermes_text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 2 }) {
            ForEach(this.groups(this.searchText, this.sourceFilter), (group: HermesSessionGroup) => {
              this.groupHeader(group)
              if (!this.isSourceCollapsed(group.source)) {
                ForEach(group.sessions, (session: HermesSession) => {
                  this.sessionRow(session)
                }, (session: HermesSession) => session.id)
              }
            }, (group: HermesSessionGroup) => group.source)
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_sidebar'))
  }

  @Builder
  private messageState() {
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
        Image($r('app.media.hermes_logo'))
          .width(52)
          .height(52)
          .borderRadius(14)
          .accessibilityText('Hermes')
        Text('这个会话没有可显示的消息')
          .fontSize($r('app.float.hermes_text_title'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hermes_text_primary'))
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
        Text(message.content)
          .fontSize($r('app.float.hermes_text_body'))
          .fontColor(message.failed ? $r('app.color.hermes_error') : $r('app.color.hermes_text_primary'))
          .lineHeight(22)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width(this.split ? 720 : '82%')
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
  private detailTitleCard() {
    HdsListItemCard({
      textItem: {
        primaryText: { text: this.activeSessionTitle() },
        secondaryText: {
          text: this.activeSession() === undefined ? 'History' :
            `${historySourceLabel(this.activeSession()?.source || '')} · ${this.activeSession()?.profile || 'default'}`
        }
      },
      suffixItem: new SuffixIcon({
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.list_bullet'))
            .fontColor([$r('app.color.hermes_text_primary')])
        },
        onClick: () => this.showOutline = !this.showOutline,
        accessibilityOptions: {
          accessibilityText: this.showOutline ? '关闭大纲' : '打开大纲',
          accessibilityRole: AccessibilityRoleType.BUTTON
        }
      }),
      cardHeight: 64,
      cardBorderRadius: 0,
      hoverBorderRadius: 0,
      cardPrefixMargin: 4,
      cardSuffixMargin: 8,
      cardBackgroundColor: $r('app.color.hermes_bg_surface'),
      accessibilityOptions: {
        accessibilityText: this.activeSessionTitle(),
        accessibilityLevel: 'yes'
      }
    })
    .width('100%')
  }

  @Builder
  private detailHeader() {
    Row() {
      if (!this.split) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(18)
            .fontColor([$r('app.color.hermes_text_primary')])
        }
        .width(36)
        .height(36)
        .margin({ left: 8 })
        .backgroundColor(Color.Transparent)
        .accessibilityText('返回历史会话列表')
        .onClick(() => {
          this.showList = true;
          this.showOutline = false;
        })
      }
      Column() {
        this.detailTitleCard()
      }
      .layoutWeight(1)
      .height(64)
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.hermes_bg_surface'))
    .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border') })
  }

  @Builder
  private messageSurface() {
    Column() {
      this.detailHeader()
      if (this.model.messageLoadState === 'loading' || this.model.messageLoadState === 'empty' ||
        this.model.messageLoadState === 'error' || this.model.messageLoadState === 'unauthorized') {
        this.messageState()
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
                    .onClick(() => this.loadOlderMessages())
                }
                if (this.model.olderMessageErrorText.length > 0) {
                  Text(this.model.olderMessageErrorText)
                    .fontSize(11)
                    .fontColor($r('app.color.hermes_error'))
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .padding({ top: 4, bottom: 4 })
            }
          }
          ListItem() {
            Text(this.model.remoteMode ? '只读历史 · 会话与消息来自真实 Hermes Server' :
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
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private outlineSurface() {
    Column() {
      HdsListItemCard({
        textItem: {
          primaryText: { text: '大纲' },
          secondaryText: { text: '问题与回答标题' }
        },
        suffixItem: new SuffixText({ text: `${this.outlineItems().length}` }),
        cardHeight: 58,
        cardBorderRadius: 0,
        hoverBorderRadius: 0,
        cardPrefixMargin: 0,
        cardSuffixMargin: 8,
        cardBackgroundColor: $r('app.color.hermes_bg_surface'),
        accessibilityOptions: {
          accessibilityText: `会话大纲，共 ${this.outlineItems().length} 项`,
          accessibilityLevel: 'yes'
        }
      })
      .width('100%')
      .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border') })
      if (this.outlineItems().length === 0) {
        Column({ space: 8 }) {
          Text('暂无大纲')
            .fontSize($r('app.float.hermes_text_title'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.hermes_text_primary'))
          Text('用户问题和 Markdown 标题会显示在这里。')
            .fontSize($r('app.float.hermes_text_caption'))
            .fontColor($r('app.color.hermes_text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.outlineItems(), (item: HermesOutlineItem) => {
            ListItem() {
              HdsListItemCard({
                textItem: {
                  primaryText: { text: item.question ? `Q: ${item.label}` : item.label }
                },
                cardHeight: item.question ? 54 : 42,
                cardBorderRadius: 8,
                hoverBorderRadius: 8,
                cardPrefixMargin: 0,
                cardSuffixMargin: 0,
                cardBackgroundColor: item.question ? $r('app.color.hermes_bg_secondary') : Color.Transparent,
                accessibilityOptions: {
                  accessibilityText: item.question ? `问题，${item.label}` : `标题，${item.label}`,
                  accessibilityLevel: 'yes',
                  accessibilityRole: AccessibilityRoleType.BUTTON
                },
                onClick: () => this.navigateOutline(item)
              })
              .width('100%')
              .padding({ left: item.question ? 0 : item.level * 8 })
            }
          }, (item: HermesOutlineItem) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(10)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_surface'))
  }

  build() {
    if (this.split) {
      Row() {
        Column() {
          this.sessionList()
        }
        .width(300)
        .height('100%')
        .border({ width: { right: 1 }, color: $r('app.color.hermes_border') })
        Column() {
          this.messageSurface()
        }
        .layoutWeight(1)
        .height('100%')
        if (this.showOutline && this.outlinePane) {
          Column() {
            this.outlineSurface()
          }
          .width(260)
          .height('100%')
          .border({ width: { left: 1 }, color: $r('app.color.hermes_border') })
        }
      }
      .width('100%')
      .height('100%')
    } else if (this.showOutline) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.outlineSurface()
        Button('返回会话')
          .height(34)
          .margin({ top: 12, right: 12 })
          .align(Alignment.TopEnd)
          .fontSize($r('app.float.hermes_text_caption'))
          .fontColor($r('app.color.hermes_text_primary'))
          .backgroundColor($r('app.color.hermes_bg_surface'))
          .border({ width: 1, color: $r('app.color.hermes_border') })
          .borderRadius($r('app.float.hermes_radius_small'))
          .onClick(() => this.showOutline = false)
      }
      .width('100%')
      .height('100%')
    } else if (this.showList) {
      this.sessionList()
    } else {
      this.messageSurface()
    }
  }
}
