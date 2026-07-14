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
  thinkSeconds?: number;
  suggestions?: string[];
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
  iconButtonNormalStyle() {
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
  }

  @Styles
  iconButtonPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
  }

  aboutToAppear(): void {
    this.messages = [
      {
        id: 'm1',
        role: 'user',
        content: '1'
      },
      {
        id: 'm2',
        role: 'ai',
        content: 'What would you like me to do with "1"? Is this the start of a math problem, a list, code, or something else? Give me more context!',
        thinkSeconds: 2,
        suggestions: ['Explain basic arithmetic', 'Explore number theory']
      }
    ];
  }

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 16;
  }

  private pagePadding(): number {
    return 20;
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
    this.messages.push({
      id: `u-${Date.now()}`,
      role: 'user',
      content: text
    });
    this.inputText = '';
    setTimeout(() => {
      this.messages.push({
        id: `a-${Date.now()}`,
        role: 'ai',
        content: '已收到您的消息，正在为您查询相关信息...',
        thinkSeconds: 1,
        suggestions: ['查看今日健康摘要', '生成护理建议']
      });
      this.scrollToBottom();
    }, 400);
  }

  @Builder
  private topBar() {
    Row() {
      Row() {
        Column({ space: 4 }) {
          Row()
            .width(20)
            .height(2)
            .borderRadius(1)
            .backgroundColor($r('sys.color.font_primary'))
          Row()
            .width(20)
            .height(2)
            .borderRadius(1)
            .backgroundColor($r('sys.color.font_primary'))
          Row()
            .width(20)
            .height(2)
            .borderRadius(1)
            .backgroundColor($r('sys.color.font_primary'))
        }
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.iconButtonNormalStyle,
        pressed: this.iconButtonPressedStyle
      })

      Blank()

      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(22)
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.iconButtonNormalStyle,
        pressed: this.iconButtonPressedStyle
      })
      .onClick(() => {
        this.onClose();
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ top: this.topPadding() })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private userBadge(count: number) {
    Row() {
      Text(count.toString())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private userMessageItem(message: ChatMessage, index: number) {
    Row() {
      Blank()
      this.userBadge(index + 1)
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ bottom: 24 })
  }

  @Builder
  private aiMessageItem(message: ChatMessage) {
    Column({ space: 16 }) {
      if (message.thinkSeconds !== undefined && message.thinkSeconds > 0) {
        Row({ space: 6 }) {
          Text('💡')
            .fontSize(14)
          Text(`思考了 ${message.thinkSeconds}s`)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
      }

      Text(message.content)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .fontWeight(FontWeight.Regular)
        .lineHeight(26)
        .width('100%')

      Row({ space: 4 }) {
        this.aiActionButton('copy')
        this.aiActionButton('share')
        this.aiActionButton('like')
        this.aiActionButton('dislike')
        this.aiActionButton('retry')
        this.aiActionButton('more')
      }
      .width('100%')
      .margin({ top: 4 })

      if (message.suggestions && message.suggestions.length > 0) {
        Column({ space: 10 }) {
          ForEach(message.suggestions, (suggestion: string, index: number) => {
            Row({ space: 8 }) {
              Text('↳')
                .fontSize(16)
                .fontColor($r('sys.color.font_tertiary'))
              Text(suggestion)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (suggestion: string, index: number) => `${index}-${suggestion}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ bottom: 32 })
    .alignItems(HorizontalAlign.Start)
  }

  private actionButtonText(type: string): string {
    if (type === 'copy') return 'copy';
    if (type === 'share') return 'share';
    if (type === 'like') return 'like';
    if (type === 'dislike') return 'dislike';
    if (type === 'retry') return 'refresh';
    if (type === 'more') return '...';
    return '';
  }

  @Builder
  private aiActionButton(type: string) {
    Row() {
      Text(this.actionButtonText(type))
        .fontSize(type === 'more' ? 14 : 12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.icon_secondary'))
    }
    .width(32)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .stateStyles({
      normal: this.iconButtonNormalStyle,
      pressed: this.iconButtonPressedStyle
    })
  }

  @Builder
  private inputCapsule() {
    Row({ space: 12 }) {
      Row() {
        Text('＋')
          .fontSize(22)
          .fontColor($r('sys.color.icon_secondary'))
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.iconButtonNormalStyle,
        pressed: this.iconButtonPressedStyle
      })

      TextInput({ text: this.inputText, placeholder: '畅所欲问' })
        .type(InputType.Normal)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .placeholderFont({ size: $r('sys.float.Body_M') })
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor('rgba(0,0,0,0)')
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
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand'))
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor($r('sys.color.font_primary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.iconButtonNormalStyle,
        pressed: this.iconButtonPressedStyle
      })
      .onClick(() => {
        this.sendMessage();
      })
    }
    .width('100%')
    .height(64)
    .padding({ left: 8, right: 8 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(32)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private inputBar() {
    Column() {
      this.inputCapsule()
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding(), bottom: 16 })
    .margin({ bottom: this.globalInfoModel.keyboardHeight })
    .backgroundColor($r('sys.color.background_primary'))
  }

  build() {
    Column() {
      this.topBar()

      List({ space: 0, scroller: this.listScroller }) {
        ForEach(this.messages, (message: ChatMessage, index: number) => {
          ListItem() {
            Row() {
              if (message.role === 'ai') {
                this.aiMessageItem(message)
              } else {
                this.userMessageItem(message, index)
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: this.expandMaxWidth() })
            .justifyContent(FlexAlign.Center)
          }
        }, (message: ChatMessage, index: number) => message.id)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('sys.color.background_primary'))
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)

      this.inputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }
}
