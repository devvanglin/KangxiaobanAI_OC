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
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
  TextStyleMode,
} from '@kit.UIDesignKit';
import { CheckInFlowPage } from '../component/CheckInFlowPage';
import { SearchPage } from '../component/SearchPage';
import { TabPageView } from '../component/TabPageView';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { HomeSearchState } from '../model/HomeSearchState';
import { PAGE_SCROLLER_MAP, PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import { TAB_PAGE_CONFIGS, TabPageConfig } from '../model/TabPageModel';
import Logger from '../util/Logger';
import { BreakpointType } from '../util/BreakpointSystem';

const TAG: string = '[MainPage]';
const CHECK_IN_ROUTE_NAME: string = 'CheckInRegister';
const SEARCH_ROUTE_NAME: string = 'SearchPage';

interface WideNavItem {
  label: ResourceStr;
  symbol: Resource;
  badge?: string;
}

@Entry
@ComponentV2
struct MainPage {
  @Provider('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  private controller: HdsTabsController = new HdsTabsController();
  private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.ADAPTIVE_TAB) ?? [];
  private pageConfigs: TabPageConfig[] = TAB_PAGE_CONFIGS;
  @Local isMiniBar: boolean = true;
  @Local currentTabIndex: number = 0;
  @Local isShowSidebar: boolean = false;
  @Local sidebarSearchText: string = '';
  @Local homeSearchState: HomeSearchState =
    AppStorageV2.connect(HomeSearchState, StorageKey.HOME_SEARCH_STATE, () => new HomeSearchState()) ??
    new HomeSearchState();

  private getCurrentPageTitle(): ResourceStr {
    return this.pageConfigs[this.currentTabIndex]?.title ?? $r('app.string.tab_home');
  }

  private openCheckInFlow(): void {
    this.pathStack.pushPath({ name: CHECK_IN_ROUTE_NAME });
  }

  private openSearchPage(): void {
    this.pathStack.pushPath({ name: SEARCH_ROUTE_NAME });
  }

  private homeSearchMenu(): HdsNavigationMenuContentOptions {
    if (this.isWideLayout()) {
      return {
        value: [
          {
            content: {
              icon: $r('sys.symbol.list_bullet'),
              isEnabled: true,
              action: () => {
                this.getUIContext().animateTo({
                  duration: 300,
                  curve: Curve.EaseInOut
                }, () => {
                  this.isShowSidebar = true;
                })
              }
            }
          },
          {
            content: {
              icon: $r('sys.symbol.magnifyingglass'),
              isEnabled: true,
              action: () => {
                this.homeSearchState.searchTrigger++;
              }
            }
          }
        ]
      };
    }
    const showSearchButton: boolean = this.currentTabIndex === 0 && this.homeSearchState.scrollY > 60;
    return {
      value: showSearchButton ? [
        {
          content: {
            icon: $r('sys.symbol.magnifyingglass'),
            isEnabled: true,
            action: () => {
              this.homeSearchState.searchTrigger++;
            }
          }
        }
      ] : []
    };
  }

  private isWideLayout(): boolean {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
      widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private sidebarWidth(): number {
    return new BreakpointType<number>({
      sm: 248,
      md: 268,
      lg: 288,
      xl: 304
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  private wideShellPadding(): number {
    return new BreakpointType<number>({
      sm: 16,
      md: 20,
      lg: 24,
      xl: 28
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  private sidebarTopPadding(): number {
    return this.globalInfoModel.statusBarHeight + 26;
  }

  private isCurrentTab(index: number): boolean {
    return this.currentTabIndex === index;
  }

  private wideNavItems(): WideNavItem[] {
    return [
      {
        label: $r('app.string.tab_home'),
        symbol: $r('sys.symbol.house_fill')
      },
      {
        label: $r('app.string.tab_music'),
        symbol: $r('sys.symbol.person_2_fill')
      },
      {
        label: $r('app.string.tab_cafe'),
        symbol: $r('sys.symbol.square_and_pencil_fill'),
        badge: '18'
      },
      {
        label: $r('app.string.tab_mine'),
        symbol: $r('sys.symbol.person_crop_circle_fill')
      }
    ];
  }

  @Builder
  private sidebarTag(text: string, backgroundColor: ResourceColor, fontColor: ResourceColor = $r('sys.color.font_secondary')) {
    Text(text)
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(fontColor)
      .padding({
        left: $r('sys.float.padding_level3'),
        right: $r('sys.float.padding_level3'),
        top: 4,
        bottom: 4
      })
      .backgroundColor(backgroundColor)
      .borderRadius(10)
  }

  @Builder
  private wideNavItemRow(item: WideNavItem, index: number) {
    Row() {
      SymbolGlyph(item.symbol)
        .fontSize(24)
        .fontColor([this.isCurrentTab(index) ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        .margin({ right: 12 })

      Text(item.label)
        .fontSize(16)
        .flexGrow(1)
        .fontColor($r('sys.color.font_primary'))
        .fontWeight(this.isCurrentTab(index) ? FontWeight.Medium : FontWeight.Regular)

      Blank()

      if (item.badge) {
        Text(item.badge)
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ right: 8 })
      }

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(20)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
    .borderRadius(12)
    .backgroundColor(this.isCurrentTab(index) ? $r('sys.color.comp_background_emphasize') : Color.Transparent)
    .onClick(() => {
      this.currentTabIndex = index;
    })
  }

  @Builder
  private sidebarAccountItem() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(48)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('李护工')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('A 栋 · 白班 08:00-18:00')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .padding({ left: 12 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)

      Blank()
      this.sidebarTag('值班中', $r('app.color.status_normal_bg'), $r('app.color.status_normal'))
    }
    .width('100%')
    .height(72)
    .padding({ left: 8, right: 8 })
    .borderRadius(12)
    .onClick(() => {})
  }

  @Builder
  private sidebarGroup(items: WideNavItem[], groupTitle?: string) {
    Column() {
      if (groupTitle) {
        Text(groupTitle)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ bottom: 8, left: 4 })
      }
      Column() {
        ForEach(items, (item: WideNavItem, index: number) => {
          this.wideNavItemRow(item, index)
          if (index < items.length - 1) {
            Divider()
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
              .margin({ left: 44, right: 8 })
          }
        }, (item: WideNavItem, index: number) => item.label.toString() + index)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .padding(4)
    }
    .width('100%')
  }

  @Builder
  private wideSidebarPanel() {
    Column() {
      Search({ placeholder: '搜索功能、长者、任务' })
        .width('100%')
        .height(40)
        .margin({ bottom: 12 })
        .onChange((value: string) => {
          this.sidebarSearchText = value;
        })

      Scroll() {
        Column({ space: 16 }) {
          this.sidebarAccountItem()

          this.sidebarGroup(this.wideNavItems(), '业务导航')

          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Text('入住登记')
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Text('资料核验、床位安排、照护计划与交接同步')
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }

            Row({ space: 8 }) {
              this.sidebarTag('今日预排 03', $r('sys.color.comp_background_emphasize'), $r('app.color.brand_blue'))
              this.sidebarTag('空床 12', $r('sys.color.comp_background_secondary'), $r('sys.color.font_secondary'))
            }

            Button('开始办理')
              .width('100%')
              .height(44)
              .backgroundColor($r('app.color.brand_blue'))
              .borderRadius(12)
              .fontColor($r('app.color.text_on_brand'))
              .fontSize($r('sys.float.Body_M'))
              .onClick(() => {
                this.openCheckInFlow();
              })
          }
          .alignItems(HorizontalAlign.Start)
          .padding($r('sys.float.padding_level6'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)

          Column({ space: 8 }) {
            Row() {
              Text('系统状态')
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              Blank()
              Text('已同步')
                .fontSize($r('sys.float.Caption_M'))
                .fontColor($r('app.color.status_normal'))
            }
            Text('设备在线 186 台，毫米波与床垫数据回传稳定，家属端摘要推送正常。')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .padding($r('sys.float.padding_level6'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: this.wideShellPadding(),
      right: this.wideShellPadding(),
      top: this.sidebarTopPadding(),
      bottom: this.wideShellPadding()
    })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private miniBarBuilder() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(44)
          .height(44)
          .backgroundColor('#00000000')
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize($r('sys.float.Title_L'))
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(44)
      .height(44)

      if (!this.isMiniBar) {
        Column({ space: 4 }) {
          Text('入住登记')
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .fontSize($r('sys.float.Body_S'))
          Text('预排 03  空床 12')
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
            .fontWeight(FontWeight.Regular)
            .fontColor($r('sys.color.font_secondary'))
            .fontSize($r('sys.float.Caption_M'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .padding({
      left: this.isMiniBar ? 6 : 4,
      right: this.isMiniBar ? 6 : 12,
      top: this.isMiniBar ? 4 : 8,
      bottom: this.isMiniBar ? 4 : 8
    })
    .onClick(() => {
      this.openCheckInFlow();
    })
  }

  @Builder
  private phoneTabs() {
    HdsTabs({ controller: this.controller }) {
      TabContent() {
        TabPageView({
          currentTabIndex: 0,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[0],
          onOpenSearch: () => {
            this.openSearchPage();
          }
        })
      }
      .tabBar(this.tabsBar[0])

      TabContent() {
        TabPageView({
          currentTabIndex: 1,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[1],
          onOpenSearch: () => {
            this.openSearchPage();
          }
        })
      }
      .tabBar(this.tabsBar[1])

      TabContent() {
        TabPageView({
          currentTabIndex: 2,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[2],
          onOpenSearch: () => {
            this.openSearchPage();
          }
        })
      }
      .tabBar(this.tabsBar[2])

      TabContent() {
        TabPageView({
          currentTabIndex: 3,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[3],
          onOpenSearch: () => {
            this.openSearchPage();
          }
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

  @Builder
  private wideShell() {
    SideBarContainer(SideBarContainerType.Overlay) {
      this.wideSidebarPanel()

      Column() {
        this.wideContentPanel()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isShowSidebar ? $r('sys.color.mask_secondary') : $r('sys.color.background_secondary'))
      .onClick(() => {
        if (this.isShowSidebar) {
          this.getUIContext().animateTo({
            duration: 300,
            curve: Curve.EaseInOut
          }, () => {
            this.isShowSidebar = false;
          })
        }
      })
    }
    .showSideBar(this.isShowSidebar)
    .showControlButton(false)
    .sideBarWidth('80%')
    .minSideBarWidth('80%')
    .maxSideBarWidth('90%')
    .autoHide(true)
    .onChange((value: boolean) => {
      this.isShowSidebar = value;
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  private wideContentPanel() {
    Stack({ alignContent: Alignment.TopStart }) {
      TabPageView({
        currentTabIndex: this.currentTabIndex,
        pageKey: PageKeyEnum.ADAPTIVE_TAB,
        config: this.pageConfigs[this.currentTabIndex],
        onOpenSearch: () => {
          this.openSearchPage();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({
      right: this.wideShellPadding(),
      bottom: this.wideShellPadding()
    })
  }

  @Builder
  private destinationBuilder(name: string, param?: ESObject) {
    if (name === CHECK_IN_ROUTE_NAME) {
      CheckInFlowPage()
    } else if (name === SEARCH_ROUTE_NAME) {
      SearchPage()
    }
  }

  build() {
    HdsNavigation(this.pathStack) {
      if (this.isWideLayout()) {
        this.wideShell()
      } else {
        this.phoneTabs()
      }
    }
    .mode(NavigationMode.Stack)
    .navDestination(this.destinationBuilder)
    .titleBar({
      content: {
        title: {
          mainTitle: this.getCurrentPageTitle(),
        },
        menu: this.homeSearchMenu(),
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      },
    })
    .bindToScrollable(PAGE_SCROLLER_MAP.get(PageKeyEnum.ADAPTIVE_TAB) ?? [])
    .hideBackButton(true)
    .hideTitleBar(this.homeSearchState.isSearchOpen, true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }
}
