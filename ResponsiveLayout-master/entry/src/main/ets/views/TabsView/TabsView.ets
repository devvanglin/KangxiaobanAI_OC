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

import { WindowInfo } from '../../utils/WindowUtil';
import { TabSideBarView } from './TabSideBarView';
import { TabDataModel, TabViewModel } from './model/TabData';
import { TopTabView } from './TopTabView';
import { VideoInfoView } from './VideoInfoView';
import { deviceInfo } from '@kit.BasicServicesKit';
import { FirstTab } from './model/TabData'

@Component
export struct TabsView {
  @ObjectLink mainWindowInfo: WindowInfo;
  @State firstLevelIndex: number = 0;
  @State secondLevelIndex: number = 0;
  pageInfos: NavPathStack = new NavPathStack();
  @State tabViewModel: TabViewModel = new TabViewModel();
  @State tabData: TabDataModel = this.tabViewModel.getTabMap();
  firstTabList: FirstTab[] = [
    new FirstTab($r('app.string.tab_home'), $r('app.media.tab_home'), $r('app.media.tab_home_selected')),
    new FirstTab($r('app.string.tab_category'), $r('app.media.tab_category'), $r('app.media.tab_category_selected')),
    new FirstTab($r('app.string.tab_shopping_bag'), $r('app.media.tab_bag'), $r('app.media.tab_bag_selected')),
    new FirstTab($r('app.string.tab_mine'), $r('app.media.tab_mine'), $r('app.media.tab_mine_selected'))
  ];

  @Builder
  tabBuilder(item: FirstTab, index: number) {
    Column() {
      Image(index !== this.firstLevelIndex ? item.tabIcon : item.tabIconSel)
        .width(24)
        .height(24)
      Text(item.tabName)
        .fontSize(10)
        .fontColor(index === this.firstLevelIndex ? '#D0092D' : Color.Black)
        .margin({ top: 4 })
        .opacity(index === this.firstLevelIndex ? 1 : 0.4)
    }
    .padding({
      bottom: this.getUIContext().px2vp(this.mainWindowInfo.AvoidNavigationIndicator?.bottomRect.height)
    })
    .height(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? 100 : '100%')
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    // [Start diff_device_container]
    // entry/src/main/ets/view/TabsView/TabsView.ets
    if ((this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG || this.mainWindowInfo.widthBp
      === WidthBreakpoint.WIDTH_XL)&& deviceInfo.deviceType == "2in1") {
      // Use SideBarContainer at XL breakpoint.
      SideBarContainer(SideBarContainerType.Embed) {
        TabSideBarView({
          firstLevelIndex: this.firstLevelIndex,
          secondLevelIndex: this.secondLevelIndex,
          tabData: this.tabData,
          firstTabList: this.firstTabList
        })
        Column() {
          Row() {
            // [StartExclude diff_device_container]
            Image($r('app.media.ic_public_back'))
              .width(40)
              .height(40)
              .margin({ left:16, right: 16 })
              .onClick(() => {
                this.pageInfos.pop();
              })
            // [EndExclude diff_device_container]
            Text(this.tabViewModel.getTabNameOfSecondLevel(this.tabViewModel.getTabNameOfFirstLevel(this.firstLevelIndex),
              this.secondLevelIndex))
              .fontSize('20fp')
              .fontWeight(700)
              .margin({
                left: 16,
              })
          }
          .padding({
            top: 60,
            bottom: 14,
          })

          VideoInfoView({
            mainWindowInfo: this.mainWindowInfo,
            firstLevelIndex: this.firstLevelIndex,
            secondLevelIndex: this.secondLevelIndex
          })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .autoHide(false)
      .divider({ strokeWidth: 0.3 })
      .showControlButton(false)
      .sideBarWidth(240)
      .minSideBarWidth(240)
      .maxSideBarWidth(240)
    } else {
      // [StartExclude diff_device_container]
      // Use Tabs and List at other breakpoints.
      // [Start tab_to_page]
      // entry/src/main/ets/view/TabsView/TabsView.ets
      Tabs({
        barPosition: this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? BarPosition.Start : BarPosition.End
      }) {
        TabContent() {
          TopTabView({
            pageInfos: this.pageInfos,
            mainWindowInfo: this.mainWindowInfo,
            firstLevelIndex: this.firstLevelIndex,
            tabData: this.tabData
          })
        }
        .tabBar(this.tabBuilder(this.firstTabList[0], 0))

        TabContent()
          .tabBar(this.tabBuilder(this.firstTabList[1], 1))

        TabContent()
          .tabBar(this.tabBuilder(this.firstTabList[2], 2))

        TabContent()
          .tabBar(this.tabBuilder(this.firstTabList[3], 3))
      }
      .barBackgroundColor('#CCF1F3F5')
      .barWidth(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? 96 : '100%')
      .barHeight(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? '100%' : 56 + this.getUIContext().px2vp(this.mainWindowInfo.AvoidNavigationIndicator?.bottomRect.height))
      .barMode(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? BarMode.Scrollable : BarMode.Fixed,
        { nonScrollableLayoutStyle: LayoutStyle.ALWAYS_CENTER })
      .barBackgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .vertical(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG)
      .onChange((index: number) => {
        this.firstLevelIndex = index;
      })
      // [End tab_to_page]
      .scrollable(false)
      .height('100%')
      .width('100%')
      // [EndExclude diff_device_container]
    }
    // [End diff_device_container]
  }
}

