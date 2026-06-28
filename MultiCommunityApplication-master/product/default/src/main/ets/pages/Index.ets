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
import { hdsMaterial, HdsNavigation, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiObserver } from '@kit.ArkUI';
import { CommonConstants, HdsNavigationModifier, TabBarListModel, TabBarModel } from 'commonmulticommunityapplication';
import { VideoPage } from './VideoPage';
import { HomePage } from './HomePage';
import { MinePage } from './MinePage';
import { HotPage } from './HotPage';

@Entry
@ComponentV2
struct Index {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Provider() pathStack: NavPathStack = new NavPathStack(); // pathStack API 22
  @Local tabs: TabBarModel[] = [];
  @Local currentIndex: number = 0;
  @Local navigationMode: NavigationMode = NavigationMode.Stack;
  private controller: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.tabs = new TabBarListModel().loadTabs();
  }

  build() {
    if (deviceInfo.distributionOSApiVersion >= 60100) {
      HdsNavigation(this.pathStack) {
        HdsTabs({ controller: this.controller }) {
          ForEach(this.tabs, (item: TabBarModel) => {
            this.SocialPanel(item, true)
          }, (item: TabBarModel) => `${item.index}`)
        }
        .scrollable(false)
        .animationDuration(0)
        .barOverlap(true)
        .barPosition(BarPosition.End)
        .vertical(false)
        .barFloatingStyle({
          barWidth: { smallWidth: 294, mediumWidth: 328, largeWidth: 328 },
          barSideMargin: 16,
          barBottomMargin: this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
            this.breakpoint.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 8 : 0,
          gradientMask: { maskColor: $r('app.color.mask_gradient'), maskHeight: 92 },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .attributeModifier(new HdsNavigationModifier(this.breakpoint.widthBreakpoint, this.navigationMode))
    } else {
      Navigation(this.pathStack) {
        Tabs({
          barPosition: this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? BarPosition.Start :
            BarPosition.End,
          index: this.currentIndex
        }) {
          ForEach(this.tabs, (item: TabBarModel) => {
            this.SocialPanel(item, false)
          }, (item: TabBarModel) => `${item.index}`)
        }
        .scrollable(false)
        .vertical(this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? true : false)
        .barMode(this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? BarMode.Scrollable : BarMode.Fixed)
        .animationDuration(0)
        .barBackgroundColor($r('app.color.background_secondary'))
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .barWidth(this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? 96 : '100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .navBarWidth(this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? '45%' : '50%')
      .mode(this.navigationMode)
      .hideToolBar(true)
    }
  }

  @Builder
  SocialPanel(item: TabBarModel, isHighApiLevel: boolean) {
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
    .tabBar(isHighApiLevel ? this.ChatTabBar23(item) : this.ChatTabBar(item))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  ChatTabBar23(item: TabBarModel) {
    Column() {
      this.TabBarColumn(item);
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ChatTabBar(item: TabBarModel) {
    Column() {
      this.TabBarColumn(item);
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .margin({ top: this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? 64 : 0 })
  }

  @Builder
  TabBarColumn(item: TabBarModel) {
    Column() {
      Image(this.currentIndex === item.index ? item.selectImg : item.img)
        .objectFit(ImageFit.Contain)
        .width(24)
        .height(24)
      Text(item.title)
        .fontColor(this.currentIndex === item.index ? $r('app.color.font_emphasize') :
          $r('app.color.font_tertiary'))
        .opacity(this.currentIndex === item.index ? 1 : 0.6)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .fontSize(10)
        .lineHeight(14)
        .margin({ top: 4 })
    }
  }
}