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
import { HdsSideBar } from '@kit.UIDesignKit';
import { WideHomePage } from './WideHomePage';
import { WideMessagePage } from './WideMessagePage';
import { WideMinePage } from './WideMinePage';
import { WideResidentPage } from './WideResidentPage';

interface WorkspaceNavItem {
  title: string;
  subtitle: string;
  symbol: Resource;
  index: number;
  badge?: string;
}

@ComponentV2
export struct WideCaregiverWorkspace {
  @Param @Require currentTabIndex: number;
  @Param statusBarHeight: number = 0;
  @Event onSwitchTab: (index: number) => void = (_index: number) => {};
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local hoveredNavIndex: number = -1;
  @Local focusedTarget: string = '';

  private navItems: WorkspaceNavItem[] = [
    { title: '首页', subtitle: '今日工作概览', symbol: $r('sys.symbol.house_fill'), index: 0 },
    { title: '长者', subtitle: '档案与照护记录', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
    {
      title: '消息', subtitle: '通知与沟通', symbol: $r('sys.symbol.message_on_message_fill'), index: 2,
      badge: '3'
    }
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

  @Builder
  private sideBarPanel() {
    Column() {
      Column({ space: 8 }) {
        Text('工作空间')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ left: 12, bottom: 2 })

        ForEach(this.navItems, (item: WorkspaceNavItem) => {
          this.navItem(item)
        }, (item: WorkspaceNavItem) => item.index.toString())
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12 })

      Blank()
        .layoutWeight(1)

      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_secondary'))
          Text('LT')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.currentTabIndex === 3 ? $r('app.color.brand_blue') :
              $r('sys.color.font_primary'))
        }
        Column({ space: 2 }) {
          Text('刘婷')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.currentTabIndex === 3 ? $r('app.color.brand_blue') :
              $r('sys.color.font_primary'))
          Text('护工 · 白班')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width('100%')
      .height(66)
      .padding({ left: 18, right: 18 })
      .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
      .backgroundColor(this.currentTabIndex === 3 ? $r('sys.color.comp_background_primary') :
        this.focusedTarget === 'profile-entry' ? $r('sys.color.interactive_hover') : Color.Transparent)
      .alignItems(VerticalAlign.Center)
      .focusable(true)
      .focusOnTouch(true)
      .onFocus(() => this.focusedTarget = 'profile-entry')
      .onBlur(() => this.focusedTarget = '')
      .onHover((isHover: boolean) => this.focusedTarget = isHover ? 'profile-entry' : '')
      .onKeyEvent((event: KeyEvent) => {
        this.activateWithKeyboard(event, () => this.onSwitchTab(3));
      })
      .onClick(() => this.onSwitchTab(3))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private navItem(item: WorkspaceNavItem) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(item.symbol)
          .fontSize(21)
          .fontColor([this.currentTabIndex === item.index ? $r('app.color.brand_blue') :
            $r('sys.color.icon_secondary')])
      }
      .width(30)
      .height(30)

      Column({ space: 2 }) {
        Text(item.title)
          .fontSize(15)
          .fontWeight(this.currentTabIndex === item.index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.currentTabIndex === item.index ? $r('app.color.brand_blue') :
            $r('sys.color.font_primary'))
        Text(item.subtitle)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.badge) {
        Text(item.badge)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 20 })
          .height(20)
          .padding({ left: 5, right: 5 })
          .borderRadius(10)
          .backgroundColor($r('app.color.status_danger'))
      }
    }
    .width('100%')
    .height(58)
    .padding({ left: 12, right: 12 })
    .borderRadius(14)
    .backgroundColor(this.currentTabIndex === item.index ? $r('sys.color.comp_background_primary') :
      this.hoveredNavIndex === item.index ? $r('sys.color.interactive_hover') : Color.Transparent)
    .border({
      width: this.focusedTarget === `nav-${item.index}` ? 2 :
        this.currentTabIndex === item.index ? 1 : 0,
      color: $r('app.color.brand_blue')
    })
    .focusable(true)
    .focusOnTouch(true)
    .onFocus(() => this.focusedTarget = `nav-${item.index}`)
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.hoveredNavIndex = isHover ? item.index : -1)
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.onSwitchTab(item.index));
    })
    .onClick(() => this.onSwitchTab(item.index))
  }

  @Builder
  private commandBarAction(id: string, symbol: Resource, hasBadge: boolean, action: () => void) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        SymbolGlyph(symbol)
          .fontSize(20)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.focusedTarget === id ? $r('sys.color.interactive_hover') :
        $r('sys.color.comp_background_primary'))
      .border({ width: this.focusedTarget === id ? 2 : 0, color: $r('app.color.brand_blue') })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      if (hasBadge) {
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
    .focusable(true)
    .focusOnTouch(true)
    .onFocus(() => this.focusedTarget = id)
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.focusedTarget = isHover ? id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, action))
    .onClick(action)
  }

  @Builder
  private commandBar() {
    Row({ space: 16 }) {
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

      Blank()

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
        .width(280)
        .height(40)
        .padding({ left: 12, right: 8 })
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_secondary'))

        this.commandBarAction('ai-action', $r('sys.symbol.message_on_message_fill'), false,
          () => this.onOpenAiChat())
        this.commandBarAction('notification-action', $r('sys.symbol.bell'), true, () => this.onSwitchTab(2))
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(68)
    .padding({ left: 28, right: 28 })
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
    HdsSideBar({
      isShowSideBar: true,
      autoHide: false,
      sideBarContainerType: SideBarContainerType.Embed,
      sideBarWidth: 256,
      sideBarPanelBuilder: () => {
        this.sideBarPanel();
      },
      contentPanelBuilder: () => {
        this.contentPanel();
      }
    })
      .width('100%')
      .height('100%')
      .padding({ top: this.statusBarHeight })
      .backgroundColor($r('sys.color.background_secondary'))
  }
}
