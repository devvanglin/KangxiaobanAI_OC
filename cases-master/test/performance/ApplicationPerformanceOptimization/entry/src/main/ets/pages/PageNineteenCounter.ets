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
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';

@Builder
export function PageNineteenCounterBuilder() {
  PageNineteenCounter()
}

@Component
export struct PageNineteenCounter {
  pathStack: NavPathStack = new NavPathStack();
  @State message: string = '';

  build() {
    NavDestination() {
      navDestinationTitle('19.1反例',()=>{
        this.pathStack.pop();
      })
      Column() {
        Button('点击打印日志')
          .onClick(() => {
            hiTraceMeter.startTrace('print', 1);
            for (let i = 0; i < 10; i++) {
              console.info(this.message);
            }
            hiTraceMeter.finishTrace('print', 1);
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