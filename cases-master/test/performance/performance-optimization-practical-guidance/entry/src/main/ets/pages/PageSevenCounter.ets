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

import { promptAction } from '@kit.ArkUI';

@Builder
export function PageSevenBuilder() {
  PageSevenCounter()
}

@Observed
class Book {
  public c: number = 0;

  constructor(c: number) {
    this.c = c;
  }
}

@Component
struct PropChild {
  @Prop testNum: Book; // @Prop装饰状态变量会深拷贝

  build() {
    Text(`PropChild testNum ${this.testNum.c}`)
  }
}

@Component
export struct PageSevenCounter {
  @State message: string = 'Hello World';
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
  }

  @Builder
  navDestinationTitleImg(res:Resource,fun:()=>void) {
    Image(res)
      .padding(8)
      .width(40)
      .height(40)
      .borderRadius('50%')
      .colorFilter('#171717')
      .backgroundColor('#e6e8e9')
      .onClick(() => {
        fun();
      })
  }

  @Builder
  navDestinationTitle() {
    Row() {
      this.navDestinationTitleImg($r('app.media.back'), () => {
        this.pathStack.pop();
      })

      Text('7.1反例')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Start)
        .lineHeight(26)
        .padding({ left: 8 })
        .fontColor(Color.Black)
        .layoutWeight(1)

      this.navDestinationTitleImg($r('app.media.more'), () => {
        promptAction.showToast({ message: $r('app.string.only_show_for_ux') })
      })
    }
    .width('100%')
    .height(56)
    .margin({ top: 36 })
    .padding({
      left: 16,
      right: 16
    })
    .backgroundColor('#F1F3F5')
  }

  @State testNum: Book[] = [new Book(1)];

  build() {
    NavDestination() {
      this.navDestinationTitle()
      Column() {
        Text(`Parent testNum ${this.testNum[0].c}`)
          .onClick(() => {
            this.testNum[0].c += 1;
          })
        // PropChild没有改变@Prop testNum: Book的值，所以这时最优的选择是使用@ObjectLink
        PropChild({ testNum: this.testNum[0] })
      }
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