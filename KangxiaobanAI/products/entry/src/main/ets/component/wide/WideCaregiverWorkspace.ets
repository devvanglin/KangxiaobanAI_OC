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

import { SymbolGlyphModifier } from '@kit.ArkUI';
import { WideHomePage } from './WideHomePage';
import { WideMessagePage } from './WideMessagePage';
import { WideResidentPage } from './WideResidentPage';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

@ComponentV2
export struct WideCaregiverWorkspace {
  @Param @Require currentTabIndex: number;
  @Param @Require primaryTabIndex: number;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Param backRequestToken: number = 0;
  @Event onSwitchTab: (index: number) => void = (_index: number) => {};
  @Event onLocalBackStateChange: (hasLocalLayer: boolean) => void = (_hasLocalLayer: boolean) => {};
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local hoveredTarget: string = '';
  @Local homeTaskPanelVisible: boolean = false;
  @Local residentDetailVisible: boolean = false;
  @Local messageDetailVisible: boolean = false;
  @Local homeBackRequestToken: number = 0;
  @Local residentBackRequestToken: number = 0;
  @Local messageBackRequestToken: number = 0;
  @Local requestedResidentId: string = '';
  @Local residentSelectionRequestToken: number = 0;
  @Local unreadMessageCount: number = 3;
  @Local generalSettingsIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.gearshape'))
    .fontSize(18)
    .fontColor([$r('sys.color.icon_primary')]);
  @Local aboutIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.info_circle'))
    .fontSize(18)
    .fontColor([$r('sys.color.icon_primary')]);
  @Local logoutIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontSize(18)
    .fontColor([$r('app.color.status_danger')]);

  private navigationItems(): WideSlidingCapsuleItem[] {
    return [
      { title: '首页', symbol: $r('sys.symbol.house_fill'), index: 0 },
      { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
      {
        title: '消息',
        symbol: $r('sys.symbol.message_on_message_fill'),
        index: 2,
        badgeText: this.unreadMessageCount > 0 ? this.unreadMessageCount.toString() : undefined,
        badgeTextColor: $r('app.color.text_on_brand'),
        badgeBackgroundColor: $r('app.color.status_danger'),
        badgeAtCorner: true
      }
    ];
  }

  private activeTabIndex(): number {
    if (this.currentTabIndex >= 0 && this.currentTabIndex <= 2) {
      return this.currentTabIndex;
    }
    return this.primaryTabIndex >= 0 && this.primaryTabIndex <= 1 ? this.primaryTabIndex : 0;
  }

  private pageTitle(): string {
    const titles: string[] = ['首页', '长者管理', '消息中心'];
    return titles[this.activeTabIndex()] ?? titles[0];
  }

  private commandBarPadding(): number {
    return this.compactWidth ? 16 : 24;
  }

  private isActiveTab(index: number): boolean {
    return this.activeTabIndex() === index;
  }

  private targetBackground(id: string, active: boolean): ResourceColor {
    if (active) {
      return $r('sys.color.comp_background_primary');
    }
    if (this.hoveredTarget === id) {
      return $r('sys.color.interactive_hover');
    }
    return $r('sys.color.ohos_id_color_background_transparent');
  }

  private pageVisibility(index: number): Visibility {
    return this.isActiveTab(index) ? Visibility.Visible : Visibility.Hidden;
  }

  @Monitor('currentTabIndex', 'primaryTabIndex', 'compactWidth')
  onWorkspaceContextChange(): void {
    this.reportActiveLocalBackState();
  }

  aboutToAppear(): void {
    this.reportActiveLocalBackState();
  }

  aboutToDisappear(): void {
    this.onLocalBackStateChange(false);
  }

  @Monitor('backRequestToken')
  onBackRequestTokenChange(): void {
    const activeIndex: number = this.activeTabIndex();
    if (activeIndex === 0) {
      this.homeBackRequestToken += 1;
    } else if (activeIndex === 1) {
      this.residentBackRequestToken += 1;
    } else if (activeIndex === 2) {
      this.messageBackRequestToken += 1;
    }
  }

  private hasLocalLayerForTab(index: number): boolean {
    if (index === 0) {
      return this.homeTaskPanelVisible;
    }
    if (index === 1) {
      return this.compactWidth && this.residentDetailVisible;
    }
    if (index === 2) {
      return this.compactWidth && this.messageDetailVisible;
    }
    return false;
  }

  private reportActiveLocalBackState(): void {
    this.onLocalBackStateChange(this.hasLocalLayerForTab(this.activeTabIndex()));
  }

  private updateLocalLayer(tabIndex: number, visible: boolean): void {
    if (tabIndex === 0) {
      this.homeTaskPanelVisible = visible;
    } else if (tabIndex === 1) {
      this.residentDetailVisible = visible;
    } else if (tabIndex === 2) {
      this.messageDetailVisible = visible;
    }
    if (this.activeTabIndex() === tabIndex) {
      this.reportActiveLocalBackState();
    }
  }

  private switchWorkspaceTab(index: number): void {
    this.onLocalBackStateChange(this.hasLocalLayerForTab(index));
    this.onSwitchTab(index);
  }

  private openResident(residentId: string): void {
    this.requestedResidentId = residentId;
    this.residentSelectionRequestToken += 1;
    this.switchWorkspaceTab(1);
  }

  @Builder
  private commandBarIdentity() {
    Row() {
      Text(this.pageTitle())
        .fontSize(this.compactWidth ? 19 : 22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .layoutWeight(1)
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private primaryNavigation() {
    Row() {
      WideSlidingCapsule({
        items: this.navigationItems(),
        selectedIndex: this.activeTabIndex(),
        itemWidth: this.compactWidth ? 96 : 104,
        onSelect: (index: number) => this.switchWorkspaceTab(index)
      })
    }
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private aiEntry() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: this.compactWidth ? 0 : 7 }) {
        SymbolGlyph($r('sys.symbol.AI_message'))
          .fontSize(20)
          .fontColor([$r('app.color.brand_blue')])

        if (!this.compactWidth) {
          Text('AI 助手')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
            .maxLines(1)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.compactWidth ? 0 : 12, right: this.compactWidth ? 0 : 12 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width(this.compactWidth ? 48 : 92)
    .height(48)
    .padding(0)
    .borderRadius(24)
    .backgroundColor(this.targetBackground('ai-entry', false))
    .hoverEffect(HoverEffect.None)
    .accessibilityText('打开 AI 助手，获取照护建议与工作问答')
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? 'ai-entry' : '')
    .onClick(() => this.onOpenAiChat())
  }

  @Builder
  private profileMenuHeader() {
    Column({ space: 4 }) {
      Row({ space: 7 }) {
        Text('刘婷')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text('L3')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
          .backgroundColor($r('sys.color.comp_background_secondary'))
      }
      .alignItems(VerticalAlign.Center)

      Text('阳光护士（2024） · 护工')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private profileMenu() {
    Menu() {
      MenuItemGroup({ header: this.profileMenuHeader }) {
        MenuItem({
          symbolStartIcon: this.generalSettingsIcon,
          content: '通用设置'
        })
          .height(46)
          .contentFont({ size: 14, weight: FontWeight.Medium })
          .onClick(() => this.onOpenGeneral())

        MenuItem({
          symbolStartIcon: this.aboutIcon,
          content: '关于我们'
        })
          .height(46)
          .contentFont({ size: 14, weight: FontWeight.Medium })
          .onClick(() => this.onOpenAbout())
      }

      MenuItemGroup() {
        MenuItem({
          symbolStartIcon: this.logoutIcon,
          content: '退出登录'
        })
          .height(46)
          .contentFont({ size: 14, weight: FontWeight.Medium })
          .contentFontColor($r('app.color.status_danger'))
          .onClick(() => this.onLogout())
      }
    }
    .width(280)
    .radius(16)
  }

  @Builder
  private accountEntry() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor($r('app.color.brand_blue'))
        Text('LT')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
      }
      .width(34)
      .height(34)
    }
    .width(48)
    .height(48)
    .padding(0)
    .borderRadius(24)
    .backgroundColor(this.targetBackground('account-entry', false))
    .hoverEffect(HoverEffect.None)
    .accessibilityText('刘婷，护工，打开账户菜单')
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? 'account-entry' : '')
    .bindMenu(this.profileMenu, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 0, y: 8 }
    })
    .bindContextMenu(this.profileMenu, ResponseType.RightClick, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 0, y: 8 }
    })
  }

  @Builder
  private commandBar() {
    Row({ space: 10 }) {
      this.commandBarIdentity()

      Row({ space: 6 }) {
        this.primaryNavigation()
        this.aiEntry()
        this.accountEntry()
      }
      .height(48)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(68 + this.statusBarHeight)
    .padding({
      left: this.commandBarPadding(),
      right: this.commandBarPadding(),
      top: this.statusBarHeight
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private persistentPages() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        WideHomePage({
          compactWidth: this.compactWidth,
          naviIndicatorHeight: this.naviIndicatorHeight,
          backRequestToken: this.homeBackRequestToken,
          onOpenAiChat: () => this.onOpenAiChat(),
          onOpenResident: (residentId: string) => this.openResident(residentId),
          onTaskPanelVisibilityChange: (visible: boolean) => this.updateLocalLayer(0, visible)
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.pageVisibility(0))
      .zIndex(this.isActiveTab(0) ? 1 : 0)

      Column() {
        WideResidentPage({
          compactWidth: this.compactWidth,
          naviIndicatorHeight: this.naviIndicatorHeight,
          backRequestToken: this.residentBackRequestToken,
          requestedResidentId: this.requestedResidentId,
          residentSelectionRequestToken: this.residentSelectionRequestToken,
          onLocalDetailVisibilityChange: (visible: boolean) => this.updateLocalLayer(1, visible)
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.pageVisibility(1))
      .zIndex(this.isActiveTab(1) ? 1 : 0)

      Column() {
        WideMessagePage({
          compactWidth: this.compactWidth,
          naviIndicatorHeight: this.naviIndicatorHeight,
          backRequestToken: this.messageBackRequestToken,
          onLocalDetailVisibilityChange: (visible: boolean) => this.updateLocalLayer(2, visible),
          onUnreadCountChange: (count: number) => this.unreadMessageCount = count
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.pageVisibility(2))
      .zIndex(this.isActiveTab(2) ? 1 : 0)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    Column({ space: 0 }) {
      this.commandBar()
      Column() {
        this.persistentPages()
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('sys.color.background_secondary'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
