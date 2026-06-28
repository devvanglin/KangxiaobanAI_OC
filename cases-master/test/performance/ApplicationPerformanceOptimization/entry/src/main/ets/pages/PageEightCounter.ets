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
export function PageEightCounterBuilder() {
  PageEightCounter()
}

@Component
export struct PageEightCounter {
  pathStack: NavPathStack = new NavPathStack();
  @State isVisible: boolean = true;
  private data: Resource[] = [];

  aboutToAppear() {
    for (let i: number = 0; i < Constants.IMAGE_TOTAL_NUM; i++) {
      this.data.push(Constants.IMAGE_LIST[i%Constants.IMAGE_LIST.length]);
    }
  }

  build() {
    NavDestination() {
      navDestinationTitle('8.1反例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Button('显隐切换')
          .onClick(() => {
            this.isVisible = !(this.isVisible);
          })
          .width('100%')
        if (this.isVisible) { // 使用条件渲染切换，会频繁创建与销毁组件
          Scroll() {
            Column() {
              ForEach(this.data, (item: Resource) => {
                Image(item)
              }, (item: number, index: number) => (item + index).toString())
            }
          }
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