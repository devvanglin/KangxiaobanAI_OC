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
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { loadPicture } from '../utils/IndependentTask';
import { taskpool } from '@kit.ArkTS';
import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageTwelvePositiveBuilder() {
  PageTwelvePositive()
}

@Component
export struct PageTwelvePositive {
  pathStack: NavPathStack = new NavPathStack();
  @State children: Number[] = Array.from(Array<number>(900), (v, k) => k);

  build() {
    NavDestination() {
      navDestinationTitle('12.2正例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Scroll() {
          Grid() {
            ForEach(this.children, (item: Number[]) => {
              GridItem() {
                Text(item.toString())
              }.backgroundColor(Color.Yellow)
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