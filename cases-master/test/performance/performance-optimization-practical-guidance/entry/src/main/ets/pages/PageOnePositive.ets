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

const DELAYED_TIME = 100; // 定时器设置延时
const LARGE_NUMBER = 50000;

@Builder
export function PageOneBuilder() {
  PageOnePositive()
}

@Component
export struct PageOnePositive {
  @State private text: string = "";
  @State private text2: string = "";
  pathStack: NavPathStack = new NavPathStack();
  private count: number = 0;

  aboutToAppear(): void {
    // 1.2正例：在aboutToAppear接口中对耗时间的计算任务进行了异步处理。
    // 耗时操作
    this.computeTaskAsync(); // 异步任务
    let context = getContext(this) as Context;
    this.text = context.resourceManager.getStringSync($r('app.string.startup_text'));
  }

  computeTask(): void {
    hiTraceMeter.startTrace("responseTime", 1002);
    this.count = 0;
    while (this.count < LARGE_NUMBER) {
      this.count++;
      hilog.info(0x0000, 'count', '%{public}s', JSON.stringify(this.count));
    }
    hiTraceMeter.finishTrace("responseTime", 1002);
  }

  // 运算任务异步处理
  private computeTaskAsync(): void {
    setTimeout(() => {
      // 这里使用setTimeout来实现异步延迟运行
      this.computeTask();
    }, DELAYED_TIME)
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

      Text('1.2正例')
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
        Text(this.text)
        // Text(this.text2)
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