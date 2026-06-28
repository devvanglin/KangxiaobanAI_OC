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
export function PageThirteenPositiveBuilder() {
  PageThirteenPositive()
}

@Component
export struct PageThirteenPositive {
  pathStack: NavPathStack = new NavPathStack();
  @State isVisible: boolean = true;
  @State data: Number[] = Array.from(Array<number>(10), (v, k) => k);

  build() {
    NavDestination() {
      navDestinationTitle('13.2正例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Button('Switch Hidden and Show').onClick(() => {
          this.isVisible = !this.isVisible;
        })

        Stack() {
          if (this.isVisible) {
            Text('New Page').width(100).height(30).backgroundColor(0xd2cab3)
          }
        }.width(100).height(30) // 在指定宽高的Stack容器内，内部的Text组件变化只会在容器内部做布局和测量更新，不会影响到容器外ForEach中的Text组件。

        ForEach(this.data, (item: number) => { // Stack容器指定了宽高，不会影响到这一层兄弟节点
          Text(`Item value: ${item}`)
            .fontSize(20)
            .width('100%')
            .textAlign(TextAlign.Center)
        }, (item: number) => item.toString())
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