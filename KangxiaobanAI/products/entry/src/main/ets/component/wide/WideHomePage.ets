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

interface WideWorkItem {
  id: string;
  title: string;
  subtitle: string;
  time: string;
  status: string;
  level: WideStatus;
}

interface WideWorkSection {
  id: string;
  title: string;
  items: WideWorkItem[];
}

interface WideAiReminder {
  id: string;
  title: string;
  subtitle: string;
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
  @Param viewportHeight: number = 0;
  @Event onOpenAiChat: () => void = () => {};
  @Local currentTime: Date = new Date();
  @Local isClockedIn: boolean = false;
  @Local isClockedOut: boolean = false;
  @Local clockInTime: Date | null = null;
  @Local clockOutTime: Date | null = null;
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
      const now: Date = new Date();
      if (Math.floor(now.getTime() / 60000) !== Math.floor(this.currentTime.getTime() / 60000)) {
        this.currentTime = now;
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
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

  private workSections(): WideWorkSection[] {
    return [
      { id: 'todo', title: '待办', items: this.todoItems() },
      { id: 'medication', title: '用药', items: this.medicationItems() },
      { id: 'record', title: '记录', items: this.recordItems() },
      { id: 'family', title: '家属', items: this.familyItems() }
    ];
  }

  private totalWorkCount(): number {
    return this.todoItems().length + this.medicationItems().length + this.recordItems().length +
      this.familyItems().length;
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
      return $r('sys.color.comp_background_secondary');
    }
    return $r('sys.color.comp_background_secondary');
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

  private attendanceHeight(): number {
    return 112;
  }

  private aiPanelHeight(): number {
    return 176;
  }

  private workAreaHeight(): number {
    if (this.viewportHeight <= 0) {
      return 620;
    }
    return Math.max(520, this.viewportHeight - 48 - this.attendanceHeight() - 16);
  }

  private workRowHeight(): number {
    return Math.max(76, Math.min(132, Math.floor((this.workAreaHeight() - 120) / 4)));
  }

  private focusPanelHeight(): number {
    return Math.max(328, this.workAreaHeight() - this.aiPanelHeight() - 16);
  }

  private focusRowHeight(): number {
    const visibleCount: number = Math.min(2, Math.max(1, this.focusItems().length));
    return Math.max(118, Math.min(190, Math.floor((this.focusPanelHeight() - 68) / visibleCount)));
  }

  private shortTime(date: Date): string {
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private clockStatusText(): string {
    if (!this.isClockedIn) {
      return '今日尚未打卡';
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
      return $r('sys.color.comp_background_secondary');
    }
    if (this.hoveredWorkId === item.id) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  private focusRowBackground(item: WideFocusItem): ResourceColor {
    if (this.selectedFocusId === item.id) {
      return $r('sys.color.comp_background_secondary');
    }
    if (this.hoveredFocusId === item.id) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  @Builder
  private clockCard() {
    Row({ space: 0 }) {
      Column({ space: 5 }) {
        Text('今日考勤')
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.dateText())
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(220)
      .alignItems(HorizontalAlign.Start)

      Divider()
        .vertical(true)
        .height(52)
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Text(this.currentTimeText())
        .width(180)
        .fontSize(40)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .letterSpacing(0)
        .textAlign(TextAlign.Center)
        .maxLines(1)

      Divider()
        .vertical(true)
        .height(52)
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Column({ space: 7 }) {
        Text('考勤状态')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
        Row({ space: 8 }) {
          Column()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.clockStatusColor())
          Text(this.clockStatusText())
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .padding({ left: 24, right: 24 })
      .alignItems(HorizontalAlign.Start)

      Button(this.clockButtonLabel())
        .width(112)
        .height(42)
        .margin({ left: 24 })
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
    .height(this.attendanceHeight())
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private aiCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('康小伴 AI')
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

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

      List({ space: 0 }) {
        Repeat(this.aiReminders()).each((repeatItem: RepeatItem<WideAiReminder>) => {
          ListItem() {
            this.aiReminderRow(repeatItem.item, repeatItem.index === this.aiReminders().length - 1)
          }
        }).virtualScroll().key((item: WideAiReminder) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(2)
      .clip(true)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    }
    .width('100%')
    .height(this.aiPanelHeight())
    .padding({ left: 18, right: 18, top: 16, bottom: 14 })
    .backgroundColor(this.isAiCardHovered ? $r('sys.color.interactive_hover') :
      $r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .geometryTransition('aiReminderCard', { follow: true })
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
    .height(52)
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
  }

  @Builder
  private workCard() {
    Column({ space: 12 }) {
      Row() {
        Text('今日工作')
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Blank()

        Text(`共 ${this.totalWorkCount()} 项`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(32)
      .alignItems(VerticalAlign.Center)

      Row({ space: 0 }) {
        ForEach(this.workSections(), (section: WideWorkSection, index: number) => {
          this.workSection(section, index === this.workSections().length - 1)
        }, (section: WideWorkSection) => section.id)
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)
    }
    .layoutWeight(1)
    .height(this.workAreaHeight())
    .padding(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private workSection(section: WideWorkSection, isLast: boolean) {
    Column({ space: 0 }) {
      Row() {
        Text(section.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Blank()

        Text(section.items.length.toString())
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(12)
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .alignItems(VerticalAlign.Center)

      List({ space: 0 }) {
        Repeat(section.items).each((repeatItem: RepeatItem<WideWorkItem>) => {
          ListItem() {
            this.workSectionRow(repeatItem.item, repeatItem.index === section.items.length - 1)
          }
        }).virtualScroll().key((item: WideWorkItem) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(2)
      .clip(true)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    }
    .layoutWeight(1)
    .height('100%')
    .border({
      width: { right: isLast ? 0 : 0.5 },
      color: { right: $r('sys.color.comp_divider') }
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private workSectionRow(item: WideWorkItem, isLast: boolean) {
    Column({ space: 5 }) {
      Row({ space: 8 }) {
        Text(item.title)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.time)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Text(item.subtitle)
          .layoutWeight(1)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.status)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.statusColor(item.level))
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(this.statusBackground(item.level))
          .borderRadius(8)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.workRowHeight())
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(8)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
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
  private focusCard() {
    Column({ space: 10 }) {
      Row() {
        Text('重点关注')
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      List({ space: 0 }) {
        Repeat(this.focusItems()).each((repeatItem: RepeatItem<WideFocusItem>) => {
          ListItem() {
            this.focusRow(repeatItem.item, repeatItem.index === this.focusItems().length - 1)
          }
        }).virtualScroll().key((item: WideFocusItem) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(2)
      .clip(true)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    }
    .width('100%')
    .height(this.focusPanelHeight())
    .padding(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.icon_fourth')])
    }
    .width('100%')
    .height(this.focusRowHeight())
    .padding({ left: 10, right: 8, top: 14, bottom: 14 })
    .borderRadius(8)
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
        Column({ space: 16 }) {
          this.clockCard()

          Row({ space: 16 }) {
            this.workCard()

            Column({ space: 16 }) {
              this.aiCard()
              this.focusCard()
            }
            .width(340)
            .height(this.workAreaHeight())
          }
          .width('100%')
          .height(this.workAreaHeight())
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .constraintSize({ maxWidth: 1560 })
        .padding({ left: 24, right: 24, top: 24, bottom: 24 })
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
