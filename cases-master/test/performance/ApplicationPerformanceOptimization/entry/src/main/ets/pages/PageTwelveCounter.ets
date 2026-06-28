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

import { IconItemSource } from '../utils/IconItemSource';
import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageTwelveCounterBuilder() {
  PageTwelveCounter()
}

@Component
export struct PageTwelveCounter {
  pathStack: NavPathStack = new NavPathStack();
  @State children: number[] = Array.from(Array<number>(900), (v, k) => k);

  build() {
    NavDestination() {
      navDestinationTitle('12.1反例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Scroll() {
          Grid() {
            ForEach(this.children, (item: number) => {
              GridItem() {
                Stack() {
                  Stack() {
                    Stack() {
                      Text(item.toString())
                    }.size({ width: "100%"})
                  }.backgroundColor(Color.Yellow)
                }.backgroundColor(Color.Pink)
              }
            }, (item: string) => item)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(0)
          .rowsGap(0)
          .size({ width: "100%", height: "100%" })
        }
      }
      .justifyContent(FlexAlign.Center)
      .height('90%')
      .width('100%')
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