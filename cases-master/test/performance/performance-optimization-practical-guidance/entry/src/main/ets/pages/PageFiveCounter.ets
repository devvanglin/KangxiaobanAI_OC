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
import { hilog, hiTraceMeter } from '@kit.PerformanceAnalysisKit';

@Builder
export function PageFiveBuilder() {
  PageFiveCounter()
}

@Component
export struct PageFiveCounter {
  @State message: string = 'Hello World';
  pathStack: NavPathStack = new NavPathStack();
  private arr: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  aboutToAppear(): void {
  }

  @Builder
  navDestinationTitleImg(res: Resource, fun: () => void) {
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

      Text('5.1反例')
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
        Scroll() {
          Column() {
            ForEach(this.arr, (item: number) => {
              Text("ListItem" + item)
                .width("100%")
                .height(100)
            }, (item: number) => item.toString())
          }
        }
        .width('100%')
        .height('100%')
        .onDidScroll(() => {
          hiTraceMeter.startTrace("ScrollSlide", 1002);
          hilog.info(0x0000, 'TAG', '%{public}s', this.message);
          // 业务逻辑
          // ...
          // 在高频接口中不建议打印Trace和日志
          hilog.info(0x0000, 'TAG', '%{public}s', this.message);
          hiTraceMeter.finishTrace("ScrollSlide", 1002);
        })
      }.width('100%')
      .height('100%')
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