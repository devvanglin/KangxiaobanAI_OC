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

import { AppStorageV2 } from '@kit.ArkUI';
import {
  HdsBarStyle,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
} from '@kit.UIDesignKit';
import { TabPageView } from '../component/TabPageView';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PAGE_SCROLLER_MAP, PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import { TAB_PAGE_CONFIGS, TabPageConfig } from '../model/TabPageModel';
import Logger from '../util/Logger';

const TAG: string = '[MainPage]';

@Entry
@ComponentV2
struct MainPage {
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  private controller: HdsTabsController = new HdsTabsController();
  private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.ADAPTIVE_TAB) ?? [];
  private pageConfigs: TabPageConfig[] = TAB_PAGE_CONFIGS;
  @Local isMiniBar: boolean = true;
  @Local currentTabIndex: number = 0;

  private getCurrentPageTitle(): ResourceStr {
    return this.pageConfigs[this.currentTabIndex]?.title ?? $r('app.string.tab_home');
  }

  @Builder
  miniBarBuilder() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize($r('sys.float.Title_L'))
          .fontColor([$r('sys.color.icon_primary')])
      }
      .padding(this.isMiniBar ? $r('sys.float.padding_level1') : $r('sys.float.padding_level3'))
      .width(56)
      .aspectRatio(1)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)

      Column({ space: 6 }) {
        Text($r('app.string.mini_bar_title'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        Text($r('app.string.mini_bar_operator'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
      }
      .padding({ left: $r('sys.float.padding_level1') })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 2 }) {
        Text($r('app.string.mini_bar_capacity_label'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
        Text($r('app.string.mini_bar_capacity_value'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
      }
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.Center)
      .padding({
        left: $r('sys.float.padding_level4'),
        right: $r('sys.float.padding_level8')
      })
    }
  }

  build() {
    HdsNavigation() {
      HdsTabs({ controller: this.controller }) {
        TabContent() {
          TabPageView({
            currentTabIndex: 0,
            pageKey: PageKeyEnum.ADAPTIVE_TAB,
            config: this.pageConfigs[0]
          })
        }
        .tabBar(this.tabsBar[0])

        TabContent() {
          TabPageView({
            currentTabIndex: 1,
            pageKey: PageKeyEnum.ADAPTIVE_TAB,
            config: this.pageConfigs[1]
          })
        }
        .tabBar(this.tabsBar[1])

        TabContent() {
          TabPageView({
            currentTabIndex: 2,
            pageKey: PageKeyEnum.ADAPTIVE_TAB,
            config: this.pageConfigs[2]
          })
        }
        .tabBar(this.tabsBar[2])

        TabContent() {
          TabPageView({
            currentTabIndex: 3,
            pageKey: PageKeyEnum.ADAPTIVE_TAB,
            config: this.pageConfigs[3]
          })
        }
        .tabBar(this.tabsBar[3])
      }
      .barOverlap(true)
      .vertical(false)
      .onChange((index: number) => {
        this.currentTabIndex = index;
      })
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
          $r('sys.float.padding_level8'),
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        miniBar: {
          miniBarBuilder: () => this.miniBarBuilder(),
          onBarStyleChange: (miniBarStyle: HdsBarStyle) => {
            this.isMiniBar = miniBarStyle === HdsBarStyle.COLLAPSE;
          }
        }
      })
      .onAttach(() => {
        try {
          this.controller.preloadItems([0, 1, 2, 3]);
        } catch (error) {
          Logger.error(TAG, 'OnAttach preloadItems failed');
        }
      })
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: {
          mainTitle: this.getCurrentPageTitle(),
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      },
    })
    .bindToScrollable(PAGE_SCROLLER_MAP.get(PageKeyEnum.ADAPTIVE_TAB) ?? [])
    .hideBackButton(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
