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
type WideTaskCategory = 'care' | 'medication' | 'record' | 'family';
type WideTaskState = 'pending' | 'inProgress' | 'done';
type WideTaskView = 'all' | 'priority' | 'care' | 'medication' | 'record' | 'family' | 'done';

interface WideClinicalTask {
  id: string;
  category: WideTaskCategory;
  title: string;
  resident: string;
  location: string;
  detail: string;
  time: string;
  owner: string;
  status: string;
  state: WideTaskState;
  level: WideStatus;
}

interface WideTaskViewItem {
  id: WideTaskView;
  label: string;
  count: number;
}

interface WideResidentContext {
  age: string;
  careLevel: string;
  diagnosis: string;
  risk: string;
  vital: string;
  lastRecord: string;
}

@ComponentV2
export struct WideHomePage {
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenResident: () => void = () => {};
  @Local currentTime: Date = new Date();
  @Local isClockedIn: boolean = false;
  @Local isClockedOut: boolean = false;
  @Local clockInTime: Date | null = null;
  @Local clockOutTime: Date | null = null;
  @Local activeView: WideTaskView = 'all';
  @Local selectedTaskId: string = 'todo-emotion';
  @Local hoveredTaskId: string = '';
  @Local hoveredView: WideTaskView | '' = '';
  @Local inProgressTaskIds: string[] = [];
  @Local completedTaskIds: string[] = [];
  @Local noteDrafts: Map<string, string> = new Map<string, string>();
  @Local validationTaskId: string = '';
  @Local isClockButtonHovered: boolean = false;
  @Local isAiSuggestionHovered: boolean = false;
  private timerId: number = -1;

  private taskData: WideClinicalTask[] = [
    {
      id: 'todo-emotion', category: 'care', title: '情绪安抚与人工接手', resident: '肖爷爷',
      location: '3F-302', detail: '活动量下降 41%，拒绝交流，需要熟悉护工优先接手', time: '现在',
      owner: '刘婷', status: '待处理', state: 'pending', level: 'danger'
    },
    {
      id: 'todo-assessment', category: 'care', title: '夜间不适评估', resident: '周奶奶',
      location: '2F-215', detail: '夜间离床次数增加，午休前完成疼痛与睡眠评估', time: '09:46',
      owner: '王倩', status: '待处理', state: 'pending', level: 'warning'
    },
    {
      id: 'med-1', category: 'medication', title: '降压药 · 1片', resident: '李秀英',
      location: '3F-305', detail: '服药后复测血压并补充用药记录', time: '08:00',
      owner: '刘婷', status: '待服用', state: 'pending', level: 'warning'
    },
    {
      id: 'med-2', category: 'medication', title: '钙片 · 2片', resident: '王德林',
      location: '2F-201', detail: '早餐后服用，注意吞咽情况', time: '08:00',
      owner: '刘婷', status: '待服用', state: 'pending', level: 'neutral'
    },
    {
      id: 'todo-round', category: 'care', title: '半护理上午巡房', resident: '李奶奶',
      location: '2F-208', detail: '检查房间安全、卧位与呼叫设备状态', time: '10:00',
      owner: '刘婷', status: '待处理', state: 'pending', level: 'neutral'
    },
    {
      id: 'med-3', category: 'medication', title: '二甲双胍 · 0.5g', resident: '张明华',
      location: '3F-302', detail: '午餐后服用，确认进食情况后执行', time: '12:00',
      owner: '王倩', status: '待服用', state: 'pending', level: 'warning'
    },
    {
      id: 'family-1', category: 'family', title: '家属回访 · 张建国', resident: '李秀英',
      location: '3F-305', detail: '沟通近期睡眠和康复训练情况', time: '今天',
      owner: '刘婷', status: '待回访', state: 'pending', level: 'warning'
    },
    {
      id: 'family-2', category: 'family', title: '家属联系 · 李秀兰', resident: '王德林',
      location: '2F-201', detail: '确认下周探视时间与陪诊安排', time: '今天',
      owner: '刘婷', status: '待联系', state: 'pending', level: 'neutral'
    },
    {
      id: 'family-3', category: 'family', title: '未接来电回拨 · 林涛', resident: '林爷爷',
      location: '3F-306', detail: '家属来电未接通，需要尽快回拨确认事项', time: '09:12',
      owner: '王倩', status: '未接通', state: 'pending', level: 'danger'
    },
    {
      id: 'record-1', category: 'record', title: '体征测量', resident: '肖爷爷',
      location: '3F-302', detail: '血压、心率和血氧数据已同步', time: '10:24',
      owner: '王倩', status: '已记录', state: 'done', level: 'normal'
    },
    {
      id: 'record-2', category: 'record', title: '翻身护理', resident: '周奶奶',
      location: '2F-215', detail: '翻身护理完成，皮肤状态无异常', time: '09:46',
      owner: '刘婷', status: '已记录', state: 'done', level: 'normal'
    },
    {
      id: 'record-3', category: 'record', title: '用药执行', resident: '林爷爷',
      location: '3F-306', detail: '晨间用药已执行并完成复核', time: '09:12',
      owner: '王倩', status: '已记录', state: 'done', level: 'normal'
    },
    {
      id: 'record-4', category: 'record', title: '夜间巡查', resident: '东区长者',
      location: '2F 东区', detail: '36 位长者夜间安全巡查已完成', time: '06:30',
      owner: '夜班组', status: '已记录', state: 'done', level: 'normal'
    },
    {
      id: 'med-4', category: 'medication', title: '维生素 D · 1粒', resident: '肖爷爷',
      location: '3F-302', detail: '药品和用药记录已完成双人核对', time: '07:00',
      owner: '刘婷', status: '已完成', state: 'done', level: 'normal'
    },
    {
      id: 'family-4', category: 'family', title: '家属沟通确认 · 周敏', resident: '周奶奶',
      location: '2F-215', detail: '疼痛评估安排已向家属说明并确认', time: '09:46',
      owner: '王倩', status: '已确认', state: 'done', level: 'normal'
    }
  ];

  private residentContextData: Record<string, WideResidentContext> = {
    '肖爷爷': {
      age: '82岁', careLevel: '一级护理', diagnosis: '高血压 · 2型糖尿病',
      risk: '跌倒高风险 · 情绪关注', vital: '血压 138/85 · 心率 72', lastRecord: '10:24 体征测量已记录'
    },
    '周奶奶': {
      age: '78岁', careLevel: '二级护理', diagnosis: '冠心病 · 骨质疏松',
      risk: '夜间离床增加', vital: '血压 125/80 · 心率 78', lastRecord: '09:46 翻身护理已记录'
    },
    '李秀英': {
      age: '81岁', careLevel: '二级护理', diagnosis: '高血压 · 术后康复',
      risk: '用药后需复测血压', vital: '血压 136/82 · 心率 70', lastRecord: '08:30 早餐协助已完成'
    },
    '王德林': {
      age: '79岁', careLevel: '三级护理', diagnosis: '骨质疏松',
      risk: '吞咽情况需观察', vital: '血压 121/76 · 心率 68', lastRecord: '08:10 晨间护理已完成'
    },
    '李奶奶': {
      age: '80岁', careLevel: '二级护理', diagnosis: '高血压',
      risk: '房间安全常规检查', vital: '血压 128/79 · 心率 73', lastRecord: '08:20 起床护理已完成'
    },
    '张明华': {
      age: '76岁', careLevel: '二级护理', diagnosis: '2型糖尿病 · 高血压',
      risk: '用药前确认进食情况', vital: '餐前血糖 7.2 mmol/L', lastRecord: '10:15 血糖测量已记录'
    },
    '林爷爷': {
      age: '85岁', careLevel: '一级护理', diagnosis: '脑梗后遗症 · 高血压',
      risk: '活动量偏低 · 社交回避', vital: '血压 142/88 · 心率 70', lastRecord: '09:12 用药执行已记录'
    },
    '东区长者': {
      age: '36位', careLevel: '分区管理', diagnosis: '夜间集中巡查',
      risk: '无新增高风险事件', vital: '设备在线率 98%', lastRecord: '06:30 夜间巡查已记录'
    }
  };

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

  private dateText(): string {
    const weekNames: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${this.currentTime.getMonth() + 1}月${this.currentTime.getDate()}日 ${weekNames[this.currentTime.getDay()]}`;
  }

  private shortTime(date: Date): string {
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
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
    return this.isClockedIn && !this.isClockedOut ? $r('app.color.status_normal') :
      $r('sys.color.font_secondary');
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
      return;
    }
    if (!this.isClockedOut) {
      this.isClockedOut = true;
      this.clockOutTime = new Date();
    }
  }

  private effectiveTaskState(task: WideClinicalTask): WideTaskState {
    if (this.completedTaskIds.includes(task.id)) {
      return 'done';
    }
    if (this.inProgressTaskIds.includes(task.id)) {
      return 'inProgress';
    }
    return task.state;
  }

  private tasksForView(view: WideTaskView): WideClinicalTask[] {
    if (view === 'all') {
      return this.taskData;
    }
    if (view === 'priority') {
      return this.taskData.filter((task: WideClinicalTask) =>
        this.effectiveTaskState(task) !== 'done' && (task.level === 'danger' || task.level === 'warning'));
    }
    if (view === 'done') {
      return this.taskData.filter((task: WideClinicalTask) => this.effectiveTaskState(task) === 'done');
    }
    return this.taskData.filter((task: WideClinicalTask) => task.category === view);
  }

  private visibleTasks(): WideClinicalTask[] {
    return this.tasksForView(this.activeView);
  }

  private taskViewItems(): WideTaskViewItem[] {
    return [
      { id: 'all', label: '全部工作', count: this.tasksForView('all').length },
      { id: 'priority', label: '优先处理', count: this.tasksForView('priority').length },
      { id: 'care', label: '护理任务', count: this.tasksForView('care').length },
      { id: 'medication', label: '用药执行', count: this.tasksForView('medication').length },
      { id: 'record', label: '护理记录', count: this.tasksForView('record').length },
      { id: 'family', label: '家属沟通', count: this.tasksForView('family').length },
      { id: 'done', label: '已完成', count: this.tasksForView('done').length }
    ];
  }

  private activeViewLabel(): string {
    const active: WideTaskViewItem | undefined =
      this.taskViewItems().find((item: WideTaskViewItem) => item.id === this.activeView);
    return active?.label ?? '全部工作';
  }

  private selectView(view: WideTaskView): void {
    this.activeView = view;
    const tasks: WideClinicalTask[] = this.tasksForView(view);
    if (tasks.length > 0) {
      this.selectedTaskId = tasks[0].id;
    }
  }

  private selectedTask(): WideClinicalTask {
    const selected: WideClinicalTask | undefined =
      this.taskData.find((task: WideClinicalTask) => task.id === this.selectedTaskId);
    return selected ?? this.taskData[0];
  }

  private categoryLabel(category: WideTaskCategory): string {
    if (category === 'medication') {
      return '用药';
    }
    if (category === 'record') {
      return '记录';
    }
    if (category === 'family') {
      return '家属';
    }
    return '护理';
  }

  private priorityLabel(level: WideStatus): string {
    if (level === 'danger') {
      return '紧急';
    }
    if (level === 'warning') {
      return '关注';
    }
    return '常规';
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

  private taskStatusText(task: WideClinicalTask): string {
    const state: WideTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return '已完成';
    }
    if (state === 'inProgress') {
      if (task.category === 'medication') {
        return '执行中';
      }
      if (task.category === 'family') {
        return '联系中';
      }
      return '处理中';
    }
    return task.status;
  }

  private taskStatusColor(task: WideClinicalTask): ResourceColor {
    const state: WideTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return $r('app.color.status_normal');
    }
    if (state === 'inProgress') {
      return $r('app.color.brand_blue');
    }
    return this.statusColor(task.level);
  }

  private taskRowBackground(taskId: string): ResourceColor {
    if (this.selectedTaskId === taskId) {
      return $r('sys.color.comp_background_secondary');
    }
    if (this.hoveredTaskId === taskId) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  private viewRowBackground(view: WideTaskView): ResourceColor {
    if (this.activeView === view) {
      return $r('sys.color.comp_background_secondary');
    }
    if (this.hoveredView === view) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  private residentContext(task: WideClinicalTask): WideResidentContext {
    return this.residentContextData[task.resident] ?? {
      age: '--', careLevel: '常规护理', diagnosis: '暂无诊断摘要',
      risk: '暂无新增风险', vital: '暂无最新体征', lastRecord: '暂无相关记录'
    };
  }

  private executionSteps(task: WideClinicalTask): string[] {
    if (task.category === 'medication') {
      return ['核对长者身份、医嘱和药品', '确认剂量、时间与给药方式', '执行后观察反应并留存记录'];
    }
    if (task.category === 'family') {
      return ['确认联系人与本次沟通事项', '完成联系并记录关键信息', '需要时生成后续跟进任务'];
    }
    if (task.category === 'record') {
      return ['核对记录对象和执行时间', '检查数据完整性与异常项', '提交记录并完成复核'];
    }
    return ['确认长者当前状态与环境安全', '按任务要求完成护理处置', '记录结果、异常和后续安排'];
  }

  private aiSuggestion(task: WideClinicalTask): string {
    if (task.id === 'todo-emotion') {
      return '建议由熟悉肖爷爷日常习惯的护工先进行短时陪伴，避免连续追问；若拒绝交流持续，请记录诱因并升级给责任护士。';
    }
    if (task.category === 'medication') {
      return '执行前请结合医嘱、进食情况和最近体征人工确认；用药后按任务要求完成观察与复测。';
    }
    if (task.category === 'family') {
      return '建议先查看最近护理记录，沟通时只反馈已确认信息，并在结束后补充家属诉求与后续责任人。';
    }
    if (task.category === 'record') {
      return '该任务已完成，可重点检查时间、执行人和异常描述是否完整，避免记录缺项。';
    }
    return '建议先确认长者当前安全状态，再按护理要求执行；异常信息需人工判断并完整记录。';
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

  private primaryActionLabel(task: WideClinicalTask): string {
    const state: WideTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return '已完成';
    }
    if (state === 'inProgress') {
      return task.category === 'medication' ? '提交执行记录' : '完成并记录';
    }
    if (task.category === 'medication') {
      return '进入执行';
    }
    if (task.category === 'family') {
      return '开始联系';
    }
    return '开始处理';
  }

  private handlePrimaryAction(task: WideClinicalTask): void {
    const state: WideTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return;
    }
    if (state === 'pending') {
      this.inProgressTaskIds = [...this.inProgressTaskIds, task.id];
      this.validationTaskId = '';
      return;
    }
    if (this.taskNote(task.id).trim().length === 0) {
      this.validationTaskId = task.id;
      return;
    }
    this.completedTaskIds = [...this.completedTaskIds, task.id];
    this.inProgressTaskIds = this.inProgressTaskIds.filter((id: string) => id !== task.id);
    this.validationTaskId = '';
    const remaining: WideClinicalTask[] = this.tasksForView(this.activeView);
    if (!remaining.some((item: WideClinicalTask) => item.id === task.id) && remaining.length > 0) {
      this.selectedTaskId = remaining[0].id;
    }
  }

  @Builder
  private taskViewPane() {
    Column({ space: 0 }) {
      Row() {
        Text('任务视图')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .height(60)
      .padding({ left: 18, right: 18 })
      .alignItems(VerticalAlign.Center)

      List({ space: 2 }) {
        Repeat(this.taskViewItems()).each((repeatItem: RepeatItem<WideTaskViewItem>) => {
          ListItem() {
            this.taskViewRow(repeatItem.item)
          }
        }).key((item: WideTaskViewItem) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 4, bottom: 8 })
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)

      Row() {
        Text(`当前 ${this.visibleTasks().length} 项`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 18, right: 18 })
      .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
      .alignItems(VerticalAlign.Center)
    }
    .width(224)
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private taskViewRow(item: WideTaskViewItem) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        Text(item.label)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(this.activeView === item.id ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(item.id === 'priority' && this.activeView !== item.id ? $r('app.color.status_danger') :
            $r('sys.color.font_primary'))
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.count.toString())
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .width(28)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 20vp)')
    .height(46)
    .margin({ left: 10, right: 10 })
    .backgroundColor(this.viewRowBackground(item.id))
    .borderRadius(10)
    .keyboardFocusStyle()
    .accessibilitySelected(this.activeView === item.id)
    .onHover((isHover: boolean) => {
      this.hoveredView = isHover ? item.id : '';
    })
    .onClick(() => {
      this.selectView(item.id);
    })
  }

  @Builder
  private taskQueuePane() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Row({ space: 10 }) {
            Text(this.activeViewLabel())
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text(`${this.visibleTasks().length} 项`)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          Text(`${this.dateText()} · 共 ${this.taskData.length} 项护理工作`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 8 }) {
          Column()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.clockStatusColor())
          Text(this.clockStatusText())
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .constraintSize({ minWidth: 132, maxWidth: 190 })
        .alignItems(VerticalAlign.Center)

        Button(this.clockButtonLabel())
          .width(104)
          .height(36)
          .borderRadius(18)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isClockedOut ? $r('sys.color.font_tertiary') : $r('app.color.text_on_brand'))
          .backgroundColor(this.isClockedOut ? $r('sys.color.comp_background_secondary') :
            $r('app.color.brand_blue'))
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
      .height(72)
      .padding({ left: 20, right: 16 })
      .alignItems(VerticalAlign.Center)

      this.taskTableHeader()

      if (this.visibleTasks().length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(28)
            .fontColor([$r('sys.color.icon_tertiary')])
          Text('当前视图没有工作项')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 4 }) {
          Repeat(this.visibleTasks()).each((repeatItem: RepeatItem<WideClinicalTask>) => {
            ListItem() {
              this.taskQueueRow(repeatItem.item)
            }
          }).virtualScroll().key((task: WideClinicalTask) => task.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: 6, bottom: 8 })
        .cachedCount(8)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private taskTableHeader() {
    Row({ space: 0 }) {
      Text('时间')
        .width(58)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('优先级')
        .width(56)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('长者 / 房间')
        .width(132)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('工作内容')
        .layoutWeight(1)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('状态')
        .width(76)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('责任人')
        .width(64)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text('处理')
        .width(52)
        .textAlign(TextAlign.End)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('calc(100% - 16vp)')
    .height(40)
    .margin({ left: 8, right: 8 })
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private taskQueueRow(task: WideClinicalTask) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 0 }) {
        Text(task.time)
          .width(58)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(task.time === '现在' ? $r('app.color.status_danger') : $r('sys.color.font_secondary'))
          .maxLines(1)

        Text(this.priorityLabel(task.level))
          .width(56)
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(task.level === 'danger' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.statusColor(task.level))
          .maxLines(1)

        Column({ space: 3 }) {
          Text(task.resident)
            .width('100%')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(task.location)
            .width('100%')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
        }
        .width(132)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 3 }) {
          Text(task.title)
            .width('100%')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(task.detail)
            .width('100%')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .padding({ right: 10 })
        .alignItems(HorizontalAlign.Start)

        Text(this.taskStatusText(task))
          .width(76)
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.taskStatusColor(task))
          .maxLines(1)

        Text(task.owner)
          .width(64)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 3 }) {
          Text(this.effectiveTaskState(task) === 'done' ? '查看' : '处理')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.effectiveTaskState(task) === 'done' ? $r('sys.color.font_secondary') :
              $r('app.color.brand_blue'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(13)
            .fontColor([this.effectiveTaskState(task) === 'done' ? $r('sys.color.icon_tertiary') :
              $r('app.color.brand_blue')])
        }
        .width(52)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 16vp)')
    .height(68)
    .margin({ left: 8, right: 8 })
    .backgroundColor(this.taskRowBackground(task.id))
    .borderRadius(10)
    .hoverEffect(HoverEffect.None)
    .keyboardFocusStyle()
    .accessibilitySelected(this.selectedTaskId === task.id)
    .onHover((isHover: boolean) => {
      this.hoveredTaskId = isHover ? task.id : '';
    })
    .onClick(() => {
      this.selectedTaskId = task.id;
      this.validationTaskId = '';
    })
  }

  @Builder
  private taskInspectorPane(task: WideClinicalTask) {
    Column({ space: 0 }) {
      Scroll() {
        Column({ space: 0 }) {
          this.taskInspectorHeader(task)
          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.residentContextSection(task)
          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.executionSection(task)
          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.noteSection(task)
          this.aiSuggestionSection(task)
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)

      this.inspectorActionBar(task)
    }
    .width(400)
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private taskInspectorHeader(task: WideClinicalTask) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.categoryLabel(task.category))
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.priorityLabel(task.level))
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(task.level))
        Blank()
        Text(this.taskStatusText(task))
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.taskStatusColor(task))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(task.title)
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(task.detail)
        .width('100%')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 20 }) {
        Text(`时间 ${task.time}`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
        Text(`责任人 ${task.owner}`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private residentContextSection(task: WideClinicalTask) {
    Column({ space: 14 }) {
      Text('长者信息')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      Row({ space: 12 }) {
        Text(task.resident.slice(0, 1))
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width(42)
          .height(42)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(21)

        Column({ space: 4 }) {
          Text(task.resident)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`${task.location} · ${this.residentContext(task).age} · ${this.residentContext(task).careLevel}`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 0 }) {
        this.contextMetric('诊断摘要', this.residentContext(task).diagnosis)
        Divider()
          .vertical(true)
          .height(44)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.contextMetric('关键风险', this.residentContext(task).risk)
      }
      .width('100%')

      Row({ space: 0 }) {
        this.contextMetric('最近体征', this.residentContext(task).vital)
        Divider()
          .vertical(true)
          .height(44)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.contextMetric('最近记录', this.residentContext(task).lastRecord)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 18 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private contextMetric(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
      Text(value)
        .width('100%')
        .fontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 8, right: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private executionSection(task: WideClinicalTask) {
    Column({ space: 8 }) {
      Text('执行要点')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      ForEach(this.executionSteps(task), (step: string, index: number) => {
        Row({ space: 10 }) {
          Text((index + 1).toString())
            .fontSize($r('sys.float.Caption_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .width(22)
            .height(22)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .borderRadius(11)
          Text(step)
            .layoutWeight(1)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(38)
        .alignItems(VerticalAlign.Center)
      }, (step: string, index: number) => `${task.id}-${index}-${step}`)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private noteSection(task: WideClinicalTask) {
    Column({ space: 8 }) {
      Text('处理记录')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      if (this.effectiveTaskState(task) === 'done') {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(17)
            .fontColor([$r('sys.color.icon_secondary')])
          Text('记录已提交，可在长者档案中查看')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .height(40)
        .alignItems(VerticalAlign.Center)
      } else {
        TextArea({
          text: this.taskNote(task.id),
          placeholder: '记录观察情况、处置结果或需要继续跟进的事项'
        })
          .width('100%')
          .height(76)
          .padding(10)
          .fontSize($r('sys.float.Body_M'))
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
          .maxLength(200)
          .onChange((value: string) => {
            this.updateTaskNote(task.id, value);
          })

        if (this.validationTaskId === task.id) {
          Text('请先填写处理记录，再完成当前工作')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('app.color.status_danger'))
        }
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private aiSuggestionSection(task: WideClinicalTask) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.AI_message'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('康小伴建议')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('继续对话')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('app.color.brand_blue'))
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(13)
          .fontColor([$r('app.color.brand_blue')])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.aiSuggestion(task))
        .width('100%')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('calc(100% - 40vp)')
    .margin({ left: 20, right: 20, top: 4, bottom: 8 })
    .padding(12)
    .backgroundColor(this.isAiSuggestionHovered ? $r('sys.color.interactive_hover') :
      $r('sys.color.comp_background_secondary'))
    .borderRadius(12)
    .keyboardFocusStyle()
    .onHover((isHover: boolean) => {
      this.isAiSuggestionHovered = isHover;
    })
    .onClick(() => {
      this.onOpenAiChat();
    })
  }

  @Builder
  private inspectorActionBar(task: WideClinicalTask) {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(17)
            .fontColor([$r('sys.color.icon_primary')])
          Text('查看长者')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width(118)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .keyboardFocusStyle()
      .onClick(() => {
        this.onOpenResident();
      })

      Button(this.primaryActionLabel(task))
        .layoutWeight(1)
        .height(40)
        .borderRadius(20)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.effectiveTaskState(task) === 'done' ? $r('sys.color.font_tertiary') :
          $r('app.color.text_on_brand'))
        .backgroundColor(this.effectiveTaskState(task) === 'done' ? $r('sys.color.comp_background_secondary') :
          $r('app.color.brand_blue'))
        .enabled(this.effectiveTaskState(task) !== 'done')
        .keyboardFocusStyle()
        .onClick(() => {
          this.handlePrimaryAction(task);
        })
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private desktopWorkSurface() {
    Row({ space: 12 }) {
      this.taskViewPane()

      this.taskQueuePane()

      ForEach([this.selectedTask()], (task: WideClinicalTask) => {
        this.taskInspectorPane(task)
      }, (task: WideClinicalTask) => task.id)
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      this.desktopWorkSurface()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 20, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
