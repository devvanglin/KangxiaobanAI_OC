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

import { KeyCode } from '@kit.InputKit';
import { WideHomePage } from './WideHomePage';
import { WideMessagePage } from './WideMessagePage';
import { WideMinePage } from './WideMinePage';
import { WideResidentPage } from './WideResidentPage';

interface WorkspacePrimaryNavItem {
  title: string;
  symbol: Resource;
  index: number;
}

@ComponentV2
export struct WideCaregiverWorkspace {
  @Param @Require currentTabIndex: number;
  @Param @Require primaryTabIndex: number;
  @Param statusBarHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Event onSwitchTab: (index: number) => void = (_index: number) => {};
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local hoveredNavIndex: number = -1;
  @Local focusedTarget: string = '';

  private primaryNavItems: WorkspacePrimaryNavItem[] = [
    { title: '首页', symbol: $r('sys.symbol.house_fill'), index: 0 },
    { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 }
  ];

  private pageTitle(): string {
    const titles: string[] = ['工作台', '长者管理', '消息中心', '我的'];
    return titles[this.currentTabIndex] ?? titles[0];
  }

  private pageSubtitle(): string {
    const subtitles: string[] = [
      '半山敬老院 · 白班 08:00–18:00',
      '半山敬老院 · 在院长者与照护档案',
      '半山敬老院 · 提醒、通知和工作沟通',
      '刘婷 · 护工'
    ];
    return subtitles[this.currentTabIndex] ?? subtitles[0];
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  private commandBarGap(): number {
    return this.compactWidth ? 12 : 20;
  }

  private commandBarPadding(): number {
    return this.compactWidth ? 20 : 28;
  }

  private titleAreaWidth(): number {
    return this.compactWidth ? 150 : 230;
  }

  private primaryNavigationWidth(): number {
    return this.compactWidth ? 176 : 196;
  }

  private primaryNavItemWidth(): number {
    return this.compactWidth ? 83 : 93;
  }

  private primarySelectionVisible(): boolean {
    return this.currentTabIndex === 0 || this.currentTabIndex === 1;
  }

  private primarySelectionOffset(): number {
    return this.primaryTabIndex === 1 ? this.primaryNavItemWidth() + 4 : 0;
  }

  private searchAreaWidth(): number {
    return this.compactWidth ? 180 : 280;
  }

  private commandActionAreaWidth(): number {
    return this.searchAreaWidth() + 144;
  }

  @Builder
  private primaryNavItem(item: WorkspacePrimaryNavItem) {
    Row({ space: 7 }) {
      SymbolGlyph(item.symbol)
        .fontSize(17)
        .fontColor([this.currentTabIndex === item.index ? $r('app.color.brand_blue') :
          $r('sys.color.icon_secondary')])
      Text(item.title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(this.currentTabIndex === item.index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTabIndex === item.index ? $r('app.color.brand_blue') :
          $r('sys.color.font_primary'))
    }
    .width(this.primaryNavItemWidth())
    .height(38)
    .padding({ left: 12, right: 12 })
    .borderRadius(19)
    .backgroundColor(this.currentTabIndex !== item.index && this.hoveredNavIndex === item.index ?
      $r('sys.color.interactive_hover') : Color.Transparent)
    .border({
      width: this.focusedTarget === `primary-nav-${item.index}` ? 2 : 0,
      color: $r('app.color.brand_blue')
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText(item.title)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilitySelected(this.currentTabIndex === item.index)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onFocus(() => this.focusedTarget = `primary-nav-${item.index}`)
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.hoveredNavIndex = isHover ? item.index : -1)
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.onSwitchTab(item.index));
    })
    .onClick(() => this.onSwitchTab(item.index))
  }

  @Builder
  private primaryNavigation() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(this.primaryNavItemWidth())
        .height(38)
        .borderRadius(19)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .shadow({ radius: 6, color: 'rgba(0,0,0,0.05)', offsetY: 1 })
        .translate({ x: this.primarySelectionOffset() })
        .opacity(this.primarySelectionVisible() ? 1 : 0)
        .animation({ duration: 260, curve: Curve.Friction })

      Row({ space: 4 }) {
        ForEach(this.primaryNavItems, (item: WorkspacePrimaryNavItem) => {
          this.primaryNavItem(item)
        }, (item: WorkspacePrimaryNavItem) => item.index.toString())
      }
    }
    .width(this.primaryNavigationWidth())
    .height(44)
    .padding(3)
    .borderRadius(22)
    .backgroundColor($r('sys.color.comp_background_secondary'))
  }

  @Builder
  private commandBarAction(id: string, label: string, symbol: Resource, badgeText: string,
    showDot: boolean, isActive: boolean, action: () => void) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        SymbolGlyph(symbol)
          .fontSize(20)
          .fontColor([isActive ? $r('app.color.brand_blue') : $r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.focusedTarget === id ? $r('sys.color.interactive_hover') :
        $r('sys.color.comp_background_primary'))
      .border({ width: this.focusedTarget === id ? 2 : isActive ? 1 : 0, color: $r('app.color.brand_blue') })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      if (badgeText.length > 0) {
        Text(badgeText)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 18 })
          .height(18)
          .padding({ left: 4, right: 4 })
          .borderRadius(9)
          .backgroundColor($r('app.color.status_danger'))
      } else if (showDot) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.status_danger'))
          .margin({ top: 5, right: 5 })
      }
    }
    .width(40)
    .height(40)
    .accessibilityText(label)
    .focusable(true)
    .focusOnTouch(true)
    .onFocus(() => this.focusedTarget = id)
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.focusedTarget = isHover ? id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, action))
    .onClick(action)
  }

  @Builder
  private profileAction() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.currentTabIndex === 3 ? $r('app.color.ai_feed_background') :
          $r('sys.color.comp_background_primary'))
        .border({
          width: this.focusedTarget === 'profile-action' ? 2 : this.currentTabIndex === 3 ? 1 : 0,
          color: $r('app.color.brand_blue')
        })
      Text('LT')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 3 ? $r('app.color.brand_blue') :
          $r('sys.color.font_primary'))
    }
    .width(40)
    .height(40)
    .accessibilityText('我的')
    .focusable(true)
    .focusOnTouch(true)
    .onFocus(() => this.focusedTarget = 'profile-action')
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.focusedTarget = isHover ? 'profile-action' : '')
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.onSwitchTab(3));
    })
    .onClick(() => this.onSwitchTab(3))
  }

  @Builder
  private commandBar() {
    Row({ space: this.commandBarGap() }) {
      Column({ space: 3 }) {
        Text(this.pageTitle())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.pageSubtitle())
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .width(this.titleAreaWidth())

      this.primaryNavigation()

      Blank()
        .layoutWeight(1)

      Row({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(17)
            .fontColor([$r('sys.color.icon_secondary')])
          TextInput({ placeholder: '搜索长者、消息或服务记录' })
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor(Color.Transparent)
        }
        .width(this.searchAreaWidth())
        .height(40)
        .padding({ left: 12, right: 8 })
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_secondary'))

        this.commandBarAction('message-action', '消息', $r('sys.symbol.message_on_message_fill'), '3', false,
          this.currentTabIndex === 2, () => this.onSwitchTab(2))
        this.commandBarAction('notification-action', '通知', $r('sys.symbol.bell'), '', true,
          false, () => this.onSwitchTab(2))
        this.profileAction()
      }
      .width(this.commandActionAreaWidth())
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(68 + this.statusBarHeight)
    .padding({
      left: this.commandBarPadding(),
      right: this.commandBarPadding(),
      top: this.statusBarHeight
    })
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
    .backgroundColor($r('sys.color.background_secondary'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private currentPage() {
    if (this.currentTabIndex === 0) {
      WideHomePage({
        onOpenAiChat: () => this.onOpenAiChat()
      })
    } else if (this.currentTabIndex === 1) {
      WideResidentPage()
    } else if (this.currentTabIndex === 2) {
      WideMessagePage()
    } else {
      WideMinePage({
        onOpenAbout: () => this.onOpenAbout(),
        onOpenGeneral: () => this.onOpenGeneral(),
        onLogout: () => this.onLogout()
      })
    }
  }

  @Builder
  private contentPanel() {
    Column() {
      this.commandBar()
      Column() {
        this.currentPage()
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('sys.color.background_secondary'))
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      this.contentPanel()
    }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
  }
}
