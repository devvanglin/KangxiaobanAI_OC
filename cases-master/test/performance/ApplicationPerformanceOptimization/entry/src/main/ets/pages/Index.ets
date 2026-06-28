/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@Entry
@Component
struct Index {
  @State childNavStack: NavPathStack = new NavPathStack();
  @State fontColor: string = '#182431'
  @State selectedFontColor: string = '#007DFF'
  @State currentIndex: number = 0
  @State selectedIndex: number = 0
  private codeSampleCount: number = 24;
  private codeSampleArray: number[] =
    Array.from({ length: this.codeSampleCount }, (item: number, index: number) => index + 1);

  @Builder
  tabBuilder(index: number, name: string) {
    Column() {
      Text(name)
        .fontColor(this.selectedIndex === index ? this.selectedFontColor : this.fontColor)
        .fontSize(16)
        .fontWeight(this.selectedIndex === index ? 500 : 400)
        .lineHeight(22)
        .margin({ top: 17, bottom: 7 })
      Divider()
        .strokeWidth(2)
        .color('#007DFF')
        .opacity(this.selectedIndex === index ? 1 : 0)
    }.width('100%')
  }

  build() {
    Navigation(this.childNavStack) {
      Scroll() {
        Column() {
          ForEach(this.codeSampleArray, (item: number) => {
            Row() {
              Button(`${item}.1反例`, { stateEffect: true, type: ButtonType.Capsule })
                .width('45%')
                .height(40)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 12 })
                .onClick(() => {
                  this.childNavStack.pushPath({ name: `page${item}Counter` });
                })
              Blank()
              Button(`${item}.2正例`, { stateEffect: true, type: ButtonType.Capsule })
                .width('45%')
                .height(40)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 12 })
                .onClick(() => {
                  this.childNavStack.pushPath({ name: `page${item}Positive` });
                })
            }.width('100%')
          })
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16
        })
      }
      .width('100%')
      .height('100%')
      .padding({
        top: 52,
        bottom: 16
      })
    }
    .backgroundColor('#F1F1F1')
    .height('100%')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}