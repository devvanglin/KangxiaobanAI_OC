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
export function PageSixteenPositiveBuilder() {
  PageSixteenPositive()
}

@Observed
class Translate {
  translateX: number = 20;
}
@Component
struct Title {
  build() {
    Row() {
      Image($r('app.media.startIcon'))
        .height(200)
        .width(200)
      Text("Title")
    }
  }
}

@Component
export struct PageSixteenPositive {
  pathStack: NavPathStack = new NavPathStack();
  @State translateObj: Translate = new Translate();

  build() {
    NavDestination() {
      navDestinationTitle('16.2正例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Column() {
          Title()
          Stack() {
          }
          Button("move")
            .onClick(() => {
              animateTo({
                duration: 50
              }, () => {
                this.translateObj.translateX = (this.translateObj.translateX + 50) % 150
              })
            })
        }
        .translate({ // the component in Column shares the same property translate
          x: this.translateObj.translateX
        })
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