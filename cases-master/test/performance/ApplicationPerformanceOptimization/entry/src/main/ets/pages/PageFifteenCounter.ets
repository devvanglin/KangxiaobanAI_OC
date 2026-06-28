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
export function PageFifteenCounterBuilder() {
  PageFifteenCounter()
}

interface Data {
  text: string;
}

// 子组件
@Component
struct componentSon{
  // 获取传递参数
  @Consume("data") data: Data;

  build() {
    Column() {
      Text(this.data.text)
    }
  }
}

@Component
export struct PageFifteenCounter {
  pathStack: NavPathStack = new NavPathStack();
  @Provide("data") data: Data = {
    text: '需要传递的数据'
  };

  build() {
    NavDestination() {
      navDestinationTitle('15.1反例',()=>{
        this.pathStack.pop();
      })
      Column() {
        componentSon()
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