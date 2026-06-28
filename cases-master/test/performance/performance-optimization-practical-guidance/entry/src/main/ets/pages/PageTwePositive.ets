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
import { IconItemSource } from '../utils/IconItemSource';
import { loadPicture } from '../utils/IndependentTask';
import { buffer, taskpool, util } from '@kit.ArkTS';
import { MyDataSource } from '../utils/MydataSource';

@Builder
export function PageTweBuilder() {
  PageTwePositive()
}

@Component
export struct PageTwePositive {
  @State message: string = '开始加密';
  private data: MyDataSource = new MyDataSource();
  pathStack: NavPathStack = new NavPathStack();

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
      Text('12.2正例')
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
  async getFriendMomentFromRawFile(): Promise<void> {
    const resourceManager = getContext().resourceManager;
    const res = await resourceManager.getRawFileContent('base64');
    const textDecoder = util.TextDecoder.create();
    let str = textDecoder.decodeToString(res)
    hiTraceMeter.startTrace('bufferFrom', 2);
    console.log("base解码")
    let baseEncode = new util.Base64Helper();
    baseEncode.decodeSync(str).buffer;
    console.log("base解码")
    hiTraceMeter.finishTrace('bufferFrom', 2);
  }


  build() {
    NavDestination() {
      this.navDestinationTitle()
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
          .onClick(()=>{
            this.getFriendMomentFromRawFile();
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