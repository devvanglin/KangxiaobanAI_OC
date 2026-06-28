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
export function PageThreeCounterBuilder() {
  PageThreeCounter()
}

@Component
export struct PageThreeCounter {
  pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      navDestinationTitle('3.1反例', () => {
        this.pathStack.pop();
      });
      Column() {
        Button('加载网页')
          .onClick(() => {
            this.pathStack.pushDestination({ name: 'PageThreeWebComponent' })
          })
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