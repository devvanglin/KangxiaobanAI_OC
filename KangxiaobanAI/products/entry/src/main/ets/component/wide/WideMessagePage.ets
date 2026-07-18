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

import { ColorMetrics, LengthMetrics } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

type WideConversationKind = 'family' | 'work' | 'system';
type WideMessageFilter = 'all' | 'unread' | WideConversationKind;
type WideChatRole = 'incoming' | 'outgoing' | 'system';

interface WideConversationData {
  id: string;
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

const DEMO_CONVERSATIONS: WideConversationData[] = [
  {
    id: 'family-zhou',
    kind: 'family',
    title: '周敏',
    subtitle: '周奶奶家属 · 2F-215 · 已授权联系人',
    avatar: '周',
    preview: '收到，谢谢您。午休后有变化再和我说。',
    time: '10:32',
    replyable: true
  },
  {
    id: 'station-east-2f',
    kind: 'work',
    title: '2F 东区护理站',
    subtitle: '当班协作群 · 8人',
    avatar: '护',
    preview: '肖爷爷关怀任务已派给你，请在 10:40 前反馈。',
    time: '10:18',
    replyable: true
  },
  {
    id: 'care-department',
    kind: 'work',
    title: '护理部',
    subtitle: '工作通知 · 32人',
    avatar: '护',
    preview: '课前案例已经更新到工作台，请在培训前完成阅读。',
    time: '09:46',
    replyable: true
  },
  {
    id: 'family-xiao',
    kind: 'family',
    title: '肖先生',
    subtitle: '肖爷爷家属 · 3F-302 · 已授权联系人',
    avatar: '肖',
    preview: '好的，完成关怀后我会把情况同步给您。',
    time: '09:36',
    replyable: true
  },
  {
    id: 'family-lin',
    kind: 'family',
    title: '林涛',
    subtitle: '林爷爷家属 · 3F-306 · 已授权联系人',
    avatar: '林',
    preview: '周六下午我过来，辛苦帮我登记一下。',
    time: '09:18',
    replyable: true
  },
  {
    id: 'system',
    kind: 'system',
    title: '系统通知',
    subtitle: '康小伴 AI 服务',
    avatar: '系',
    preview: '2 条离线护理记录已同步完成，无需重复提交。',
    time: '昨天',
    replyable: false
  }
];

const DEMO_CHAT_RECORDS: WideChatRecord[] = [
  {
    id: 'zhou-1',
    conversationId: 'family-zhou',
    role: 'incoming',
    author: '周敏',
    content: '刘护工您好，我妈妈昨晚休息得怎么样？她早上说左膝有点酸。',
    time: '09:54',
    dayLabel: '今天'
  },
  {
    id: 'zhou-2',
    conversationId: 'family-zhou',
    role: 'outgoing',
    author: '刘婷',
    content: '您好，周奶奶昨晚起身两次，晨间状态平稳。我已经安排午休前做疼痛评估。',
    time: '10:02'
  },
  {
    id: 'zhou-3',
    conversationId: 'family-zhou',
    role: 'incoming',
    author: '周敏',
    content: '好的，她午饭后通常会睡一会儿，麻烦评估后告诉我。',
    time: '10:06'
  },
  {
    id: 'zhou-4',
    conversationId: 'family-zhou',
    role: 'outgoing',
    author: '刘婷',
    content: '刚完成评估，左膝轻度酸胀，没有红肿。已经协助热敷并做好记录，午休后会继续观察。',
    time: '10:27'
  },
  {
    id: 'zhou-5',
    conversationId: 'family-zhou',
    role: 'incoming',
    author: '周敏',
    content: '收到，谢谢您。午休后有变化再和我说。',
    time: '10:32'
  },
  {
    id: 'station-1',
    conversationId: 'station-east-2f',
    role: 'incoming',
    author: '王倩',
    content: '周奶奶昨夜 2:10 和 4:35 两次离床，晨间说左膝酸胀，交班记录已补。',
    time: '07:46',
    dayLabel: '今天'
  },
  {
    id: 'station-2',
    conversationId: 'station-east-2f',
    role: 'outgoing',
    author: '刘婷',
    content: '收到，我午休前复评并同步家属。',
    time: '07:50'
  },
  {
    id: 'station-3',
    conversationId: 'station-east-2f',
    role: 'incoming',
    author: '护理站',
    content: '3F-306 林爷爷房间毫米波雷达离线，维修组已接单。巡房时请先人工确认。',
    time: '09:40'
  },
  {
    id: 'station-4',
    conversationId: 'station-east-2f',
    role: 'outgoing',
    author: '刘婷',
    content: '已确认，林爷爷状态稳定，设备等待检修。',
    time: '09:43'
  },
  {
    id: 'station-5',
    conversationId: 'station-east-2f',
    role: 'incoming',
    author: '护理站',
    content: '肖爷爷关怀任务已派给你，请在 10:40 前反馈接触情况。',
    time: '10:18'
  },
  {
    id: 'department-1',
    conversationId: 'care-department',
    role: 'incoming',
    author: '护理部',
    content: '本周五 16:00 在二楼培训室开展压疮预防培训，请提前 10 分钟签到。',
    time: '16:20',
    dayLabel: '昨天'
  },
  {
    id: 'department-2',
    conversationId: 'care-department',
    role: 'outgoing',
    author: '刘婷',
    content: '收到，已确认参加。',
    time: '16:31'
  },
  {
    id: 'department-3',
    conversationId: 'care-department',
    role: 'incoming',
    author: '护理部',
    content: '课前案例已经更新到工作台，请在培训前完成阅读。',
    time: '09:46',
    dayLabel: '今天'
  },
  {
    id: 'xiao-1',
    conversationId: 'family-xiao',
    role: 'incoming',
    author: '肖先生',
    content: '刘护工您好，我父亲今天还是不太愿意参加活动吗？',
    time: '09:08',
    dayLabel: '今天'
  },
  {
    id: 'xiao-2',
    conversationId: 'family-xiao',
    role: 'outgoing',
    author: '刘婷',
    content: '上午用餐正常，但情绪有些低落。我准备先陪他聊一会儿，再邀请他去熟悉的活动区。',
    time: '09:16'
  },
  {
    id: 'xiao-3',
    conversationId: 'family-xiao',
    role: 'incoming',
    author: '肖先生',
    content: '他最近会想家，您可以和他聊聊以前在厂里的事情。',
    time: '09:24'
  },
  {
    id: 'xiao-4',
    conversationId: 'family-xiao',
    role: 'outgoing',
    author: '刘婷',
    content: '好的，完成关怀后我会把情况同步给您。',
    time: '09:36'
  },
  {
    id: 'lin-1',
    conversationId: 'family-lin',
    role: 'incoming',
    author: '林涛',
    content: '您好，我爸爸今天有去书法角吗？',
    time: '08:36',
    dayLabel: '今天'
  },
  {
    id: 'lin-2',
    conversationId: 'family-lin',
    role: 'outgoing',
    author: '刘婷',
    content: '上午设备检修期间先做了人工巡房，林爷爷状态稳定。书法活动安排在下午两点。',
    time: '08:42'
  },
  {
    id: 'lin-3',
    conversationId: 'family-lin',
    role: 'outgoing',
    author: '刘婷',
    content: '如果您周末来院，我可以提前登记探视信息。',
    time: '09:02'
  },
  {
    id: 'lin-4',
    conversationId: 'family-lin',
    role: 'incoming',
    author: '林涛',
    content: '周六下午我过来，辛苦帮我登记一下。',
    time: '09:18'
  },
  {
    id: 'system-1',
    conversationId: 'system',
    role: 'system',
    author: '排班更新',
    content: '7月19日早班安排已更新，请前往工作台查看。',
    time: '昨天 18:30',
    dayLabel: '昨天'
  },
  {
    id: 'system-2',
    conversationId: 'system',
    role: 'system',
    author: '离线记录已同步',
    content: '2 条离线护理记录已同步完成，无需重复提交。',
    time: '昨天 18:42'
  }
];

@ComponentV2
export struct WideMessagePage {
  @Local searchText: string = '';
  @Local activeFilterIndex: number = 0;
  @Local selectedConversationId: string = 'family-zhou';
  @Local unreadConversationIds: string[] = [
    'station-east-2f',
    'care-department',
    'family-xiao'
  ];
  @Local hoveredConversationId: string = '';
  @Local focusedConversationId: string = '';
  @Local hoveredHeaderAction: string = '';
  @Local replyText: string = '';
  @Local sentRecords: WideChatRecord[] = [];
  private chatScroller: Scroller = new Scroller();
  private scrollTimerId: number = -1;

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
    this.scheduleScrollToBottom();
  }

  aboutToDisappear(): void {
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
      this.scrollTimerId = -1;
    }
  }

  private activeFilter(): WideMessageFilter {
    return MESSAGE_FILTER_VALUES[this.activeFilterIndex] ?? 'all';
  }

  private isUnread(conversationId: string): boolean {
    return this.unreadConversationIds.includes(conversationId);
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
    return DEMO_CONVERSATIONS.filter((item: WideConversationData) => {
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
    return DEMO_CONVERSATIONS.find((item: WideConversationData) => item.id === this.selectedConversationId);
  }

  private currentChatRecords(): WideChatRecord[] {
    const presetRecords: WideChatRecord[] = DEMO_CHAT_RECORDS.filter((item: WideChatRecord) =>
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
    this.scheduleScrollToBottom();
  }

  private toggleReadState(): void {
    const selected: WideConversationData | undefined = this.selectedConversation();
    if (!selected) {
      return;
    }
    if (this.isUnread(selected.id)) {
      this.unreadConversationIds = this.unreadConversationIds.filter((id: string) => id !== selected.id);
      return;
    }
    this.unreadConversationIds = [...this.unreadConversationIds, selected.id];
  }

  private currentTimeText(): string {
    const now: Date = new Date();
    const hour: string = now.getHours().toString().padStart(2, '0');
    const minute: string = now.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private sendReply(): void {
    const conversation: WideConversationData | undefined = this.selectedConversation();
    const content: string = this.replyText.trim();
    if (!conversation || !conversation.replyable || content === '') {
      return;
    }
    const record: WideChatRecord = {
      id: `local-${Date.now()}`,
      conversationId: conversation.id,
      role: 'outgoing',
      author: '刘婷',
      content: content,
      time: this.currentTimeText()
    };
    this.sentRecords = [...this.sentRecords, record];
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
      Text(item.avatar)
        .fontSize(size >= 40 ? 16 : 13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.avatarColor(item.kind))
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .backgroundColor(this.avatarBackground(item.kind))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private selectedConversationAvatar(size: number) {
    Row() {
      Text(this.selectedConversation()!.avatar)
        .fontSize(size >= 40 ? 16 : 13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.avatarColor(this.selectedConversation()!.kind))
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .backgroundColor(this.avatarBackground(this.selectedConversation()!.kind))
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
      fillWidth: false,
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
      List({ space: 4 }) {
        ForEach(this.filteredConversations(), (item: WideConversationData) => {
          ListItem() {
            this.conversationRow(item)
          }
        }, (item: WideConversationData) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
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
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private listPane() {
    Column({ space: 12 }) {
      this.messageSearch()
      this.filterBar()
      this.conversationList()
    }
    .width(400)
    .height('100%')
    .padding({ left: 14, right: 14, top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { right: 0.5 }, color: { right: $r('sys.color.comp_divider') } })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private conversationHeader() {
    Row({ space: 12 }) {
      this.selectedConversationAvatar(44)

      Column({ space: 3 }) {
        Text(this.selectedConversation()!.title)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.selectedConversation()!.subtitle)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.bell'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_primary')])
        Text(this.isUnread(this.selectedConversation()!.id) ? '标为已读' : '标为未读')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .height(36)
      .padding({ left: 13, right: 13 })
      .borderRadius(18)
      .backgroundColor(this.hoveredHeaderAction === 'read' ? $r('sys.color.interactive_hover') :
        $r('sys.color.comp_background_secondary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .keyboardFocusStyle()
      .onHover((isHover: boolean) => {
        this.hoveredHeaderAction = isHover ? 'read' : '';
      })
      .onKeyEvent((event: KeyEvent) => {
        this.activateWithKeyboard(event, () => this.toggleReadState());
      })
      .onClick(() => {
        this.toggleReadState();
      })
    }
    .width('100%')
    .height(72)
    .padding({ left: 20, right: 20 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
    .alignItems(VerticalAlign.Center)
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
      Row({ space: 10 }) {
        this.conversationAvatar(this.selectedConversation()!, 34)

        Column({ space: 4 }) {
          Text(record.author)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))

          Text(record.content)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(23)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius({ topLeft: 3, topRight: 17, bottomLeft: 17, bottomRight: 17 })
            .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            .constraintSize({ maxWidth: 620 })

          Text(record.time)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .constraintSize({ maxWidth: 620 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .constraintSize({ maxWidth: 900 })
      .alignItems(VerticalAlign.Top)
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
            .borderRadius({ topLeft: 17, topRight: 3, bottomLeft: 17, bottomRight: 17 })
            .constraintSize({ maxWidth: 620 })

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
      .constraintSize({ maxWidth: 900 })
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
      .width(520)
      .padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
    List({ scroller: this.chatScroller, space: 12 }) {
      ForEach(this.currentChatRecords(), (record: WideChatRecord) => {
        ListItem() {
          Column({ space: 12 }) {
            if (record.dayLabel !== undefined) {
              this.daySeparator(record.dayLabel)
            }
            this.chatRecord(record)
          }
          .width('100%')
        }
      }, (record: WideChatRecord) => record.id)

      ListItem() {
        Row()
          .width('100%')
          .height(4)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 24, right: 24, top: 18, bottom: 12 })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
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
          .barState(BarState.Auto)
          .layoutWeight(1)
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
      .constraintSize({ minHeight: 56, maxWidth: 900 })
      .padding({ left: 10, right: 6, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(28)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 3 })
      .alignItems(VerticalAlign.Bottom)
      .animation({ duration: 180, curve: Curve.EaseOut })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 10, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
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
    .height(64)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private detailPane() {
    if (this.selectedConversation()) {
      Column({ space: 0 }) {
        this.conversationHeader()
        this.chatHistory()
        if (this.selectedConversation()!.replyable) {
          this.composer()
        } else {
          this.readOnlyFooter()
        }
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
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }

  build() {
    Row({ space: 0 }) {
      this.listPane()
      this.detailPane()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
