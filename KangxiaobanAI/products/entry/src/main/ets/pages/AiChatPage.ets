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
  Chip,
  ChipSize,
  ColorMetrics,
  KeyboardAvoidMode,
  LengthMetrics,
  SymbolGlyphModifier
} from '@kit.ArkUI';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import {
  ActionBarButton,
  ActionBarStyle,
  HdsActionBar,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitle,
  IconStyleMode,
  hdsMaterial,
  ScrollEffectType,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';
import { WindowUtil } from '../util/WindowUtil';

const CONTENT_TOP_OFFSET: number = 56;
const AI_CHAT_HISTORY_KEY: string = 'aiChatHistoryStore';
const MAX_CHAT_SESSIONS: number = 50;

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
  thinkingContent?: string;
  thinkSeconds?: number;
  thinkingExpanded?: boolean;
  feedback?: ChatFeedback;
}

interface ChatSession {
  id: string;
  title: string;
  messages: ChatMessage[];
  modeIndex: number;
  deepThinkingEnabled: boolean;
  smartSearchEnabled: boolean;
  updatedAt: number;
}

@ObservedV2
class AiChatHistoryStore {
  @Trace sessions: ChatSession[] = [];
  @Trace activeSessionId: string = '';
}

@ComponentV2
export struct AiChatPage {
  @Param @Require geometryId: string;
  @Event onClose: () => void = () => {};
  @Event onMenu: () => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local historyStore: AiChatHistoryStore =
    AppStorageV2.connect(AiChatHistoryStore, AI_CHAT_HISTORY_KEY, () => new AiChatHistoryStore()) ??
      new AiChatHistoryStore();
  @Local messages: ChatMessage[] = [];
  @Local inputText: string = '';
  @Local keyboardOffset: number = 0;
  @Local modeSelectedIndex: number = 0;
  @Local deepThinkingEnabled: boolean = true;
  @Local smartSearchEnabled: boolean = true;
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
      thinkingContent: message.thinkingContent,
      thinkSeconds: message.thinkSeconds,
      thinkingExpanded: message.thinkingExpanded,
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
      return '新对话';
    }
    return normalized.length > 18 ? `${normalized.substring(0, 18)}…` : normalized;
  }

  private sessionModeLabel(index: number): string {
    if (index === 1) {
      return '专家模式';
    }
    if (index === 2) {
      return '识图模式';
    }
    return '快速模式';
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
      modeIndex: this.modeSelectedIndex,
      deepThinkingEnabled: this.deepThinkingEnabled,
      smartSearchEnabled: this.smartSearchEnabled,
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
      modeIndex: this.modeSelectedIndex,
      deepThinkingEnabled: this.deepThinkingEnabled,
      smartSearchEnabled: this.smartSearchEnabled,
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
    this.modeSelectedIndex = session.modeIndex;
    this.deepThinkingEnabled = session.deepThinkingEnabled;
    this.smartSearchEnabled = session.smartSearchEnabled;
    this.inputText = '';
    this.isGenerating = false;
    this.getUIContext().setKeyboardAvoidMode(
      session.messages.length > 0 ? KeyboardAvoidMode.RESIZE : KeyboardAvoidMode.NONE
    );
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
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
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
    this.modeSelectedIndex = 0;
    this.deepThinkingEnabled = true;
    this.smartSearchEnabled = true;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
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
    if (this.globalInfoModel.deviceWidth <= 0) {
      return 240;
    }
    return Math.min(272, Math.max(232, this.globalInfoModel.deviceWidth * 0.64));
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

  private titleBarTitle(): HdsNavigationTitle {
    if (this.messages.length === 0) {
      return { mainTitle: '康小伴智能守护' };
    }
    return {
      mainTitle: this.conversationTitle(),
      subTitle: this.currentModeLabel()
    };
  }

  private titleBarContent(): TitleBarContentOptions {
    return {
      title: this.titleBarTitle(),
      backIcon: {
        label: '打开菜单',
        icon: $r('sys.symbol.line_3_horizontal'),
        type: IconStyleMode.NORMAL,
        isEnabled: true,
        action: () => {
          this.openHistoryDrawer();
        }
      },
      menu: {
        value: [{
          content: {
            label: '关闭',
            icon: $r('sys.symbol.xmark'),
            type: IconStyleMode.NORMAL,
            isEnabled: true,
            action: () => {
              this.closeChatPage();
            }
          }
        }]
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
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          },
          menuStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          }
        }
      },
      scrollEffectStyle: {
        contentStyle: {
          backIconStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          },
          menuStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          }
        }
      }
    };
  }

  private pagePadding(): number {
    if (this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      this.globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_XL) {
      return 24;
    }
    return 16;
  }

  private expandMaxWidth(): number {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    if (widthBreakpoint === WidthBreakpoint.WIDTH_LG || widthBreakpoint === WidthBreakpoint.WIDTH_XL) {
      return 760;
    }
    if (widthBreakpoint === WidthBreakpoint.WIDTH_MD) {
      return 680;
    }
    return 9999;
  }

  private currentModeIndex(): number {
    return this.modeSelectedIndex;
  }

  private currentModeLabel(): string {
    const index: number = this.currentModeIndex();
    if (index === 1) {
      return '专家模式';
    }
    if (index === 2) {
      return '识图模式';
    }
    return '快速模式';
  }

  private conversationTitle(): string {
    for (let i: number = 0; i < this.messages.length; i++) {
      if (this.messages[i].role === 'user') {
        const text: string = this.messages[i].content.replace(/\n/g, ' ').trim();
        const shortText: string = text.length > 10 ? `${text.substring(0, 10)}…` : text;
        return `用户发送${shortText}`;
      }
    }
    return '康小伴智能守护';
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

  private buildThinkingText(text: string, modeIndex: number): string {
    if (modeIndex === 2) {
      return '用户当前选择了识图模式，但这条消息没有附带图片。我会先根据文字理解意图，同时提醒用户可以添加图片，以便进行更准确的分析。';
    }
    if (text.trim() === '1') {
      return '好的，用户只发了一个“1”。这肯定不是完整的问题，可能是在测试，也可能是不小心按到了发送，或者在等着我先开口。\n\n无论如何，直接回应“1”没有意义。我需要主动打破僵局，引导用户说出真实意图。回复应该友好、开放，并提供几个常见的可选方向，让用户能快速说明需求。';
    }
    return `我需要先理解“${text}”背后的真实需求，再结合护理工作场景给出清晰、可执行的回答。回答应避免过度推断，同时把需要确认的信息交还给用户。`;
  }

  private buildAnswerText(text: string, modeIndex: number): string {
    if (text.trim() === '1') {
      return '你好！看起来你只发了一个“1”，是想测试我是否在线，还是不小心按到了发送键？🙂\n\n不管怎样，我在这里呢！有什么我可以帮你的吗？无论是提问、聊天、查资料，还是需要我帮你处理什么问题，都随时告诉我吧～';
    }
    if (modeIndex === 2) {
      return `我收到了你的消息：“${text}”。当前是识图模式，你可以点击输入框右下角的附件按钮添加图片；收到图片后，我会结合文字说明一起分析。`;
    }
    return `我收到了你的消息：“${text}”。\n\n我会按照${modeIndex === 1 ? '专家模式' : '快速模式'}整理重点，并优先给出清晰、可执行的建议。如果涉及住户健康或安全风险，请同时补充时间、症状和最近一次测量结果。`;
  }

  private createAiMessage(id: string, text: string, modeIndex: number, useThinking: boolean): ChatMessage {
    return {
      id: id,
      role: 'ai',
      content: this.buildAnswerText(text, modeIndex),
      thinkingContent: useThinking ? this.buildThinkingText(text, modeIndex) : undefined,
      thinkSeconds: useThinking ? (modeIndex === 1 ? 4 : 2) : undefined,
      thinkingExpanded: useThinking,
      feedback: 'none'
    };
  }

  private appendAiResponse(text: string, modeIndex: number, useThinking: boolean): void {
    const message: ChatMessage = this.createAiMessage(`a-${Date.now()}`, text, modeIndex, useThinking);
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
    const modeIndex: number = this.currentModeIndex();
    const useThinking: boolean = this.deepThinkingEnabled;
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
      this.appendAiResponse(text, modeIndex, useThinking);
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
    const modeIndex: number = this.currentModeIndex();
    const useThinking: boolean = this.deepThinkingEnabled;
    this.responseTimer = setTimeout(() => {
      const replacement: ChatMessage = this.createAiMessage(message.id, text, modeIndex, useThinking);
      this.messages = this.messages.map((item: ChatMessage): ChatMessage =>
        item.id === message.id ? replacement : item);
      this.syncActiveSession();
      this.isGenerating = false;
      this.scheduleScrollToBottom(100);
      this.responseTimer = -1;
    }, 500);
  }

  private toggleThinking(message: ChatMessage): void {
    this.messages = this.messages.map((item: ChatMessage): ChatMessage => {
      if (item.id !== message.id) {
        return item;
      }
      return {
        id: item.id,
        role: item.role,
        content: item.content,
        thinkingContent: item.thinkingContent,
        thinkSeconds: item.thinkSeconds,
        thinkingExpanded: !(item.thinkingExpanded ?? true),
        feedback: item.feedback
      };
    });
    this.syncActiveSession();
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
        thinkingContent: item.thinkingContent,
        thinkSeconds: item.thinkSeconds,
        thinkingExpanded: item.thinkingExpanded,
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

  private chipSymbol(symbol: Resource, color: ResourceColor): SymbolGlyphModifier {
    return new SymbolGlyphModifier(symbol)
      .fontSize(15)
      .fontColor([color]);
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
  private thoughtBlock(message: ChatMessage) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.AI_deep_thinking'))
          .fontSize(18)
          .fontColor([$r('app.color.brand_blue')])
        Text(`已思考（用时 ${message.thinkSeconds ?? 0} 秒）`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
        SymbolGlyph(message.thinkingExpanded === false ?
          $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_up'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .height(40)
      .onClick(() => {
        this.toggleThinking(message);
      })

      if (message.thinkingExpanded !== false) {
        Row({ space: 12 }) {
          Column()
            .width(1)
            .alignSelf(ItemAlign.Stretch)
            .backgroundColor($r('sys.color.comp_divider'))
          Text(message.thinkingContent ?? '')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
            .lineHeight(24)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private aiMessageItem(message: ChatMessage) {
    Column({ space: 12 }) {
      if (message.thinkingContent && message.thinkingContent.length > 0) {
        this.thoughtBlock(message)
      }

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
      Text(this.deepThinkingEnabled ? '康小伴正在思考…' : '康小伴正在回复…')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 8, bottom: 24 })
  }

  @Builder
  private modeButton(index: number, label: string, symbol: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 4 }) {
        SymbolGlyph(symbol)
          .fontSize(14)
          .fontColor([this.modeSelectedIndex === index ?
            $r('app.color.brand_blue') : $r('sys.color.icon_secondary')])
        Text(label)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.modeSelectedIndex === index ?
            $r('app.color.brand_blue') : $r('sys.color.font_secondary'))
          .maxLines(1)
      }
      .justifyContent(FlexAlign.Center)
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .layoutWeight(1)
    .height(36)
    .padding({ left: 5, right: 5 })
    .backgroundColor(this.modeSelectedIndex === index ? 0xFFEAF1FF : Color.Transparent)
    .border({
      width: 0.5,
      color: this.modeSelectedIndex === index ? $r('app.color.brand_blue') : $r('sys.color.comp_divider')
    })
    .onClick(() => {
      this.modeSelectedIndex = index;
      this.syncActiveSession();
    })
  }

  @Builder
  private emptyHero() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.AI_message'))
          .fontSize(26)
          .fontColor([$r('app.color.brand_blue')])
        Text(`使用${this.currentModeLabel()}开始对话`)
          .fontSize($r('sys.float.Title_S'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
      }

      Row({ space: 6 }) {
        this.modeButton(0, '快速模式', $r('sys.symbol.bolt_fill'))
        this.modeButton(1, '专家模式', $r('sys.symbol.AI_deep_thinking'))
        this.modeButton(2, '识图模式', $r('sys.symbol.AI_picture_on_square'))
      }
      .width('100%')
      .height(40)
      .constraintSize({ maxWidth: 320 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 18 })
  }

  @Builder
  private featureChip(
    label: string,
    symbol: Resource,
    activated: boolean,
    action: () => void
  ) {
    Chip({
      prefixSymbol: {
        normal: this.chipSymbol(symbol, $r('sys.color.icon_secondary')),
        activated: this.chipSymbol(symbol, $r('app.color.brand_blue'))
      },
      label: {
        text: label,
        fontSize: $r('sys.float.Caption_M'),
        fontColor: $r('sys.color.font_secondary'),
        activatedFontColor: $r('app.color.brand_blue'),
        labelMargin: { left: 3, right: 3 }
      },
      size: ChipSize.SMALL,
      allowClose: false,
      activated: activated,
      backgroundColor: Color.Transparent,
      activatedBackgroundColor: 0xFFEAF1FF,
      enabled: true,
      onClicked: action
    })
  }

  @Builder
  private composer() {
    Column({ space: 4 }) {
      TextInput({ text: this.inputText, placeholder: '给 康小伴 发送消息' })
        .type(InputType.Normal)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .placeholderFont({ size: $r('sys.float.Body_L') })
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor(Color.Transparent)
        .padding({ left: 2, right: 2 })
        .height(36)
        .width('100%')
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          this.sendMessage();
        })

      Row({ space: 4 }) {
        this.featureChip('深度思考', $r('sys.symbol.AI_deep_thinking'), this.deepThinkingEnabled, () => {
          this.deepThinkingEnabled = !this.deepThinkingEnabled;
          this.syncActiveSession();
        })
        this.featureChip('智能搜索', $r('sys.symbol.AI_search'), this.smartSearchEnabled, () => {
          this.smartSearchEnabled = !this.smartSearchEnabled;
          this.syncActiveSession();
        })
        Blank()

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.paperclip'))
            .fontSize(19)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .width(36)
        .height(36)
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
        .width(38)
        .height(38)
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
      .height(40)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .constraintSize({ maxWidth: this.expandMaxWidth(), minHeight: 94 })
    .padding({ left: 12, right: 8, top: 8, bottom: 6 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(22)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({
      radius: 18,
      color: 'rgba(0,0,0,0.07)',
      offsetX: 0,
      offsetY: 7
    })
    .alignItems(HorizontalAlign.Start)
  }

  private inputBottomMargin(): number {
    if (this.messages.length === 0) {
      return this.globalInfoModel.naviIndicatorHeight;
    }
    return this.keyboardOffset > 0 ? 8 : this.globalInfoModel.naviIndicatorHeight;
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
      left: this.pagePadding(),
      right: this.pagePadding(),
      top: 8,
      bottom: this.messages.length > 0 && this.keyboardOffset > 0 ? 0 : 2
    })
    .margin({ bottom: this.inputBottomMargin() })
    .backgroundColor($r('sys.color.background_primary'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private newConversationButton() {
    Row() {
      Text('新建会话')
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
      top: this.globalInfoModel.statusBarHeight + 10,
      bottom: this.globalInfoModel.naviIndicatorHeight + 8
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .shadow({ radius: 18, color: 'rgba(0,0,0,0.12)', offsetX: 3 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
            if (message.role === 'ai') {
              this.aiMessageItem(message)
            } else {
              this.userMessageItem(message)
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: this.expandMaxWidth() })
          .justifyContent(FlexAlign.Center)
        }
      }, (message: ChatMessage) =>
        `${message.id}-${message.thinkingExpanded ?? true}-${message.feedback ?? 'none'}`)

      if (this.isGenerating) {
        ListItem() {
          Row() {
            this.generatingItem()
          }
          .width('100%')
          .constraintSize({ maxWidth: this.expandMaxWidth() })
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .contentStartOffset(8)
    .contentEndOffset(8)
    .margin({ top: this.globalInfoModel.statusBarHeight + CONTENT_TOP_OFFSET })
    .clip(true)
    .layoutWeight(1)
  }

  @Builder
  private pageContent() {
    Column() {
      if (this.messages.length === 0) {
        Blank()
          .layoutWeight(4)
        this.emptyHero()
      } else {
        this.messageList()
      }

      this.inputArea(this.messages.length > 0)

      if (this.messages.length === 0) {
        Blank()
          .layoutWeight(5)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  build() {
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
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }
}
