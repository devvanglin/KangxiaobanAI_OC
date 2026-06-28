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
import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageSeventeenCounterBuilder() {
  PageSeventeenCounter()
}

@Observed
class AnimationParams {
  translateX: number = 0;
  translateY: number = 0;
  alpha: number = 1;
  rotationX: number = 0;
  rotationY: number = 0;
  centerX: number = 0;
  centerY: number = 0;
  angle: number = 0;
  scaleX: number = 1;
  scaleY: number = 1;
}

@Component
export struct PageSeventeenCounter {
  pathStack: NavPathStack = new NavPathStack();
  @State animationParam: AnimationParams = new AnimationParams();

  build() {
    NavDestination() {
      navDestinationTitle('17.1反例', () => {
        this.pathStack.pop();
      })
      Column() {
        Column() {
          Row() {
            Image($r('app.media.startIcon'))
              .translate({
                x: this.animationParam.translateX,
                y: this.animationParam.translateY
              })
              .rotate({
                x: this.animationParam.rotationX,
                y: this.animationParam.translateY,
                centerX: this.animationParam.centerX,
                centerY: this.animationParam.centerY,
                angle: this.animationParam.angle
              })
              .opacity(this.animationParam.alpha)
              .scale({
                x: this.animationParam.scaleX,
                y: this.animationParam.scaleY,
                centerX: this.animationParam.centerX,
                centerY: this.animationParam.centerY
              })
              .animation({
                duration: 3000
              })
              .height(200)
              .width(200)
          }

          Button('点击播放动画')
            .onClick(() => {
              this.animationParam.translateX = 300;
              this.animationParam.translateY = 200;
              this.animationParam.rotationX = 90;
              this.animationParam.rotationY = 90;
              this.animationParam.centerX = 20;
              this.animationParam.centerY = 20;
              this.animationParam.angle = 270;
              this.animationParam.alpha = 0.5;
              this.animationParam.scaleX = 3;
              this.animationParam.scaleY = 3;
            })
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
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