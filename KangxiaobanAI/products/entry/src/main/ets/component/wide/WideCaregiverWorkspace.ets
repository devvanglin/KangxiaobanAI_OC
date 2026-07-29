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

interface CaregiverNavigationItem {
  id: string;
  title: string;
  description: string;
  symbol: Resource;
  tabIndex: number;
}

type CaregiverShiftState = 'pending' | 'working' | 'done';

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
  @Local shiftState: CaregiverShiftState = 'pending';
  @Local completedTaskCount: number = 4;
  @Local totalTaskCount: number = 10;
  @Local generalSettingsIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.gearshape'))
    .fontSize(18)
    .fontColor([$r('sys.color.icon_primary')]);
  @Local aboutIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.info_circle'))
    .fontSize(18)
    .fontColor([$r('sys.color.icon_primary')]);
  @Local logoutIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontSize(18)
    .fontColor([$r('app.color.status_danger')]);

  private navigationItems: CaregiverNavigationItem[] = [
    {
      id: 'home-navigation',
      title: '首页',
      description: '查看当班照护与今日重点',
      symbol: $r('sys.symbol.house_fill'),
      tabIndex: 0
    },
    {
      id: 'resident-navigation',
      title: '长者',
      description: '查看长者状态与照护档案',
      symbol: $r('sys.symbol.person_2_fill'),
      tabIndex: 1
    },
    {
      id: 'message-navigation',
      title: '消息',
      description: '处理交接、家属沟通与通知',
      symbol: $r('sys.symbol.message_on_message_fill'),
      tabIndex: 2
    }
  ];

  private activeTabIndex(): number {
    if (this.currentTabIndex >= 0 && this.currentTabIndex <= 2) {
      return this.currentTabIndex;
    }
    return this.primaryTabIndex >= 0 && this.primaryTabIndex <= 1 ? this.primaryTabIndex : 0;
  }

  private pageTitle(): string {
    const titles: string[] = ['工作台', '长者管理', '消息中心'];
    return titles[this.activeTabIndex()] ?? titles[0];
  }

  private sidebarWidth(): number {
    return this.compactWidth ? 84 : 224;
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

  private updateShiftState(isClockedIn: boolean, isClockedOut: boolean): void {
    if (isClockedOut) {
      this.shiftState = 'done';
    } else if (isClockedIn) {
      this.shiftState = 'working';
    } else {
      this.shiftState = 'pending';
    }
  }

  private updateTaskProgress(completed: number, total: number): void {
    this.completedTaskCount = Math.max(0, completed);
    this.totalTaskCount = Math.max(0, total);
  }

  private shiftStatusText(): string {
    if (this.shiftState === 'done') {
      return '已完成';
    }
    if (this.shiftState === 'working') {
      return '在岗';
    }
    return '待打卡';
  }

  private shiftStatusColor(): ResourceColor {
    return this.shiftState === 'pending' ? $r('sys.color.icon_secondary') : $r('app.color.status_normal');
  }

  private taskProgressPercent(): number {
    if (this.totalTaskCount <= 0) {
      return 0;
    }
    return Math.round(this.completedTaskCount / this.totalTaskCount * 100);
  }

  private taskProgressWidth(): string {
    return this.taskProgressPercent().toString() + '%';
  }

  private remainingTaskCount(): number {
    return Math.max(0, this.totalTaskCount - this.completedTaskCount);
  }

  @Builder
  private brandHeader() {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.heart_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.text_on_brand')])
      }
      .width(36)
      .height(36)
      .borderRadius(12)
      .backgroundColor($r('app.color.brand_blue'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      if (!this.compactWidth) {
        Column({ space: 2 }) {
          Text($r('app.string.caregiver_workspace_brand'))
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('智慧照护工作台')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height(68 + this.statusBarHeight)
    .padding({
      left: this.compactWidth ? 22 : 18,
      right: this.compactWidth ? 22 : 18,
      top: this.statusBarHeight
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private navigationItem(item: CaregiverNavigationItem) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: this.compactWidth ? 0 : 12 }) {
        Row() {
          SymbolGlyph(item.symbol)
            .fontSize(20)
            .fontColor([this.isActiveTab(item.tabIndex) ? $r('app.color.brand_blue') :
              $r('sys.color.icon_secondary')])
        }
        .width(36)
        .height(36)
        .borderRadius(11)
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        if (!this.compactWidth) {
          Text(item.title)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(this.isActiveTab(item.tabIndex) ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.isActiveTab(item.tabIndex) ? $r('app.color.brand_blue') :
              $r('sys.color.font_secondary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .maxLines(1)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.compactWidth ? 8 : 10, right: this.compactWidth ? 8 : 12 })
      .justifyContent(this.compactWidth ? FlexAlign.Center : FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width(this.compactWidth ? 52 : 'calc(100% - 28vp)')
    .height(50)
    .margin({ left: this.compactWidth ? 16 : 14, right: this.compactWidth ? 16 : 14 })
    .borderRadius(16)
    .backgroundColor(this.targetBackground(item.id, this.isActiveTab(item.tabIndex)))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(`${item.title}，${item.description}`)
    .accessibilitySelected(this.isActiveTab(item.tabIndex))
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? item.id : '')
    .onClick(() => this.switchWorkspaceTab(item.tabIndex))
  }

  @Builder
  private primaryNavigation() {
    Column({ space: 4 }) {
      ForEach(this.navigationItems, (item: CaregiverNavigationItem) => {
        this.navigationItem(item)
      }, (item: CaregiverNavigationItem) => item.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private aiEntry() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: this.compactWidth ? 0 : 12 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.AI_message'))
            .fontSize(20)
            .fontColor([$r('app.color.brand_blue')])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        if (!this.compactWidth) {
          Text('AI 助手')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textAlign(TextAlign.Start)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.compactWidth ? 8 : 10, right: this.compactWidth ? 8 : 12 })
      .justifyContent(this.compactWidth ? FlexAlign.Center : FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width(this.compactWidth ? 52 : 'calc(100% - 28vp)')
    .height(this.compactWidth ? 52 : 50)
    .margin({ left: this.compactWidth ? 16 : 14, right: this.compactWidth ? 16 : 14 })
    .borderRadius(16)
    .backgroundColor(this.targetBackground('ai-entry', false))
    .hoverEffect(HoverEffect.None)
    .accessibilityText('打开 AI 助手，获取照护建议与工作问答')
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? 'ai-entry' : '')
    .onClick(() => this.onOpenAiChat())
  }

  @Builder
  private shiftCard() {
    if (this.compactWidth) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Row() {
          SymbolGlyph($r('sys.symbol.calendar_badge_clock'))
            .fontSize(21)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(48)
        .height(48)
        .borderRadius(14)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Row()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.shiftStatusColor())
          .border({ width: 2, color: $r('sys.color.background_secondary') })
      }
      .width(48)
      .height(48)
      .accessibilityText('当前早班，时间 07:30 至 16:00，' + this.shiftStatusText())
    } else {
      Column({ space: 10 }) {
        Row({ space: 6 }) {
          Text('当前班次')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          Row()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.shiftStatusColor())
          Text(this.shiftStatusText())
            .fontSize($r('sys.float.Caption_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.shiftStatusColor())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('早班 · 07:30–16:00')
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(4)
            .borderRadius(2)
            .backgroundColor($r('sys.color.comp_background_secondary'))
          Row()
            .width(this.taskProgressWidth())
            .height(4)
            .borderRadius(2)
            .backgroundColor($r('app.color.brand_blue'))
        }
        .width('100%')
        .height(4)

        Text('已完成 ' + this.completedTaskCount + ' / ' + this.totalTaskCount + ' 项工作')
          .width('100%')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('calc(100% - 28vp)')
      .padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .alignItems(HorizontalAlign.Start)
      .accessibilityText('当前早班，时间 07:30 至 16:00，' + this.shiftStatusText() + '，已完成 ' +
        this.completedTaskCount + ' 项，共 ' + this.totalTaskCount + ' 项')
    }
  }

  @Builder
  private profileMetric(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private profileMenuHeader() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(46)
            .height(46)
            .borderRadius(23)
            .backgroundColor($r('app.color.ai_feed_background'))
          Text('LT')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
        }

        Column({ space: 3 }) {
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
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 5 }) {
          Row()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.shiftStatusColor())
          Text(this.shiftStatusText())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.shiftStatusColor())
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        Row() {
          Text('当前班次')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          Text('早班 · 07:30–16:00')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(5)
            .borderRadius(3)
            .backgroundColor($r('sys.color.comp_background_secondary'))
          Row()
            .width(this.taskProgressWidth())
            .height(5)
            .borderRadius(3)
            .backgroundColor($r('app.color.brand_blue'))
        }
        .width('100%')
        .height(5)

        Row() {
          Text('已完成 ' + this.completedTaskCount + ' 项')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
          Blank()
          Text('剩余 ' + this.remainingTaskCount() + ' 项')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
      }
      .width('100%')
      .padding(12)
      .borderRadius(12)
      .backgroundColor($r('sys.color.comp_background_secondary'))

      Row() {
        this.profileMetric('28', '负责长者')
        Divider()
          .vertical(true)
          .height(32)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.profileMetric(this.taskProgressPercent() + '%', '班次完成')
      }
      .width('100%')
      .height(48)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 8 })
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
    .width(320)
    .radius(16)
  }

  @Builder
  private sidebarAccount() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: this.compactWidth ? 0 : 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(38)
            .height(38)
            .borderRadius(19)
            .backgroundColor($r('app.color.ai_feed_background'))
          Text('LT')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
        }
        .width(38)
        .height(38)

        if (!this.compactWidth) {
          Column({ space: 2 }) {
            Text('刘婷')
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
            Text('护工 · ' + this.shiftStatusText())
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(13)
            .fontColor([$r('sys.color.icon_tertiary')])
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.compactWidth ? 7 : 10, right: this.compactWidth ? 7 : 10 })
      .justifyContent(this.compactWidth ? FlexAlign.Center : FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width(this.compactWidth ? 52 : 'calc(100% - 28vp)')
    .height(56)
    .padding(0)
    .margin({ left: this.compactWidth ? 16 : 14, right: this.compactWidth ? 16 : 14 })
    .borderRadius(16)
    .backgroundColor(this.targetBackground('sidebar-account', false))
    .hoverEffect(HoverEffect.None)
    .accessibilityText('刘婷，护工，当前' + this.shiftStatusText() + '，打开账户菜单')
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? 'sidebar-account' : '')
    .bindMenu(this.profileMenu, {
      placement: Placement.RightBottom,
      enableArrow: true,
      offset: { x: 0, y: 8 }
    })
    .bindContextMenu(this.profileMenu, ResponseType.RightClick, {
      placement: Placement.RightBottom,
      enableArrow: true,
      offset: { x: 0, y: 8 }
    })
  }

  @Builder
  private commandBarAction(id: string, label: string, symbol: Resource, showDot: boolean,
    isActive: boolean, action: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Row() {
          SymbolGlyph(symbol)
            .fontSize(20)
            .fontColor([isActive ? $r('app.color.brand_blue') : $r('sys.color.icon_primary')])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        if (showDot) {
          Row()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor($r('app.color.status_danger'))
            .border({ width: 1.5, color: $r('sys.color.background_secondary') })
            .margin({ top: 4, right: 4 })
        }
      }
      .width(40)
      .height(40)
    }
    .width(40)
    .height(40)
    .padding(0)
    .borderRadius(20)
    .backgroundColor(this.targetBackground(id, isActive))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .accessibilitySelected(isActive)
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? id : '')
    .onClick(action)
  }

  @Builder
  private workStatusChip() {
    Row({ space: 7 }) {
      Row()
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(this.shiftStatusColor())
      Text('早班 · ' + this.shiftStatusText())
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
    }
    .height(36)
    .padding({ left: 13, right: 13 })
    .borderRadius(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .alignItems(VerticalAlign.Center)
    .accessibilityText('当前早班，' + this.shiftStatusText())
  }

  @Builder
  private commandBar() {
    Row({ space: 12 }) {
      Text(this.pageTitle())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)

      if (!this.compactWidth) {
        this.workStatusChip()
      }

      this.commandBarAction('notification-action', '打开消息中心', $r('sys.symbol.bell'),
        !this.isActiveTab(2), this.isActiveTab(2), () => this.switchWorkspaceTab(2))
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
  private sidebar() {
    Column({ space: 0 }) {
      this.brandHeader()

      Column({ space: 12 }) {
        this.primaryNavigation()
        this.aiEntry()
      }
      .width('100%')
      .padding({ top: 12 })
      .alignItems(HorizontalAlign.Center)

      Blank()
        .layoutWeight(1)

      Column({ space: 12 }) {
        if (this.compactWidth) {
          this.shiftCard()
        }
        this.sidebarAccount()
      }
      .width('100%')
      .padding({ bottom: 16 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Center)
    }
    .width(this.sidebarWidth())
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private persistentPages() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        WideHomePage({
          compactWidth: this.compactWidth,
          backRequestToken: this.homeBackRequestToken,
          onOpenAiChat: () => this.onOpenAiChat(),
          onOpenResident: (residentId: string) => this.openResident(residentId),
          onTaskPanelVisibilityChange: (visible: boolean) => this.updateLocalLayer(0, visible),
          onShiftStateChange: (isClockedIn: boolean, isClockedOut: boolean) =>
            this.updateShiftState(isClockedIn, isClockedOut),
          onTaskProgressChange: (completed: number, total: number) => this.updateTaskProgress(completed, total)
        })
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: this.naviIndicatorHeight })
      .visibility(this.pageVisibility(0))
      .zIndex(this.isActiveTab(0) ? 1 : 0)

      Column() {
        WideResidentPage({
          compactWidth: this.compactWidth,
          backRequestToken: this.residentBackRequestToken,
          requestedResidentId: this.requestedResidentId,
          residentSelectionRequestToken: this.residentSelectionRequestToken,
          onLocalDetailVisibilityChange: (visible: boolean) => this.updateLocalLayer(1, visible)
        })
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: this.naviIndicatorHeight })
      .visibility(this.pageVisibility(1))
      .zIndex(this.isActiveTab(1) ? 1 : 0)

      Column() {
        WideMessagePage({
          compactWidth: this.compactWidth,
          backRequestToken: this.messageBackRequestToken,
          onLocalDetailVisibilityChange: (visible: boolean) => this.updateLocalLayer(2, visible)
        })
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: this.naviIndicatorHeight })
      .visibility(this.pageVisibility(2))
      .zIndex(this.isActiveTab(2) ? 1 : 0)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private contentPanel() {
    Column({ space: 0 }) {
      this.commandBar()
      Column() {
        this.persistentPages()
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('sys.color.background_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
  }

  build() {
    Row({ space: 0 }) {
      this.sidebar()
      this.contentPanel()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
