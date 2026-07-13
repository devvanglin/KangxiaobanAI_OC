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
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';

interface ChatMessage {
  id: string;
  role: 'ai' | 'user';
  content: string;
  time: string;
}

@ComponentV2
export struct AiChatPage {
  @Param @Require geometryId: string;
  @Event onClose: () => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local messages: ChatMessage[] = [];
  @Local inputText: string = '';
  private listScroller: ListScroller = new ListScroller();

  @Styles
  itemNormalStyle() {
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
  }

  @Styles
  itemPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
  }

  aboutToAppear(): void {
    this.messages = [
      {
        id: 'm1',
        role: 'ai',
        content: '您好，我是康小伴智能守护。今日已识别 2 条重点关注事项：\n1. 302-1 张明华 血压连续3天偏高\n2. 3F-306 林爷爷 深睡时长低于均值 23%\n需要我为您安排护理任务吗？',
        time: '08:30'
      },
      {
        id: 'm2',
        role: 'user',
        content: '张明华的血压详细情况',
        time: '08:31'
      },
      {
        id: 'm3',
        role: 'ai',
        content: '张明华（302-1）近3日血压记录：\n· 7/12  152/96 mmHg\n· 7/13  148/94 mmHg\n· 7/14  155/98 mmHg\n建议：今日重点观察，考虑调整用药方案并通知主治医生。',
        time: '08:31'
      }
    ];
  }

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 16;
  }

  private pagePadding(): number {
    return 16;
  }

  private expandMaxWidth(): number {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    if (widthBreakpoint === WidthBreakpoint.WIDTH_LG || widthBreakpoint === WidthBreakpoint.WIDTH_XL) {
      return 880;
    }
    if (widthBreakpoint === WidthBreakpoint.WIDTH_MD) {
      return 720;
    }
    return 9999;
  }

  private scrollToBottom(): void {
    if (this.messages.length > 0) {
      this.listScroller.scrollToIndex(this.messages.length - 1);
    }
  }

  private sendMessage(): void {
    const text: string = this.inputText.trim();
    if (text.length === 0) {
      return;
    }
    const now: Date = new Date();
    const timeStr: string = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    this.messages.push({
      id: `u-${Date.now()}`,
      role: 'user',
      content: text,
      time: timeStr
    });
    this.inputText = '';
    setTimeout(() => {
      this.messages.push({
        id: `a-${Date.now()}`,
        role: 'ai',
        content: '已收到您的消息，正在为您查询相关信息...',
        time: timeStr
      });
      this.scrollToBottom();
    }, 400);
  }

  @Builder
  private topBar() {
    Row() {
      Row({ space: 10 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.brand_blue')])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column({ space: 2 }) {
          Text('康小伴智能守护')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('智能养老助手 · 在线')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.itemNormalStyle,
        pressed: this.itemPressedStyle
      })
      .onClick(() => {
        this.onClose();
      })
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ top: this.topPadding(), bottom: 12 })
  }

  @Builder
  private messageBubble(message: ChatMessage) {
    Row() {
      if (message.role === 'ai') {
        Row() {
          SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
            .fontSize(18)
            .fontColor([$r('app.color.brand_blue')])
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }

      Column({ space: 4 }) {
        Text(message.content)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(message.role === 'ai' ? $r('sys.color.font_primary') : $r('app.color.text_on_brand'))
          .lineHeight(22)
        Text(message.time)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor(message.role === 'ai' ? $r('sys.color.font_tertiary') : $r('app.color.text_on_brand'))
      }
      .alignItems(message.role === 'ai' ? HorizontalAlign.Start : HorizontalAlign.End)
      .constraintSize({ maxWidth: '75%' })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(message.role === 'ai' ? $r('sys.color.comp_background_primary') : $r('app.color.brand_blue'))
      .borderRadius(16)
      .border({
        width: message.role === 'ai' ? 0.5 : 0,
        color: $r('sys.color.comp_divider')
      })
      .margin({ left: message.role === 'ai' ? 10 : 0, right: message.role === 'ai' ? 0 : 10 })

      if (message.role === 'user') {
        Row() {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .justifyContent(message.role === 'ai' ? FlexAlign.Start : FlexAlign.End)
    .alignItems(VerticalAlign.Top)
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  private inputBar() {
    Row({ space: 10 }) {
      TextInput({ text: this.inputText, placeholder: '输入消息...' })
        .type(InputType.Normal)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .placeholderFont({ size: $r('sys.float.Body_M') })
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(26)
        .height(52)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          this.sendMessage();
        })

      Row() {
        Text('↑')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_blue'))
      }
      .width(52)
      .height(52)
      .borderRadius(26)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.itemNormalStyle,
        pressed: this.itemPressedStyle
      })
      .onClick(() => {
        this.sendMessage();
      })
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 10, bottom: 12 })
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
  }

  build() {
    Column() {
      this.topBar()

      List({ space: 0, scroller: this.listScroller }) {
        Repeat<ChatMessage>(this.messages)
          .each((repeatItem: RepeatItem<ChatMessage>) => {
            ListItem() {
              Row() {
                this.messageBubble(repeatItem.item)
              }
              .width('100%')
              .constraintSize({ maxWidth: this.expandMaxWidth() })
              .padding({
                left: this.pagePadding(),
                right: this.pagePadding()
              })
              .justifyContent(FlexAlign.Center)
            }
          })
          .key((item: ChatMessage) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('sys.color.background_secondary'))
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)

      this.inputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }
}
