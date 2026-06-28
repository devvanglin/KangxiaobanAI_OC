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

import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageSeventeenPositiveBuilder() {
  PageSeventeenPositive()
}

@Observed
class RotationAnimationParams {
  rotationX: number = 0;
  rotationY: number = 0;
  centerX: number = 0;
  centerY: number = 0;
  angle: number = 0;
}

@Observed
class TranslateAnimationParams {
  translateX: number = 0;
  translateY: number = 0;
}

@Observed
class AlphaAnimationParams {
  alpha: number = 1;
}

@Observed
class ScaleAnimationParams {
  scaleX: number = 1;
  scaleY: number = 1;
  centerX: number = 0;
  centerY: number = 0;
}


@Component
export struct PageSeventeenPositive {
  pathStack: NavPathStack = new NavPathStack();
  @State rotationAnimation: RotationAnimationParams = new RotationAnimationParams();
  @State translateAnimation: TranslateAnimationParams = new TranslateAnimationParams();
  @State alphaAnimation: AlphaAnimationParams = new AlphaAnimationParams();
  @State scaleAnimation: ScaleAnimationParams = new ScaleAnimationParams();

  build() {
    NavDestination() {
      navDestinationTitle('17.2正例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Column() {
          Row() {
            Image($r('app.media.startIcon'))
              .translate({
                x: this.translateAnimation.translateX,
                y: this.translateAnimation.translateY
              })
              .rotate({
                x: this.rotationAnimation.rotationX,
                y: this.rotationAnimation.rotationY,
                centerX: this.rotationAnimation.centerX,
                centerY: this.rotationAnimation.centerY,
                angle: this.rotationAnimation.angle
              })
              .opacity(this.alphaAnimation.alpha)
              .scale({
                x: this.scaleAnimation.scaleX,
                y: this.scaleAnimation.scaleY,
                centerX: this.scaleAnimation.centerX,
                centerY: this.scaleAnimation.centerY
              })
              .animation({
                duration: 3000
              })
              .height(200)
              .width(200)
          }

          Button('点击播放动画')
            .onClick(() => {
              this.rotationAnimation.rotationX = 90;
              this.rotationAnimation.rotationY = 90;
              this.rotationAnimation.centerX = 20;
              this.rotationAnimation.centerY = 20;
              this.rotationAnimation.angle = 270;

              this.translateAnimation.translateX = 300;
              this.translateAnimation.translateY = 200;

              this.alphaAnimation.alpha = 0.5;

              this.scaleAnimation.scaleX = 3;
              this.scaleAnimation.scaleY = 3;
              this.scaleAnimation.centerX = 20;
              this.scaleAnimation.centerY = 20;
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