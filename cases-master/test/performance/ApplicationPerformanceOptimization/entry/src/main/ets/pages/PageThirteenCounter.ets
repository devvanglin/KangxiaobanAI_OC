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
export function PageThirteenCounterBuilder() {
  PageThirteenCounter()
}

@Component
export struct PageThirteenCounter {
  pathStack: NavPathStack = new NavPathStack();
  @State isVisible: boolean = true;
  @State data: Number[] = Array.from(Array<number>(10), (v, k) => k);

  build() {
    NavDestination() {
      navDestinationTitle('13.1反例',()=>{
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
        }.width(100) // 本案例以Stack容器为例，只指定了宽，会触发父容器组件重新布局计算，引起ForEach中文本测量。

        ForEach(this.data, (item: number) => { // 由于Stack容器没有同时指定宽高，会扩散影响到这一层，引起Text的测量更新。
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