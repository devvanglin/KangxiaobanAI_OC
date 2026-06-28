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
export function PageEighteenCounterBuilder() {
  PageEighteenCounter()
}

@Observed
class Translate {
  translateX: number = 20;
}

@Component
export struct PageEighteenCounter {
  pathStack: NavPathStack = new NavPathStack();
  @State realState1: Array<number> = [4, 1, 3, 2]; // 使用状态变量装饰器
  @State realState2: Array<number> = [4, 1, 3, 2];
  @State realState3: Array<number> = [4, 1, 3, 2];
  @State realState4: Array<number> = [4, 1, 3, 2];
  @State realState5: Array<number> = [4, 1, 3, 2];
  @State realState6: Array<number> = [4, 1, 3, 2];
  @State realState7: Array<number> = [4, 1, 3, 2];
  @State realState8: Array<number> = [4, 1, 3, 2];
  @State realState9: Array<number> = [4, 1, 3, 2];
  @State realState10: Array<number> = [4, 1, 3, 2];
  @State realStateColor: Color = Color.Yellow;

  build() {
    NavDestination() {
      navDestinationTitle('18.1反例', () => {
        this.pathStack.pop();
      })
      Column() {
        Button("执行未关联组件的状态变量装饰器")
          .fontSize(18)
          .onClick(() => {
            hiTraceMeter.startTrace('StateVariable', 1);
            // 改变realState不会触发UI视图更新
            this.realState1.push(this.realState1[this.realState1.length-1] + 1);
            this.realState2.push(this.realState2[this.realState2.length-1] + 1);
            this.realState3.push(this.realState3[this.realState3.length-1] + 1);
            this.realState4.push(this.realState4[this.realState4.length-1] + 1);
            this.realState5.push(this.realState5[this.realState5.length-1] + 1);
            this.realState6.push(this.realState6[this.realState6.length-1] + 1);
            this.realState7.push(this.realState7[this.realState7.length-1] + 1);
            this.realState8.push(this.realState8[this.realState8.length-1] + 1);
            this.realState9.push(this.realState9[this.realState9.length-1] + 1);
            this.realState10.push(this.realState10[this.realState10.length-1] + 1);
            hiTraceMeter.finishTrace('StateVariable', 1);
            // 改变realStateColor触发UI视图更新
            this.realStateColor = this.realStateColor == Color.Yellow ? Color.Red : Color.Yellow;
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