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

import { ColorMetrics, LengthMetrics } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';

interface WideMineQuickAction {
  id: string;
  icon: Resource;
  label: string;
  description: string;
}

interface WideMineSettingItem {
  id: string;
  icon: Resource;
  label: string;
  value: string;
}

@ComponentV2
export struct WideMinePage {
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local hoveredQuickActionId: string = '';
  @Local focusedQuickActionId: string = '';
  @Local hoveredSettingId: string = '';
  @Local focusedSettingId: string = '';
  @Local hoveredLogout: boolean = false;
  @Local focusedLogout: boolean = false;

  private quickActions(): WideMineQuickAction[] {
    return [
      {
        id: 'training',
        icon: $r('sys.symbol.paintpalette'),
        label: '培训学习',
        description: '本月 12 小时'
      },
      {
        id: 'schedule',
        icon: $r('sys.symbol.calendar_badge_clock'),
        label: '排班表',
        description: '查看本周班次'
      },
      {
        id: 'records',
        icon: $r('sys.symbol.doc_text'),
        label: '服务记录',
        description: '今日已完成 18 条'
      },
      {
        id: 'help',
        icon: $r('sys.symbol.questionmark_circle'),
        label: '帮助中心',
        description: '常见问题与支持'
      }
    ];
  }

  private accountSettingItems(): WideMineSettingItem[] {
    return [
      {
        id: 'security',
        icon: $r('sys.symbol.lock'),
        label: '账号安全',
        value: 'L3 权限'
      },
      {
        id: 'notification',
        icon: $r('sys.symbol.bell'),
        label: '通知提醒',
        value: '关键提醒'
      },
      {
        id: 'devices',
        icon: $r('sys.symbol.share'),
        label: '登录设备',
        value: '2 台'
      }
    ];
  }

  private applicationSettingItems(): WideMineSettingItem[] {
    return [
      {
        id: 'about',
        icon: $r('sys.symbol.info_circle'),
        label: '关于我们',
        value: ''
      },
      {
        id: 'general',
        icon: $r('sys.symbol.gearshape'),
        label: '通用设置',
        value: ''
      }
    ];
  }

  private quickActionBackground(itemId: string): ResourceColor {
    if (itemId === this.hoveredQuickActionId || itemId === this.focusedQuickActionId) {
      return $r('sys.color.interactive_hover');
    }
    return $r('sys.color.ohos_id_color_background_transparent');
  }

  private settingBackground(itemId: string): ResourceColor {
    if (itemId === this.hoveredSettingId || itemId === this.focusedSettingId) {
      return $r('sys.color.interactive_hover');
    }
    return $r('sys.color.ohos_id_color_background_transparent');
  }

  private openSetting(itemId: string): void {
    if (itemId === 'about') {
      this.onOpenAbout();
    } else if (itemId === 'general') {
      this.onOpenGeneral();
    }
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  @Builder
  private identityOverview() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(62)
          .height(62)
          .borderRadius(31)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        Text('LT')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_blue'))
      }

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text('刘婷')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('L3')
            .fontSize($r('sys.float.Caption_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(0xFFEAF1FF)
            .borderRadius(6)
        }
        .alignItems(VerticalAlign.Center)

        Text('阳光护士（2024）')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('康养中心 · 护理一组')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private shiftOverview() {
    Column({ space: 8 }) {
      Row() {
        Text('当前班次')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('在岗')
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.status_normal'))
      }
      .width('100%')

      Text('早班 · 07:30 - 16:00')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

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
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        Text('剩余 3 小时 14 分')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private summaryStat(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private workOverview() {
    Column({ space: 4 }) {
      Text('本月工作')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')

      Row({ space: 0 }) {
        this.summaryStat('28', '负责长者')
        Divider()
          .vertical(true)
          .height(30)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.summaryStat('92%', '班次完成')
      }
      .width('100%')

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Row({ space: 0 }) {
        this.summaryStat('4.9', '服务评分')
        Divider()
          .vertical(true)
          .height(30)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.summaryStat('12h', '培训时长')
      }
      .width('100%')
    }
    .layoutWeight(1.15)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private overviewCard() {
    Row({ space: 20 }) {
      this.identityOverview()

      Divider()
        .vertical(true)
        .height(104)
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      this.shiftOverview()

      Divider()
        .vertical(true)
        .height(104)
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      this.workOverview()
    }
    .width('100%')
    .height(158)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private quickActionItem(item: WideMineQuickAction) {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph(item.icon)
          .fontSize(22)
          .fontColor([$r('app.color.brand_blue')])
      }
      .width(40)
      .height(40)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_secondary'))

      Column({ space: 3 }) {
        Text(item.label)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
        Text(item.description)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .layoutWeight(1)
    .height(72)
    .padding({ left: 12, right: 12 })
    .borderRadius(10)
    .backgroundColor(this.quickActionBackground(item.id))
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(-2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
    .onHover((isHover: boolean) => {
      this.hoveredQuickActionId = isHover ? item.id : '';
    })
    .onFocus(() => {
      this.focusedQuickActionId = item.id;
    })
    .onBlur(() => {
      if (this.focusedQuickActionId === item.id) {
        this.focusedQuickActionId = '';
      }
    })
  }

  @Builder
  private quickActionsCard() {
    Column({ space: 2 }) {
      Row() {
        Text('常用功能')
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('工作入口')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 15, bottom: 4 })

      Row({ space: 4 }) {
        ForEach(this.quickActions(), (item: WideMineQuickAction) => {
          this.quickActionItem(item)
        }, (item: WideMineQuickAction) => item.id)
      }
      .width('100%')
      .padding({ left: 6, right: 6, bottom: 8 })
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private settingRow(item: WideMineSettingItem, isLast: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Row() {
          SymbolGlyph(item.icon)
            .fontSize(19)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(34)
        .height(34)
        .borderRadius(9)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_secondary'))

        Text(item.label)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        if (item.value !== '') {
          Text(item.value)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })

      if (!isLast) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
          .margin({ left: 62, right: 16 })
      }
    }
    .width('100%')
    .backgroundColor(this.settingBackground(item.id))
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(-2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
    .onHover((isHover: boolean) => {
      this.hoveredSettingId = isHover ? item.id : '';
    })
    .onFocus(() => {
      this.focusedSettingId = item.id;
    })
    .onBlur(() => {
      if (this.focusedSettingId === item.id) {
        this.focusedSettingId = '';
      }
    })
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.openSetting(item.id));
    })
    .onClick(() => {
      this.openSetting(item.id);
    })
  }

  @Builder
  private logoutRow() {
    Column({ space: 0 }) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 62, right: 16 })

      Row({ space: 12 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(19)
            .fontColor([$r('app.color.status_danger')])
        }
        .width(34)
        .height(34)
        .borderRadius(9)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.status_danger_bg'))

        Text('退出登录')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.status_danger'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor(this.hoveredLogout || this.focusedLogout ? $r('sys.color.interactive_hover') :
      $r('sys.color.ohos_id_color_background_transparent'))
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(-2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.numeric(0xFF1D63ED)
    })
    .onHover((isHover: boolean) => {
      this.hoveredLogout = isHover;
    })
    .onFocus(() => {
      this.focusedLogout = true;
    })
    .onBlur(() => {
      this.focusedLogout = false;
    })
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.onLogout());
    })
    .onClick(() => {
      this.onLogout();
    })
  }

  @Builder
  private settingGroup(title: string, description: string, items: WideMineSettingItem[], showLogout: boolean) {
    Column({ space: 0 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(description)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height(62)
      .padding({ left: 18, right: 18 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      ForEach(items, (item: WideMineSettingItem, index: number) => {
        this.settingRow(item, index === items.length - 1)
      }, (item: WideMineSettingItem) => item.id)

      if (showLogout) {
        this.logoutRow()
      }
    }
    .layoutWeight(1)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .clip(true)
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.overviewCard()
        this.quickActionsCard()

        Row({ space: 14 }) {
          this.settingGroup('账号与权限', '安全、通知和登录设备', this.accountSettingItems(), false)
          this.settingGroup('应用与支持', '偏好设置、产品信息和账号操作', this.applicationSettingItems(), true)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
