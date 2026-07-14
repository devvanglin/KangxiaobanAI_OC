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

interface RichSegment {
  text: string;
  bold: boolean;
}

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
        content: '你好，我收到了你的"1"。\n\n由于我们还没有之前的对话记录，我不太确定这个"1"具体指什么。你是想：\n• 选择某个选项（比如列表里的第1项）\n• 测试我是否在线\n• 数个数（那就是数字1）\n• 还是不小心点到了发送\n\n麻烦你补充一下上下文或者具体需求，我随时准备好为你效劳。',
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

  private parseBold(text: string): RichSegment[] {
    const segments: RichSegment[] = [];
    let current: string = '';
    let isBold: boolean = false;
    let i: number = 0;
    while (i < text.length - 1) {
      if (text[i] === '*' && text[i + 1] === '*') {
        segments.push({ text: current, bold: isBold });
        current = '';
        isBold = !isBold;
        i += 2;
      } else {
        current += text[i];
        i++;
      }
    }
    if (text.length > 0) {
      current += text[text.length - 1];
    }
    segments.push({ text: current, bold: isBold });
    return segments;
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
        content: '已收到你的消息，正在查询相关信息，请稍候。',
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
      .width('100%')
      .lineHeight(28)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private aiContent(content: string) {
    Column({ space: 12 }) {
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
  private aiMessageItem(message: ChatMessage, index: number) {
    Row() {
      Column({ space: 0 }) {
        Row()
          .width(3)
          .height('100%')
          .backgroundColor($r('app.color.brand_blue'))
      }
      .width(3)
      .height('100%')
      .margin({ right: 12 })

      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Text('AI 助手')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
          if (message.thinkSeconds !== undefined && message.thinkSeconds > 0) {
            Text(`已思考 ${message.thinkSeconds} 秒`)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
        .width('100%')

        this.aiContent(message.content)

        Row({ space: 12 }) {
          Text('复制')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
          Text('重试')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
          Text('点赞')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .margin({ left: this.pagePadding(), right: this.pagePadding(), bottom: 24 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .shadow({
      radius: 12,
      color: 'rgba(0,0,0,0.06)',
      offsetX: 0,
      offsetY: 4
    })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private userMessageItem(message: ChatMessage) {
    Row() {
      Blank()
      Column({ space: 8 }) {
        Text(message.content)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(26)
          .width('100%')
      }
      .constraintSize({ maxWidth: '78%' })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(0xFFE8F0FE)
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding() })
    .margin({ bottom: 24 })
  }

  @Builder
  private inputCapsule() {
    Row({ space: 10 }) {
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
        Text('↑')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand'))
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor($r('app.color.brand_blue'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.sendMessage();
      })
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 8 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(32)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.08)',
      offsetX: 0,
      offsetY: 6
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private inputArea() {
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
                this.aiMessageItem(message, index)
              } else {
                this.userMessageItem(message)
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
