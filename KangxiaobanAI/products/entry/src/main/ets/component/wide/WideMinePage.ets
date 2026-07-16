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

  private settingItems(): WideMineSettingItem[] {
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
      },
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

  @Builder
  private identityCard() {
    Column({ space: 18 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(68)
            .height(68)
            .borderRadius(34)
            .backgroundColor(0xFFEAF1FF)
          Text('LT')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
        }

        Column({ space: 5 }) {
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
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Row({ space: 9 }) {
        SymbolGlyph($r('sys.symbol.person_2_fill'))
          .fontSize(17)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('康养中心 · 护理一组')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private shiftCard() {
    Column({ space: 14 }) {
      Row() {
        Text('当前班次')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('在岗')
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.status_normal'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.status_normal_bg'))
          .borderRadius(6)
      }
      .width('100%')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar_badge_clock'))
          .fontSize(20)
          .fontColor([$r('app.color.brand_blue')])
        Column({ space: 4 }) {
          Text('早班 · 07:30 - 16:00')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('护理一组 · 负责 28 位长者')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        Row()
          .width('62%')
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.brand_blue'))
      }
      .width('100%')
      .height(6)

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
    .width('100%')
    .padding(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private statItem(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(21)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(label)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .height(66)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private statsCard() {
    Column({ space: 0 }) {
      Text('本月工作')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .padding({ left: 18, right: 18, top: 16, bottom: 8 })

      Row({ space: 0 }) {
        this.statItem('28', '负责长者')
        Divider()
          .vertical(true)
          .height(40)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.statItem('92%', '班次完成')
      }
      .width('100%')

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 18, right: 18 })

      Row({ space: 0 }) {
        this.statItem('4.9', '服务评分')
        Divider()
          .vertical(true)
          .height(40)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.statItem('12h', '培训时长')
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private profilePane() {
    Scroll() {
      Column({ space: 14 }) {
        this.identityCard()
        this.shiftCard()
        this.statsCard()
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 24 })
    }
    .width(348)
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: { right: 0.5 }, color: { right: $r('sys.color.comp_divider') } })
  }

  @Builder
  private quickActionItem(item: WideMineQuickAction) {
    Column({ space: 9 }) {
      Row() {
        SymbolGlyph(item.icon)
          .fontSize(24)
          .fontColor([$r('app.color.brand_blue')])
      }
      .width(46)
      .height(46)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(0xFFEAF1FF)

      Text(item.label)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(item.description)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(128)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.quickActionBackground(item.id))
    .borderRadius(10)
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
    Column({ space: 4 }) {
      Row() {
        Text('常用功能')
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('四项')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 4 })

      Row({ space: 4 }) {
        ForEach(this.quickActions(), (item: WideMineQuickAction) => {
          this.quickActionItem(item)
        }, (item: WideMineQuickAction) => item.id)
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 8 })
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private settingRow(item: WideMineSettingItem, isLast: boolean) {
    Column({ space: 0 }) {
      Row({ space: 13 }) {
        Row() {
          SymbolGlyph(item.icon)
            .fontSize(20)
            .fontColor([$r('sys.color.font_primary')])
        }
        .width(36)
        .height(36)
        .borderRadius(10)
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
          .fontSize(16)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })

      if (!isLast) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
          .margin({ left: 64, right: 16 })
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
    .onClick(() => {
      this.openSetting(item.id);
    })
  }

  @Builder
  private settingsCard() {
    Column({ space: 0 }) {
      ForEach(this.settingItems(), (item: WideMineSettingItem, index: number) => {
        this.settingRow(item, index === this.settingItems().length - 1)
      }, (item: WideMineSettingItem) => item.id)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .clip(true)
  }

  @Builder
  private logoutCard() {
    Row({ space: 13 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor([$r('app.color.status_danger')])
      }
      .width(36)
      .height(36)
      .borderRadius(10)
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
    .backgroundColor(this.hoveredLogout || this.focusedLogout ? $r('sys.color.interactive_hover') :
      $r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(2),
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
    .onClick(() => {
      this.onLogout();
    })
  }

  @Builder
  private workspacePane() {
    Scroll() {
      Row() {
        Column({ space: 14 }) {
          this.quickActionsCard()

          Text('账号与应用')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .padding({ left: 2, top: 4, bottom: 2 })

          this.settingsCard()
          this.logoutCard()

          Text('康小伴 AI · 护工工作台')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 6 })
        }
        .width('100%')
        .constraintSize({ maxWidth: 920 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 28, right: 28, top: 18, bottom: 28 })
    }
    .layoutWeight(1)
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    Row({ space: 0 }) {
      this.profilePane()
      this.workspacePane()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
