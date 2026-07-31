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

import { curves, LengthMetrics } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { AiTitleLabel } from '../AiTitleLabel';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

type CarePriority = 'danger' | 'warning' | 'normal';
type CareTaskState = 'pending' | 'doing' | 'done';
type CareTaskCategory = 'todo' | 'medication' | 'record' | 'family' | 'report';
type CareWorkFilter = CareTaskCategory | 'priority' | 'completed';

interface CareTaskData {
  id: string;
  category: CareTaskCategory;
  title: string;
  residentId: string;
  resident: string;
  room: string;
  summary: string;
  time: string;
  owner: string;
  priority: CarePriority;
  state: CareTaskState;
}

interface CareFocusResident {
  id: string;
  name: string;
  room: string;
  note: string;
  updatedAt: string;
  priority: CarePriority;
}

interface CareCheckpoint {
  id: string;
  time: string;
  title: string;
  note: string;
  completed: boolean;
}

@ComponentV2
export struct WideHomePage {
  @Param compactWidth: boolean = false;
  @Param topBarHeight: number = 0;
  @Param @Require pageScroller: Scroller;
  @Param @Require taskDetailScroller: Scroller;
  @Param naviIndicatorHeight: number = 0;
  @Param backRequestToken: number = 0;
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenResident: (residentId: string) => void = (_residentId: string) => {};
  @Event onTaskPanelVisibilityChange: (visible: boolean) => void = (_visible: boolean) => {};
  @Event onShiftStateChange: (clockedIn: boolean, clockedOut: boolean) => void =
    (_clockedIn: boolean, _clockedOut: boolean) => {};
  @Event onTaskProgressChange: (completed: number, total: number) => void =
    (_completed: number, _total: number) => {};
  @Local currentTime: Date = new Date();
  @Local isClockedIn: boolean = false;
  @Local isClockedOut: boolean = false;
  @Local clockInTime: Date | null = null;
  @Local clockOutTime: Date | null = null;
  @Local activeFilter: CareWorkFilter = 'todo';
  @Local selectedTaskId: string = '';
  @Local isTaskPanelOpen: boolean = false;
  @Local hoveredTaskId: string = '';
  @Local hoveredResidentId: string = '';
  @Local focusedTarget: string = '';
  @Local inProgressTaskIds: string[] = [];
  @Local completedTaskIds: string[] = [];
  @Local noteDrafts: Map<string, string> = new Map<string, string>();
  @Local validationTaskId: string = '';
  @Local taskPanelHeaderHeight: number = 88;
  private timerId: number = -1;

  private taskData: CareTaskData[] = [
    {
      id: 'care-emotion', category: 'todo', title: '情绪安抚与人工接手', residentId: 'r1', resident: '肖爷爷',
      room: '3F-302',
      summary: '活动量下降 41%，拒绝交流，建议由熟悉的护理员优先接手', time: '现在', owner: '刘婷',
      priority: 'danger', state: 'pending'
    },
    {
      id: 'med-blood-pressure', category: 'medication', title: '晨间降压药复核', residentId: 'r5',
      resident: '李秀英', room: '3F-305',
      summary: '服药后复测血压并补充执行记录', time: '08:00', owner: '刘婷',
      priority: 'warning', state: 'pending'
    },
    {
      id: 'care-night-review', category: 'todo', title: '夜间不适评估', residentId: 'r2', resident: '周奶奶',
      room: '2F-215',
      summary: '夜间离床次数增加，午休前完成疼痛和睡眠观察', time: '09:46', owner: '王倩',
      priority: 'warning', state: 'pending'
    },
    {
      id: 'report-device', category: 'report', title: '床旁呼叫设备离线', residentId: 'r3', resident: '林爷爷',
      room: '3F-306',
      summary: '设备离线 18 分钟，需现场确认并向值班负责人反馈', time: '10:12', owner: '刘婷',
      priority: 'danger', state: 'pending'
    },
    {
      id: 'record-vital', category: 'record', title: '上午体征记录', residentId: 'r1', resident: '肖爷爷',
      room: '3F-302',
      summary: '血压、心率和血氧已同步，等待护理观察补充', time: '10:24', owner: '王倩',
      priority: 'normal', state: 'doing'
    },
    {
      id: 'family-callback', category: 'family', title: '家属回访 · 张建国', residentId: 'r5', resident: '李秀英',
      room: '3F-305',
      summary: '沟通近期睡眠和康复训练情况，记录后续诉求', time: '14:30', owner: '刘婷',
      priority: 'warning', state: 'pending'
    },
    {
      id: 'med-calcium', category: 'medication', title: '钙片 · 2片', residentId: 'r4', resident: '王德林',
      room: '2F-201',
      summary: '早餐后服用，执行时关注吞咽情况', time: '08:00', owner: '刘婷',
      priority: 'normal', state: 'done'
    },
    {
      id: 'record-turnover', category: 'record', title: '翻身护理记录', residentId: 'r2', resident: '周奶奶',
      room: '2F-215',
      summary: '翻身护理完成，皮肤状态无异常', time: '09:18', owner: '刘婷',
      priority: 'normal', state: 'done'
    },
    {
      id: 'family-confirm', category: 'family', title: '疼痛评估安排确认', residentId: 'r2', resident: '周奶奶',
      room: '2F-215',
      summary: '安排已向家属说明并完成确认', time: '09:46', owner: '王倩',
      priority: 'normal', state: 'done'
    },
    {
      id: 'report-handoff', category: 'report', title: '夜班异常交接', residentId: '', resident: '东区长者',
      room: '2F 东区',
      summary: '夜间巡查无新增高风险事件，交接摘要已整理', time: '07:20', owner: '夜班组',
      priority: 'normal', state: 'done'
    }
  ];

  private focusResidents: CareFocusResident[] = [
    {
      id: 'r1', name: '肖爷爷', room: '3F-302', note: '活动量下降，情绪需要陪伴观察',
      updatedAt: '10分钟前', priority: 'danger'
    },
    {
      id: 'r2', name: '周奶奶', room: '2F-215', note: '夜间离床增加，午休前复评',
      updatedAt: '24分钟前', priority: 'warning'
    },
    {
      id: 'r5', name: '李秀英', room: '3F-305', note: '用药后需要复测血压',
      updatedAt: '38分钟前', priority: 'warning'
    }
  ];

  private checkpoints: CareCheckpoint[] = [
    { id: 'checkpoint-handoff', time: '07:30', title: '早班交接', note: '重点风险已阅读', completed: true },
    { id: 'checkpoint-medication', time: '08:00', title: '晨间用药', note: '剩余 1 项待复核', completed: false },
    { id: 'checkpoint-round', time: '10:30', title: '东区巡房', note: '即将开始', completed: false },
    { id: 'checkpoint-family', time: '14:30', title: '家属沟通', note: '2 项待联系', completed: false }
  ];

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

  @Monitor('backRequestToken')
  onBackRequestTokenChange(): void {
    if (this.isTaskPanelOpen) {
      this.closeTaskPanel();
    }
  }

  aboutToAppear(): void {
    this.onShiftStateChange(this.isClockedIn, this.isClockedOut);
    this.reportTaskProgress();
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

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  private updateTaskPanelHeaderHeight(height: Length): void {
    let nextHeight: number = 0;
    if (typeof height === 'number') {
      nextHeight = height;
    } else if (typeof height === 'string') {
      nextHeight = parseFloat(height);
    }
    if (nextHeight > 0 && Math.abs(nextHeight - this.taskPanelHeaderHeight) > 0.5) {
      this.taskPanelHeaderHeight = nextHeight;
    }
  }

  private currentTimeText(): string {
    const hour: string = this.currentTime.getHours().toString().padStart(2, '0');
    const minute: string = this.currentTime.getMinutes().toString().padStart(2, '0');
    return hour + ':' + minute;
  }

  private dateText(): string {
    const weekNames: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return (this.currentTime.getMonth() + 1) + '月' + this.currentTime.getDate() + '日 · ' +
      weekNames[this.currentTime.getDay()];
  }

  private greetingText(): string {
    const hour: number = this.currentTime.getHours();
    if (hour < 11) {
      return '早上好，刘婷';
    }
    if (hour < 14) {
      return '中午好，刘婷';
    }
    if (hour < 18) {
      return '下午好，刘婷';
    }
    return '晚上好，刘婷';
  }

  private clockStatusText(): string {
    if (!this.isClockedIn) {
      return '尚未开始今日班次';
    }
    if (this.isClockedOut && this.clockInTime && this.clockOutTime) {
      return '今日班次已完成';
    }
    return '东区照护组 · 工作中';
  }

  private clockButtonLabel(): string {
    if (this.isClockedOut) {
      return '今日已完成';
    }
    return this.isClockedIn ? '下班打卡' : '上班打卡';
  }

  private handleClockAction(): void {
    if (!this.isClockedIn) {
      this.isClockedIn = true;
      this.clockInTime = new Date();
      this.onShiftStateChange(this.isClockedIn, this.isClockedOut);
      return;
    }
    if (!this.isClockedOut) {
      this.isClockedOut = true;
      this.clockOutTime = new Date();
      this.onShiftStateChange(this.isClockedIn, this.isClockedOut);
    }
  }

  private effectiveTaskState(task: CareTaskData): CareTaskState {
    if (this.completedTaskIds.includes(task.id)) {
      return 'done';
    }
    if (this.inProgressTaskIds.includes(task.id)) {
      return 'doing';
    }
    return task.state;
  }

  private tasksForFilter(filter: CareWorkFilter): CareTaskData[] {
    if (filter === 'todo') {
      return this.taskData.filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done');
    }
    if (filter === 'priority') {
      return this.taskData.filter((task: CareTaskData) =>
        this.effectiveTaskState(task) !== 'done' && task.priority === 'danger');
    }
    if (filter === 'completed') {
      return this.taskData.filter((task: CareTaskData) => this.effectiveTaskState(task) === 'done');
    }
    return this.taskData.filter((task: CareTaskData) => task.category === filter);
  }

  private visibleTasks(): CareTaskData[] {
    return this.tasksForFilter(this.activeFilter);
  }

  private taskFilterItems(): WideSlidingCapsuleItem[] {
    return [
      { title: '待办', index: 0, badgeText: this.tasksForFilter('todo').length.toString() },
      { title: '优先', index: 1, badgeText: this.tasksForFilter('priority').length.toString() },
      { title: '用药', index: 2, badgeText: this.tasksForFilter('medication').length.toString() },
      { title: '记录', index: 3, badgeText: this.tasksForFilter('record').length.toString() },
      { title: '家属', index: 4, badgeText: this.tasksForFilter('family').length.toString() },
      { title: '上报', index: 5, badgeText: this.tasksForFilter('report').length.toString() },
      { title: '完成', index: 6, badgeText: this.tasksForFilter('completed').length.toString() }
    ];
  }

  private filterIndex(): number {
    const filters: CareWorkFilter[] = ['todo', 'priority', 'medication', 'record', 'family', 'report', 'completed'];
    return filters.indexOf(this.activeFilter);
  }

  private selectFilter(index: number): void {
    const filters: CareWorkFilter[] = ['todo', 'priority', 'medication', 'record', 'family', 'report', 'completed'];
    this.activeFilter = filters[index] ?? 'todo';
  }

  private pendingCount(): number {
    return this.taskData.filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done').length;
  }

  private urgentCount(): number {
    return this.tasksForFilter('priority').length;
  }

  private completedCount(): number {
    return this.tasksForFilter('completed').length;
  }

  private progressPercent(): number {
    return Math.round(this.completedCount() / this.taskData.length * 100);
  }

  private reportTaskProgress(): void {
    this.onTaskProgressChange(this.completedCount(), this.taskData.length);
  }

  private selectedTask(): CareTaskData | undefined {
    return this.taskData.find((task: CareTaskData) => task.id === this.selectedTaskId);
  }

  private priorityText(priority: CarePriority): string {
    if (priority === 'danger') {
      return '优先';
    }
    if (priority === 'warning') {
      return '关注';
    }
    return '常规';
  }

  private priorityColor(priority: CarePriority): ResourceColor {
    if (priority === 'danger') {
      return $r('app.color.status_danger');
    }
    if (priority === 'warning') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.status_normal');
  }

  private priorityBackground(priority: CarePriority): ResourceColor {
    if (priority === 'danger') {
      return $r('app.color.status_danger_bg');
    }
    if (priority === 'warning') {
      return $r('app.color.status_warning_bg');
    }
    return $r('app.color.status_normal_bg');
  }

  private taskStateText(task: CareTaskData): string {
    const state: CareTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return '已完成';
    }
    if (state === 'doing') {
      return '进行中';
    }
    return task.time === '现在' ? '立即处理' : '待处理';
  }

  private taskStateColor(task: CareTaskData): ResourceColor {
    const state: CareTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return $r('app.color.status_normal');
    }
    if (state === 'doing') {
      return $r('app.color.brand_blue');
    }
    return this.priorityColor(task.priority);
  }

  private openTask(taskId: string): void {
    this.selectedTaskId = taskId;
    this.validationTaskId = '';
    if (this.isTaskPanelOpen) {
      return;
    }
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 328, 36)
    }, () => {
      this.isTaskPanelOpen = true;
      this.onTaskPanelVisibilityChange(true);
    });
  }

  private closeTaskPanel(): void {
    if (!this.isTaskPanelOpen) {
      return;
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.isTaskPanelOpen = false;
      this.onTaskPanelVisibilityChange(false);
    });
  }

  private taskNote(taskId: string): string {
    return this.noteDrafts.get(taskId) ?? '';
  }

  private updateTaskNote(taskId: string, value: string): void {
    const nextDrafts: Map<string, string> = new Map<string, string>(this.noteDrafts);
    nextDrafts.set(taskId, value);
    this.noteDrafts = nextDrafts;
    if (value.trim().length > 0 && this.validationTaskId === taskId) {
      this.validationTaskId = '';
    }
  }

  private taskActionLabel(task: CareTaskData): string {
    const state: CareTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return '已完成';
    }
    if (state === 'doing') {
      return '完成并记录';
    }
    return '开始处理';
  }

  private handleTaskAction(task: CareTaskData): void {
    const state: CareTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return;
    }
    if (state === 'pending') {
      this.inProgressTaskIds = [...this.inProgressTaskIds, task.id];
      return;
    }
    if (this.taskNote(task.id).trim().length === 0) {
      this.validationTaskId = task.id;
      return;
    }
    this.completedTaskIds = [...this.completedTaskIds, task.id];
    this.inProgressTaskIds = this.inProgressTaskIds.filter((id: string) => id !== task.id);
    this.validationTaskId = '';
    this.reportTaskProgress();
  }

  private executionSteps(task: CareTaskData): string[] {
    if (task.category === 'medication') {
      return ['核对长者、医嘱和药品', '确认剂量、时间与进食情况', '执行后观察并补充记录'];
    }
    if (task.category === 'family') {
      return ['查看最近护理记录', '仅沟通已确认的信息', '记录诉求和后续责任人'];
    }
    if (task.category === 'report') {
      return ['先确认现场安全状态', '记录事实、时间和已采取措施', '提交给对应负责人并跟进结果'];
    }
    return ['确认长者当前状态', '按护理要求完成处置', '记录结果和后续观察事项'];
  }

  @Builder
  private shiftCard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.greetingText())
            .fontSize(this.compactWidth ? 22 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('早班 · 东区照护组 · 负责 28 位长者')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 6 }) {
          Row()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.isClockedIn && !this.isClockedOut ?
              $r('app.color.status_normal') : $r('sys.color.icon_tertiary'))
          Text(this.clockStatusText())
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.isClockedIn && !this.isClockedOut ?
              $r('app.color.status_normal') : $r('sys.color.font_secondary'))
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 16 }) {
        Column({ space: 2 }) {
          Text(this.currentTimeText())
            .fontSize(this.compactWidth ? 42 : 48)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.dateText())
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(this.clockButtonLabel())
          .height(44)
          .padding({ left: 20, right: 20 })
          .borderRadius(22)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isClockedOut ? $r('sys.color.font_tertiary') : $r('app.color.text_on_brand'))
          .backgroundColor(this.isClockedOut ? $r('sys.color.comp_background_secondary') :
            (this.isClockedIn ? $r('app.color.status_danger') : $r('app.color.brand_blue')))
          .enabled(!this.isClockedOut)
          .keyboardFocusStyle()
          .onClick(() => this.handleClockAction())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        Row() {
          Text('班次进度')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          Text(this.completedCount() + ' / ' + this.taskData.length + ' 项完成')
            .fontSize($r('sys.float.Caption_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('sys.color.comp_background_secondary'))
          Row()
            .width(this.progressPercent() + '%')
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('app.color.brand_blue'))
        }
        .width('100%')
        .height(6)
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: 240 })
    .padding(this.compactWidth ? 20 : 24)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private aiFocusCard() {
    Column({ space: 18 }) {
      Row({ space: 10 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.AI_message'))
            .fontSize(20)
            .fontColor([$r('app.color.brand_blue')])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.ai_feed_background'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column({ space: 3 }) {
          AiTitleLabel({ text: '今日照护重点', compact: false })
          Text('根据本地演示数据整理 · 需要人工确认')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 6 }) {
            Text('继续对话')
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_blue'))
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([$r('app.color.brand_blue')])
          }
        }
        .height(38)
        .padding({ left: 14, right: 12 })
        .borderRadius(19)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .keyboardFocusStyle()
        .onClick(() => this.onOpenAiChat())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 0 }) {
        this.aiFocusRow('肖爷爷', '活动量下降且拒绝交流，建议 20 分钟内由熟悉人员接手', '立即关注', 'danger', false)
        this.aiFocusRow('周奶奶', '夜间离床次数增加，午休前补充疼痛与睡眠观察', '午休前', 'warning', false)
        this.aiFocusRow('东区设备', '1 台床旁呼叫设备离线，先现场确认再上报', '18 分钟', 'warning', true)
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: 240 })
    .padding(this.compactWidth ? 20 : 24)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .geometryTransition('aiReminderCard', { follow: true })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private aiFocusRow(name: string, detail: string, timeLabel: string, priority: CarePriority, isLast: boolean) {
    Row({ space: 12 }) {
      Row()
        .width(4)
        .height(38)
        .borderRadius(2)
        .backgroundColor(this.priorityColor(priority))

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(name)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(timeLabel)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.priorityColor(priority))
        }
        Text(detail)
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 10, bottom: isLast ? 2 : 10 })
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private metricCard(label: string, value: string, note: string, symbol: Resource,
    valueColor: ResourceColor, targetFilter: CareWorkFilter) {
    Row({ space: 14 }) {
      Row() {
        SymbolGlyph(symbol)
          .fontSize(20)
          .fontColor([valueColor])
      }
      .width(42)
      .height(42)
      .borderRadius(14)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Column({ space: 3 }) {
        Row({ space: 7 }) {
          Text(value)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(valueColor)
          Text(label)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .alignItems(VerticalAlign.Bottom)
        Text(note)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .height(82)
    .padding({ left: 16, right: 14 })
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .keyboardFocusStyle()
    .accessibilityText(label + '，' + value + '，' + note)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.activeFilter = targetFilter;
      this.pageScroller.scrollEdge(Edge.Bottom);
    }))
    .onClick(() => {
      this.activeFilter = targetFilter;
      this.pageScroller.scrollEdge(Edge.Bottom);
    })
  }

  @Builder
  private metricsRow() {
    GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
      GridCol({ span: this.compactWidth ? 6 : 3 }) {
        this.metricCard('待处理', this.pendingCount().toString(), '按风险和时间排序',
          $r('sys.symbol.calendar_badge_clock'), $r('app.color.brand_blue'), 'todo')
      }
      GridCol({ span: this.compactWidth ? 6 : 3 }) {
        this.metricCard('优先事项', this.urgentCount().toString(), '需要尽快人工确认',
          $r('sys.symbol.exclamationmark_triangle_fill'), $r('app.color.status_danger'), 'priority')
      }
      GridCol({ span: this.compactWidth ? 6 : 3 }) {
        this.metricCard('用药任务', this.tasksForFilter('medication').length.toString(), '1 项等待复核',
          $r('sys.symbol.doc_text'), $r('app.color.status_warning'), 'medication')
      }
      GridCol({ span: this.compactWidth ? 6 : 3 }) {
        this.metricCard('班次完成', this.progressPercent() + '%', this.completedCount() + ' 项已留痕',
          $r('sys.symbol.checkmark_circle_fill'), $r('app.color.status_normal'), 'completed')
      }
    }
    .width('100%')
  }

  @Builder
  private taskQueueCard() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text('今日工作')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('沿用手机端入口，按当前班次优先级整理')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.visibleTasks().length + ' 项')
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor($r('sys.color.comp_background_secondary'))
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 22, bottom: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        WideSlidingCapsule({
          items: this.taskFilterItems(),
          selectedIndex: this.filterIndex(),
          itemWidth: this.compactWidth ? 76 : 88,
          onSelect: (index: number) => this.selectFilter(index)
        })
      }
      .width('100%')
      .padding({ left: 22, right: 22, bottom: 14 })
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      if (this.visibleTasks().length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(34)
            .fontColor([$r('app.color.status_normal')])
          Text('当前分类暂无工作事项')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column({ space: 4 }) {
          ForEach(this.visibleTasks(), (task: CareTaskData) => {
            this.taskQueueRow(task)
          }, (task: CareTaskData) => task.id)
        }
        .width('100%')
        .padding({ left: 10, right: 10, bottom: 12 })
      }
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private taskQueueRow(task: CareTaskData) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(task.time)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(task.time === '现在' ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(task.time === '现在' ? $r('app.color.status_danger') : $r('sys.color.font_primary'))
        Text(task.room)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width(62)
      .alignItems(HorizontalAlign.Start)

      Row()
        .width(4)
        .height(42)
        .borderRadius(2)
        .backgroundColor(this.priorityColor(task.priority))

      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(task.title)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(task.resident)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .width('100%')
        Text(task.summary)
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 5 }) {
        Text(this.taskStateText(task))
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.taskStateColor(task))
        Text(task.owner)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.End)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .height(78)
    .padding({ left: 14, right: 14 })
    .borderRadius(14)
    .backgroundColor(this.hoveredTaskId === task.id ? $r('sys.color.interactive_hover') : Color.Transparent)
    .keyboardFocusStyle()
    .accessibilityText(task.time + '，' + task.resident + '，' + task.title + '，' + this.taskStateText(task))
    .onFocus(() => this.focusedTarget = task.id)
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.hoveredTaskId = isHover ? task.id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.openTask(task.id)))
    .onClick(() => this.openTask(task.id))
  }

  @Builder
  private focusResidentCard() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text('重点长者')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('本班次需要持续观察')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            Text('全部长者')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.brand_blue'))
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([$r('app.color.brand_blue')])
          }
        }
        .height(36)
        .padding({ left: 12, right: 10 })
        .borderRadius(18)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .keyboardFocusStyle()
        .onClick(() => this.onOpenResident(''))
      }
      .width('100%')
      .padding({ left: 20, right: 18, top: 20, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      ForEach(this.focusResidents, (resident: CareFocusResident, index: number) => {
        this.focusResidentRow(resident, index === this.focusResidents.length - 1)
      }, (resident: CareFocusResident) => resident.id)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
  }

  @Builder
  private focusResidentRow(resident: CareFocusResident, isLast: boolean) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Text(resident.name.slice(0, 1))
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width(42)
          .height(42)
          .textAlign(TextAlign.Center)
          .borderRadius(21)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        Row()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.priorityColor(resident.priority))
      }
      .width(42)
      .height(42)

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(resident.name)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(resident.room)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        Text(resident.note)
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(resident.updatedAt)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('calc(100% - 24vp)')
    .height(72)
    .margin({ left: 12, right: 12 })
    .padding({ left: 8, right: 8 })
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .backgroundColor(this.hoveredResidentId === resident.id ? $r('sys.color.interactive_hover') : Color.Transparent)
    .borderRadius(12)
    .keyboardFocusStyle()
    .accessibilityText(resident.name + '，' + resident.room + '，' + resident.note)
    .onHover((isHover: boolean) => this.hoveredResidentId = isHover ? resident.id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.onOpenResident(resident.id)))
    .onClick(() => this.onOpenResident(resident.id))
  }

  @Builder
  private checkpointCard() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text('今日护理节奏')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('按照班次节点安排，不替代人工判断')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 })

      ForEach(this.checkpoints, (checkpoint: CareCheckpoint, index: number) => {
        this.checkpointRow(checkpoint, index === this.checkpoints.length - 1)
      }, (checkpoint: CareCheckpoint) => checkpoint.id)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
  }

  @Builder
  private checkpointRow(checkpoint: CareCheckpoint, isLast: boolean) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(checkpoint.time)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(checkpoint.completed ? $r('app.color.status_normal') : $r('sys.color.font_primary'))
        Text(checkpoint.completed ? '完成' : '计划')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width(54)
      .alignItems(HorizontalAlign.Start)

      Stack({ alignContent: Alignment.Top }) {
        if (!isLast) {
          Row()
            .width(1)
            .height(54)
            .backgroundColor($r('sys.color.comp_divider'))
            .margin({ top: 12 })
        }
        Row() {
          if (checkpoint.completed) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([$r('app.color.status_normal')])
          } else {
            Row()
              .width(10)
              .height(10)
              .borderRadius(5)
              .backgroundColor($r('app.color.brand_blue'))
          }
        }
        .width(18)
        .height(18)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width(18)
      .height(58)

      Column({ space: 4 }) {
        Text(checkpoint.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(checkpoint.note)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(66)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private mainWorkArea() {
    GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
      GridCol({ span: this.compactWidth ? 12 : 8 }) {
        this.taskQueueCard()
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        Column({ space: 16 }) {
          this.focusResidentCard()
          this.checkpointCard()
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private taskDetailPanel(task: CareTaskData) {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(this.priorityText(task.priority))
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.priorityColor(task.priority))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(8)
              .backgroundColor(this.priorityBackground(task.priority))
            Text(this.taskStateText(task))
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.taskStateColor(task))
          }
          Text(task.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .keyboardFocusStyle()
        .accessibilityText('关闭任务详情')
        .onClick(() => this.closeTaskPanel())
      }
      .width('100%')
      .constraintSize({ minHeight: 88 })
      .padding({ left: 22, right: 18, top: 22, bottom: 18 })
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
      .margin({ top: this.topBarHeight })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .alignItems(VerticalAlign.Top)
      .zIndex(1)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.updateTaskPanelHeaderHeight(newValue.height);
      })

      Scroll(this.taskDetailScroller) {
        Column({ space: 18 }) {
          Column({ space: 10 }) {
            Text(task.summary)
              .width('100%')
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('sys.color.font_secondary'))
            Row({ space: 10 }) {
              Text(task.time)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text('责任人 ' + task.owner)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_tertiary'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 12 }) {
            Text('关联长者')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))

            Row({ space: 12 }) {
              Text(task.resident.slice(0, 1))
                .width(44)
                .height(44)
                .borderRadius(22)
                .textAlign(TextAlign.Center)
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .backgroundColor($r('sys.color.comp_background_secondary'))
              Column({ space: 4 }) {
                Text(task.resident)
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(task.room + ' · 最近护理记录已同步')
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(14)
                .fontColor([$r('sys.color.icon_tertiary')])
            }
            .width('100%')
            .height(64)
            .padding({ left: 10, right: 10 })
            .borderRadius(14)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .keyboardFocusStyle()
            .onClick(() => {
              this.closeTaskPanel();
              this.onOpenResident(task.residentId);
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('执行要点')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            ForEach(this.executionSteps(task), (step: string, index: number) => {
              Row({ space: 10 }) {
                Text((index + 1).toString())
                  .width(24)
                  .height(24)
                  .borderRadius(12)
                  .textAlign(TextAlign.Center)
                  .fontSize($r('sys.float.Caption_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_blue'))
                  .backgroundColor($r('sys.color.comp_background_secondary'))
                Text(step)
                  .layoutWeight(1)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_primary'))
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }, (step: string, index: number) => task.id + '-step-' + index)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('处理记录')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            if (this.effectiveTaskState(task) === 'done') {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([$r('app.color.status_normal')])
                Text('记录已提交，可在长者档案中查看')
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .width('100%')
              .height(48)
              .alignItems(VerticalAlign.Center)
            } else {
              TextArea({
                text: this.taskNote(task.id),
                placeholder: '记录观察情况、处置结果或后续跟进事项'
              })
                .width('100%')
                .height(104)
                .padding(12)
                .fontSize($r('sys.float.Body_M'))
                .backgroundColor($r('sys.color.comp_background_secondary'))
                .borderRadius(14)
                .maxLength(200)
                .onChange((value: string) => this.updateTaskNote(task.id, value))

              if (this.validationTaskId === task.id) {
                Text('请先填写处理记录，再完成当前工作')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('app.color.status_danger'))
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.AI_message'))
                .fontSize(18)
                .fontColor([$r('app.color.brand_blue')])
              Text('康小伴建议')
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
            }
            Text('先确认长者当前安全状态，再按护理要求执行；异常信息需要人工判断并完整记录。')
              .width('100%')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .contentStartOffset(this.topBarHeight + this.taskPanelHeaderHeight)
      .contentEndOffset(70 + this.naviIndicatorHeight)
      .align(Alignment.TopStart)

      Column() {
        Row({ space: 10 }) {
          Button('查看长者')
            .width(118)
            .height(42)
            .borderRadius(21)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .keyboardFocusStyle()
            .onClick(() => {
              this.closeTaskPanel();
              this.onOpenResident(task.residentId);
            })

          Button(this.taskActionLabel(task))
            .layoutWeight(1)
            .height(42)
            .borderRadius(21)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.effectiveTaskState(task) === 'done' ? $r('sys.color.font_tertiary') :
              $r('app.color.text_on_brand'))
            .backgroundColor(this.effectiveTaskState(task) === 'done' ? $r('sys.color.comp_background_secondary') :
              $r('app.color.brand_blue'))
            .enabled(this.effectiveTaskState(task) !== 'done')
            .keyboardFocusStyle()
            .onClick(() => this.handleTaskAction(task))
        }
        .width('100%')
        .height(70 + this.naviIndicatorHeight)
        .padding({ left: 18, right: 18, bottom: this.naviIndicatorHeight })
        .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.None)
      .zIndex(1)
    }
    .width(this.compactWidth ? '88%' : 456)
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll(this.pageScroller) {
        Column({ space: 16 }) {
          GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
            GridCol({ span: this.compactWidth ? 12 : 4 }) {
              this.shiftCard()
            }
            GridCol({ span: this.compactWidth ? 12 : 8 }) {
              this.aiFocusCard()
            }
          }
          .width('100%')

          this.metricsRow()
          this.mainWorkArea()
        }
        .width('100%')
        .constraintSize({ maxWidth: 1440 })
        .padding({
          left: this.compactWidth ? 16 : 24,
          right: this.compactWidth ? 16 : 24,
          top: this.compactWidth ? 16 : 20,
          bottom: 28 + this.naviIndicatorHeight
        })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .contentStartOffset(this.topBarHeight)
      .backgroundColor($r('sys.color.background_secondary'))

      if (this.isTaskPanelOpen && this.selectedTask() !== undefined) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.closeTaskPanel())

        this.taskDetailPanel(this.selectedTask()!)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
