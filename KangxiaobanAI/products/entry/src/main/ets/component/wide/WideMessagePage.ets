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

import { ColorMetrics, KeyboardAvoidMode, LengthMetrics } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';
import { MessageApi } from '../../network/MessageApi';
import AuthStore from '../../network/AuthStore';
import { MessageContact, UserMessage } from '../../network/Dto';
import { WsClient } from '../../network/WsClient';

type WideConversationKind = 'family' | 'work' | 'system';
type WideMessageFilter = 'all' | 'unread' | WideConversationKind;
type WideChatRole = 'incoming' | 'outgoing' | 'system';

interface WideConversationData {
  id: string;
  peerId?: number;
  kind: WideConversationKind;
  title: string;
  subtitle: string;
  avatar: string;
  preview: string;
  time: string;
  replyable: boolean;
}

interface WideChatRecord {
  id: string;
  conversationId: string;
  role: WideChatRole;
  author: string;
  content: string;
  time: string;
  dayLabel?: string;
}

const MESSAGE_FILTER_ITEMS: WideSlidingCapsuleItem[] = [
  { title: '全部', index: 0 },
  { title: '未读', index: 1 },
  { title: '家属', index: 2 },
  { title: '工作', index: 3 },
  { title: '系统', index: 4 }
];

const MESSAGE_FILTER_VALUES: WideMessageFilter[] = ['all', 'unread', 'family', 'work', 'system'];


@ComponentV2
export struct WideMessagePage {
  @Param compactWidth: boolean = false;
  @Param topBarHeight: number = 0;
  @Param @Require messageListScroller: Scroller;
  @Param @Require chatScroller: Scroller;
  @Param naviIndicatorHeight: number = 0;
  @Param backRequestToken: number = 0;
  @Event onLocalDetailVisibilityChange: (visible: boolean) => void = (_visible: boolean) => {};
  @Event onUnreadCountChange: (count: number) => void = (_count: number) => {};
  @Event onListScrollerActive: () => void = () => {};
  @Event onChatScrollerActive: () => void = () => {};
  @Local searchText: string = '';
  @Local activeFilterIndex: number = 0;
  @Local selectedConversationId: string = '';
  @Local unreadConversationIds: string[] = [];
  @Local hoveredConversationId: string = '';
  @Local focusedConversationId: string = '';
  @Local replyText: string = '';
  @Local sentRecords: WideChatRecord[] = [];
  @Local backendConversations: WideConversationData[] = [];
  @Local backendRecords: WideChatRecord[] = [];
  @Local compactDetailVisible: boolean = false;
  private scrollTimerId: number = -1;
  private previousKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private composerHasFocus: boolean = false;
  private wsClient: WsClient = new WsClient();

  @Monitor('backRequestToken')
  onBackRequestTokenChange(): void {
    if (this.compactWidth && this.compactDetailVisible) {
      this.showCompactList();
    }
  }

  @Monitor('compactWidth')
  onCompactWidthChange(): void {
    this.reportVisibleScrollerOwner();
  }

  @Monitor('unreadConversationIds')
  onUnreadConversationIdsChange(): void {
    this.reportUnreadCount();
  }

  @Styles
  keyboardFocusStyle() {
    .focusable(true)
    .focusOnTouch(true)
    .hoverEffect(HoverEffect.None)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
  }

  aboutToAppear(): void {
    this.loadBackendMessages();
    this.wsClient.connect((payload: string): void => {
      if (payload.indexOf('message.created') >= 0) {
        this.loadBackendMessages();
      }
    });
    this.reportUnreadCount();
    this.reportVisibleScrollerOwner();
    if (!this.compactWidth) {
      this.scheduleScrollToBottom();
    }
  }

  private async loadBackendMessages(): Promise<void> {
    const resp = await MessageApi.contacts();
    if (resp.code !== 0 || !resp.data) {
      return;
    }
    const currentUserId: number = AuthStore.getUser()?.id ?? 0;
    const conversations: WideConversationData[] = resp.data.list.map((contact: MessageContact): WideConversationData => {
      const role: string = contact.roles.length > 0 ? contact.roles[0].code : 'work';
      const kind: WideConversationKind = role === 'family' ? 'family' : 'work';
      return {
        id: `user-${contact.id}`,
        peerId: contact.id,
        kind: kind,
        title: contact.real_name.length > 0 ? contact.real_name : contact.username,
        subtitle: `${contact.username} · ${kind === 'family' ? '家属沟通' : '工作协作'}`,
        avatar: (contact.real_name.length > 0 ? contact.real_name : contact.username).slice(0, 1),
        preview: '暂无消息',
        time: '--',
        replyable: true
      };
    });
    const records: WideChatRecord[] = [];
    for (const conversation of conversations) {
      const messageResp = await MessageApi.list(conversation.peerId ?? 0);
      if (messageResp.code !== 0 || !messageResp.data) {
        continue;
      }
      for (const message of messageResp.data.list) {
        records.push(this.toChatRecord(message, currentUserId, conversation.id));
      }
      const latest: UserMessage | undefined = messageResp.data.list.length > 0 ?
        messageResp.data.list[messageResp.data.list.length - 1] : undefined;
      if (latest) {
        conversation.preview = latest.content;
        conversation.time = this.messageTime(latest.sent_at);
      }
    }
    this.backendConversations = conversations;
    this.backendRecords = records;
    if (conversations.length > 0 && this.selectedConversationId.indexOf('user-') !== 0) {
      this.selectedConversationId = conversations[0].id;
    }
    this.reportUnreadCount();
    this.scheduleScrollToBottom();
  }

  private messageTime(value: string): string {
    const parsed: Date = new Date(value);
    if (isNaN(parsed.getTime())) { return '--'; }
    return `${parsed.getHours().toString().padStart(2, '0')}:${parsed.getMinutes().toString().padStart(2, '0')}`;
  }

  private toChatRecord(message: UserMessage, currentUserId: number, conversationId: string): WideChatRecord {
    return {
      id: `message-${message.id}`,
      conversationId: conversationId,
      role: message.sender_id === currentUserId ? 'outgoing' : 'incoming',
      author: message.sender_id === currentUserId ? (AuthStore.getUser()?.real_name ?? '我') : '联系人',
      content: message.content,
      time: this.messageTime(message.sent_at)
    };
  }

  aboutToDisappear(): void {
    this.wsClient.close();
    this.restoreKeyboardAvoidMode();
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
      this.scrollTimerId = -1;
    }
  }

  private useComposerKeyboardAvoidMode(): void {
    if (this.composerHasFocus) {
      return;
    }
    this.previousKeyboardAvoidMode = this.getUIContext().getKeyboardAvoidMode();
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.composerHasFocus = true;
  }

  private restoreKeyboardAvoidMode(): void {
    if (!this.composerHasFocus) {
      return;
    }
    this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardAvoidMode);
    this.composerHasFocus = false;
  }

  private activeFilter(): WideMessageFilter {
    return MESSAGE_FILTER_VALUES[this.activeFilterIndex] ?? 'all';
  }

  private paneTopOffset(): number {
    return this.topBarHeight + (this.compactWidth ? 16 : 20);
  }

  private paneRadius(): number {
    return this.compactWidth ? 18 : 20;
  }

  private conversationListStartOffset(): number {
    return this.paneTopOffset() + 16 + 40 + 12 + 44 + 12 + 16;
  }

  private chatHistoryStartOffset(): number {
    return this.paneTopOffset();
  }

  private isUnread(conversationId: string): boolean {
    return this.unreadConversationIds.includes(conversationId);
  }

  private reportUnreadCount(): void {
    this.onUnreadCountChange(this.unreadConversationIds.length);
  }

  private latestSentRecord(conversationId: string): WideChatRecord | undefined {
    const records: WideChatRecord[] = this.sentRecords.filter((item: WideChatRecord) =>
      item.conversationId === conversationId);
    return records.length > 0 ? records[records.length - 1] : undefined;
  }

  private conversationPreview(item: WideConversationData): string {
    return this.latestSentRecord(item.id)?.content ?? item.preview;
  }

  private conversationTime(item: WideConversationData): string {
    return this.latestSentRecord(item.id)?.time ?? item.time;
  }

  private filteredConversations(): WideConversationData[] {
    const filter: WideMessageFilter = this.activeFilter();
    const query: string = this.searchText.trim().toLowerCase();
    return this.backendConversations.filter((item: WideConversationData) => {
      const matchesFilter: boolean = filter === 'all' ||
        (filter === 'unread' && this.isUnread(item.id)) || item.kind === filter;
      if (!matchesFilter) {
        return false;
      }
      if (query === '') {
        return true;
      }
      return item.title.toLowerCase().includes(query) || item.subtitle.toLowerCase().includes(query) ||
        this.conversationPreview(item).toLowerCase().includes(query);
    });
  }

  private selectedConversation(): WideConversationData | undefined {
    return this.backendConversations.find((item: WideConversationData) => item.id === this.selectedConversationId);
  }

  private reportVisibleScrollerOwner(): void {
    if (this.compactWidth && !this.compactDetailVisible) {
      this.onListScrollerActive();
    } else {
      this.onChatScrollerActive();
    }
  }

  private currentChatRecords(): WideChatRecord[] {
    const presetRecords: WideChatRecord[] = this.backendRecords.filter((item: WideChatRecord) =>
      item.conversationId === this.selectedConversationId);
    const localRecords: WideChatRecord[] = this.sentRecords.filter((item: WideChatRecord) =>
      item.conversationId === this.selectedConversationId);
    return [...presetRecords, ...localRecords];
  }

  private kindLabel(kind: WideConversationKind): string {
    if (kind === 'family') {
      return '家属沟通';
    }
    if (kind === 'work') {
      return '工作协作';
    }
    return '系统消息';
  }

  private avatarColor(kind: WideConversationKind): ResourceColor {
    if (kind === 'family') {
      return $r('app.color.status_normal');
    }
    if (kind === 'system') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.brand_blue');
  }

  private avatarBackground(kind: WideConversationKind): ResourceColor {
    if (kind === 'family') {
      return $r('app.color.status_normal_bg');
    }
    if (kind === 'system') {
      return $r('app.color.status_warning_bg');
    }
    return $r('sys.color.comp_background_secondary');
  }

  private conversationRowBackground(conversationId: string): ResourceColor {
    if (conversationId === this.selectedConversationId) {
      return $r('sys.color.comp_background_secondary');
    }
    if (conversationId === this.hoveredConversationId || conversationId === this.focusedConversationId) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  private selectConversation(item: WideConversationData): void {
    this.selectedConversationId = item.id;
    this.replyText = '';
    if (this.isUnread(item.id)) {
      this.unreadConversationIds = this.unreadConversationIds.filter((id: string) => id !== item.id);
    }
    if (this.compactWidth) {
      this.showCompactDetail();
    } else {
      this.onChatScrollerActive();
    }
    this.scheduleScrollToBottom();
  }

  private showCompactList(): void {
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
      this.scrollTimerId = -1;
    }
    this.compactDetailVisible = false;
    this.onLocalDetailVisibilityChange(false);
    this.onListScrollerActive();
  }

  private showCompactDetail(): void {
    this.compactDetailVisible = true;
    this.onLocalDetailVisibilityChange(true);
    this.onChatScrollerActive();
  }

  private currentTimeText(): string {
    const now: Date = new Date();
    const hour: string = now.getHours().toString().padStart(2, '0');
    const minute: string = now.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private async sendReply(): Promise<void> {
    const conversation: WideConversationData | undefined = this.selectedConversation();
    const content: string = this.replyText.trim();
    if (!conversation || !conversation.replyable || content === '') {
      return;
    }
    const resp = await MessageApi.send(conversation.peerId ?? 0, content);
    if (resp.code !== 0 || !resp.data) { return; }
    this.backendRecords = [...this.backendRecords, this.toChatRecord(resp.data, AuthStore.getUser()?.id ?? 0, conversation.id)];
    conversation.preview = content;
    conversation.time = this.currentTimeText();
    this.replyText = '';
    this.scheduleScrollToBottom();
  }

  private scheduleScrollToBottom(): void {
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
    }
    this.scrollTimerId = setTimeout(() => {
      const records: WideChatRecord[] = this.currentChatRecords();
      if (records.length > 0) {
        this.chatScroller.scrollToIndex(records.length - 1, true, ScrollAlign.END);
      }
      this.scrollTimerId = -1;
    }, 80);
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  @Builder
  private conversationAvatar(item: WideConversationData, size: number) {
    Row() {
      if (item.kind === 'family') {
        Text(item.avatar)
          .fontSize(size >= 40 ? 16 : 13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.avatarColor(item.kind))
      } else {
        SymbolGlyph($r('sys.symbol.bell_fill'))
          .fontSize(size >= 40 ? 20 : 16)
          .fontColor([this.avatarColor(item.kind)])
      }
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .backgroundColor(this.avatarBackground(item.kind))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private messageSearch() {
    Search({ value: this.searchText, placeholder: '搜索联系人或消息内容' })
      .width('100%')
      .height(40)
      .fontColor($r('sys.color.font_primary'))
      .placeholderColor($r('sys.color.font_tertiary'))
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(20)
      .focusBox({
        margin: LengthMetrics.vp(1),
        strokeWidth: LengthMetrics.vp(2),
        strokeColor: ColorMetrics.numeric(0xFF1D63ED)
      })
      .onChange((value: string) => {
        this.searchText = value;
      })
  }

  @Builder
  private filterBar() {
    WideSlidingCapsule({
      items: MESSAGE_FILTER_ITEMS,
      selectedIndex: this.activeFilterIndex,
      itemWidth: 68,
      fillWidth: true,
      onSelect: (index: number) => {
        this.activeFilterIndex = index;
      }
    })
  }

  @Builder
  private conversationRow(item: WideConversationData) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        this.conversationAvatar(item, 44)

        if (this.isUnread(item.id)) {
          Row()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor($r('app.color.brand_blue'))
            .border({ width: 2, color: $r('sys.color.comp_background_primary') })
        }
      }
      .width(44)
      .height(44)

      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(item.title)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(this.isUnread(item.id) ? FontWeight.Medium : FontWeight.Regular)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.conversationTime(item))
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.conversationPreview(item))
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.isUnread(item.id) ? $r('sys.color.font_secondary') :
            $r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(76)
    .padding({ left: 12, right: 12 })
    .borderRadius(12)
    .backgroundColor(this.conversationRowBackground(item.id))
    .alignItems(VerticalAlign.Center)
    .accessibilityText(`${item.title} ${this.conversationPreview(item)}`)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .keyboardFocusStyle()
    .onHover((isHover: boolean) => {
      this.hoveredConversationId = isHover ? item.id : '';
    })
    .onFocus(() => {
      this.focusedConversationId = item.id;
    })
    .onBlur(() => {
      if (this.focusedConversationId === item.id) {
        this.focusedConversationId = '';
      }
    })
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.selectConversation(item));
    })
    .onClick(() => {
      this.selectConversation(item);
    })
  }

  @Builder
  private conversationList() {
    if (this.filteredConversations().length > 0) {
      List({ scroller: this.messageListScroller, space: 4 }) {
        ForEach(this.filteredConversations(), (item: WideConversationData, index: number) => {
          ListItem() {
            this.conversationRow(item)
          }
          .padding({ top: index === 0 ? this.conversationListStartOffset() : 0 })
        }, (item: WideConversationData) => item.id)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, bottom: 16 + this.naviIndicatorHeight })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScrollStart(() => {
        this.onListScrollerActive();
      })
    } else {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.message_on_message_fill'))
          .fontSize(38)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('没有找到会话')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text('试试其他关键词或筛选条件')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height('100%')
      .padding({
        left: 14,
        right: 14,
        top: this.conversationListStartOffset(),
        bottom: 16 + this.naviIndicatorHeight
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private listPane() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row()
          .width('100%')
          .height(this.paneTopOffset())

        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(this.paneRadius())
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)

      this.conversationList()

      Column({ space: 12 }) {
        this.messageSearch()
        this.filterBar()
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 16, bottom: 12 })
      .margin({ top: this.paneTopOffset() })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius({
        topLeft: this.paneRadius(),
        topRight: this.paneRadius(),
        bottomLeft: 0,
        bottomRight: 0
      })
      .clip(true)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private daySeparator(label: string) {
    Row() {
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(12)
        .backgroundColor($r('sys.color.comp_background_secondary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private incomingRecord(record: WideChatRecord) {
    Row() {
      Column({ space: 4 }) {
        Text(record.author)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))

        Text(record.content)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(23)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
          .constraintSize({ maxWidth: 560 })

        Text(record.time)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .constraintSize({ maxWidth: 820 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private outgoingRecord(record: WideChatRecord) {
    Row() {
      Row() {
        Blank()

        Column({ space: 4 }) {
          Text(record.content)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_on_brand'))
            .lineHeight(23)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor($r('app.color.brand_blue'))
            .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
            .constraintSize({ maxWidth: 560 })

          Row({ space: 6 }) {
            Text(record.time)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
            Text('已读')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .constraintSize({ maxWidth: 820 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private systemRecord(record: WideChatRecord) {
    Row() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.bell_fill'))
            .fontSize(16)
            .fontColor([$r('app.color.status_warning')])
          Text(record.author)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(record.content)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(22)
          .width('100%')

        Text(record.time)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .textAlign(TextAlign.End)
      }
      .width(480)
      .padding(16)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private chatRecord(record: WideChatRecord) {
    if (record.role === 'incoming') {
      this.incomingRecord(record)
    } else if (record.role === 'outgoing') {
      this.outgoingRecord(record)
    } else {
      this.systemRecord(record)
    }
  }

  @Builder
  private chatHistory() {
    List({ scroller: this.chatScroller, space: 10 }) {
      ForEach(this.currentChatRecords(), (record: WideChatRecord, index: number) => {
        ListItem() {
          Column({ space: 12 }) {
            if (record.dayLabel !== undefined) {
              this.daySeparator(record.dayLabel)
            }
            this.chatRecord(record)
          }
          .width('100%')
        }
        .padding({ top: index === 0 ? this.chatHistoryStartOffset() : 0 })
      }, (record: WideChatRecord) => record.id)

      ListItem() {
        Row()
          .width('100%')
          .height(4)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 20, right: 20, top: 16, bottom: 10 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
    .onScrollStart(() => {
      this.onChatScrollerActive();
    })
  }

  @Builder
  private composer() {
    Column() {
      Row({ space: 4 }) {
        TextArea({ text: this.replyText, placeholder: `回复 ${this.selectedConversation()!.title}` })
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
          .barState(BarState.Off)
          .layoutWeight(1)
          .onFocus(() => {
            this.useComposerKeyboardAvoidMode();
          })
          .onBlur(() => {
            this.restoreKeyboardAvoidMode();
          })
          .onChange((value: string) => {
            this.replyText = value;
          })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(19)
            .fontColor([this.replyText.trim().length > 0 ? $r('app.color.text_on_brand') :
              $r('sys.color.icon_tertiary')])
        }
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width(40)
        .height(40)
        .backgroundColor(this.replyText.trim().length > 0 ? $r('app.color.brand_blue') :
          $r('sys.color.comp_background_secondary'))
        .enabled(this.replyText.trim().length > 0)
        .accessibilityText('发送')
        .onClick(() => {
          this.sendReply();
        })
      }
      .width('100%')
      .constraintSize({ minHeight: 56, maxWidth: 760 })
      .padding({ left: 10, right: 6, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(28)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 3 })
      .alignItems(VerticalAlign.Bottom)
      .animation({ duration: 180, curve: Curve.EaseOut })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 12 + this.naviIndicatorHeight })
    .backgroundColor($r('sys.color.background_secondary'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private readOnlyFooter() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.bell_fill'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_secondary')])
      Text('系统通知无需回复')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(64 + this.naviIndicatorHeight)
    .padding({ bottom: this.naviIndicatorHeight })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private detailFooter() {
    Column() {
      if (this.selectedConversation()!.replyable) {
        this.composer()
      } else {
        this.readOnlyFooter()
      }
    }
    .width('100%')
    .borderRadius({
      topLeft: 0,
      topRight: 0,
      bottomLeft: this.paneRadius(),
      bottomRight: this.paneRadius()
    })
    .clip(true)
  }

  @Builder
  private detailPane() {
    if (this.selectedConversation()) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Row()
            .width('100%')
            .height(this.paneTopOffset())

          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(this.paneRadius())
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)

        Column({ space: 0 }) {
          this.chatHistory()
          this.detailFooter()
        }
        .width('100%')
        .height('100%')

      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
    } else {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.message_on_message_fill'))
          .fontSize(46)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('选择一个会话')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .height('100%')
      .padding({ top: this.paneTopOffset() })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(this.paneRadius())
      .clip(true)
    }
  }

  build() {
    if (this.compactWidth) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.compactDetailVisible) {
          Column() {
            this.detailPane()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.move(TransitionEdge.END)
              .animation({ duration: 250, curve: Curve.LinearOutSlowIn }),
            TransitionEffect.move(TransitionEdge.END)
              .animation({ duration: 200, curve: Curve.FastOutLinearIn })
          ))
        } else {
          Column() {
            this.listPane()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.move(TransitionEdge.START)
              .animation({ duration: 250, curve: Curve.LinearOutSlowIn }),
            TransitionEffect.move(TransitionEdge.START)
              .animation({ duration: 200, curve: Curve.FastOutLinearIn })
          ))
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
      .backgroundColor($r('sys.color.background_secondary'))
    } else {
      Row({ space: 20 }) {
        Column() {
          this.listPane()
        }
        .width('30%')
        .constraintSize({ minWidth: 360, maxWidth: 440 })
        .height('100%')

        this.detailPane()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }
}
