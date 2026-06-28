/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import { Constants } from '../common/Constants';
import { FriendMoment } from '../model/BasicDataSource';
import { FriendMomentsData } from '../model/FriendMomentData';
import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageFourCounterBuilder() {
  PageFourCounter()
}

@Component
export struct PageFourCounter {
  @State message: string = 'Hello World';
  private momentData: FriendMomentsData = new FriendMomentsData();
  private readonly LIST_SPACE: number = 18;
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.momentData.getFriendMomentFromRawFile();
  }

  build() {
    NavDestination() {
      navDestinationTitle('4.1反例', () => {
        this.pathStack.pop();
      })
      Column() {
        List({ space: this.LIST_SPACE }) {
          LazyForEach(this.momentData, (moment: FriendMoment) => {
            ListItem() {
              OneMoment({ moment: moment })
            }
          }, (moment: FriendMoment) => moment.id)
        }
        .cachedCount(0)
        .margin({ top: 8 })
        .width(Constants.LAYOUT_MAX)
        .height(Constants.LAYOUT_MAX)
      }
      .justifyContent(FlexAlign.Center)
      .height('90%')
      .width('100%')
    }
    .backgroundColor(Color.White)
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
export struct OneMoment {
  @Prop moment: FriendMoment;

  build() {
    Row() {
      Image($r(this.moment.image))
        .height(30)
        .width(30)
        .borderRadius(50)
      Column() {
        Text(this.moment.text)
          .fontSize(12)
          .fontColor(Color.Black)
          .fontWeight(FontWeight.Bold)
          .opacity(0.6)

        if (this.moment.image !== '') {
          Flex({ wrap: FlexWrap.Wrap }) {
            Image($r(this.moment.image)).width('20%')
            Image($r(this.moment.image)).width('20%')
            Image($r(this.moment.image)).width('20%')
            Image($r(this.moment.image)).width('20%')
            Image($r(this.moment.image)).width('20%')
          }
          .width(Constants.LAYOUT_MAX)
          .margin({
            top: 5,
            left: 10
          })
        }
        Row() {
          Text('回复')
            .layoutWeight(1)
            .fontSize(12)
            .fontColor(Color.Black)
            .fontWeight(FontWeight.Bold)
            .lineHeight(5)
          Text('点赞')
            .layoutWeight(1)
            .fontSize(12)
            .fontColor(Color.Black)
            .fontWeight(FontWeight.Bold)
            .lineHeight(5)
          Text('收藏')
            .layoutWeight(1)
            .fontSize(12)
            .fontColor(Color.Black)
            .fontWeight(FontWeight.Bold)
            .lineHeight(5)
        }.margin({ top: 10 })
      }
      .layoutWeight(1)
    }
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
    .margin({
      left: 10,
      right: 10
    })
  }
}