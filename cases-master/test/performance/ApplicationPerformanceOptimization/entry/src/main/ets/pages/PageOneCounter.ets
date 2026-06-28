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
export function PageOneCounterBuilder() {
  PageOneCounter()
}

@Component
export struct PageOneCounter {
  @State private text: string = "";
  pathStack: NavPathStack = new NavPathStack();
  @State fontColor: string = '#182431';
  @State selectedFontColor: string = '#007DFF';
  @State currentIndex: number = 0;
  @State selectedIndex: number = 0;
  private controller: TabsController = new TabsController();

  loadPicture(count: number): IconItemSource[] {
    let iconItemSourceList: IconItemSource[] = [];
    // 遍历添加6*count个IconItem的数据
    for (let index = 0; index < count; index++) {
      const numStart: number = index * 6;
      // 此处循环使用6张图片资源
      iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 1}`));
      iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 2}`));
      iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 3}`));
      iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 4}`));
      iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 5}`));
      iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 6}`));
    }
    return iconItemSourceList;
  }

  @Builder tabBuilder(index: number, name: string) {
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
    NavDestination() {
      navDestinationTitle('1.1反例',()=>{
        this.pathStack.pop();
      })
      Column() {

        Tabs({ barPosition: BarPosition.Start, index: this.currentIndex, controller: this.controller }) {
          TabContent() {
            Column().width('100%').height('100%').backgroundColor('#00CB87')
          }.tabBar(this.tabBuilder(0, 'One'))

          TabContent() {
            Column(){
              Text(this.text)
            }.width('100%').height('100%').backgroundColor('#007DFF')
          }.tabBar(this.tabBuilder(1, 'clickMe'))

          TabContent() {
            Column().width('100%').height('100%').backgroundColor('#FFBF00')
          }.tabBar(this.tabBuilder(2, 'Three'))

          TabContent() {
            Column().width('100%').height('100%').backgroundColor('#E67C92')
          }.tabBar(this.tabBuilder(3, 'Four'))
        }
        .vertical(false)
        .barMode(BarMode.Fixed)
        .barWidth(360)
        .barHeight(56)
        .animationDuration(400)
        .onChange((index: number) => {
          // currentIndex控制TabContent显示页签
          this.currentIndex = index
          this.selectedIndex = index
        })
        .onContentWillChange((currentIndex, comingIndex) => {
          if (comingIndex == 1) {
            // 耗时操作
            this.loadPicture(100000); // 同步任务
            let context = getContext(this) as Context;
            this.text = context.resourceManager.getStringSync($r('app.string.startup_text'));
          }
          return true
        })
        .onAnimationStart((index: number, targetIndex: number, event: TabsAnimationEvent) => {
          if (index === targetIndex) {
            return
          }
          // selectedIndex控制自定义TabBar内Image和Text颜色切换
          this.selectedIndex = targetIndex
        })
        .width(360)
        .height(296)
        .margin({ top: 52 })
        .backgroundColor('#F1F3F5')
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