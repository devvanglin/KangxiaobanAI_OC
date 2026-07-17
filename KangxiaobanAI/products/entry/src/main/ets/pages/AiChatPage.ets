/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  AppStorageV2,
  ColorMetrics,
  KeyboardAvoidMode,
  LengthMetrics
} from '@kit.ArkUI';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import {
  ActionBarButton,
  ActionBarStyle,
  HdsActionBar,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconStyleMode,
  hdsMaterial,
  ScrollEffectType,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';
import { WindowUtil } from '../util/WindowUtil';
import { BreakpointUtil } from '../util/BreakpointSystem';
import { AI_BRAND_NAME, AiTitleLabel } from '../component/AiTitleLabel';

const CONTENT_TOP_OFFSET: number = 56;
const AI_CHAT_HISTORY_KEY: string = 'aiChatHistoryStore';
const MAX_CHAT_SESSIONS: number = 50;
const CURRENT_USER_DISPLAY_NAME: string = '刘婷';

type ChatRole = 'ai' | 'user';
type ChatFeedback = 'none' | 'up' | 'down';

interface RichSegment {
  text: string;
  bold: boolean;
}

interface ChatMessage {
  id: string;
  role: ChatRole;
  content: string;
  feedback?: ChatFeedback;
}

interface ChatSession {
  id: string;
  title: string;
  messages: ChatMessage[];
  updatedAt: number;
}

interface AiInformationFeedItem {
  id: string;
  title: string;
  prompt: string;
}

const AI_INFORMATION_FEED_ROWS: AiInformationFeedItem[][] = [
  [
    {
      id: 'care-summary',
      title: '资讯：今日重点照护事项已汇总 4 条',
      prompt: '请汇总今天需要优先关注的照护事项'
    },
    {
      id: 'health-change',
      title: '健康：3 位住户晨间指标出现变化',
      prompt: '请解读今天晨间健康指标的变化和关注重点'
    },
    {
      id: 'care-priority',
      title: '如何安排今天的护理优先级',
      prompt: '请根据风险和时间节点安排今天的护理优先级'
    }
  ],
  [
    {
      id: 'shift-records',
      title: '交班：下午班新增 2 条重点记录',
      prompt: '请帮我整理下午班新增的重点交班记录'
    },
    {
      id: 'family-follow-up',
      title: '家属：今天有 2 项回访需要准备',
      prompt: '请生成今天家属回访的沟通提纲'
    },
    {
      id: 'rehab-progress',
      title: '分享一下近期康复训练的完成情况',
      prompt: '请总结近期康复训练完成情况并给出后续建议'
    }
  ],
  [
    {
      id: 'shift-plan',
      title: '帮我整理一份当班护理工作计划',
      prompt: '请帮我整理一份清晰可执行的当班护理工作计划'
    },
    {
      id: 'health-trend',
      title: '解读本周异常健康数据趋势',
      prompt: '请深度解读本周异常健康数据的变化趋势'
    },
    {
      id: 'family-script',
      title: '生成一段专业的家属沟通话术',
      prompt: '请生成一段专业、温和的家属沟通话术'
    }
  ]
];

@ObservedV2
class AiChatHistoryStore {
  @Trace sessions: ChatSession[] = [];
  @Trace activeSessionId: string = '';
}

@ComponentV2
export struct AiChatPage {
  @Param @Require geometryId: string;
  @Event onClose: () => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local historyStore: AiChatHistoryStore =
    AppStorageV2.connect(AiChatHistoryStore, AI_CHAT_HISTORY_KEY, () => new AiChatHistoryStore()) ??
      new AiChatHistoryStore();
  @Local messages: ChatMessage[] = [];
  @Local inputText: string = '';
  @Local keyboardOffset: number = 0;
  @Local isGenerating: boolean = false;
  @Local historyDrawerOpen: boolean = false;
  private listScroller: ListScroller = new ListScroller();
  private focusController = this.getUIContext().getFocusController();
  private previousKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private responseTimer: number = -1;
  private scrollTimer: number = -1;

  @Monitor('globalInfoModel.keyboardHeight')
  onKeyboardHeightChange(): void {
    this.keyboardOffset = this.globalInfoModel.keyboardHeight;
    if (this.messages.length > 0) {
      this.scheduleScrollToBottom(300);
    }
  }

  private cloneMessage(message: ChatMessage): ChatMessage {
    return {
      id: message.id,
      role: message.role,
      content: message.content,
      feedback: message.feedback
    };
  }

  private cloneMessages(messages: ChatMessage[]): ChatMessage[] {
    const result: ChatMessage[] = [];
    for (let i: number = 0; i < messages.length; i++) {
      result.push(this.cloneMessage(messages[i]));
    }
    return result;
  }

  private findSession(sessionId: string): ChatSession | undefined {
    for (let i: number = 0; i < this.historyStore.sessions.length; i++) {
      if (this.historyStore.sessions[i].id === sessionId) {
        return this.historyStore.sessions[i];
      }
    }
    return undefined;
  }

  private buildSessionTitle(text: string): string {
    const normalized: string = text.replace(/\n/g, ' ').trim();
    if (normalized.length === 0) {
      return AI_BRAND_NAME;
    }
    return normalized.length > 18 ? `${normalized.substring(0, 18)}…` : normalized;
  }

  private syncActiveSession(messages: ChatMessage[] = this.messages, refreshActivity: boolean = true): void {
    const activeId: string = this.historyStore.activeSessionId;
    if (activeId.length === 0) {
      return;
    }
    const current: ChatSession | undefined = this.findSession(activeId);
    if (!current) {
      this.historyStore.activeSessionId = '';
      return;
    }
    const updated: ChatSession = {
      id: current.id,
      title: current.title,
      messages: this.cloneMessages(messages),
      updatedAt: refreshActivity ? Date.now() : current.updatedAt
    };
    if (!refreshActivity) {
      this.historyStore.sessions = this.historyStore.sessions.map((session: ChatSession): ChatSession =>
        session.id === activeId ? updated : session);
      return;
    }
    const remaining: ChatSession[] = [];
    for (let i: number = 0; i < this.historyStore.sessions.length; i++) {
      if (this.historyStore.sessions[i].id !== activeId) {
        remaining.push(this.historyStore.sessions[i]);
      }
    }
    this.historyStore.sessions = [updated, ...remaining].slice(0, MAX_CHAT_SESSIONS);
  }

  private createSession(firstText: string, messages: ChatMessage[]): void {
    const session: ChatSession = {
      id: `session-${Date.now()}`,
      title: this.buildSessionTitle(firstText),
      messages: this.cloneMessages(messages),
      updatedAt: Date.now()
    };
    this.historyStore.activeSessionId = session.id;
    this.historyStore.sessions = [session, ...this.historyStore.sessions].slice(0, MAX_CHAT_SESSIONS);
  }

  private cancelPendingWork(): void {
    if (this.responseTimer >= 0) {
      clearTimeout(this.responseTimer);
      this.responseTimer = -1;
    }
    if (this.scrollTimer >= 0) {
      clearTimeout(this.scrollTimer);
      this.scrollTimer = -1;
    }
    this.isGenerating = false;
  }

  private restoreSession(session: ChatSession): void {
    this.historyStore.activeSessionId = session.id;
    this.messages = this.cloneMessages(session.messages);
    this.inputText = '';
    this.isGenerating = false;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
  }

  private restoreActiveSession(): void {
    const active: ChatSession | undefined = this.findSession(this.historyStore.activeSessionId);
    if (active) {
      this.restoreSession(active);
      if (active.messages.length > 0) {
        this.scheduleScrollToBottom(160);
      }
      return;
    }
    this.historyStore.activeSessionId = '';
    this.messages = [];
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
  }

  private openHistoryDrawer(): void {
    this.focusController.clearFocus();
    this.syncActiveSession(this.messages, false);
    this.getUIContext().animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.historyDrawerOpen = true;
    });
  }

  private closeHistoryDrawer(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.historyDrawerOpen = false;
    });
  }

  private startNewConversation(): void {
    this.syncActiveSession(this.messages, false);
    const wasGenerating: boolean = this.isGenerating;
    this.cancelPendingWork();
    if (wasGenerating) {
      this.showToast('已停止当前回复');
    }
    this.focusController.clearFocus();
    this.historyStore.activeSessionId = '';
    this.messages = [];
    this.inputText = '';
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.closeHistoryDrawer();
  }

  private selectSession(sessionId: string): void {
    if (sessionId === this.historyStore.activeSessionId) {
      this.closeHistoryDrawer();
      return;
    }
    this.syncActiveSession(this.messages, false);
    const wasGenerating: boolean = this.isGenerating;
    this.cancelPendingWork();
    if (wasGenerating) {
      this.showToast('已停止当前回复');
    }
    this.focusController.clearFocus();
    const session: ChatSession | undefined = this.findSession(sessionId);
    if (!session) {
      this.closeHistoryDrawer();
      return;
    }
    this.restoreSession(session);
    this.closeHistoryDrawer();
    this.scheduleScrollToBottom(120);
  }

  private closeChatPage(): void {
    this.syncActiveSession(this.messages, false);
    this.closeHistoryDrawer();
    this.onClose();
  }

  private historyDrawerWidth(): number {
    if (this.isWideLayout()) {
      return 280;
    }
    if (this.globalInfoModel.deviceWidth <= 0) {
      return 240;
    }
    return Math.min(272, Math.max(232, this.globalInfoModel.deviceWidth * 0.64));
  }

  private isWideLayout(): boolean {
    return BreakpointUtil.isWide(this.globalInfoModel.widthBreakpoint);
  }

  aboutToAppear(): void {
    WindowUtil.setImmersiveMode(true);
    this.previousKeyboardAvoidMode = this.getUIContext().getKeyboardAvoidMode();
    this.restoreActiveSession();
  }

  aboutToDisappear(): void {
    this.syncActiveSession(this.messages, false);
    this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardAvoidMode);
    this.cancelPendingWork();
    WindowUtil.setImmersiveMode(false);
  }

  private titleBarTitleText(): string {
    const activeSession: ChatSession | undefined = this.findSession(this.historyStore.activeSessionId);
    return activeSession?.title ?? AI_BRAND_NAME;
  }

  @Builder
  private titleBarTitleBuilder() {
    Row() {
      AiTitleLabel({ text: this.titleBarTitleText(), compact: true })
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 64, right: 112 })
    .alignItems(VerticalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private titleBarContent(): TitleBarContentOptions {
    return {
      stackBuilder: (): void => this.titleBarTitleBuilder(),
      backIcon: {
        label: '打开菜单',
        icon: $r('sys.symbol.line_3_horizontal'),
        type: IconStyleMode.SMALL,
        isEnabled: true,
        action: () => {
          this.openHistoryDrawer();
        }
      },
      menu: {
        value: [
          {
            content: {
              label: '新建对话',
              icon: $r('sys.symbol.square_and_pencil'),
              type: IconStyleMode.SMALL,
              isEnabled: true,
              action: () => {
                this.startNewConversation();
              }
            }
          },
          {
            content: {
              label: '关闭',
              icon: $r('sys.symbol.xmark'),
              type: IconStyleMode.SMALL,
              isEnabled: true,
              action: () => {
                this.closeChatPage();
              }
            }
          }
        ]
      }
    };
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      },
      originalStyle: {
        contentStyle: {
          backIconStyle: {
            backgroundColor: Color.Transparent,
            iconColor: $r('sys.color.icon_primary')
          },
          menuStyle: {
            backgroundColor: Color.Transparent,
            iconColor: $r('sys.color.icon_primary')
          }
        }
      },
      scrollEffectStyle: {
        contentStyle: {
          backIconStyle: {
            backgroundColor: Color.Transparent,
            iconColor: $r('sys.color.icon_primary')
          },
          menuStyle: {
            backgroundColor: Color.Transparent,
            iconColor: $r('sys.color.icon_primary')
          }
        }
      }
    };
  }

  private pagePadding(): number {
    if (this.isWideLayout()) {
      return 24;
    }
    return 16;
  }

  private expandMaxWidth(): number {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    if (widthBreakpoint === WidthBreakpoint.WIDTH_LG || widthBreakpoint === WidthBreakpoint.WIDTH_XL) {
      return 1040;
    }
    if (widthBreakpoint === WidthBreakpoint.WIDTH_MD) {
      return 920;
    }
    return 9999;
  }

  private userTextBeforeMessage(messageId: string): string {
    let targetIndex: number = -1;
    for (let i: number = 0; i < this.messages.length; i++) {
      if (this.messages[i].id === messageId) {
        targetIndex = i;
        break;
      }
    }
    for (let i: number = targetIndex - 1; i >= 0; i--) {
      if (this.messages[i].role === 'user') {
        return this.messages[i].content;
      }
    }
    return '';
  }

  private parseBold(text: string): RichSegment[] {
    const segments: RichSegment[] = [];
    let current: string = '';
    let isBold: boolean = false;
    let i: number = 0;
    while (i < text.length) {
      if (i + 1 < text.length && text[i] === '*' && text[i + 1] === '*') {
        if (current.length > 0) {
          segments.push({ text: current, bold: isBold });
        }
        current = '';
        isBold = !isBold;
        i += 2;
      } else {
        current += text[i];
        i++;
      }
    }
    if (current.length > 0 || segments.length === 0) {
      segments.push({ text: current, bold: isBold });
    }
    return segments;
  }

  private scrollToBottom(): void {
    if (this.messages.length === 0) {
      return;
    }
    if (this.messages.length <= 2) {
      this.listScroller.scrollToIndex(0, true, ScrollAlign.START);
      return;
    }
    const targetIndex: number = this.isGenerating ? this.messages.length : this.messages.length - 1;
    this.listScroller.scrollToIndex(targetIndex, true, ScrollAlign.END);
  }

  private scheduleScrollToBottom(delay: number = 80): void {
    if (this.scrollTimer >= 0) {
      clearTimeout(this.scrollTimer);
    }
    this.scrollTimer = setTimeout(() => {
      this.scrollToBottom();
      this.scrollTimer = -1;
    }, delay);
  }

  private buildAnswerText(text: string): string {
    if (text.trim() === '1') {
      return '你好！看起来你只发了一个“1”，是想测试我是否在线，还是不小心按到了发送键？🙂\n\n不管怎样，我在这里呢！有什么我可以帮你的吗？无论是提问、聊天、查资料，还是需要我帮你处理什么问题，都随时告诉我吧～';
    }
    return `我收到了你的消息：“${text}”。\n\n我会整理重点，并优先给出清晰、可执行的建议。如果涉及住户健康或安全风险，请同时补充时间、症状和最近一次测量结果。`;
  }

  private createAiMessage(id: string, text: string): ChatMessage {
    return {
      id: id,
      role: 'ai',
      content: this.buildAnswerText(text),
      feedback: 'none'
    };
  }

  private appendAiResponse(text: string): void {
    const message: ChatMessage = this.createAiMessage(`a-${Date.now()}`, text);
    const nextMessages: ChatMessage[] = [...this.messages, message];
    this.messages = nextMessages;
    this.syncActiveSession(nextMessages);
    this.isGenerating = false;
    this.scheduleScrollToBottom(100);
  }

  private sendMessage(): void {
    const text: string = this.inputText.trim();
    if (text.length === 0 || this.isGenerating) {
      return;
    }
    if (this.messages.length === 0) {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    }
    const userMessage: ChatMessage = {
      id: `u-${Date.now()}`,
      role: 'user',
      content: text
    };
    const nextMessages: ChatMessage[] = [...this.messages, userMessage];
    this.messages = nextMessages;
    if (this.historyStore.activeSessionId.length === 0) {
      this.createSession(text, nextMessages);
    } else {
      this.syncActiveSession(nextMessages);
    }
    this.inputText = '';
    this.isGenerating = true;
    this.scheduleScrollToBottom(80);
    this.responseTimer = setTimeout(() => {
      this.appendAiResponse(text);
      this.responseTimer = -1;
    }, 650);
  }

  private regenerateMessage(message: ChatMessage): void {
    if (this.isGenerating) {
      return;
    }
    const text: string = this.userTextBeforeMessage(message.id);
    if (text.length === 0) {
      return;
    }
    this.isGenerating = true;
    this.showToast('正在重新生成');
    this.responseTimer = setTimeout(() => {
      const replacement: ChatMessage = this.createAiMessage(message.id, text);
      this.messages = this.messages.map((item: ChatMessage): ChatMessage =>
        item.id === message.id ? replacement : item);
      this.syncActiveSession();
      this.isGenerating = false;
      this.scheduleScrollToBottom(100);
      this.responseTimer = -1;
    }, 500);
  }

  private setFeedback(message: ChatMessage, feedback: ChatFeedback): void {
    const nextFeedback: ChatFeedback = message.feedback === feedback ? 'none' : feedback;
    this.messages = this.messages.map((item: ChatMessage): ChatMessage => {
      if (item.id !== message.id) {
        return item;
      }
      return {
        id: item.id,
        role: item.role,
        content: item.content,
        feedback: nextFeedback
      };
    });
    this.syncActiveSession();
    this.showToast(nextFeedback === 'up' ? '感谢你的认可' : nextFeedback === 'down' ? '已记录反馈' : '已取消反馈');
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
    }
  }

  private copyText(text: string): void {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.showToast('已复制');
      }).catch((error: BusinessError) => {
        this.showToast('复制失败');
      });
    } catch (error) {
      this.showToast('复制失败');
    }
  }

  private editMessage(message: ChatMessage): void {
    this.inputText = message.content;
    this.showToast('已放回输入框');
  }

  private colorMetric(color: ResourceColor): ColorMetrics | undefined {
    try {
      return ColorMetrics.resourceColor(color);
    } catch (error) {
      return undefined;
    }
  }

  private actionButton(
    icon: Resource,
    label: string,
    action: () => void,
    selected: boolean = false
  ): ActionBarButton {
    return new ActionBarButton({
      width: LengthMetrics.vp(36),
      baseIcon: icon,
      iconSize: LengthMetrics.vp(18),
      iconFillColor: this.colorMetric(selected ? $r('app.color.brand_blue') : $r('sys.color.icon_secondary')),
      backgroundColor: this.colorMetric(Color.Transparent),
      shadowStyle: { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 },
      hoverTips: label,
      accessibilityText: label,
      onClick: action
    });
  }

  private aiActionButtons(message: ChatMessage): ActionBarButton[] {
    return [
      this.actionButton($r('sys.symbol.square_on_square_fill'), '复制', () => {
        this.copyText(message.content);
      }),
      this.actionButton($r('sys.symbol.arrow_clockwise'), '重新生成', () => {
        this.regenerateMessage(message);
      }),
      this.actionButton(
        message.feedback === 'up' ? $r('sys.symbol.hand_thumbsup_fill') : $r('sys.symbol.hand_thumbsup'),
        '有帮助',
        () => {
          this.setFeedback(message, 'up');
        },
        message.feedback === 'up'
      ),
      this.actionButton(
        message.feedback === 'down' ? $r('sys.symbol.hand_thumbsdown_fill') : $r('sys.symbol.hand_thumbsdown'),
        '没帮助',
        () => {
          this.setFeedback(message, 'down');
        },
        message.feedback === 'down'
      ),
      this.actionButton($r('sys.symbol.share'), '分享', () => {
        this.showToast('分享能力接入中');
      })
    ];
  }

  private aiActionBarStyle(): ActionBarStyle {
    return new ActionBarStyle({
      height: LengthMetrics.vp(40),
      backgroundColor: this.colorMetric(Color.Transparent),
      innerSpace: LengthMetrics.vp(0),
      startSpace: LengthMetrics.vp(0),
      endSpace: LengthMetrics.vp(0)
    });
  }

  @Builder
  private richParagraph(line: string) {
    Text() {
      ForEach(this.parseBold(line), (segment: RichSegment, index: number) => {
        Span(segment.text)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(segment.bold ? FontWeight.Bold : FontWeight.Regular)
      }, (segment: RichSegment, index: number) => `${index}-${segment.text}`)
    }
    .width('100%')
    .lineHeight(28)
  }

  @Builder
  private richBullet(line: string) {
    Row({ space: 10 }) {
      Row()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor($r('app.color.brand_blue'))
        .margin({ top: 10 })
      Text() {
        ForEach(this.parseBold(line.substring(2)), (segment: RichSegment, index: number) => {
          Span(segment.text)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(segment.bold ? FontWeight.Bold : FontWeight.Regular)
        }, (segment: RichSegment, index: number) => `${index}-${segment.text}`)
      }
      .layoutWeight(1)
      .lineHeight(28)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private aiContent(content: string) {
    Column({ space: 10 }) {
      ForEach(content.split('\n'), (line: string, index: number) => {
        if (line.startsWith('• ')) {
          this.richBullet(line)
        } else if (line.trim().length === 0) {
          Row().width('100%').height(4)
        } else {
          this.richParagraph(line)
        }
      }, (line: string, index: number) => `${index}-${line}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private userActionButton(symbol: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(17)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .buttonStyle(ButtonStyleMode.TEXTUAL)
    .width(36)
    .height(36)
    .accessibilityText(label)
    .onClick(action)
  }

  @Builder
  private userMessageItem(message: ChatMessage) {
    Column({ space: 2 }) {
      Row() {
        Blank()
        Text(message.content)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(26)
          .textAlign(message.content.length <= 2 ? TextAlign.Center : TextAlign.Start)
          .constraintSize({ minWidth: 44, minHeight: 44, maxWidth: '78%' })
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .backgroundColor(0xFFEAF1FF)
          .borderRadius(22)
      }
      .width('100%')

      Row({ space: 0 }) {
        Blank()
        this.userActionButton($r('sys.symbol.square_on_square_fill'), '复制', () => {
          this.copyText(message.content);
        })
        this.userActionButton($r('sys.symbol.pencil_line'), '编辑', () => {
          this.editMessage(message);
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ bottom: 14 })
  }

  @Builder
  private aiMessageItem(message: ChatMessage) {
    Column({ space: 12 }) {
      this.aiContent(message.content)

      Row() {
        HdsActionBar({
          startButtons: this.aiActionButtons(message),
          actionBarStyle: this.aiActionBarStyle()
        })
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private generatingItem() {
    Row({ space: 10 }) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color($r('app.color.brand_blue'))
      Text('康小伴正在回复…')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 8, bottom: 24 })
  }

  private usePromptShortcut(prompt: string): void {
    this.inputText = prompt;
  }

  private emptyGreetingText(hour: number = new Date().getHours()): string {
    let greeting: string = '上午好';
    if (hour >= 14) {
      greeting = '下午好';
    } else if (hour >= 12) {
      greeting = '中午好';
    }
    return `${greeting}，${CURRENT_USER_DISPLAY_NAME}`;
  }

  private informationFeedCategory(title: string): string {
    const separatorIndex: number = title.indexOf('：');
    return separatorIndex > 0 ? title.substring(0, separatorIndex) : '建议';
  }

  private informationFeedContent(title: string): string {
    const separatorIndex: number = title.indexOf('：');
    return separatorIndex > 0 ? title.substring(separatorIndex + 1) : title;
  }

  @Builder
  private informationFeedItem(item: AiInformationFeedItem) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(item.title)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .height(40)
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('app.color.ai_feed_background'))
    .borderRadius(12)
    .onClick(() => {
      this.usePromptShortcut(item.prompt);
    })
  }

  @Builder
  private informationFeedRow(items: AiInformationFeedItem[]) {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(items, (item: AiInformationFeedItem) => {
          this.informationFeedItem(item)
        }, (item: AiInformationFeedItem) => item.id)
      }
      .padding({ left: this.pagePadding(), right: this.pagePadding() })
    }
    .width('100%')
    .height(40)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private emptyInformationHero() {
    Column({ space: 20 }) {
      Column({ space: 4 }) {
        Text(this.emptyGreetingText())
          .fontSize($r('sys.float.Title_M'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .maxLines(1)
          .ellipsisMode(EllipsisMode.END)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('让我们开始当前的工作吧')
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_secondary'))
          .fontWeight(FontWeight.Regular)
          .width('100%')
          .maxLines(1)
          .ellipsisMode(EllipsisMode.END)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding() })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        this.informationFeedRow(AI_INFORMATION_FEED_ROWS[0])
        this.informationFeedRow(AI_INFORMATION_FEED_ROWS[1])
        this.informationFeedRow(AI_INFORMATION_FEED_ROWS[2])
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: this.expandMaxWidth() })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private wideInformationFeedItem(item: AiInformationFeedItem) {
    Button({ stateEffect: true }) {
      Column({ space: 3 }) {
        Text(this.informationFeedCategory(item.title))
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .maxLines(1)

        Text(this.informationFeedContent(item.title))
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .layoutWeight(1)
    .height(66)
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .borderRadius(14)
    .backgroundColor($r('app.color.ai_feed_background'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.usePromptShortcut(item.prompt);
    })
  }

  @Builder
  private wideInformationFeedRow(items: AiInformationFeedItem[]) {
    Row({ space: 12 }) {
      ForEach(items, (item: AiInformationFeedItem) => {
        this.wideInformationFeedItem(item)
      }, (item: AiInformationFeedItem) => item.id)
    }
    .width('100%')
  }

  @Builder
  private wideEmptyInformationHero() {
    Column({ space: 26 }) {
      Column({ space: 6 }) {
        Text(this.emptyGreetingText())
          .fontSize($r('sys.float.Title_L'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('让我们开始当前的工作吧')
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        Text('快捷开始')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .fontWeight(FontWeight.Medium)
          .width('100%')

        this.wideInformationFeedRow(AI_INFORMATION_FEED_ROWS[0])
        this.wideInformationFeedRow(AI_INFORMATION_FEED_ROWS[1])
        this.wideInformationFeedRow(AI_INFORMATION_FEED_ROWS[2])
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ maxWidth: this.expandMaxWidth() })
    .padding({ left: 36, right: 36 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private wideEmptyConversationPage() {
    Column() {
      this.wideEmptyInformationHero()

      Blank()
        .layoutWeight(1)

      this.inputArea(true)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 34 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private emptyConversationPage() {
    Column() {
      Blank()
        .layoutWeight(4)

      this.emptyInformationHero()

      Blank()
        .layoutWeight(5)

      this.inputArea(true)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.isWideLayout() ? 20 : this.globalInfoModel.statusBarHeight + CONTENT_TOP_OFFSET })
    .alignItems(HorizontalAlign.Center)
  }
  @Builder
  private composer() {
    Row({ space: 4 }) {
      TextArea({ text: this.inputText, placeholder: '给 康小伴 发送消息' })
        .enterKeyType(EnterKeyType.NEW_LINE)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(24)
        .placeholderFont({ size: $r('sys.float.Body_L') })
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor(Color.Transparent)
        .padding({ left: 8, right: 4, top: 8, bottom: 8 })
        .minLines(1)
        .maxLines(4, { overflowMode: MaxLinesMode.SCROLL })
        .textOverflow(TextOverflow.Clip)
        .barState(BarState.Auto)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.inputText = value;
        })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.paperclip'))
          .fontSize(19)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width(40)
      .height(40)
      .accessibilityText('添加附件')
      .onClick(() => {
        this.showToast('附件能力接入中');
      })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(19)
          .fontColor([$r('app.color.text_on_brand')])
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .width(40)
      .height(40)
      .backgroundColor(this.inputText.trim().length > 0 && !this.isGenerating ?
        $r('app.color.brand_blue') : 0xFFB7C8F8)
      .enabled(this.inputText.trim().length > 0 && !this.isGenerating)
      .opacity(this.inputText.trim().length > 0 && !this.isGenerating ? 1 : 0.72)
      .accessibilityText('发送')
      .onClick(() => {
        this.sendMessage();
      })
    }
    .width('100%')
    .constraintSize({ minHeight: 56, maxWidth: this.expandMaxWidth() })
    .padding({ left: 10, right: 6, top: 8, bottom: 8 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(28)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({
      radius: 12,
      color: 'rgba(0,0,0,0.06)',
      offsetX: 0,
      offsetY: 4
    })
    .alignItems(VerticalAlign.Bottom)
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  private inputBottomMargin(): number {
    if (this.keyboardOffset > 0) {
      return 8;
    }
    return this.isWideLayout() ? Math.max(12, this.globalInfoModel.naviIndicatorHeight) :
      this.globalInfoModel.naviIndicatorHeight;
  }

  @Builder
  private inputArea(showDisclaimer: boolean) {
    Column({ space: 6 }) {
      this.composer()
      if (showDisclaimer && this.keyboardOffset === 0) {
        Text('内容由 AI 生成，请仔细甄别')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({
      left: this.isWideLayout() ? 28 : this.pagePadding(),
      right: this.isWideLayout() ? 28 : this.pagePadding(),
      top: 8,
      bottom: this.keyboardOffset > 0 ? 0 : 2
    })
    .margin({ bottom: this.inputBottomMargin() })
    .backgroundColor($r('sys.color.background_primary'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private newConversationButton() {
    Row() {
      Text('新对话')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(42)
    .justifyContent(FlexAlign.Center)
    .borderRadius(21)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetY: 2 })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.startNewConversation();
    })
  }

  private sessionGroupLabel(updatedAt: number): string {
    const now: Date = new Date();
    const target: Date = new Date(updatedAt);
    const todayStart: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const targetStart: number = new Date(target.getFullYear(), target.getMonth(), target.getDate()).getTime();
    const dayDiff: number = Math.floor((todayStart - targetStart) / (24 * 60 * 60 * 1000));
    if (dayDiff <= 0) {
      return '今天';
    }
    if (dayDiff === 1) {
      return '昨天';
    }
    if (dayDiff <= 7) {
      return '7 天内';
    }
    if (dayDiff <= 30) {
      return '30 天内';
    }
    return '更早';
  }

  private shouldShowSessionGroup(index: number): boolean {
    if (index <= 0 || index >= this.historyStore.sessions.length) {
      return true;
    }
    return this.sessionGroupLabel(this.historyStore.sessions[index - 1].updatedAt) !==
      this.sessionGroupLabel(this.historyStore.sessions[index].updatedAt);
  }

  @Builder
  private sessionGroupTitle(label: string) {
    Text(label)
      .fontSize($r('sys.float.Caption_S'))
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .padding({ left: 8, top: 8, bottom: 3 })
  }

  @Builder
  private historySessionItem(session: ChatSession) {
    Row() {
      Text(session.title)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(session.id === this.historyStore.activeSessionId ?
          $r('app.color.brand_blue') : $r('sys.color.font_primary'))
        .fontWeight(session.id === this.historyStore.activeSessionId ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .height(40)
    .padding({ left: 10, right: 10 })
    .borderRadius(9)
    .backgroundColor(session.id === this.historyStore.activeSessionId ?
      $r('sys.color.comp_background_tertiary') : Color.Transparent)
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.selectSession(session.id);
    })
  }

  @Builder
  private emptyHistory() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.AI_message'))
        .fontSize(30)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text('暂无对话记录')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ top: 28 })
  }

  @Builder
  private historyDrawer() {
    Column({ space: 10 }) {
      if (this.isWideLayout()) {
        Row() {
          Text('对话记录')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .height(68)
        .padding({ left: 4, right: 4 })
        .alignItems(VerticalAlign.Center)
      }

      this.newConversationButton()

      Scroll() {
        Column({ space: 1 }) {
          if (this.historyStore.sessions.length === 0) {
            this.emptyHistory()
          } else {
            ForEach(this.historyStore.sessions, (session: ChatSession, index: number) => {
              if (this.shouldShowSessionGroup(index)) {
                this.sessionGroupTitle(this.sessionGroupLabel(session.updatedAt))
              }
              this.historySessionItem(session)
            }, (session: ChatSession) => `${session.id}-${session.updatedAt}`)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 14,
      right: 14,
      top: this.isWideLayout() ? this.globalInfoModel.statusBarHeight :
        this.globalInfoModel.statusBarHeight + 10,
      bottom: this.isWideLayout() ? Math.max(18, this.globalInfoModel.naviIndicatorHeight + 8) :
        this.globalInfoModel.naviIndicatorHeight + 8
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .shadow(this.isWideLayout() ? { radius: 0, color: Color.Transparent, offsetX: 0 } :
      { radius: 18, color: 'rgba(0,0,0,0.12)', offsetX: 3 })
  }

  @Builder
  private drawerMask() {
    Row()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.28)')
      .zIndex(10)
      .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      .onClick(() => {
        this.closeHistoryDrawer();
      })
  }

  @Builder
  private messageList() {
    List({ space: 0, scroller: this.listScroller }) {
      ForEach(this.messages, (message: ChatMessage) => {
        ListItem() {
          Row() {
            Column() {
              if (message.role === 'ai') {
                this.aiMessageItem(message)
              } else {
                this.userMessageItem(message)
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: this.expandMaxWidth() })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }, (message: ChatMessage) => `${message.id}-${message.feedback ?? 'none'}`)

      if (this.isGenerating) {
        ListItem() {
          Row() {
            Column() {
              this.generatingItem()
            }
            .width('100%')
            .constraintSize({ maxWidth: this.expandMaxWidth() })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .contentStartOffset(8)
    .contentEndOffset(8)
    .margin({ top: this.isWideLayout() ? 16 : this.globalInfoModel.statusBarHeight + CONTENT_TOP_OFFSET })
    .clip(true)
    .layoutWeight(1)
  }

  @Builder
  private pageContent() {
    Column() {
      if (this.messages.length === 0) {
        this.emptyConversationPage()
      } else {
        this.messageList()
        this.inputArea(true)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private wideHeaderIcon(symbol: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(19)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(40)
    .height(40)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .accessibilityText(label)
    .onClick(action)
  }

  private wideTitleBarTitleText(): string {
    const activeSession: ChatSession | undefined = this.findSession(this.historyStore.activeSessionId);
    return activeSession?.title ?? AI_BRAND_NAME;
  }

  @Builder
  private wideTitleBar() {
    Row({ space: 10 }) {
      Text(this.wideTitleBarTitleText())
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)

      this.wideHeaderIcon($r('sys.symbol.square_and_pencil'), '新建对话', () => {
        this.startNewConversation();
      })

      this.wideHeaderIcon($r('sys.symbol.xmark'), '关闭', () => {
        this.closeChatPage();
      })
    }
    .width('100%')
    .height(68 + this.globalInfoModel.statusBarHeight)
    .padding({ left: 24, right: 24, top: this.globalInfoModel.statusBarHeight })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.background_primary'))
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  @Builder
  private wideConversationContent() {
    Column() {
      if (this.messages.length === 0) {
        this.wideEmptyConversationPage()
      } else {
        this.messageList()
        this.inputArea(true)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  private wideLayout() {
    Row({ space: 0 }) {
      Column() {
        this.historyDrawer()
      }
      .width(this.historyDrawerWidth())
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))

      Divider()
        .vertical(true)
        .height('100%')
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Column() {
        this.wideTitleBar()
        this.wideConversationContent()
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor($r('sys.color.background_primary'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private phoneLayout() {
    SideBarContainer(SideBarContainerType.Overlay) {
      this.historyDrawer()

      Stack() {
        HdsNavDestination() {
          this.pageContent()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.background_primary'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .hideBackButton(false)
        .titleMode(HdsNavDestinationTitleMode.MINI)
        .titleBar({
          avoidLayoutSafeArea: true,
          enableComponentSafeArea: false,
          style: this.titleBarStyle(),
          content: this.titleBarContent()
        })
        .bindToScrollable([this.listScroller])
        .ignoreLayoutSafeArea(
          [LayoutSafeAreaType.SYSTEM],
          [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
        )

        if (this.historyDrawerOpen) {
          this.drawerMask()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_primary'))
    }
    .showSideBar(this.historyDrawerOpen)
    .onChange((value: boolean) => {
      this.historyDrawerOpen = value;
    })
    .showControlButton(false)
    .autoHide(false)
    .sideBarPosition(SideBarPosition.Start)
    .sideBarWidth(this.historyDrawerWidth())
    .minSideBarWidth(this.historyDrawerWidth())
    .maxSideBarWidth(this.historyDrawerWidth())
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      if (this.isWideLayout()) {
        this.wideLayout()
      } else {
        this.phoneLayout()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }
}
