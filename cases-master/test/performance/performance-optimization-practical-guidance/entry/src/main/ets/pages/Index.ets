/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

  build() {
    Navigation(this.childNavStack) {
      Scroll() {
        Column() {
          // 不建议在aboutToAppear()、aboutToDisappear()等生命周期中执行耗时操作
          Row() {
            Button('1.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageOneCounter' });
              })
            Blank()
            Button('1.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageOnePositive' });
              })
          }.width('100%')

          // 	不要在回调函数中执行耗时操作(ArkUI接口回调、网络访问回调、await等)
          Row() {
            Button('2.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageTwoCounter' });
              })
            Blank()
            Button('2.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageTwoPositive' });
              })
          }.width('100%')

          // 列表场景未使用LazyForEach+组件复用+缓存列表项
          Row() {
            Button('3.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageThreeCounter' });
              })
            Blank()
            Button('3.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageThreePositive' });
              })
          }.width('100%')

          // Web未使用预连接，未提前初始化引擎
          Row() {
            Button('4.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFourCounter' });
              })
            Blank()
            Button('4.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFourPositive' });
              })
          }.width('100%')

          // 高频接口中不要打印Trace和日志
          Row() {
            Button('5.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFiveCounter' });
              })
            Blank()
            Button('5.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFivePositive' });
              })
          }.width('100%')

          // 组件复用里面有if语句，但是未使用reuseId
          Row() {
            Button('6.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSixCounter' });
              })
            Blank()
            Button('6.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSixPositive' });
              })
          }.width('100%')

          // 不建议使用@Prop装饰器
          Row() {
            Button('7.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSevenCounter' });
              })
            Blank()
            Button('7.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSevenPositive' });
              })
          }.width('100%')

          // 避免在ResourceManager的getXXXSync接口入参中直接使用资源信息
          Row() {
            Button('8.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageEightCounter' });
              })
            Blank()
            Button('8.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageEightPositive' });
              })
          }.width('100%')

          // 展示用的自定义组件（数据从父组件中获取，无独立数据处理）使用@Builder替换
          Row() {
            Button('9.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageNineCounter' });
              })
            Blank()
            Button('9.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageNinePositive' });
              })
          }.width('100%')

          // 	删除无具体逻辑的生命周期，ArkUI的函数回调等，删除冗余堵塞日志打印
          Row() {
            Button('10.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageTenCounter' });
              })
            Blank()
            Button('10.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageTenPositive' });
              })
          }.width('100%')

          // 删除未关联组件的状态变量装饰器
          Row() {
            Button('11.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageElevenCounter' });
              })
            Blank()
            Button('11.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageElevenPositive' });
              })
          }.width('100%')

          // 	crypto-js性能差
          Row() {
            Button('12.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageTweCounter' });
              })
            Blank()
            Button('12.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageTwePositive' });
              })
          }.width('100%')

          // 不建议使用Marquee组件
          Row() {
            Button('13.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageThirteenCounter' });
              })
            Blank()
            Button('13.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageThirteenPositive' });
              })
          }.width('100%')

          // 不能使用函数作为ArkUI组件的属性和组件复用的自定义组件的入参
          Row() {
            Button('14.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFourteenCounter' });
              })
            Blank()
            Button('14.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFourteenPositive' });
              })
          }.width('100%')

          // 不建议使用.linearGradient颜色渐变属性
          Row() {
            Button('15.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFifteenCounter' });
              })
            Blank()
            Button('15.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageFifteenPositive' });
              })
          }.width('100%')

          // 不要在for/while循环中执行耗时操作
          Row() {
            Button('16.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSixteenCounter' });
              })
            Blank()
            Button('16.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSixteenPositive' });
              })
          }.width('100%')

          // 变量初值不建议设置为undefined，需进行默认初始化
          Row() {
            Button('17.1反例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSeventeenCounter' });
              })
            Blank()
            Button('17.2正例', { stateEffect: true, type: ButtonType.Capsule })
              .width('45%')
              .height(40)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.childNavStack.pushPath({ name: 'pageSeventeenPositive' });
              })
          }.width('100%')
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