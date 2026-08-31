import { Bed, CareTask, Elder, Room, Schedule } from '../../network/Dto';

interface DoctorScheduleItem {
  id: string;
  time: string;
  title: string;
  elder: string;
  location: string;
  status: string;
  tone: string;
}

interface CalendarDay {
  key: string;
  day: string;
  month: string;
  weekday: string;
  isToday: boolean;
  isPlaceholder?: boolean;
}

interface CalendarWeek {
  key: string;
  label: string;
  days: CalendarDay[];
}

@ComponentV2
export struct WideDoctorSchedule {
  @Param @Require elders: Elder[];
  @Param @Require beds: Bed[];
  @Param @Require rooms: Room[];
  @Param @Require tasks: CareTask[];
  @Param @Require schedules: Schedule[];
  @Param loading: boolean = false;
  @Param compactWidth: boolean = false;
  @Local selectedDate: string = '';
  @Local calendarExpanded: boolean = false;
  @Local calendarMonthOffset: number = 0;

  aboutToAppear(): void {
    this.selectedDate = this.today();
  }

  private dateKey(value: Date): string {
    return `${value.getFullYear()}-${(value.getMonth() + 1).toString().padStart(2, '0')}-${value.getDate().toString().padStart(2, '0')}`;
  }

  private today(): string {
    return this.dateKey(new Date());
  }

  private selectedDateKey(): string {
    return this.selectedDate.length > 0 ? this.selectedDate : this.today();
  }

  private selectDate(key: string): void {
    this.selectedDate = key;
    const selected: Date = new Date(`${key}T12:00:00`);
    const current: Date = new Date();
    if (!Number.isNaN(selected.getTime())) {
      this.calendarMonthOffset = (selected.getFullYear() - current.getFullYear()) * 12 +
        selected.getMonth() - current.getMonth();
    }
  }

  private dayKey(value: string): string {
    const parsed: Date = new Date(value.replace('T', ' '));
    if (Number.isNaN(parsed.getTime())) {
      return value.length >= 10 ? value.slice(0, 10) : '';
    }
    return this.dateKey(parsed);
  }

  private timeLabel(value?: string): string {
    if (value === undefined || value.trim().length === 0) return '待定';
    const normalized: string = value.replace('T', ' ');
    return normalized.length >= 16 ? normalized.slice(11, 16) : '待定';
  }

  private elderName(elderId: number): string {
    return this.elders.find((item: Elder) => item.id === elderId)?.name ?? '未知老人';
  }

  private elderLocation(elderId: number): string {
    const elder: Elder | undefined = this.elders.find((item: Elder) => item.id === elderId);
    const bed: Bed | undefined = this.beds.find((item: Bed) => item.id === elder?.bed_id);
    const room: Room | undefined = bed === undefined ? undefined : this.rooms.find((item: Room) => item.id === bed.room_id);
    return room !== undefined && bed !== undefined ? `${room.floor}F-${room.room_no} · ${bed.bed_no}床` : '房间未分配';
  }

  private statusLabel(status: string): string {
    return status === 'done' ? '已完成' : status === 'doing' ? '进行中' : '待处理';
  }

  private statusTone(status: string): string {
    return status === 'done' ? 'success' : status === 'doing' ? 'focus' : 'warning';
  }

  private toneColor(tone: string): ResourceColor {
    return tone === 'success' ? $r('app.color.doctor_workspace_success') :
      tone === 'focus' ? $r('app.color.doctor_workspace_focus') :
      $r('app.color.doctor_workspace_warning');
  }

  private taskItems(date: string = this.selectedDateKey()): DoctorScheduleItem[] {
    return this.tasks
      .filter((task: CareTask) => task.due_at !== undefined && this.dayKey(task.due_at) === date)
      .sort((left: CareTask, right: CareTask): number => (left.due_at ?? '').localeCompare(right.due_at ?? ''))
      .map((task: CareTask): DoctorScheduleItem => ({
        id: `task-${task.id}`,
        time: this.timeLabel(task.due_at),
        title: task.title || '查房',
        elder: this.elderName(task.elder_id),
        location: this.elderLocation(task.elder_id),
        status: this.statusLabel(task.status),
        tone: this.statusTone(task.status)
      }));
  }

  private scheduleItems(date: string = this.selectedDateKey()): DoctorScheduleItem[] {
    return this.schedules
      .filter((item: Schedule) => item.work_date === date)
      .map((item: Schedule): DoctorScheduleItem => ({
        id: `schedule-${item.id}`,
        time: item.shift || '今日',
        title: '今日排班',
        elder: item.staff || '未指定人员',
        location: item.room_scope || '范围未登记',
        status: '已排班',
        tone: 'focus'
      }));
  }

  private items(date: string = this.selectedDateKey()): DoctorScheduleItem[] {
    const tasks: DoctorScheduleItem[] = this.taskItems(date);
    return tasks.length > 0 ? tasks : this.scheduleItems(date);
  }

  private calendarDays(): CalendarDay[] {
    const days: CalendarDay[] = [];
    const weekNames: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    const selected: Date = new Date(`${this.selectedDateKey()}T12:00:00`);
    const current: Date = Number.isNaN(selected.getTime()) ? new Date() : selected;
    current.setHours(12, 0, 0, 0);
    current.setDate(current.getDate() - current.getDay());
    for (let offset: number = 0; offset < 7; offset++) {
      const value: Date = new Date(current.getTime());
      value.setDate(current.getDate() + offset);
      const key: string = this.dateKey(value);
      days.push({ key: key, day: value.getDate().toString(), month: `${value.getMonth() + 1}月`,
        weekday: `周${weekNames[value.getDay()]}`, isToday: key === this.today() });
    }
    return days;
  }

  private calendarMonthDate(): Date {
    const value: Date = new Date();
    value.setHours(12, 0, 0, 0);
    value.setDate(1);
    value.setMonth(value.getMonth() + this.calendarMonthOffset);
    return value;
  }

  private calendarMonthLabel(): string {
    const value: Date = this.calendarMonthDate();
    return `${value.getFullYear()}年${value.getMonth() + 1}月`;
  }

  private monthWeeks(): CalendarWeek[] {
    const month: Date = this.calendarMonthDate();
    const firstWeekday: number = month.getDay();
    const daysInMonth: number = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    const weekNames: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    const cells: CalendarDay[] = [];
    for (let index: number = 0; index < firstWeekday; index++) {
      cells.push({ key: `placeholder-${index}`, day: '', month: '', weekday: '', isToday: false, isPlaceholder: true });
    }
    for (let day: number = 1; day <= daysInMonth; day++) {
      const value: Date = new Date(month.getFullYear(), month.getMonth(), day, 12);
      const key: string = this.dateKey(value);
      cells.push({ key: key, day: day.toString(), month: `${value.getMonth() + 1}月`,
        weekday: `周${weekNames[value.getDay()]}`, isToday: key === this.today() });
    }
    while (cells.length % 7 !== 0) {
      cells.push({ key: `placeholder-${cells.length}`, day: '', month: '', weekday: '', isToday: false, isPlaceholder: true });
    }
    const weeks: CalendarWeek[] = [];
    for (let index: number = 0; index < cells.length; index += 7) {
      const first: CalendarDay = cells[index];
      const date: Date = first.isPlaceholder === true ? new Date(month.getFullYear(), month.getMonth(), 1, 12) :
        new Date(`${first.key}T12:00:00`);
      const weekNo: number = Math.ceil((date.getDate() + new Date(date.getFullYear(), date.getMonth(), 1).getDay()) / 7);
      weeks.push({ key: `week-${index}`, label: `${weekNo}`, days: cells.slice(index, index + 7) });
    }
    return weeks;
  }

  private hasItems(date: string): boolean {
    return this.tasks.some((task: CareTask) => task.due_at !== undefined && this.dayKey(task.due_at) === date) ||
      this.schedules.some((item: Schedule) => item.work_date === date);
  }

  private selectedDateLabel(): string {
    const parsed: Date = new Date(`${this.selectedDateKey()}T12:00:00`);
    return Number.isNaN(parsed.getTime()) ? this.selectedDateKey() : `${parsed.getMonth() + 1}月${parsed.getDate()}日`;
  }

  private summaryText(): string {
    const items: DoctorScheduleItem[] = this.items();
    if (this.loading) return '正在加载';
    if (items.length === 0) return `${this.selectedDateLabel()} 暂无安排`;
    return `${items.length} 项安排`;
  }

  private toggleCalendar(): void {
    const nextExpanded: boolean = !this.calendarExpanded;
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.calendarExpanded = nextExpanded;
      if (nextExpanded) {
        this.selectDate(this.selectedDateKey());
      }
    });
  }

  @Builder
  private calendarDay(day: CalendarDay) {
    Column({ space: 4 }) {
      Text(day.weekday).fontSize(10)
        .fontColor(day.key === this.selectedDateKey() ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
      Stack({ alignContent: Alignment.Center }) {
        Row().width(34).height(34).borderRadius(17)
          .backgroundColor(day.key === this.selectedDateKey() ? $r('app.color.doctor_workspace_danger') : Color.Transparent)
        Text(day.day).fontSize(14).fontWeight(day.key === this.selectedDateKey() ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(day.key === this.selectedDateKey() ? Color.White : $r('sys.color.font_primary'))
      }
      Row().width(5).height(5).borderRadius(3)
        .backgroundColor(this.hasItems(day.key) ? $r('app.color.doctor_workspace_warning') : Color.Transparent)
    }
    .width(this.compactWidth ? 48 : 64)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.Transparent)
    .accessibilityText(`${day.month}${day.day}日${day.weekday}${this.hasItems(day.key) ? '有日程' : ''}`)
    .onClick(() => this.selectDate(day.key))
  }

  @Builder
  private monthCell(day: CalendarDay) {
    Column({ space: 2 }) {
      if (day.isPlaceholder !== true) {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).borderRadius(16)
            .backgroundColor(day.key === this.selectedDateKey() ? $r('app.color.doctor_workspace_danger') : Color.Transparent)
          Text(day.day).fontSize(13).fontWeight(day.key === this.selectedDateKey() ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(day.key === this.selectedDateKey() ? Color.White : $r('sys.color.font_primary'))
        }
        Row().width(4).height(4).borderRadius(2)
          .backgroundColor(this.hasItems(day.key) ? $r('app.color.doctor_workspace_warning') : Color.Transparent)
      }
    }
    .layoutWeight(1).height(42)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .borderRadius(10)
    .backgroundColor(Color.Transparent)
    .accessibilityText(day.isPlaceholder === true ? '空日期' : `${day.month}${day.day}日${day.weekday}`)
    .onClick(() => { if (day.isPlaceholder !== true) this.selectDate(day.key); })
  }

  @Builder
  private monthWeekRow(week: CalendarWeek) {
    Row({ space: 4 }) {
      Text(`${week.label}周`).fontSize(9).fontColor($r('sys.color.font_tertiary')).width(26)
      ForEach(week.days, (day: CalendarDay) => this.monthCell(day), (day: CalendarDay) => day.key)
    }.width('100%').height(46).alignItems(VerticalAlign.Center)
  }

  @Builder
  private monthView() {
    Column({ space: 8 }) {
      Row() {
        Text(this.calendarMonthLabel()).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
      }.width('100%')
      Row({ space: 4 }) {
        Text('').width(26)
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string) => {
          Text(day).layoutWeight(1).fontSize(13).fontColor($r('sys.color.font_tertiary')).textAlign(TextAlign.Center)
        }, (day: string) => day)
      }.width('100%')
      Column() {
        ForEach(this.monthWeeks(), (week: CalendarWeek) => this.monthWeekRow(week), (week: CalendarWeek) => week.key)
      }.width('100%')
    }.width('100%')
  }

  @Builder
  private scheduleRow(item: DoctorScheduleItem, isLast: boolean) {
    Row({ space: 10 }) {
      Text(item.time).fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor(this.toneColor(item.tone)).width(this.compactWidth ? 48 : 58)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(item.elder).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).maxLines(1)
          Text(item.title).fontSize(13).fontColor($r('sys.color.font_secondary')).maxLines(1)
        }.width('100%').alignItems(VerticalAlign.Center)
        Text(item.location).fontSize(13).fontColor($r('sys.color.font_tertiary')).maxLines(1)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(item.status).fontSize(13).fontColor(this.toneColor(item.tone))
    }
    .width('100%').height(54).padding({ left: 2, right: 2 })
    .border({ width: { bottom: isLast ? 0 : 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private expandedCalendar() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(14)
        }.width(30).height(30).padding(0).backgroundColor($r('sys.color.comp_background_secondary'))
          .accessibilityText('上一个月').onClick(() => this.calendarMonthOffset -= 1)
        Text(this.calendarMonthLabel()).fontSize(11).fontColor($r('sys.color.font_secondary'))
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14)
        }.width(30).height(30).padding(0).backgroundColor($r('sys.color.comp_background_secondary'))
          .accessibilityText('下一个月').onClick(() => this.calendarMonthOffset += 1)
        Blank()
      }.width('100%').alignItems(VerticalAlign.Center)
      this.monthView()
    }.width('100%')
  }

  @Builder
  private scheduleContent() {
    Column({ space: 12 }) {
      if (!this.calendarExpanded) {
        Scroll() {
          Row({ space: 4 }) {
            ForEach(this.calendarDays(), (day: CalendarDay) => this.calendarDay(day), (day: CalendarDay) => day.key)
          }.width('100%').justifyContent(FlexAlign.SpaceAround)
        }
        .width('100%').height(70)
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      }
      if (this.calendarExpanded) {
        this.expandedCalendar()
      }
      Row() {
        Text(`${this.selectedDateLabel()} 安排`).fontSize(14).fontColor($r('sys.color.font_secondary'))
        Blank()
        if (this.items().length > 0) {
          Text('按时间排序').fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }
      }.width('100%')
      if (this.items().length === 0) {
        Text(this.summaryText()).width('100%').height(58).fontSize(14)
          .fontColor($r('sys.color.font_tertiary')).textAlign(TextAlign.Center)
      } else {
        Column() {
          ForEach(this.items(), (item: DoctorScheduleItem, index: number) => this.scheduleRow(item, index === this.items().length - 1),
            (item: DoctorScheduleItem) => item.id)
        }.width('100%')
      }
    }
    .width('100%')
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('日常总览').fontSize(19).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.calendar_fill')).fontSize(14)
              .fontColor([$r('app.color.doctor_workspace_focus')])
            Text(this.calendarExpanded ? '收起日历' : '展开日历').fontSize(13)
              .fontColor($r('app.color.doctor_workspace_focus'))
          }
        }
        .height(32).padding({ left: 10, right: 10 }).borderRadius(16).backgroundColor(Color.Transparent)
        .accessibilityText(this.calendarExpanded ? '收起日历' : '展开日历')
        .onClick(() => this.toggleCalendar())
      }.width('100%')
      if (this.compactWidth) {
        this.scheduleContent()
      } else {
        // The expanded month can be taller than the remaining dashboard
        // viewport. Keep the card fixed and scroll only its content area so
        // the sibling age chart remains aligned and no rows escape the card.
        Scroll() {
          this.scheduleContent()
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height(this.compactWidth ? 'auto' : '100%')
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }
}
