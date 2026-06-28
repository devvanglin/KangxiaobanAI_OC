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
export function PageNinePositiveBuilder() {
  PageNinePositive()
}

@Component
export struct PageNinePositive {
  pathStack: NavPathStack = new NavPathStack();
  private data: number[] = [];

  aboutToAppear() {
    for (let i: number = 0; i < 10; i++) {
      this.data.push(i);
    }
  }

  build() {
    NavDestination() {
      navDestinationTitle('9.2正例', () => {
        this.pathStack.pop();
      })
      Column() {
        Row() {
          ForEach(this.data, (item: number) => {
            Text(item.toString())
          })
          ForEach(this.data, (item: number) => {
            Text(item.toString())
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