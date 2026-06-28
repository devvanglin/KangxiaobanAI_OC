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

import { promptAction } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { FriendMoment } from '../model/BasicDataSource';
import { FriendMomentsData } from '../model/FriendMomentData';
import { hilog, hiTraceMeter } from '@kit.PerformanceAnalysisKit';

@Builder
export function PageFourteenBuilder() {
  PageFourteenPositive()
}

@Component
export struct PageFourteenPositive {
  @State sum: number = 0;
  @State message: string = 'Hello World';
  private momentData: FriendMomentsData = new FriendMomentsData();
  private readonly LIST_CACHE_COUNT: number = 5;
  private readonly LIST_SPACE: number = 18;
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.momentData.getFriendMomentFromRawFile();
    // 执行该异步函数
    this.countAndRecord();
  }

  // 真实场景的函数中可能存在未知的耗时操作逻辑，此处用循环函数模拟耗时操作
  async countAndRecord() {
    let temp: number = 0;
    for (let index = 0; index < 100000; index++) {
      temp += index;
    }
    // 将结果放入状态变量中
    this.sum = temp;
  }

  @Builder
  navDestinationTitleImg(res:Resource,fun:()=>void) {
    Image(res)
      .padding(8)
      .width(40)
      .height(40)
      .borderRadius('50%')
      .colorFilter('#171717')
      .backgroundColor('#e6e8e9')
      .onClick(() => {
        fun();
      })
  }

  @Builder
  navDestinationTitle() {
    Row() {
      this.navDestinationTitleImg($r('app.media.back'), () => {
        this.pathStack.pop();
      })

      Text('14.2正例')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Start)
        .lineHeight(26)
        .padding({ left: 8 })
        .fontColor(Color.Black)
        .layoutWeight(1)

      this.navDestinationTitleImg($r('app.media.more'), () => {
        promptAction.showToast({ message: $r('app.string.only_show_for_ux') })
      })
    }
    .width('100%')
    .height(56)
    .margin({ top: 36 })
    .padding({
      left: 16,
      right: 16
    })
    .backgroundColor('#F1F3F5')
  }

  build() {
    NavDestination() {
      this.navDestinationTitle()
      Column() {
        List({ space: this.LIST_SPACE }) {
          LazyForEach(this.momentData, (moment: FriendMoment) => {
            ListItem() {
              OneMoment({ moment: moment,
                sum: this.sum })// ReusId is used to control component reuse
            }
          }, (moment: FriendMoment) => moment.id)
        }
        .cachedCount(this.LIST_CACHE_COUNT)
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

@Reusable
@Component
export struct OneMoment {
  @Prop moment: FriendMoment;
  @State sum: number = 0;

  aboutToReuse(params: Record<string, Object>): void {
    this.sum = params.sum as number;
  }

  build() {
    Column() {
      Text(`${this.moment.userName} （${this.moment.id} / ${this.sum}）`)
    }
    .justifyContent(FlexAlign.Start)
    .margin({
      left: 16,
      right: 16
    })
  }
}