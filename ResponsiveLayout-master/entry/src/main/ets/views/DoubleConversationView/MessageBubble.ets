/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { HomeConstants } from '../../constants/ConversationConstants';
import { ConversationListData } from './model/ConversationDatal';

@Component
export struct MessageBubble {
  @Link receivedName: Resource;
  @Link currentFeatureIndex: number;
  isReceived: boolean = !HomeConstants.IS_RECEIVED;
  content: ResourceStr = "";
  isDocumentMsg?: boolean;
  avatar1: Resource = $r('app.media.avatar1');
  avatar2: Resource = $r('app.media.avatar7');
  pathStack: NavPathStack = new NavPathStack();
  @Link isNavFullScreen: boolean;

  build() {
    Column() {
      Flex({ justifyContent: this.isReceived ? FlexAlign.Start : FlexAlign.End, direction: FlexDirection.Row }) {
        if (this.isReceived) {
          Image(ConversationListData.find((item) => item.name === this.receivedName)?.icon || this.avatar1)
            .width(40)
            .height(40)
            .flexShrink(0)
        }
        Column() {
          Stack({ alignContent: this.isReceived ? Alignment.TopStart : Alignment.TopEnd }) {
            Path()
              .commands('M-10 1 L0 18 L32 1 Z')
              .fillOpacity(HomeConstants.CONVERSATION_DETAIL_FILL_OPACITY)
              .stroke(Color.White)
              .strokeWidth(HomeConstants.CONVERSATION_DETAIL_STROKE_WIDTH)
              .fill(Color.White)
              .visibility(this.isReceived ? Visibility.Visible : Visibility.None)
            Path()
              .commands('M23 1 L0 28 L-10 1 Z')
              .fillOpacity(HomeConstants.CONVERSATION_DETAIL_FILL_OPACITY)
              .stroke(Color.White)
              .strokeWidth(HomeConstants.CONVERSATION_DETAIL_STROKE_WIDTH)
              .fill(Color.White)
              .visibility(this.isReceived ? Visibility.None : Visibility.Visible)
              .zIndex(HomeConstants.CONTACTS_DETAIL_AVATAR_Z_INDEX)
              .margin({ right: -10 })
            Column() {
              this.MessageContent()
            }
            .padding({
              left: 12,
              right: 12,
              top: 10,
              bottom: 10
            })
            .backgroundColor(Color.White)
            .borderRadius(HomeConstants.PATH_BORDER_RADIUS)
          }
          .padding({
            top: 1,
            left: 20,
            right: 20,
            bottom: 22
          })
          .width('100%')
        }
        .width('100%')

        if (!this.isReceived) {
          Image(this.avatar2)
            .width(40)
            .height(40)
            .flexShrink(0)
        }
      }
    }
    .margin({ left: 15, right: 16})
  }

  @Builder
  MessageContent() {
    if (this.isDocumentMsg) {
      Column() {
        Row() {
          NormalText({ data: this.content })
            .margin({ right: 10 })
            .width( 120 )
          Image($r('app.media.product_cover'))
            .height(48)
            .width(48)
            .margin({top: 10, right: 10})
        }
        .margin({ bottom: 0 })

        IntroduceText({ data: HomeConstants.DOCUMENT_SIZE, fontColor: $r('app.color.background_color_grey_three') })
          .margin({ top: -10, bottom: 10 })
        Divider()
          .color($r('app.color.divider_background_color'))
          .strokeWidth(HomeConstants.DOCUMENT_DIVIDER_WIDTH).margin({ bottom: 1 })
        Row() {
          Blank()
            .layoutWeight(1)
          IntroduceText({
            data: HomeConstants.DOCUMENT_INTRODUCE,
            fontColor: $r('app.color.background_color_grey_three')
          })
            .margin({ top: -2 , right: 0})
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width(180)
      .margin({ bottom: -7 })
      .onClick(() => {
        this.isNavFullScreen = true;
        this.pathStack.pushPathByName('productPage', null)
      })
    } else {
      Text(this.content)
        .fontSize(12)
        .fontFamily('HarmonyHeiTi')
        .fontWeight(400)
        .lineHeight('21vp')
        .fontColor($r('app.color.conversation_default_text_color'))
        .copyOption(CopyOptions.LocalDevice)
    }
  }
}

@Component
struct NormalText {
  @Prop data: ResourceStr;
  @Prop fontSize: number = 12;
  @Prop fontColor: string = "#182431";
  @Prop fontWeight: number = 400;
  @Prop fontFamily: string = "HarmonyHeiTi";

  build() {
    Text(this.data)
      .fontFamily(this.fontFamily)
      .fontSize(this.fontSize)
      .fontColor(this.fontColor)
      .textAlign(TextAlign.Start)
      .lineHeight('21fp')
      .fontWeight(this.fontWeight)
      .copyOption(CopyOptions.LocalDevice)
  }
}

@Component
struct IntroduceText {
  @Prop data: ResourceStr;
  @Prop fontSize: string = '10fp';
  @Prop fontColor: Resource = $r('app.color.font_color_gray');
  @Prop fontWeight: number = 400;

  build() {
    Text(this.data)
      .opacity(0.5)
      .fontFamily("HarmonyHeiTi")
      .fontSize(this.fontSize)
      .fontColor(this.fontColor)
      .textAlign(TextAlign.Start)
      .lineHeight('21fp')
      .fontWeight(this.fontWeight)
  }
}