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
  note: string;
  symbol: Resource;
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
        note: '总览、床位、异常与执行效率',
        symbol: $r('sys.symbol.house_fill')
      },
      {
        label: $r('app.string.tab_music'),
        note: '长者画像、风险分层与陪护建议',
        symbol: $r('sys.symbol.person_2_fill')
      },
      {
        label: $r('app.string.tab_cafe'),
        note: '任务闭环、交接班与时段排程',
        symbol: $r('sys.symbol.square_and_pencil_fill')
      },
      {
        label: $r('app.string.tab_mine'),
        note: '班次、绩效、培训与偏好设置',
        symbol: $r('sys.symbol.person_crop_circle_fill')
      }
    ];
  }

  @Builder
  private sidebarTag(text: string, backgroundColor: ResourceColor, fontColor: ResourceColor = '#335C88') {
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
  private wideNavButton(item: WideNavItem, index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(40)
          .height(40)
          .backgroundColor(this.isCurrentTab(index) ? '#1D63ED' : '#F3F6FA')
          .borderRadius(12)
        SymbolGlyph(item.symbol)
          .fontSize($r('sys.float.Body_L'))
          .fontColor([this.isCurrentTab(index) ? '#FFFFFF' : $r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)

      Column({ space: 2 }) {
        Text(item.label)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(this.isCurrentTab(index) ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.isCurrentTab(index) ? '#10233E' : $r('sys.color.font_primary'))
        Text(item.note)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.isCurrentTab(index) ? '#47617D' : $r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: 12,
      bottom: 12
    })
    .backgroundColor(this.isCurrentTab(index) ? '#EAF1FD' : '#FFFFFF')
    .borderRadius(14)
    .border({
      width: 1,
      color: this.isCurrentTab(index) ? '#C9D9FB' : '#E2E8F0'
    })
    .onClick(() => {
      this.currentTabIndex = index;
    })
  }

  @Builder
  private wideSidebar() {
    Column({ space: 18 }) {
      Column({ space: 10 }) {
        Row() {
          Text('康小伴 AI 护工端')
            .fontSize($r('sys.float.Subtitle_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Blank()
          this.sidebarTag('值班中', '#E8F3EA', '#216E39')
        }

        Text('面向养老院护工、护理站和值班主管的多端工作台。')
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#526277')
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .padding($r('sys.float.padding_level6'))
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .border({
        width: 1,
        color: '#DFE7F1'
      })

      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text('白班总控')
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('08:00 - 18:00')
              .fontSize($r('sys.float.Body_S'))
              .fontColor('#526277')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('A 栋服务区')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#6B7C93')
        }

        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text('18')
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('待办')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor('#6B7C93')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text('6')
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('风险观察')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor('#6B7C93')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text('92%')
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('闭环率')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor('#6B7C93')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding($r('sys.float.padding_level6'))
      .backgroundColor('#F8FBFF')
      .borderRadius(16)
      .border({
        width: 1,
        color: '#DDE7F4'
      })

      Column({ space: 10 }) {
        Text('业务导航')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#6B7C93')
        Repeat(this.wideNavItems())
          .each((repeatItem: RepeatItem<WideNavItem>) => {
            this.wideNavButton(repeatItem.item, repeatItem.index)
          })
      }

      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text('入住登记')
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('资料核验、床位安排、照护计划与交接同步。')
              .fontSize($r('sys.float.Body_S'))
              .fontColor('#526277')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }

        Row({ space: 10 }) {
          this.sidebarTag('今日预排 03', '#EAF1FD', '#1D63ED')
          this.sidebarTag('空床 12', '#F3F6FA', '#526277')
        }

        Button('开始办理')
          .width('100%')
          .height(44)
          .backgroundColor('#1D63ED')
          .borderRadius(12)
          .fontColor('#FFFFFF')
          .fontSize($r('sys.float.Body_M'))
          .onClick(() => {
            this.openCheckInFlow();
          })
      }
      .alignItems(HorizontalAlign.Start)
      .padding($r('sys.float.padding_level6'))
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .border({
        width: 1,
        color: '#DFE7F1'
      })

      Column({ space: 8 }) {
        Row() {
          Text('系统状态')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Blank()
          Text('已同步')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#216E39')
        }
        Text('设备在线 186 台，毫米波与床垫数据回传稳定，家属端摘要推送正常。')
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#526277')
      }
      .alignItems(HorizontalAlign.Start)
      .padding($r('sys.float.padding_level6'))
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .border({
        width: 1,
        color: '#DFE7F1'
      })

      Blank()
    }
    .width(this.sidebarWidth())
    .height('100%')
    .padding({
      left: this.wideShellPadding(),
      right: 0,
      top: this.sidebarTopPadding(),
      bottom: this.wideShellPadding()
    })
    .backgroundColor('#EAF0F6')
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
    Row({ space: this.wideShellPadding() }) {
      this.wideSidebar()

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
      .layoutWeight(1)
      .height('100%')
      .padding({
        right: this.wideShellPadding(),
        bottom: this.wideShellPadding()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EAF0F6')
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
    .hideTitleBar(this.homeSearchState.isSearchOpen)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }
}
