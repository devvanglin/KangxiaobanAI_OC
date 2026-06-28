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
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';

@Builder
export function PageTwentyPositiveBuilder() {
  PageTwentyPositive()
}

@Component
export struct PageTwentyPositive {
  pathStack: NavPathStack = new NavPathStack();
  private arr: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  build() {
    NavDestination() {
      navDestinationTitle('20.2正例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Scroll() {
          Column(){
            ForEach(this.arr, (item: number) => {
              Text("ListItem" + item)
                .width("100%")
                .height("100%")
            }, (item: number) => item.toString())
          }
        }
        .width('100%')
        .height('100%')
        .onDidScroll(() => {
          // 业务逻辑

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