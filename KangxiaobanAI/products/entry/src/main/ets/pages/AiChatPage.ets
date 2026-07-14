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
        content: '你好！我收到了你的"1"。\n\n不过因为我们没有之前的对话记录，我不太确定这个"1"具体指什么。你是想：\n• 选择某个选项（比如列表里的第1项）？\n• 测试我是否在线（收到，我在👋）？\n• 数个数（那就是数字1）？\n• 还是不小心点到了发送？\n\n麻烦你补充一下上下文或者具体需求，我随时准备好为你效劳！😄',
        thinkSeconds: 6
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
        thinkSeconds: 1
      });
      this.scrollToBottom();
    }, 400);
  }

  @Builder
  private menuIcon() {
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

  @Builder
  private iconButton(symbol: Resource, onClick?: () => void) {
    Row() {
      SymbolGlyph(symbol)
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
    .onClick(onClick ?? (() => {}))
  }

  @Builder
  private topBar() {
    Row() {
      Row() {
        this.menuIcon()
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.iconButtonNormalStyle,
        pressed: this.iconButtonPressedStyle
      })

      Column({ space: 2 }) {
        Text('数字1的询问')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.bolt_fill'))
            .fontSize(10)
            .fontColor([$r('app.color.brand_blue')])
          Text('快速模式')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('app.color.brand_blue'))
        }
      }

      Row({ space: 2 }) {
        this.iconButton($r('sys.symbol.plus'))
        this.iconButton($r('sys.symbol.share'))
        this.iconButton($r('sys.symbol.xmark'), () => {
          this.onClose();
        })
      }
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
  private aiThinkRow(seconds: number) {
    Row({ space: 6 }) {
      SymbolGlyph($r('sys.symbol.bolt_fill'))
        .fontSize(12)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(`已思考（用时 ${seconds} 秒）`)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(10)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private aiActionButton(symbol: Resource | string) {
    Row() {
      if (typeof symbol === 'string') {
        Text(symbol)
          .fontSize(16)
          .fontColor($r('sys.color.icon_secondary'))
      } else {
        SymbolGlyph(symbol)
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
      }
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
  private aiMessageItem(message: ChatMessage) {
    Column({ space: 16 }) {
      if (message.thinkSeconds !== undefined && message.thinkSeconds > 0) {
        this.aiThinkRow(message.thinkSeconds)
      }

      Text(message.content)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .fontWeight(FontWeight.Regular)
        .lineHeight(26)
        .width('100%')

      Row({ space: 8 }) {
        this.aiActionButton($r('sys.symbol.doc_text'))
        this.aiActionButton('↻')
        this.aiActionButton($r('sys.symbol.hand_thumbsup'))
        this.aiActionButton($r('sys.symbol.hand_thumbsdown'))
        this.aiActionButton($r('sys.symbol.share'))
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ bottom: 32 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private quickTag(label: string, icon: Resource | string) {
    Row({ space: 5 }) {
      if (typeof icon === 'string') {
        Text(icon)
          .fontSize(12)
          .fontColor($r('sys.color.icon_secondary'))
      } else {
        SymbolGlyph(icon)
          .fontSize(12)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      Text(label)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .height(28)
    .padding({ left: 10, right: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private inputArea() {
    Column({ space: 10 }) {
      Column({ space: 0 }) {
        Row({ space: 8 }) {
          TextInput({ text: this.inputText, placeholder: '给 康小伴 发送消息' })
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
            Text('🔗')
              .fontSize(20)
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

          Row() {
            Text('↑')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_brand'))
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.brand_blue'))
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
        .height(56)
        .padding({ left: 8, right: 8 })
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          this.quickTag('深度思考', $r('sys.symbol.bolt_fill'))
          this.quickTag('智能搜索', $r('sys.symbol.magnifyingglass'))
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 8 })
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(24)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })

      Text('内容由 AI 生成，请仔细甄别')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .textAlign(TextAlign.Center)
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

      this.inputArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }
}
