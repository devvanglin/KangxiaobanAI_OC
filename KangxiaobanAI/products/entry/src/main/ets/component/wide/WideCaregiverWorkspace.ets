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
import { KeyCode } from '@kit.InputKit';
import { WideHomePage } from './WideHomePage';
import { WideMessagePage } from './WideMessagePage';
import { WideResidentPage } from './WideResidentPage';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

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
  @Local focusedTarget: string = '';
  @Local generalSettingsIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.gearshape'))
    .fontSize(18)
    .fontColor([$r('sys.color.icon_primary')]);
  @Local aboutIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.info_circle'))
    .fontSize(18)
    .fontColor([$r('sys.color.icon_primary')]);
  @Local logoutIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontSize(18)
    .fontColor([$r('app.color.status_danger')]);

  private primaryNavItems: WideSlidingCapsuleItem[] = [
    { title: '首页', symbol: $r('sys.symbol.house_fill'), index: 0 },
    { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 }
  ];

  private activeTabIndex(): number {
    return this.currentTabIndex >= 0 && this.currentTabIndex <= 2 ? this.currentTabIndex : 0;
  }

  private pageTitle(): string {
    const titles: string[] = ['工作台', '长者管理', '消息中心'];
    return titles[this.activeTabIndex()] ?? titles[0];
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

  private primaryNavItemWidth(): number {
    return this.compactWidth ? 83 : 93;
  }

  private primaryCapsuleIndex(): number {
    return this.activeTabIndex() === 0 || this.activeTabIndex() === 1 ? this.primaryTabIndex : -1;
  }

  private searchAreaWidth(): number {
    return this.compactWidth ? 180 : 280;
  }

  private commandActionAreaWidth(): number {
    return this.searchAreaWidth() + 144;
  }

  @Builder
  private primaryNavigation() {
    WideSlidingCapsule({
      items: this.primaryNavItems,
      selectedIndex: this.primaryCapsuleIndex(),
      itemWidth: this.primaryNavItemWidth(),
      onSelect: (index: number) => {
        this.onSwitchTab(index);
      }
    })
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
            .backgroundColor($r('app.color.status_normal'))
          Text('在岗')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.status_normal'))
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
            .width('62%')
            .height(5)
            .borderRadius(3)
            .backgroundColor($r('app.color.brand_blue'))
        }
        .width('100%')
        .height(5)

        Row() {
          Text('已完成 5 小时 16 分')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
          Blank()
          Text('剩余 3 小时 14 分')
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
        this.profileMetric('92%', '班次完成')
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
  private profileAction() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.focusedTarget === 'profile-action' ? $r('sys.color.interactive_hover') :
          $r('sys.color.comp_background_primary'))
        .border({
          width: this.focusedTarget === 'profile-action' ? 2 : 0,
          color: $r('app.color.brand_blue')
        })
      Text('LT')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.focusedTarget === 'profile-action' ? $r('app.color.brand_blue') :
          $r('sys.color.font_primary'))
    }
    .width(40)
    .height(40)
    .accessibilityText('账户菜单，左键或右键打开')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onFocus(() => this.focusedTarget = 'profile-action')
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.focusedTarget = isHover ? 'profile-action' : '')
    .bindMenu(this.profileMenu, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 12, y: 0 }
    })
    .bindContextMenu(this.profileMenu, ResponseType.RightClick, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 12, y: 0 }
    })
  }

  @Builder
  private commandBar() {
    Row({ space: this.commandBarGap() }) {
      Column() {
        Text(this.pageTitle())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
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
          this.activeTabIndex() === 2, () => this.onSwitchTab(2))
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
    if (this.activeTabIndex() === 0) {
      WideHomePage({
        onOpenAiChat: () => this.onOpenAiChat()
      })
    } else if (this.activeTabIndex() === 1) {
      WideResidentPage()
    } else {
      WideMessagePage()
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
