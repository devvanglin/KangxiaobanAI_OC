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

import { AppStorageV2 } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconStyleMode,
  ScrollEffectType,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import AuthStore from '../network/AuthStore';
import { MessageApi } from '../network/MessageApi';
import { UserMessage } from '../network/Dto';

type PhoneChatRole = 'incoming' | 'outgoing' | 'system';

interface PhoneChatRecord {
  id: string;
  role: PhoneChatRole;
  author: string;
  content: string;
  time: string;
  dayLabel?: string;
}

export interface PhoneLocalMessageRecord {
  id: string;
  conversationId: string;
  content: string;
  time: string;
}

@ComponentV2
export struct PhoneMessageChatPage {
  @Param @Require conversationId: string;
  @Param @Require title: string;
  @Param @Require subtitle: string;
  @Param @Require kind: string;
  @Param @Require initialContent: string;
  @Param replyable: boolean = true;
  @Param localRecords: PhoneLocalMessageRecord[] = [];
  @Event onClose: () => void = () => {};
  @Event onSend: (record: PhoneLocalMessageRecord) => void = (_record: PhoneLocalMessageRecord) => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local replyText: string = '';
  @Local backendRecords: PhoneChatRecord[] = [];
  private chatScroller: Scroller = new Scroller();
  private scrollTimerId: number = -1;

  aboutToAppear(): void {
    this.loadMessages();
    this.scheduleScrollToBottom();
  }

  private peerId(): number {
    return this.conversationId.indexOf('user-') === 0 ? Number(this.conversationId.slice(5)) : 0;
  }

  private async loadMessages(): Promise<void> {
    const peerId: number = this.peerId();
    if (peerId <= 0) {
      return;
    }
    const response = await MessageApi.list(peerId);
    const currentUserId: number = AuthStore.getUser()?.id ?? 0;
    this.backendRecords = response.data.list.map((message: UserMessage): PhoneChatRecord => {
      return { id: `${message.id}`, role: message.sender_id === currentUserId ? 'outgoing' : 'incoming',
        author: message.sender_id === currentUserId ? (AuthStore.getUser()?.real_name ?? '我') : this.title,
        content: message.content, time: message.sent_at.slice(11, 16) };
    });
    this.scheduleScrollToBottom();
  }

  aboutToDisappear(): void {
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
      this.scrollTimerId = -1;
    }
  }

  private avatarColor(): ResourceColor {
    if (this.kind === 'family') {
      return $r('app.color.status_normal');
    }
    if (this.kind === 'notice') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.brand_blue');
  }

  private avatarBackground(): ResourceColor {
    if (this.kind === 'family') {
      return $r('app.color.status_normal_bg');
    }
    if (this.kind === 'notice') {
      return $r('app.color.status_warning_bg');
    }
    return 0xFFEAF1FF;
  }

  private currentRecords(): PhoneChatRecord[] {
    const local: PhoneChatRecord[] = this.localRecords
      .filter((item: PhoneLocalMessageRecord) => item.conversationId === this.conversationId)
      .map((item: PhoneLocalMessageRecord) => {
        const record: PhoneChatRecord = {
          id: item.id,
          role: 'outgoing',
          author: '刘婷',
          content: item.content,
          time: item.time
        };
        return record;
      });
    return [...this.backendRecords, ...local];
  }

  private currentTimeText(): string {
    const now: Date = new Date();
    return `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  }

  private sendReply(): void {
    const content: string = this.replyText.trim();
    if (!this.replyable || content === '') {
      return;
    }
    const record: PhoneLocalMessageRecord = {
      id: `phone-local-${Date.now()}`,
      conversationId: this.conversationId,
      content: content,
      time: this.currentTimeText()
    };
    if (this.peerId() > 0) {
      this.persistReply(content);
    } else {
      this.onSend(record);
    }
    this.replyText = '';
    this.scheduleScrollToBottom();
  }

  private async persistReply(content: string): Promise<void> {
    const peerId: number = this.peerId();
    if (peerId <= 0) {
      return;
    }
    const response = await MessageApi.send(peerId, content);
    if (response.code === 0) {
      await this.loadMessages();
    }
  }

  private scheduleScrollToBottom(): void {
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
    }
    this.scrollTimerId = setTimeout(() => {
      const records: PhoneChatRecord[] = this.currentRecords();
      if (records.length > 0) {
        this.chatScroller.scrollToIndex(records.length - 1, true, ScrollAlign.END);
      }
      this.scrollTimerId = -1;
    }, 80);
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
      }
    };
  }

  private titleBarContent(): TitleBarContentOptions {
    return {
      title: { mainTitle: this.title },
      backIcon: {
        label: '返回消息列表',
        icon: $r('sys.symbol.chevron_left'),
        type: IconStyleMode.SMALL,
        isEnabled: true,
        action: () => this.onClose()
      },
      menu: { value: [] }
    };
  }

  @Builder
  private avatar(size: number) {
    Row() {
      if (this.kind === 'family') {
        Text(this.title.substring(0, 1))
          .fontSize(size >= 36 ? 14 : 12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.avatarColor())
      } else {
        SymbolGlyph($r('sys.symbol.bell_fill'))
          .fontSize(size >= 36 ? 18 : 15)
          .fontColor([this.avatarColor()])
      }
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .backgroundColor(this.avatarBackground())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private daySeparator(label: string) {
    Row() {
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(12)
        .backgroundColor($r('sys.color.comp_background_secondary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private incomingRecord(record: PhoneChatRecord) {
    Row({ space: 8 }) {
      this.avatar(32)
      Column({ space: 4 }) {
        Text(record.author)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
        Text(record.content)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(23)
          .padding({ left: 13, right: 13, top: 9, bottom: 9 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
          .constraintSize({ maxWidth: '78%' })
        Text(record.time)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private outgoingRecord(record: PhoneChatRecord) {
    Row() {
      Blank()
      Column({ space: 4 }) {
        Text(record.content)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_on_brand'))
          .lineHeight(23)
          .padding({ left: 13, right: 13, top: 9, bottom: 9 })
          .backgroundColor($r('app.color.brand_blue'))
          .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
          .constraintSize({ maxWidth: '78%' })
        Row({ space: 5 }) {
          Text(record.time)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
          Text('已发送')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
  }

  @Builder
  private systemRecord(record: PhoneChatRecord) {
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
      Text(record.content)
        .width('100%')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(22)
      Text(record.time)
        .width('100%')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .textAlign(TextAlign.End)
    }
    .width('88%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chatRecord(record: PhoneChatRecord) {
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
      Repeat(this.currentRecords())
        .each((repeatItem: RepeatItem<PhoneChatRecord>) => {
          ListItem() {
            Column({ space: 10 }) {
              if (repeatItem.item.dayLabel !== undefined) {
                this.daySeparator(repeatItem.item.dayLabel)
              }
              this.chatRecord(repeatItem.item)
            }
            .width('100%')
          }
          .padding({ top: repeatItem.index === 0 ? this.globalInfoModel.statusBarHeight + 64 : 0 })
        })
        .key((record: PhoneChatRecord) => record.id)
      ListItem() {
        Row()
          .width('100%')
          .height(4)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 12, bottom: 8 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private composer() {
    Row({ space: 6 }) {
      TextArea({ text: this.replyText, placeholder: `发消息给 ${this.title}` })
        .enterKeyType(EnterKeyType.NEW_LINE)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor(Color.Transparent)
        .padding({ left: 8, right: 2, top: 8, bottom: 8 })
        .minLines(1)
        .maxLines(4, { overflowMode: MaxLinesMode.SCROLL })
        .barState(BarState.Off)
        .layoutWeight(1)
        .onChange((value: string) => this.replyText = value)

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(18)
          .fontColor([this.replyText.trim().length > 0 ? $r('app.color.text_on_brand') :
            $r('sys.color.icon_tertiary')])
      }
      .width(40)
      .height(40)
      .backgroundColor(this.replyText.trim().length > 0 ? $r('app.color.brand_blue') :
        $r('sys.color.comp_background_secondary'))
      .enabled(this.replyText.trim().length > 0)
      .accessibilityText('发送消息')
      .onClick(() => this.sendReply())
    }
    .width('100%')
    .constraintSize({ minHeight: 54 })
    .padding({ left: 8, right: 6, top: 6, bottom: 6 })
    .borderRadius(27)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 2 })
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private footer() {
    if (this.replyable) {
      Column() {
        this.composer()
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 + this.globalInfoModel.naviIndicatorHeight })
    } else {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.bell_fill'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('通知消息无需回复')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(58 + this.globalInfoModel.naviIndicatorHeight)
      .padding({ bottom: this.globalInfoModel.naviIndicatorHeight })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .justifyContent(FlexAlign.Center)
    }
  }

  build() {
    HdsNavDestination() {
      Column({ space: 0 }) {
        this.chatHistory()
        this.footer()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      style: this.titleBarStyle(),
      content: this.titleBarContent()
    })
    .bindToScrollable([this.chatScroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
