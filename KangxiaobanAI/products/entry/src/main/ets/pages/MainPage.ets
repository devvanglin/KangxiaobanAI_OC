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

import { AppStorageV2, curves, router, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  hdsMaterial,
  HdsListItemCard,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixText,
  TextStyleMode,
} from '@kit.UIDesignKit';
import { TabPageView } from '../component/TabPageView';
import { WideCaregiverWorkspace } from '../component/wide/WideCaregiverWorkspace';
import { AiChatPage } from '../pages/AiChatPage';
import { MineDetailPage } from '../pages/MineDetailPage';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PAGE_SCROLLER_MAP, PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import { TAB_PAGE_CONFIGS, TabPageConfig } from '../model/TabPageModel';
import Logger from '../util/Logger';
import { BreakpointUtil } from '../util/BreakpointSystem';

const TAG: string = '[MainPage]';

interface WideNavItem {
  label: ResourceStr;
  symbol: Resource;
  badge?: string;
  tabIndex?: number;
  action?: () => void;
}

interface WideNavGroup {
  label: string;
  items: WideNavItem[];
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
  @Local currentTabIndex: number = 0;
  @Local primaryTabIndex: number = 0;
  @Local isSidebarCollapsed: boolean = false;
  @Local isAiChatShow: boolean = false;

  @Styles
  pcIconNormalStyle() {
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Styles
  pcIconPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
  }

  private getCurrentPageTitle(): ResourceStr {
    return this.pageConfigs[this.currentTabIndex]?.title ?? $r('app.string.tab_home');
  }

  private updateTabSelection(index: number): void {
    if (index === 0 || index === 1) {
      this.primaryTabIndex = index;
    }
    this.currentTabIndex = index;
  }

  private switchTab(index: number): void {
    if (this.isWideLayout()) {
      this.isAiChatShow = false;
      this.updateTabSelection(index);
    } else {
      this.controller.changeIndex(index);
    }
  }

  private isRoleAdapted(): boolean {
    return this.globalInfoModel.role === '护工';
  }

  @Builder
  private roleWipPanel() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.hammer_fill'))
        .fontSize(56)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(`${this.globalInfoModel.role}端`)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text('适配中')
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_secondary'))
      Text('该角色页面正在开发中，敬请期待')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.globalInfoModel.statusBarHeight })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }

  private isWideLayout(): boolean {
    return BreakpointUtil.isWide(this.globalInfoModel.widthBreakpoint);
  }

  private async handleLogout(): Promise<void> {
    try {
      await router.replaceUrl({ url: 'pages/LoginPage' });
    } catch (error) {
      Logger.error(TAG, `logout failed: ${JSON.stringify(error)}`);
    }
  }

  private sidebarWidth(): number {
    return this.isSidebarCollapsed ? 72 : 288;
  }

  private isNavActive(item: WideNavItem): boolean {
    return item.tabIndex !== undefined && this.currentTabIndex === item.tabIndex;
  }

  private handleNavClick(item: WideNavItem): void {
    if (item.tabIndex !== undefined) {
      this.updateTabSelection(item.tabIndex);
    } else if (item.action) {
      item.action();
    }
  }

  private toggleSidebar(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.isSidebarCollapsed = !this.isSidebarCollapsed;
    });
  }

  private openAiChat(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 328, 36)
    }, () => {
      this.isAiChatShow = true;
    })
  }

  private closeAiChat(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isAiChatShow = false;
    })
  }

  onBackPress(): boolean {
    if (this.isAiChatShow) {
      this.closeAiChat();
      return true;
    }
    if (this.isWideLayout() && this.pathStack.size() === 0 && this.currentTabIndex !== 0) {
      this.switchTab(0);
      return true;
    }
    return false;
  }

  private wideNavGroups(): WideNavGroup[] {
    return [
      {
        label: '业务',
        items: [
          { label: $r('app.string.tab_home'), symbol: $r('sys.symbol.house_fill'), tabIndex: 0 },
          { label: $r('app.string.tab_music'), symbol: $r('sys.symbol.person_2_fill'), tabIndex: 1 },
          { label: $r('app.string.tab_message'), symbol: $r('sys.symbol.message_on_message_fill'), tabIndex: 2 },
        ]
      },
      {
        label: '管理',
        items: [
          { label: '排班', symbol: $r('sys.symbol.calendar_badge_clock') },
          { label: '服务记录', symbol: $r('sys.symbol.doc_text') },
        ]
      },
      {
        label: '系统',
        items: [
          { label: '帮助', symbol: $r('sys.symbol.questionmark_circle') },
        ]
      },
    ];
  }

  // ==================== PC 侧边栏 ====================

  @Builder
  private pcSidebar() {
    Column() {
      this.pcSidebarHeader()

      Scroll() {
        Column({ space: 20 }) {
          ForEach(this.wideNavGroups(), (group: WideNavGroup, groupIndex: number) => {
            this.pcNavGroup(group, groupIndex)
          }, (group: WideNavGroup, groupIndex: number) => `${groupIndex}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)

      this.pcSidebarFooter()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.globalInfoModel.statusBarHeight })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private pcSidebarHeader() {
    Row() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.house_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.brand_blue')])

        if (!this.isSidebarCollapsed) {
          Column({ space: 2 }) {
            Text('康小伴')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('移动智慧养老')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
      .layoutWeight(this.isSidebarCollapsed ? 0 : 1)
      .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
      .width(this.isSidebarCollapsed ? '100%' : undefined)
      .alignItems(VerticalAlign.Center)

      if (!this.isSidebarCollapsed) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(14)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .stateStyles({
          normal: this.pcIconNormalStyle,
          pressed: this.pcIconPressedStyle
        })
        .focusable(true)
        .onClick(() => {
          this.toggleSidebar();
        })
      }
    }
    .width('100%')
    .height(68)
    .padding({ left: this.isSidebarCollapsed ? 0 : 20, right: this.isSidebarCollapsed ? 0 : 12 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private pcSidebarFooter() {
    Column() {
      if (this.isSidebarCollapsed) {
        HdsListItemCard({
          prefixItem: new PrefixIcon({
            iconSize: IconSize.SYSTEM_ICON,
            iconValue: {
              symbol: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill'))
                .fontColor([$r('sys.color.icon_secondary')])
            }
          }),
          cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          cardHeight: 56,
          cardBorderRadius: 12,
          cardPrefixMargin: 0,
          cardSuffixMargin: 0
        })
      } else {
        HdsListItemCard({
          prefixItem: new PrefixIcon({
            iconSize: IconSize.SYSTEM_ICON,
            iconValue: {
              symbol: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill'))
                .fontColor([$r('sys.color.icon_secondary')])
            }
          }),
          textItem: {
            primaryText: { text: '李护工' },
            secondaryText: { text: '白班 08:00-18:00' }
          },
          suffixItem: new SuffixArrow(),
          cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          cardHeight: 56,
          cardBorderRadius: 12,
          cardPrefixMargin: 0,
          cardSuffixMargin: 0
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
  }

  @Builder
  private pcNavGroup(group: WideNavGroup, groupIndex: number) {
    Column({ space: 6 }) {
      if (!this.isSidebarCollapsed) {
        Text(group.label)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8, top: 4, bottom: 2 })
      }
      Column({ space: 2 }) {
        ForEach(group.items, (item: WideNavItem, index: number) => {
          if (this.isSidebarCollapsed) {
            this.pcNavItemCollapsed(item, this.isNavActive(item))
          } else {
            this.pcNavItemExpanded(item, this.isNavActive(item))
          }
        }, (item: WideNavItem, index: number) => `${groupIndex}-${index}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private pcNavItemExpanded(item: WideNavItem, isActive: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(item.symbol)
            .fontColor([isActive ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        }
      }),
      textItem: {
        primaryText: {
          text: item.label
        }
      },
      suffixItem: item.badge ? new SuffixText({ text: item.badge }) : new SuffixArrow(),
      cardBackgroundColor: isActive ? $r('sys.color.comp_background_emphasize') :
        $r('sys.color.ohos_id_color_background_transparent'),
      cardHeight: 48,
      cardBorderRadius: 12,
      cardPrefixMargin: 4,
      cardSuffixMargin: 0
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.handleNavClick(item);
    })
  }

  @Builder
  private pcNavItemCollapsed(item: WideNavItem, isActive: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(item.symbol)
            .fontColor([isActive ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        }
      }),
      cardBackgroundColor: isActive ? $r('sys.color.comp_background_emphasize') :
        $r('sys.color.ohos_id_color_background_transparent'),
      cardHeight: 48,
      cardBorderRadius: 12,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.handleNavClick(item);
    })
  }

  // ==================== PC 顶部栏 ====================

  @Builder
  private pcTopBar() {
    Row({ space: 16 }) {
      Row({ space: 12 }) {
        if (this.isSidebarCollapsed) {
          Row() {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize($r('sys.float.Title_S'))
              .fontColor([$r('sys.color.font_primary')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .stateStyles({
            normal: this.pcIconNormalStyle,
            pressed: this.pcIconPressedStyle
          })
          .focusable(true)
          .onClick(() => {
            this.toggleSidebar();
          })
        }

        Column({ space: 2 }) {
          Text(this.getCurrentPageTitle())
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('移动智慧养老 · 半山敬老院')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Row({ space: 8 }) {
        this.pcTopBarIcon($r('sys.symbol.bell'), true)
        this.pcTopBarIcon($r('sys.symbol.gearshape'), false)
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(36)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(64)
    .padding({ left: 24, right: 24 })
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
    .margin({ top: this.globalInfoModel.statusBarHeight })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private pcTopBarIcon(symbol: Resource, hasBadge: boolean) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        SymbolGlyph(symbol)
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.pcIconNormalStyle,
        pressed: this.pcIconPressedStyle
      })
      .focusable(true)

      if (hasBadge) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.status_danger'))
          .margin({ top: 6, right: 6 })
      }
    }
    .width(40)
    .height(40)
  }

  // ==================== 手机端（原样保留） ====================

  @Builder
  private phoneTabs() {
    HdsTabs({ controller: this.controller }) {
      TabContent() {
        TabPageView({
          currentTabIndex: 0,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[0],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          }
        })
      }
      .tabBar(this.tabsBar[0])

      TabContent() {
        TabPageView({
          currentTabIndex: 1,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[1],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          }
        })
      }
      .tabBar(this.tabsBar[1])

      TabContent() {
        TabPageView({
          currentTabIndex: 2,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[2],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          }
        })
      }
      .tabBar(this.tabsBar[2])

      TabContent() {
        TabPageView({
          currentTabIndex: 3,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[3],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          }
        })
      }
      .tabBar(this.tabsBar[3])
    }
    .barOverlap(true)
    .vertical(false)
    .onChange((index: number) => {
      this.updateTabSelection(index);
    })
    .barPosition(BarPosition.End)
    .barFloatingStyle({
      barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
        $r('sys.float.padding_level8'),
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
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

  // ==================== 平板 / PC 共用工作台 ====================

  @Builder
  private wideShell() {
    WideCaregiverWorkspace({
      currentTabIndex: this.currentTabIndex,
      primaryTabIndex: this.primaryTabIndex,
      statusBarHeight: this.globalInfoModel.statusBarHeight,
      compactWidth: BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint),
      onSwitchTab: (index: number) => {
        this.switchTab(index);
      },
      onOpenAiChat: () => {
        this.openAiChat();
      },
      onOpenAbout: () => {
        this.pathStack.pushPath({ name: 'AboutPage' });
      },
      onOpenGeneral: () => {
        this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
      },
      onLogout: () => {
        this.handleLogout();
      }
    })
  }

  @Builder
  private destinationBuilder(name: string, param?: ESObject) {
    if (name === 'AboutPage') {
      MineDetailPage({ pageType: 'about' })
    } else if (name === 'GeneralSettingsPage') {
      MineDetailPage({ pageType: 'general' })
    }
  }

  @Builder
  private aiChatCover() {
    AiChatPage({
      geometryId: 'aiReminderCard',
      onClose: () => {
        this.closeAiChat();
      }
    })
  }

  build() {
    Stack() {
      if (this.isRoleAdapted()) {
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
            menu: { value: [] },
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
        .hideTitleBar(this.isWideLayout(), true)
        .titleMode(HdsNavigationTitleMode.MINI)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .width('100%')
        .height('100%')
      } else {
        this.roleWipPanel()
      }

      if (this.isAiChatShow) {
        this.aiChatCover()
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
