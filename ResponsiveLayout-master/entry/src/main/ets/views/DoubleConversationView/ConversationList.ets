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

import { ConversationDataInterface, ConversationListData } from './model/ConversationDatal';
import { HomeConstants } from '../../constants/ConversationConstants';
import { deviceInfo } from '@kit.BasicServicesKit';
import { WindowInfo } from '../../utils/WindowUtil';
import { WidthBreakpointType } from '../../utils/WidthBreakpointType';

// [Start conversation_list_diff_device]
@Component
export struct ConversationList {
  @ObjectLink mainWindowInfo: WindowInfo;
  @Link currentContactUserName: string;
  @State private currentIndex: number = 0;
  pageInfos: NavPathStack = new NavPathStack();
  pathStack: NavPathStack = new NavPathStack();

  build() {
    Flex({ direction: FlexDirection.Column }) {
      HomeTopSearch({
        pageInfos: this.pageInfos,
      })
        .height('13%')
      // [Start conversation_list]
      List() {
        ForEach(ConversationListData, (item: ConversationDataInterface, index: number) => {
          ListItem() {
            ConversationItem(item)
              .onClick(() => {
                if (this.pathStack.size() > 1) {
                  this.pathStack.pop();
                }
                this.pathStack.pushPathByName('conversationDetail', null)
                this.currentContactUserName = '';
                this.currentIndex = index;
              })
              .backgroundColor(this.currentIndex === index ? '#33D8D8D8' : Color.White)
          }
          .height(new WidthBreakpointType('11%', '11%', '10%', '10%').getValue(this.mainWindowInfo.widthBp))
        }, (item: ConversationDataInterface, index: number) => index + JSON.stringify(item))
      }
      // [End conversation_list]
      .padding({
        left: 12,
        right: 12,
        bottom: deviceInfo.deviceType !== '2in1' && (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ||
          this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) ? '28vp' : '0vp',
      })
      .backgroundColor(Color.White)
      .width('100%')
      .height('100%')
    }
    .height('100%')
    .width('100%')
  }
}
// [End conversation_list_diff_device]

@Component
export struct ConversationItem {
  private name?: Resource;
  private msg?: Resource;
  private time?: ResourceStr;
  private icon?: Resource;

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
      Column() {
        Image(this.icon)
          .height(40)
          .width(40)
      }
      .width(40)
      .margin({ left: 24, right: 12 })

      Flex({ direction: FlexDirection.Column,justifyContent:FlexAlign.Center }) {
        Text(this.name)
          .fontSize(16)
          .fontWeight(500)
          .lineHeight('22fp')
          .fontFamily('HarmonyHeiTi-Medium')
        Text(this.msg)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(14)
          .fontWeight(400)
          .lineHeight('19fp')
          .fontFamily('HarmonyHeiTi')
          .fontColor(Color.Grey)
          .width('100%')
      }
      .flexShrink(1)
      .margin({ left: 12 })

      Blank()
      Column() {
        Text(this.time)
          .fontWeight(400)
          .fontSize(10)
          .fontColor(Color.Grey)
          .fontFamily('HarmonyHeiTi')
          .width(45)
      }
      .flexBasis('auto')
      .margin({ left: 24, right: 12 })
    }
    .width('100%')
    .padding(3)
  }
}

@Component
export struct HomeTopSearch {
  pageInfos: NavPathStack = new NavPathStack();
  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(30)
          .height(30)
          .margin({ right: 12 })
          .onClick(() => {
            this.pageInfos.pop();
          })
        Column() {
          Text($r('app.string.message'))
            .fontWeight(500)
            .fontSize(24)
            .fontFamily('HarmonyHeiTi-Medium')
            .width('100%')
        }
        .flexBasis(HomeConstants.SEARCH_TEXT_FLEX_BASIS)
      }

      Blank()
      Row() {
        Image($r('app.media.ic_public_search'))
          .width(24)
          .height(24)
          .margin({ right: 24 })

        Image($r('app.media.ic_public_add_norm'))
          .width(24)
          .height(24)
          .margin({ right: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .padding({ left: 24, top: deviceInfo.deviceType === '2in1' ? 0 : 36 })
  }
}