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

import GlassCoverView from '../view/GlassCoverView'

@Entry
@Component
struct Index {
  @State pointsToDraw: number[][] = [];

  build() {
    Stack() {
      Image($r('app.media.drawImage'))
        .width('100%')
        .height('100%')
      GlassCoverView({ pointsToDraw: this.pointsToDraw })
        .width('100%')
        .height('100%')
      Button('Begin Draw')
        .width(100)
        .height(40)
        .margin({ bottom: 40 })
        .onClick(() => {
          this.startDraw();
        })
    }.alignContent(Alignment.Bottom)
    .width('100%')
    .height('100%')
  }

  private startDraw() {
    this.pointsToDraw = [];
    for (let index = 0; index < 1000; index++) {
      this.pointsToDraw.push([Math.random(), Math.random()]);
    }
  }
}