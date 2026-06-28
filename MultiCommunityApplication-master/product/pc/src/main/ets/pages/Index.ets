/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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
import { CommonConstants, TabBarListModel, TabBarModel } from 'commonmulticommunityapplication';
import { VideoPage } from './VideoPage';
import { HomePage } from './HomePage';
import { MinePage } from './MinePage';
import { HotPage } from './HotPage';

@Entry
@ComponentV2
struct Index {
  @Provider() pathStack: NavPathStack = new NavPathStack();
  @Provider() sideBar: boolean = true;
  @Local tabs: TabBarModel[] = [];
  @Local currentIndex: number = 0;
  @Local navigationMode: NavigationMode = NavigationMode.Stack;
  private controller: TabsController = new TabsController();

  aboutToAppear(): void {
    this.tabs = new TabBarListModel().loadTabs();
  }

  build() {
    SideBarContainer() {
      Column() {
        Row() {
          Image($r('app.media.icon_pc'))
            .width(24)
            .height(24)

          Text($r('app.string.side_bar_title'))
            .fontSize(16)
            .lineHeight(21)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_primary'))
            .margin({ left: 12 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 24, right: 24 })

        Column({ space: 2 }) {
          ForEach(this.tabs, (item: TabBarModel) => {
            this.TabBarRow(item)
          }, (item: TabBarModel) => `${item.index}`)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .margin({ top: 8 })
      }
      .width('100%')
      .height('100%')

      Column() {
        Navigation(this.pathStack) {
          Tabs({ controller: this.controller, index: this.currentIndex }) {
            ForEach(this.tabs, (item: TabBarModel) => {
              this.ChatTabContent(item)
            }, (item: TabBarModel) => `${item.index}`)
          }
          .barHeight(0)
          .scrollable(false)
          .animationDuration(0)
        }
        .hideTitleBar(true)
        .hideToolBar(true)
        .width('100%')
        .height('100%')
        .mode(this.navigationMode)
        .navBarWidth('40%')
      }
      .width('100%')
      .height('100%')
    }
    .showSideBar(this.sideBar)
    .sideBarWidth(240)
    .showControlButton(false)
    .autoHide(false)
  }

  @Builder
  ChatTabContent(item: TabBarModel) {
    TabContent() {
      if (item.index === CommonConstants.TAB_HOME_INDEX) {
        HomePage({ activeIndex: this.currentIndex })
      } else if (item.index === CommonConstants.TAB_HOT_PAGE_INDEX) {
        HotPage({ activeIndex: this.currentIndex })
      } else if (item.index === CommonConstants.TAB_VIDEO_PAGE_INDEX) {
        VideoPage({ activeIndex: this.currentIndex })
      } else {
        MinePage({ activeIndex: this.currentIndex })
      }
    }
  }

  @Builder
  TabBarRow(item: TabBarModel) {
    Row() {
      Image(this.currentIndex === item.index ? item.selectImg : item.img)
        .objectFit(ImageFit.Contain)
        .width(24)
        .height(24)
        .borderRadius(6)
        .margin({ left: 8 })
      Text(item.title)
        .fontColor(this.currentIndex === item.index ? $r('app.color.font_emphasize') :
          $r('app.color.font_tertiary'))
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .fontSize(16)
        .lineHeight(19)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(40)
    .borderRadius(8)
    .backgroundColor(this.currentIndex === item.index ? $r('app.color.comp_emphasize_tertiary') : Color.Transparent)
    .onClick(() => {
      this.currentIndex = item.index;
      this.controller.changeIndex(item.index);
    })
  }
}
