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

type WideMessageKind = 'handoff' | 'family' | 'notice';
type WideMessageFilter = 'all' | 'unread' | WideMessageKind;

interface WideMessageData {
  id: string;
  kind: WideMessageKind;
  sender: string;
  preview: string;
  content: string;
  time: string;
}

interface WideMessageFilterOption {
  label: string;
  value: WideMessageFilter;
}

@ComponentV2
export struct WideMessagePage {
  @Local searchText: string = '';
  @Local activeFilter: WideMessageFilter = 'all';
  @Local selectedMessageId: string = 'msg-family-health';
  @Local unreadMessageIds: string[] = [
    'msg-family-health',
    'msg-handoff-night',
    'msg-notice-training'
  ];
  @Local hoveredMessageId: string = '';
  @Local focusedMessageId: string = '';
  @Local hoveredFilter: WideMessageFilter | '' = '';
  @Local hoveredAction: string = '';
  @Local actionNotice: string = '';

  private messages(): WideMessageData[] {
    return [
      {
        id: 'msg-family-health',
        kind: 'family',
        sender: '张明华家属',
        preview: '已回复今日健康情况，晚些时候会来电沟通。',
        content: '您好，张爷爷上午精神状态稳定，家属已经了解近期血压变化。晚些时候会来电与护理站进一步沟通，请保持电话畅通。',
        time: '10:32'
      },
      {
        id: 'msg-handoff-night',
        kind: 'handoff',
        sender: '护理站',
        preview: '夜间不适评估记录已补充，请交班时重点说明。',
        content: '周奶奶夜间不适评估记录已经补充。下午交班时请重点说明休息情况、进食状态和最近一次生命体征。',
        time: '10:08'
      },
      {
        id: 'msg-notice-training',
        kind: 'notice',
        sender: '护理部',
        preview: '压疮预防培训调整至本周五 16:00。',
        content: '本周压疮预防培训调整至周五 16:00，在二楼培训室进行。请提前十分钟签到，并携带个人学习记录。',
        time: '09:46'
      },
      {
        id: 'msg-family-visit',
        kind: 'family',
        sender: '李秀英家属',
        preview: '已确认周六下午三点到院探视。',
        content: '家属已确认周六下午三点到院探视，并已了解探视登记和陪同要求。',
        time: '09:18'
      },
      {
        id: 'msg-handoff-record',
        kind: 'handoff',
        sender: '刘婧',
        preview: '晨间护理记录已经同步完成。',
        content: '305-2 李秀英的晨间护理记录已经同步，康复训练完成情况和饮水记录均已补充。',
        time: '08:52'
      },
      {
        id: 'msg-notice-update',
        kind: 'notice',
        sender: '系统通知',
        preview: '消息同步和离线缓存能力已更新。',
        content: '应用服务已更新完成。消息同步和离线缓存能力已经恢复，可以继续正常使用。',
        time: '昨天'
      }
    ];
  }

  private filterOptions(): WideMessageFilterOption[] {
    return [
      { label: '全部', value: 'all' },
      { label: '未读', value: 'unread' },
      { label: '交接', value: 'handoff' },
      { label: '家属', value: 'family' },
      { label: '通知', value: 'notice' }
    ];
  }

  private isUnread(messageId: string): boolean {
    return this.unreadMessageIds.includes(messageId);
  }

  private unreadCount(): number {
    return this.unreadMessageIds.length;
  }

  private filteredMessages(): WideMessageData[] {
    const query: string = this.searchText.trim().toLowerCase();
    return this.messages().filter((item: WideMessageData) => {
      const matchesFilter: boolean = this.activeFilter === 'all' ||
        (this.activeFilter === 'unread' && this.isUnread(item.id)) || item.kind === this.activeFilter;
      if (!matchesFilter || query === '') {
        return matchesFilter;
      }
      return item.sender.toLowerCase().includes(query) || item.preview.toLowerCase().includes(query) ||
        item.content.toLowerCase().includes(query);
    });
  }

  private selectedMessage(): WideMessageData | undefined {
    return this.messages().find((item: WideMessageData) => item.id === this.selectedMessageId);
  }

  private kindLabel(kind: WideMessageKind): string {
    if (kind === 'handoff') {
      return '交接消息';
    }
    if (kind === 'family') {
      return '家属沟通';
    }
    return '工作通知';
  }

  private kindIcon(kind: WideMessageKind): Resource {
    if (kind === 'handoff') {
      return $r('sys.symbol.person_2_fill');
    }
    if (kind === 'family') {
      return $r('sys.symbol.phone_fill');
    }
    return $r('sys.symbol.bell_fill');
  }

  private kindColor(kind: WideMessageKind): ResourceColor {
    if (kind === 'family') {
      return $r('app.color.status_normal');
    }
    if (kind === 'notice') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.brand_blue');
  }

  private kindBackground(kind: WideMessageKind): ResourceColor {
    if (kind === 'family') {
      return 0xFFE9F7EF;
    }
    if (kind === 'notice') {
      return 0xFFFFF4DC;
    }
    return 0xFFEAF1FF;
  }

  private rowBackground(messageId: string): ResourceColor {
    if (messageId === this.selectedMessageId) {
      return 0xFFEAF1FF;
    }
    if (messageId === this.hoveredMessageId || messageId === this.focusedMessageId) {
      return $r('sys.color.interactive_hover');
    }
    return $r('sys.color.ohos_id_color_background_transparent');
  }

  private selectMessage(item: WideMessageData): void {
    this.selectedMessageId = item.id;
    this.actionNotice = '';
  }

  private toggleReadState(): void {
    const selected: WideMessageData | undefined = this.selectedMessage();
    if (!selected) {
      return;
    }
    if (this.isUnread(selected.id)) {
      this.unreadMessageIds = this.unreadMessageIds.filter((messageId: string) => messageId !== selected.id);
      this.actionNotice = '已标为已读';
    } else {
      this.unreadMessageIds = [...this.unreadMessageIds, selected.id];
      this.actionNotice = '已标为未读';
    }
  }

  @Builder
  private messageSearch() {
    Search({ value: this.searchText, placeholder: '搜索联系人或消息内容' })
      .width('100%')
      .height(44)
      .fontColor($r('sys.color.font_primary'))
      .placeholderColor($r('sys.color.font_tertiary'))
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(10)
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
  private filterChip(option: WideMessageFilterOption) {
    Row() {
      Text(option.label)
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(this.activeFilter === option.value ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.activeFilter === option.value ? $r('app.color.text_on_brand') :
          $r('sys.color.font_secondary'))
    }
    .height(34)
    .padding({ left: 13, right: 13 })
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(this.activeFilter === option.value ? $r('app.color.brand_blue') :
      (this.hoveredFilter === option.value ? $r('sys.color.interactive_hover') :
        $r('sys.color.comp_background_primary')))
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(1),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
    .onHover((isHover: boolean) => {
      this.hoveredFilter = isHover ? option.value : '';
    })
    .onClick(() => {
      this.activeFilter = option.value;
    })
  }

  @Builder
  private filterBar() {
    Row({ space: 8 }) {
      ForEach(this.filterOptions(), (option: WideMessageFilterOption) => {
        this.filterChip(option)
      }, (option: WideMessageFilterOption) => option.value)
    }
    .width('100%')
  }

  @Builder
  private messageAvatar(item: WideMessageData) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        SymbolGlyph(this.kindIcon(item.kind))
          .fontSize(19)
          .fontColor([this.kindColor(item.kind)])
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.kindBackground(item.kind))

      if (this.isUnread(item.id)) {
        Row()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor($r('app.color.brand_blue'))
          .border({ width: 2, color: $r('sys.color.comp_background_primary') })
      }
    }
    .width(42)
    .height(42)
  }

  @Builder
  private messageRow(item: WideMessageData, isLast: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Row()
          .width(3)
          .height(42)
          .borderRadius(2)
          .backgroundColor(item.id === this.selectedMessageId ? $r('app.color.brand_blue') :
            $r('sys.color.ohos_id_color_background_transparent'))

        this.messageAvatar(item)

        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(item.sender)
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(this.isUnread(item.id) ? FontWeight.Medium : FontWeight.Regular)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(item.time)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')

          Text(item.preview)
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
      .padding({ left: 12, right: 14, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
          .margin({ left: 72, right: 14 })
      }
    }
    .width('100%')
    .backgroundColor(this.rowBackground(item.id))
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(-2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
    .onHover((isHover: boolean) => {
      this.hoveredMessageId = isHover ? item.id : '';
    })
    .onFocus(() => {
      this.focusedMessageId = item.id;
    })
    .onBlur(() => {
      if (this.focusedMessageId === item.id) {
        this.focusedMessageId = '';
      }
    })
    .onClick(() => {
      this.selectMessage(item);
    })
  }

  @Builder
  private messageList() {
    if (this.filteredMessages().length > 0) {
      List({ space: 0 }) {
        ForEach(this.filteredMessages(), (item: WideMessageData, index: number) => {
          ListItem() {
            this.messageRow(item, index === this.filteredMessages().length - 1)
          }
        }, (item: WideMessageData) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .clip(true)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    } else {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.message_on_message_fill'))
          .fontSize(40)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('没有找到消息')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text('尝试更换筛选条件或搜索内容')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    }
  }

  @Builder
  private listPane() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('全部消息')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(`${this.unreadCount()} 条未读`)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(`${this.filteredMessages().length}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.messageSearch()
      this.filterBar()
      this.messageList()
    }
    .width(380)
    .height('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: { right: 0.5 }, color: { right: $r('sys.color.comp_divider') } })
  }

  @Builder
  private detailHeader(item: WideMessageData) {
    Row({ space: 14 }) {
      Row() {
        SymbolGlyph(this.kindIcon(item.kind))
          .fontSize(24)
          .fontColor([this.kindColor(item.kind)])
      }
      .width(50)
      .height(50)
      .borderRadius(25)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.kindBackground(item.kind))

      Column({ space: 5 }) {
        Row({ space: 10 }) {
          Text(item.sender)
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.isUnread(item.id)) {
            Text('未读')
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_blue'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(0xFFEAF1FF)
              .borderRadius(6)
          }
        }
        Text(`${this.kindLabel(item.kind)} · ${item.time}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private messageContentCard(item: WideMessageData) {
    Column({ space: 18 }) {
      Row() {
        Text('消息内容')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text(item.time)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Text(item.content)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(30)
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding(24)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private actionButton(id: string, icon: Resource, label: string, primary: boolean, action: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(17)
        .fontColor([primary ? $r('app.color.text_on_brand') : $r('sys.color.font_primary')])
      Text(label)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(primary ? $r('app.color.text_on_brand') : $r('sys.color.font_primary'))
    }
    .height(42)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
    .borderRadius(8)
    .backgroundColor(primary ? $r('app.color.brand_blue') :
      (this.hoveredAction === id ? $r('sys.color.interactive_hover') :
        $r('sys.color.comp_background_primary')))
    .border({
      width: primary ? 0 : 0.5,
      color: primary ? $r('app.color.brand_blue') : $r('sys.color.comp_divider')
    })
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
    .onHover((isHover: boolean) => {
      this.hoveredAction = isHover ? id : '';
    })
    .onClick(action)
  }

  @Builder
  private detailFooter(item: WideMessageData) {
    Row({ space: 10 }) {
      if (this.actionNotice !== '') {
        Text(this.actionNotice)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      Blank()
      this.actionButton('read', $r('sys.symbol.bell'), this.isUnread(item.id) ? '标为已读' : '标为未读',
        false, () => {
          this.toggleReadState();
        })
      this.actionButton('transfer', $r('sys.symbol.share'), '转交', false, () => {
        this.actionNotice = '已加入转交流程';
      })
      this.actionButton('reply', $r('sys.symbol.message_on_message_fill'), '回复消息', true, () => {
        this.actionNotice = '已准备回复';
      })
    }
    .width('100%')
    .height(74)
    .padding({ left: 24, right: 24 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
  }

  @Builder
  private detailPane() {
    if (this.selectedMessage()) {
      Column({ space: 0 }) {
        Scroll() {
          Row() {
            Column({ space: 20 }) {
              this.detailHeader(this.selectedMessage()!)
              this.messageContentCard(this.selectedMessage()!)
            }
            .width('100%')
            .constraintSize({ maxWidth: 840 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: 28, right: 28, top: 26, bottom: 26 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)

        this.detailFooter(this.selectedMessage()!)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
    } else {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.message_on_message_fill'))
          .fontSize(48)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('选择一条消息查看内容')
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
