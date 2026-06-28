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
import { deviceInfo } from '@kit.BasicServicesKit';
import { WindowInfo } from '../../utils/WindowUtil';
import { WidthBreakpointType } from '../../utils/WidthBreakpointType';
import { MessageBubble } from './MessageBubble';

// [Start conversation_detail]
@Component
export struct ConversationDetail {
  @ObjectLink mainWindowInfo: WindowInfo;
  @State currentConversationUserName: Resource = $r('app.string.default_username');
  @Prop currentFeatureIndex: number;
  @Link isNavFullScreen: boolean;
  pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Flex({ direction: FlexDirection.Column }) {
        ConversationDetailTopSearch({ mainWindowInfo: this.mainWindowInfo,
          currentConversationUserName: $currentConversationUserName,
          pathStack: this.pathStack
        })
          .height(new WidthBreakpointType('11%', '11%', '10%', '10%').getValue(this.mainWindowInfo.widthBp))
        ConversationDetailItem({
          receivedName: $currentConversationUserName,
          isReceived: true,
          content: $r('app.string.shopping_title'),
          isDocumentMsg: true,
          currentFeatureIndex: $currentFeatureIndex,
          pathStack: this.pathStack,
          isNavFullScreen: this.isNavFullScreen
        })
        ConversationDetailItem({
          receivedName: $currentConversationUserName,
          isReceived: true,
          content: $r('app.string.product_view'),
          currentFeatureIndex: $currentFeatureIndex,
          pathStack: this.pathStack,
          isNavFullScreen: this.isNavFullScreen
        })
        ConversationDetailItem({
          receivedName: $currentConversationUserName,
          isReceived: false,
          content: $r('app.string.waiting_for_long'),
          currentFeatureIndex: $currentFeatureIndex,
          pathStack: this.pathStack,
          isNavFullScreen: this.isNavFullScreen
        })
        Blank()
        ConversationDetailBottom()
      }
      .height('100%')
      .width('100%')
      .backgroundColor($r('app.color.background_color_grey'))
      .padding({
        bottom: deviceInfo.deviceType !== '2in1' ? 28 : 0
      })
    }
    .hideTitleBar(true)
  }
}
// [End conversation_detail]

@Component
struct ConversationDetailBottom {
  @Builder CustomKeyboardBuilder(){}
  build() {
    Flex({ alignItems: ItemAlign.Center }) {
      Column() {
        Image($r('app.media.ic_public_emoji'))
          .width(24)
          .height(24)
      }
      .flexBasis(HomeConstants.FLEX_BASIS_AUTO)
      .padding({
        right: 24,
        left: 24,
      })

      Blank()
      Column() {
        TextArea()
          .placeholderColor($r('app.color.text_input_default_color'))
          .caretColor($r('app.color.text_input_default_care_color'))
          .backgroundColor($r('app.color.text_input_default_background_color'))
          .borderRadius(HomeConstants.CONVERSATION_DETAIL_BOTTOM_TEXT_RADIUS)
          .flexGrow(1)
          .padding({ right: 3 })
          .backgroundColor(Color.White)
          .enableKeyboardOnFocus(false)
          .customKeyboard(this.CustomKeyboardBuilder())
      }

      Column() {
        Image($r('app.media.ic_public_add_norm'))
          .width(24)
          .height(24)
      }
      .padding({
        right: 24,
        left: 24,
      })
    }
    .width('100%')
    .height(56)
  }
}

@Component
struct ConversationDetailItem {
  @Link currentFeatureIndex: number;
  @Link receivedName: string;
  isReceived: boolean = !HomeConstants.IS_RECEIVED;
  content: ResourceStr = '';
  isDocumentMsg?: boolean;
  pathStack: NavPathStack = new NavPathStack();
  @Link isNavFullScreen: boolean;

  build() {
    Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.End }) {
      MessageBubble({
        receivedName: $receivedName,
        currentFeatureIndex: $currentFeatureIndex,
        isReceived: this.isReceived,
        content: this.content,
        isDocumentMsg: this.isDocumentMsg,
        pathStack: this.pathStack,
        isNavFullScreen: this.isNavFullScreen
      })
    }
  }
}

@Component
struct ConversationDetailTopSearch {
  @ObjectLink mainWindowInfo: WindowInfo;
  @Link currentConversationUserName: string;
  pathStack: NavPathStack = new NavPathStack();

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
      Image($r('app.media.ic_public_back'))
        .width(24)
        .height(24)
        .onClick(() => {
          if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM) {
            this.pathStack.clear();
          } else if (this.pathStack.size() === 1) {
            this.pathStack.clear();
            this.pathStack.pushPath({ name: 'conversationDetailNone' });
          } else {
            this.pathStack.clear();
            this.pathStack.pushPath({ name: 'conversationDetailNone' });
          }
        })
      Text(this.currentConversationUserName)
        .fontWeight(500)
        .fontSize(18)
        .fontFamily("HarmonyHeiTi-Medium")
        .fontColor($r('app.color.conversation_default_text_color'))
      Image($r('app.media.ic_public_more'))
        .width(24)
        .height(24)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24,top: deviceInfo.deviceType === '2in1' ? 0 : 36 })
  }
}