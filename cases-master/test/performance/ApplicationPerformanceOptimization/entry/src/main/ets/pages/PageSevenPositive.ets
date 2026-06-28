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

import { IconItem } from '../model/IconItems';
import { navDestinationTitle } from '../view/CommonView';

// IconItem相关数据
class IconItemSource {
  image: string | Resource = ''
  text: string | Resource = ''

  constructor(image: string | Resource = '', text: string | Resource = '') {
    this.image = image;
    this.text = text;
  }
}

@Builder
export function PageSevenPositiveBuilder() {
  PageSevenPositive()
}

@Component
export struct PageSevenPositive {
  pathStack: NavPathStack = new NavPathStack();
  private iconItemSourceList: IconItemSource[] = [];

  aboutToAppear() {
    // 遍历添加60个IconItem的数据
    for (let index = 0; index < 20; index++) {
      const numStart: number = index * 3;
      // 此处循环使用三张图片资源
      this.iconItemSourceList.push(
        new IconItemSource($r('app.media.album'), `item${numStart + 1}`),
        new IconItemSource($r('app.media.applet'), `item${numStart + 2}`),
        new IconItemSource($r('app.media.cards'), `item${numStart + 3}`),
      );
    }
  }

  build() {
    NavDestination() {
      navDestinationTitle('7.2正例', () => {
        this.pathStack.pop();
      })
      Column() {
        Row() {
          Row() {
            Text('场景示例')
              .fontSize(24)
              .lineHeight(24)
              .fontColor(Color.Black)
              .fontWeight(FontWeight.Bold)
              .margin({ left: 30 })
          }
        }
        .height(56)
        .width('100%')
        .backgroundColor(Color.White)
        .justifyContent(FlexAlign.SpaceBetween)

        // IconItem放置在grid内
        GridRow({
          columns: 6,
          gutter: { x: 0, y: 0 },
          breakpoints: {
            value: ["400vp", "600vp", "800vp"],
            reference: BreakpointsReference.WindowSize
          },
          direction: GridRowDirection.Row
        }) {
          ForEach(this.iconItemSourceList, (item: IconItemSource) => {
            GridCol() {
              IconItem({ renderGroupFlag: true, image: item.image, text: item.text })
                .transition(
                  TransitionEffect.scale({ x: 0.5, y: 0.5 })
                    .animation({ duration: 3000, curve: Curve.FastOutSlowIn, iterations: -1 })
                    .combine(TransitionEffect.rotate({ z: 1, angle: 360 })
                      .animation({ duration: 3000, curve: Curve.Linear, iterations: -1 }))
                )
            }
            .height(70)
            .width('25%')
          })
        }
        .width("100%")
        .height("100%")
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