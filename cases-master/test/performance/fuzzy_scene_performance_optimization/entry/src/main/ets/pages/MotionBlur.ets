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

import { window } from '@kit.ArkUI';

@Component
export struct MotionBlur {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State isShowMotionBlur: boolean = false;
  @State bottomSafeHeight: number = 0; // bottom navigation bar height

  aboutToAppear() {
    window.getLastWindow(getContext(this), (err, windowBar) => {
      if (err.code) {
        return;
      }
      // get the height of the bottom navigation bar
      this.bottomSafeHeight =
        px2vp(windowBar.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height);
      windowBar.setWindowLayoutFullScreen(true);
    });
  }

  // modal page with dynamically blurred image settings
  @Builder
  motionBlurBuilder() {
    Stack({ alignContent: Alignment.Bottom }) {
      Image($r('app.media.test'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .blur(13) // add motion blur effect
      Button('close')
        .width('90%')
        .height(40)
        .margin({ bottom: this.bottomSafeHeight + 16 })
        .onClick(() => {
          this.isShowMotionBlur = false;
        })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Button('motion blur')
          .width('90%')
          .height(40)
          .onClick(() => {
            this.isShowMotionBlur = true;
          })
          .bindContentCover(this.isShowMotionBlur, this.motionBlurBuilder(), {
            modalTransition: ModalTransition.DEFAULT
          })
      }
      .padding({ bottom: this.bottomSafeHeight + 16 })
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .hideTitleBar(true)
  }
}