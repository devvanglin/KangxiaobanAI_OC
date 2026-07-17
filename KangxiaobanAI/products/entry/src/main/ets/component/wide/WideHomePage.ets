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

import { LengthMetrics } from '@kit.ArkUI';

type WideStatus = 'danger' | 'warning' | 'normal' | 'brand' | 'neutral';

interface WideWorkTab {
  label: string;
  count: number;
}

interface WideWorkItem {
  id: string;
  title: string;
  subtitle: string;
  time: string;
  status: string;
  level: WideStatus;
}

interface WideAiReminder {
  id: string;
  title: string;
  subtitle: string;
  level: WideStatus;
}

interface WideOverviewItem {
  label: string;
  value: string;
  unit: string;
  level: WideStatus;
}

interface WideFocusItem {
  id: string;
  name: string;
  location: string;
  title: string;
  detail: string;
  level: WideStatus;
}

@ComponentV2
export struct WideHomePage {
  @Event onOpenAiChat: () => void = () => {};
  @Local currentTime: Date = new Date();
  @Local isClockedIn: boolean = false;
  @Local isClockedOut: boolean = false;
  @Local clockInTime: Date | null = null;
  @Local clockOutTime: Date | null = null;
  @Local activeWorkIndex: number = 0;
  @Local hoveredWorkTabIndex: number = -1;
  @Local hoveredWorkId: string = '';
  @Local selectedWorkId: string = '';
  @Local hoveredFocusId: string = '';
  @Local selectedFocusId: string = '';
  @Local isClockButtonHovered: boolean = false;
  @Local isAiCardHovered: boolean = false;
  private timerId: number = -1;

  @Styles
  keyboardFocusStyle() {
    .focusable(true)
    .focusOnTouch(true)
    .hoverEffect(HoverEffect.None)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2)
    })
  }

  aboutToAppear(): void {
    this.timerId = setInterval(() => {
      this.currentTime = new Date();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private workTabs(): WideWorkTab[] {
    return [
      { label: '待办', count: 3 },
      { label: '用药', count: 4 },
      { label: '记录', count: 4 },
      { label: '家属', count: 4 }
    ];
  }

  private todoItems(): WideWorkItem[] {
    return [
      {
        id: 'todo-emotion',
        title: '情绪安抚与人工接手',
        subtitle: '3F-302 肖爷爷 · 责任护工 刘婷',
        time: '现在',
        status: '高优先',
        level: 'danger'
      },
      {
        id: 'todo-assessment',
        title: '夜间不适评估',
        subtitle: '2F-215 周奶奶 · 责任护工 王倩',
        time: '09:46',
        status: '待处理',
        level: 'warning'
      },
      {
        id: 'todo-round',
        title: '半护理上午巡房',
        subtitle: '2F-208 李奶奶 · 责任护工 刘婷',
        time: '10:00',
        status: '待处理',
        level: 'brand'
      }
    ];
  }

  private medicationItems(): WideWorkItem[] {
    return [
      {
        id: 'med-1',
        title: '降压药 · 1片',
        subtitle: '李秀英 · 服药后复测血压',
        time: '08:00',
        status: '待服用',
        level: 'brand'
      },
      {
        id: 'med-2',
        title: '钙片 · 2片',
        subtitle: '王德林 · 餐后服用',
        time: '08:00',
        status: '待服用',
        level: 'brand'
      },
      {
        id: 'med-3',
        title: '二甲双胍 · 0.5g',
        subtitle: '张明华 · 午餐后服用',
        time: '12:00',
        status: '待服用',
        level: 'warning'
      },
      {
        id: 'med-4',
        title: '维生素 D · 1粒',
        subtitle: '肖爷爷 · 已核对用药记录',
        time: '07:00',
        status: '已完成',
        level: 'normal'
      }
    ];
  }

  private recordItems(): WideWorkItem[] {
    return [
      {
        id: 'record-1',
        title: '体征测量',
        subtitle: '3F-302 肖爷爷',
        time: '10:24',
        status: '已记录',
        level: 'normal'
      },
      {
        id: 'record-2',
        title: '翻身护理',
        subtitle: '2F-215 周奶奶',
        time: '09:46',
        status: '已记录',
        level: 'normal'
      },
      {
        id: 'record-3',
        title: '用药执行',
        subtitle: '3F-306 林爷爷',
        time: '09:12',
        status: '已记录',
        level: 'normal'
      },
      {
        id: 'record-4',
        title: '夜间巡查',
        subtitle: '2F 东区 · 36位长者',
        time: '06:30',
        status: '已记录',
        level: 'normal'
      }
    ];
  }

  private familyItems(): WideWorkItem[] {
    return [
      {
        id: 'family-1',
        title: '张建国',
        subtitle: '李秀英儿子 · 138****8000',
        time: '今天',
        status: '待回访',
        level: 'warning'
      },
      {
        id: 'family-2',
        title: '李秀兰',
        subtitle: '王德林女儿 · 139****9000',
        time: '今天',
        status: '待联系',
        level: 'brand'
      },
      {
        id: 'family-3',
        title: '林涛',
        subtitle: '林爷爷儿子 · 137****7000',
        time: '09:12',
        status: '未接通',
        level: 'danger'
      },
      {
        id: 'family-4',
        title: '周敏',
        subtitle: '周奶奶女儿 · 136****6000',
        time: '09:46',
        status: '已确认',
        level: 'normal'
      }
    ];
  }

  private currentWorkItems(): WideWorkItem[] {
    if (this.activeWorkIndex === 1) {
      return this.medicationItems();
    }
    if (this.activeWorkIndex === 2) {
      return this.recordItems();
    }
    if (this.activeWorkIndex === 3) {
      return this.familyItems();
    }
    return this.todoItems();
  }

  private aiReminders(): WideAiReminder[] {
    return [
      {
        id: 'ai-blood-pressure',
        title: '血压连续3天偏高',
        subtitle: '302-1 张明华 · 建议今日重点观察',
        level: 'danger'
      },
      {
        id: 'ai-rehabilitation',
        title: '康复训练完成率 87%',
        subtitle: '305-2 李秀英 · 进度稳定，继续保持',
        level: 'normal'
      }
    ];
  }

  private overviewItems(): WideOverviewItem[] {
    return [
      { label: '待办任务', value: '3', unit: '项', level: 'danger' },
      { label: '进行中', value: '3', unit: '项', level: 'warning' },
      { label: '已完成', value: '1', unit: '项', level: 'normal' },
      { label: '用药进度', value: '3/4', unit: '人', level: 'brand' }
    ];
  }

  private focusItems(): WideFocusItem[] {
    return [
      {
        id: 'focus-emotion',
        name: '肖爷爷',
        location: '3F-302',
        title: '情绪低落 · 拒交流',
        detail: '活动量下降 41%，需要熟悉护工人工接手',
        level: 'danger'
      },
      {
        id: 'focus-sleep',
        name: '周奶奶',
        location: '2F-215',
        title: '夜间不适待评估',
        detail: '午休前完成疼痛评估并补充交班记录',
        level: 'warning'
      }
    ];
  }

  private statusColor(level: WideStatus): ResourceColor {
    if (level === 'danger') {
      return $r('app.color.status_danger');
    }
    if (level === 'warning') {
      return $r('app.color.status_warning');
    }
    if (level === 'normal') {
      return $r('app.color.status_normal');
    }
    if (level === 'brand') {
      return $r('app.color.brand_blue');
    }
    return $r('sys.color.font_secondary');
  }

  private statusBackground(level: WideStatus): ResourceColor {
    if (level === 'danger') {
      return $r('app.color.status_danger_bg');
    }
    if (level === 'warning') {
      return $r('app.color.status_warning_bg');
    }
    if (level === 'normal') {
      return $r('app.color.status_normal_bg');
    }
    if (level === 'brand') {
      return $r('sys.color.comp_background_emphasize');
    }
    return $r('sys.color.comp_background_secondary');
  }

  private workSymbol(index: number): Resource {
    if (index === 1) {
      return $r('sys.symbol.heart_fill');
    }
    if (index === 2) {
      return $r('sys.symbol.doc_text');
    }
    if (index === 3) {
      return $r('sys.symbol.phone_fill');
    }
    return $r('sys.symbol.calendar_badge_clock');
  }

  private currentTimeText(): string {
    const hour: string = this.currentTime.getHours().toString().padStart(2, '0');
    const minute: string = this.currentTime.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private dateText(): string {
    const weekNames: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${this.currentTime.getMonth() + 1}月${this.currentTime.getDate()}日 ${weekNames[this.currentTime.getDay()]}`;
  }

  private shortTime(date: Date): string {
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private clockStatusText(): string {
    if (!this.isClockedIn) {
      return '今日未打卡 · 白班 08:00-18:00';
    }
    if (this.isClockedOut && this.clockInTime && this.clockOutTime) {
      return `${this.shortTime(this.clockInTime)} 上班 · ${this.shortTime(this.clockOutTime)} 下班`;
    }
    if (this.clockInTime) {
      return `${this.shortTime(this.clockInTime)} 已上班 · 工作中`;
    }
    return '';
  }

  private clockStatusColor(): ResourceColor {
    if (this.isClockedOut) {
      return $r('sys.color.font_secondary');
    }
    if (this.isClockedIn) {
      return $r('app.color.status_normal');
    }
    return $r('sys.color.font_secondary');
  }

  private clockButtonLabel(): string {
    if (this.isClockedOut) {
      return '今日已完成';
    }
    return this.isClockedIn ? '下班打卡' : '上班打卡';
  }

  private clockButtonColor(): ResourceColor {
    if (this.isClockedOut) {
      return $r('sys.color.comp_background_secondary');
    }
    return this.isClockedIn ? $r('app.color.status_danger') : $r('app.color.brand_blue');
  }

  private clockButtonTextColor(): ResourceColor {
    return this.isClockedOut ? $r('sys.color.font_tertiary') : $r('app.color.text_on_brand');
  }

  private handleClockAction(): void {
    if (!this.isClockedIn) {
      this.isClockedIn = true;
      this.clockInTime = new Date();
      return;
    }
    if (!this.isClockedOut) {
      this.isClockedOut = true;
      this.clockOutTime = new Date();
    }
  }

  private workRowBackground(item: WideWorkItem): ResourceColor {
    if (this.selectedWorkId === item.id) {
      return $r('sys.color.comp_background_emphasize');
    }
    if (this.hoveredWorkId === item.id) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  private focusRowBackground(item: WideFocusItem): ResourceColor {
    if (this.selectedFocusId === item.id) {
      return this.statusBackground(item.level);
    }
    if (this.hoveredFocusId === item.id) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  @Builder
  private clockCard() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text('今日考勤')
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Blank()

        Text(this.dateText())
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 16 }) {
        Text(this.currentTimeText())
          .fontSize(42)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .letterSpacing(0)
          .maxLines(1)

        Blank()

        Button(this.clockButtonLabel())
          .height(42)
          .padding({ left: 20, right: 20 })
          .borderRadius(21)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.clockButtonTextColor())
          .backgroundColor(this.clockButtonColor())
          .opacity(this.isClockButtonHovered && !this.isClockedOut ? 0.86 : 1)
          .enabled(!this.isClockedOut)
          .keyboardFocusStyle()
          .onHover((isHover: boolean) => {
            this.isClockButtonHovered = isHover;
          })
          .onClick(() => {
            this.handleClockAction();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 7 }) {
        Column()
          .width(7)
          .height(7)
          .borderRadius(4)
          .backgroundColor(this.clockStatusColor())

        Text(this.clockStatusText())
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('36%')
    .height(208)
    .constraintSize({ minWidth: 280, maxWidth: 400 })
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private aiCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 1 }) {
          Text('康小伴 AI')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('已为你整理 2 条智能提醒')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 4 }) {
          Text('进入对话')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.brand_blue'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([$r('app.color.brand_blue')])
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 0 }) {
        ForEach(this.aiReminders(), (item: WideAiReminder, index: number) => {
          this.aiReminderRow(item, index === this.aiReminders().length - 1)
        }, (item: WideAiReminder) => item.id)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .height(208)
    .padding({ left: 20, right: 20, top: 18, bottom: 14 })
    .backgroundColor(this.isAiCardHovered ? $r('sys.color.interactive_hover') :
      $r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .keyboardFocusStyle()
    .onHover((isHover: boolean) => {
      this.isAiCardHovered = isHover;
    })
    .onClick(() => {
      this.onOpenAiChat();
    })
  }

  @Builder
  private aiReminderRow(item: WideAiReminder, isLast: boolean) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.subtitle)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(item.level === 'danger' ? '需关注' : '状态良好')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor(this.statusColor(item.level))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.statusBackground(item.level))
        .borderRadius(8)
    }
    .width('100%')
    .height(60)
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
  }

  @Builder
  private workCard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 3 }) {
          Text('今日工作')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('按工作类型快速查看和处理')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(`${this.currentWorkItems().length} 项`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 4 }) {
        ForEach(this.workTabs(), (tab: WideWorkTab, index: number) => {
          this.workTab(tab, index)
        }, (tab: WideWorkTab, index: number) => `wide-work-tab-${index}`)
      }
      .width('100%')
      .height(44)
      .padding(4)
      .borderRadius(12)
      .backgroundColor($r('sys.color.comp_background_secondary'))

      Column({ space: 0 }) {
        ForEach(this.currentWorkItems(), (item: WideWorkItem, index: number) => {
          this.workRow(item, index === this.currentWorkItems().length - 1)
        }, (item: WideWorkItem) => item.id)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .height(536)
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private workTab(tab: WideWorkTab, index: number) {
    Row({ space: 6 }) {
      Text(tab.label)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(this.activeWorkIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.activeWorkIndex === index ? $r('app.color.text_on_brand') :
          $r('sys.color.font_primary'))

      Text(`${tab.count}`)
        .fontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.activeWorkIndex === index ? $r('app.color.brand_blue') :
          $r('sys.color.font_secondary'))
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.activeWorkIndex === index ? $r('app.color.text_on_brand') :
          $r('sys.color.comp_background_primary'))
        .borderRadius(11)
    }
    .layoutWeight(1)
    .height(36)
    .borderRadius(9)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.activeWorkIndex === index ? $r('app.color.brand_blue') :
      (this.hoveredWorkTabIndex === index ? $r('sys.color.interactive_hover') : Color.Transparent))
    .opacity(this.activeWorkIndex === index && this.hoveredWorkTabIndex === index ? 0.88 : 1)
    .keyboardFocusStyle()
    .onHover((isHover: boolean) => {
      this.hoveredWorkTabIndex = isHover ? index : -1;
    })
    .onClick(() => {
      this.activeWorkIndex = index;
      this.selectedWorkId = '';
    })
  }

  @Builder
  private workRow(item: WideWorkItem, isLast: boolean) {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph(this.workSymbol(this.activeWorkIndex))
          .fontSize(18)
          .fontColor([this.statusColor(item.level)])
      }
      .width(38)
      .height(38)
      .borderRadius(10)
      .backgroundColor(this.statusBackground(item.level))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.subtitle)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 5 }) {
        Text(item.time)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
        Text(item.status)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.statusColor(item.level))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(this.statusBackground(item.level))
          .borderRadius(8)
      }
      .alignItems(HorizontalAlign.End)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.icon_fourth')])
    }
    .width('100%')
    .height(82)
    .padding({ left: 10, right: 10 })
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.workRowBackground(item))
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .keyboardFocusStyle()
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.hoveredWorkId = item.id;
      } else if (this.hoveredWorkId === item.id) {
        this.hoveredWorkId = '';
      }
    })
    .onClick(() => {
      this.selectedWorkId = item.id;
    })
  }

  @Builder
  private overviewCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 3 }) {
          Text('今日概览')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('工作进度实时汇总')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('7 项已处理')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('app.color.status_normal'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 0 }) {
        Row({ space: 0 }) {
          this.overviewMetric(this.overviewItems()[0])
          Divider()
            .vertical(true)
            .height(48)
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.overviewMetric(this.overviewItems()[1])
        }
        .width('100%')
        .height(60)

        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))

        Row({ space: 0 }) {
          this.overviewMetric(this.overviewItems()[2])
          Divider()
            .vertical(true)
            .height(48)
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.overviewMetric(this.overviewItems()[3])
        }
        .width('100%')
        .height(60)
      }
      .width('100%')
    }
    .width('100%')
    .height(214)
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private overviewMetric(item: WideOverviewItem) {
    Column({ space: 4 }) {
      Text(item.label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 4 }) {
        Text(item.value)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(item.level))
        Text(item.unit)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .padding({ left: 8, right: 8 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private focusCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('重点关注')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('优先处理需要人工介入的事项')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 0 }) {
        ForEach(this.focusItems(), (item: WideFocusItem, index: number) => {
          this.focusRow(item, index === this.focusItems().length - 1)
        }, (item: WideFocusItem) => item.id)
      }
      .width('100%')
    }
    .width('100%')
    .height(306)
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private focusRow(item: WideFocusItem, isLast: boolean) {
    Row({ space: 11 }) {
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.name)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(item.location)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(item.level))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.detail)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.icon_fourth')])
    }
    .width('100%')
    .height(106)
    .padding({ left: 8, right: 8 })
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.focusRowBackground(item))
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .keyboardFocusStyle()
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.hoveredFocusId = item.id;
      } else if (this.hoveredFocusId === item.id) {
        this.hoveredFocusId = '';
      }
    })
    .onClick(() => {
      this.selectedFocusId = item.id;
    })
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 20 }) {
          Row({ space: 20 }) {
            this.clockCard()
            this.aiCard()
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Row({ space: 20 }) {
            this.workCard()

            Column({ space: 16 }) {
              this.overviewCard()
              this.focusCard()
            }
            .width('34%')
            .constraintSize({ minWidth: 280, maxWidth: 380 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .constraintSize({ maxWidth: 1440 })
        .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
