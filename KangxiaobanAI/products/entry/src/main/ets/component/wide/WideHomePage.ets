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

import { display, LengthMetrics } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { KeyCode } from '@kit.InputKit';
import { AiTitleLabel } from '../AiTitleLabel';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

const HOME_LG_MIN_WIDTH: number = 840;
const HOME_SUMMARY_SPLIT_MIN_WIDTH: number = 960;
const HOME_WORK_SPLIT_MIN_WIDTH: number = 1180;
const HOME_FULL_WIDTH_RATIO: number = 0.9;
const HOME_XL_MIN_WIDTH: number = 1440;
const HOME_XL_MAX_CONTENT_WIDTH: number = 1600;

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

interface AiFocusItem {
  id: string;
  taskId: string;
  name: string;
  location: string;
  detail: string;
  signal: string;
  suggestion: string;
  timeLabel: string;
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
  @Event onTaskProgressChange: (completed: number, total: number) => void =
    (_completed: number, _total: number) => {};
  private currentTime: Date = new Date();
  @Local layoutWidth: number = 0;
  @Local layoutHeight: number = 0;
  @Local displayWidth: number = 0;
  @Local activeFilter: CareWorkFilter = 'todo';
  @Local taskPageIndex: number = 0;
  @Local aiPageIndex: number = 0;
  @Local selectedTaskId: string = '';
  @Local isTaskPanelOpen: boolean = false;
  @Local selectedAiFocusId: string = '';
  @Local isAiFocusSheetOpen: boolean = false;
  @Local hoveredTaskId: string = '';
  @Local pressedTaskId: string = '';
  @Local hoveredAiFocusId: string = '';
  @Local pressedAiFocusId: string = '';
  @Local focusedTarget: string = '';
  @Local inProgressTaskIds: string[] = [];
  @Local completedTaskIds: string[] = [];
  @Local noteDrafts: Map<string, string> = new Map<string, string>();
  @Local validationTaskId: string = '';

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
    },
    {
      id: 'care-hydration', category: 'todo', title: '补水与吞咽观察', residentId: 'r3', resident: '林爷爷',
      room: '3F-306', summary: '上午饮水量偏低，补水时同步观察呛咳和吞咽状态',
      time: '11:00', owner: '刘婷', priority: 'warning', state: 'pending'
    },
    {
      id: 'med-noon-review', category: 'medication', title: '午间用药前复核', residentId: 'r4', resident: '王德林',
      room: '2F-201', summary: '核对血糖记录、用药剂量与进食情况',
      time: '11:30', owner: '王倩', priority: 'danger', state: 'pending'
    },
    {
      id: 'record-lunch', category: 'record', title: '午餐摄入记录', residentId: 'r2', resident: '周奶奶',
      room: '2F-215', summary: '记录主食、饮水和特殊饮食完成情况',
      time: '12:30', owner: '王倩', priority: 'normal', state: 'pending'
    },
    {
      id: 'family-visit', category: 'family', title: '家属探访前沟通', residentId: 'r1', resident: '肖爷爷',
      room: '3F-302', summary: '提前说明近期情绪和活动量变化，统一陪伴方式',
      time: '15:00', owner: '刘婷', priority: 'warning', state: 'pending'
    },
    {
      id: 'report-fall-risk', category: 'report', title: '走廊防跌环境上报', residentId: '', resident: '东区长者',
      room: '2F 东区', summary: '走廊临时物品占用扶手区域，需要清理并复查',
      time: '15:20', owner: '刘婷', priority: 'danger', state: 'pending'
    },
    {
      id: 'care-rehabilitation', category: 'todo', title: '下午康复训练陪护', residentId: 'r5', resident: '李秀英',
      room: '3F-305', summary: '按当日计划完成下肢活动，记录疲劳与疼痛反馈',
      time: '16:00', owner: '刘婷', priority: 'normal', state: 'pending'
    },
    {
      id: 'care-evening-round', category: 'todo', title: '晚餐前安全巡视', residentId: '', resident: '东区长者',
      room: '3F 东区', summary: '复查床边动线、呼叫设备和高风险长者状态',
      time: '17:10', owner: '刘婷', priority: 'warning', state: 'pending'
    },
    {
      id: 'record-evening-handoff', category: 'record', title: '晚班交接摘要整理', residentId: '', resident: '东区长者',
      room: '2F/3F', summary: '整理未完成事项、异常观察和后续复查节点',
      time: '17:30', owner: '王倩', priority: 'normal', state: 'pending'
    }
  ];

  private aiFocusItems: AiFocusItem[] = [
    {
      id: 'ai-focus-emotion', taskId: 'care-emotion', name: '肖爷爷', location: '3F-302',
      detail: '活动量下降且拒绝交流，建议 20 分钟内由熟悉人员接手',
      signal: '近 2 小时活动量较个人基线下降 41%，两次交流未获回应。',
      suggestion: '由熟悉的护理人员面对面确认情绪、疼痛和不适，避免连续追问。',
      timeLabel: '立即关注', priority: 'danger'
    },
    {
      id: 'ai-focus-sleep', taskId: 'care-night-review', name: '周奶奶', location: '2F-215',
      detail: '夜间离床次数增加，午休前补充疼痛与睡眠观察',
      signal: '昨夜离床 4 次，高于近 7 日夜间平均水平。',
      suggestion: '午休前完成疼痛、睡眠和排泄情况询问，并记录变化。',
      timeLabel: '午休前', priority: 'warning'
    },
    {
      id: 'ai-focus-device', taskId: 'report-device', name: '东区设备', location: '3F-306',
      detail: '1 台床旁呼叫设备离线，先现场确认再上报',
      signal: '床旁呼叫设备已连续 18 分钟未上报心跳。',
      suggestion: '现场确认电源、网络和呼叫按键，无法恢复时按机构流程上报。',
      timeLabel: '18 分钟', priority: 'warning'
    },
    {
      id: 'ai-focus-pressure', taskId: 'med-blood-pressure', name: '李秀英', location: '3F-305',
      detail: '降压药服用后尚未补充复测记录',
      signal: '当前用药记录已完成，但复测字段仍为空。',
      suggestion: '按护理规范复测并记录，如有不适及时报告。',
      timeLabel: '08:20 前', priority: 'warning'
    },
    {
      id: 'ai-focus-vital', taskId: 'record-vital', name: '肖爷爷', location: '3F-302',
      detail: '上午体征数据已同步，护理观察尚未补充',
      signal: '血压、心率和血氧数据完整，主观观察项为空。',
      suggestion: '结合精神、饮食和活动状态补充人工观察。',
      timeLabel: '进行中', priority: 'normal'
    },
    {
      id: 'ai-focus-family', taskId: 'family-callback', name: '李秀英', location: '3F-305',
      detail: '家属回访需要同步近期睡眠和康复进度',
      signal: '家属上次沟通距今已 6 天，期间康复记录有更新。',
      suggestion: '按已记录事实说明变化，将家属诉求写入回访记录。',
      timeLabel: '14:30', priority: 'warning'
    },
    {
      id: 'ai-focus-hydration', taskId: 'care-hydration', name: '林爷爷', location: '3F-306',
      detail: '上午饮水量偏低，补水时需同步观察吞咽',
      signal: '上午记录饮水量 180ml，低于当日分时计划。',
      suggestion: '少量分次补水，出现呛咳或声音变化时暂停并人工评估。',
      timeLabel: '11:00', priority: 'warning'
    },
    {
      id: 'ai-focus-medication', taskId: 'med-noon-review', name: '王德林', location: '2F-201',
      detail: '午间用药前需要复核血糖、进食与剂量',
      signal: '今日早间血糖记录存在波动，午间核对项尚未完成。',
      suggestion: '依照已确认的用药要求完成双人复核，不由 AI 调整剂量。',
      timeLabel: '11:30', priority: 'danger'
    },
    {
      id: 'ai-focus-lunch', taskId: 'record-lunch', name: '周奶奶', location: '2F-215',
      detail: '午餐记录需要补充主食、饮水和特殊饮食',
      signal: '当日饮食记录尚缺午餐时段数据。',
      suggestion: '餐后按实际摄入量记录，不使用预估值代替。',
      timeLabel: '12:30', priority: 'normal'
    },
    {
      id: 'ai-focus-visit', taskId: 'family-visit', name: '肖爷爷', location: '3F-302',
      detail: '家属探访前建议先统一情绪陪伴和沟通方式',
      signal: '近期对陌生话题和连续询问的响应较弱。',
      suggestion: '提前向家属说明当日状态，建议简短、熟悉的陪伴活动。',
      timeLabel: '15:00', priority: 'warning'
    },
    {
      id: 'ai-focus-corridor', taskId: 'report-fall-risk', name: '东区走廊', location: '2F 东区',
      detail: '扶手区域有临时物品占用，需要清理并复查',
      signal: '环境巡查记录标记一处扶手动线受阻。',
      suggestion: '先恢复通行和扶手使用条件，再按流程完成环境风险上报。',
      timeLabel: '15:20', priority: 'danger'
    },
    {
      id: 'ai-focus-rehabilitation', taskId: 'care-rehabilitation', name: '李秀英', location: '3F-305',
      detail: '下午康复训练需要关注疲劳和疼痛反馈',
      signal: '上次训练后记录有轻度疲劳，今日计划尚未开始。',
      suggestion: '按既定计划陪护完成，过程中询问不适并如实记录。',
      timeLabel: '16:00', priority: 'normal'
    },
    {
      id: 'ai-focus-evening-round', taskId: 'care-evening-round', name: '东区巡视', location: '3F 东区',
      detail: '晚餐前需要复查动线、呼叫设备和高风险长者',
      signal: '当日存在设备离线和环境风险记录，需在晚班前确认状态。',
      suggestion: '按区域顺序完成巡视，将未关闭事项明确交接给晚班。',
      timeLabel: '17:10', priority: 'warning'
    },
    {
      id: 'ai-focus-handoff', taskId: 'record-evening-handoff', name: '晚班交接', location: '2F/3F',
      detail: '交接摘要需要覆盖未完成事项和后续复查节点',
      signal: '当前班次仍有多项待处理和进行中工作。',
      suggestion: '按人员、位置、时限和风险等级整理，避免只记录模糊描述。',
      timeLabel: '17:30', priority: 'normal'
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
    } else if (this.isAiFocusSheetOpen) {
      this.closeAiFocusSheet();
    }
  }

  aboutToAppear(): void {
    this.reportTaskProgress();
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  private lengthValue(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return parseFloat(value);
    }
    return 0;
  }

  private updateLayoutSize(width: Length, height: Length): void {
    let nextWidth: number = 0;
    let nextHeight: number = 0;
    nextWidth = this.lengthValue(width);
    nextHeight = this.lengthValue(height);
    if (nextWidth > 0 && Math.abs(nextWidth - this.layoutWidth) > 0.5) {
      this.layoutWidth = nextWidth;
    }
    if (nextHeight > 0 && Math.abs(nextHeight - this.layoutHeight) > 0.5) {
      this.layoutHeight = nextHeight;
    }
    try {
      const displayInfo: display.Display = display.getDefaultDisplaySync();
      const nextDisplayWidth: number = displayInfo.densityPixels > 0 ?
        displayInfo.width / displayInfo.densityPixels : 0;
      if (nextDisplayWidth > 0 && Math.abs(nextDisplayWidth - this.displayWidth) > 0.5) {
        this.displayWidth = nextDisplayWidth;
      }
    } catch (_error) {
      this.displayWidth = 0;
    }
  }

  private layoutAtLeast(minWidth: number): boolean {
    if (this.layoutWidth > 0) {
      return this.layoutWidth >= minWidth;
    }
    return !this.compactWidth && minWidth <= HOME_WORK_SPLIT_MIN_WIDTH;
  }

  private useSummarySplitLayout(): boolean {
    return this.layoutAtLeast(HOME_SUMMARY_SPLIT_MIN_WIDTH);
  }

  private useWorkSplitLayout(): boolean {
    const occupiesFullWidth: boolean = this.displayWidth > 0 && this.layoutWidth > 0 ?
      this.layoutWidth >= this.displayWidth * HOME_FULL_WIDTH_RATIO : !this.compactWidth;
    return occupiesFullWidth && this.layoutAtLeast(HOME_WORK_SPLIT_MIN_WIDTH);
  }

  private usePairedSupportCards(): boolean {
    return this.layoutAtLeast(HOME_LG_MIN_WIDTH);
  }

  private useXlLayout(): boolean {
    return this.layoutWidth >= HOME_XL_MIN_WIDTH;
  }

  private isTabletDevice(): boolean {
    return deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_TABLET;
  }

  private sectionGap(): number {
    return this.useXlLayout() ? 16 : 12;
  }

  private cardPadding(): number {
    return this.useXlLayout() ? 24 : 20;
  }

  private summaryCardMinHeight(): number {
    if (!this.useSummarySplitLayout()) {
      return 0;
    }
    return this.useXlLayout() ? 276 : 252;
  }

  private contentHorizontalPadding(): number {
    return this.useXlLayout() ? 32 : 16;
  }

  private contentMaxWidth(): number {
    return this.useXlLayout() ? HOME_XL_MAX_CONTENT_WIDTH : 1440;
  }

  private aiFocusSheetWidth(): number {
    if (this.layoutWidth <= 0) {
      return 720;
    }
    return Math.max(360, Math.min(720, this.layoutWidth - 32));
  }

  private mainWorkAreaMinHeight(): number {
    if (!this.useWorkSplitLayout() || this.layoutHeight <= 0) {
      return 0;
    }
    const topInset: number = this.topBarHeight + (this.compactWidth ? 16 : 20);
    const bottomInset: number = 28 + this.naviIndicatorHeight;
    let availableHeight: number = this.layoutHeight - topInset - bottomInset;
    if (!this.isTabletDevice()) {
      availableHeight -= this.summaryCardMinHeight() + this.sectionGap();
    }
    return Math.max(this.isTabletDevice() ? 520 : 440, availableHeight);
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

  private cardPageSize(): number {
    if (this.useWorkSplitLayout()) {
      if (this.isTabletDevice()) {
        return this.mainWorkAreaMinHeight() >= 640 ? 7 : 6;
      }
      return this.mainWorkAreaMinHeight() >= 600 ? 5 : 4;
    }
    return this.usePairedSupportCards() ? 4 : 3;
  }

  private totalTaskPages(): number {
    return Math.max(1, Math.ceil(this.visibleTasks().length / this.cardPageSize()));
  }

  private currentTaskPage(): number {
    return Math.min(this.taskPageIndex, this.totalTaskPages() - 1);
  }

  private totalAiPages(): number {
    return Math.max(1, Math.ceil(this.aiFocusItems.length / this.cardPageSize()));
  }

  private currentAiPage(): number {
    return Math.min(this.aiPageIndex, this.totalAiPages() - 1);
  }

  private pagedVisibleTasks(): CareTaskData[] {
    const start: number = this.currentTaskPage() * this.cardPageSize();
    return this.visibleTasks().slice(start, start + this.cardPageSize());
  }

  private pagedAiFocusItems(): AiFocusItem[] {
    const start: number = this.currentAiPage() * this.cardPageSize();
    return this.aiFocusItems.slice(start, start + this.cardPageSize());
  }

  private previousTaskPage(): void {
    this.taskPageIndex = Math.max(0, this.currentTaskPage() - 1);
  }

  private nextTaskPage(): void {
    this.taskPageIndex = Math.min(this.totalTaskPages() - 1, this.currentTaskPage() + 1);
  }

  private previousAiPage(): void {
    this.aiPageIndex = Math.max(0, this.currentAiPage() - 1);
  }

  private nextAiPage(): void {
    this.aiPageIndex = Math.min(this.totalAiPages() - 1, this.currentAiPage() + 1);
  }

  private currentCardPage(isAiCard: boolean): number {
    return isAiCard ? this.currentAiPage() : this.currentTaskPage();
  }

  private totalCardPages(isAiCard: boolean): number {
    return isAiCard ? this.totalAiPages() : this.totalTaskPages();
  }

  private previousCardPage(isAiCard: boolean): void {
    if (isAiCard) {
      this.previousAiPage();
    } else {
      this.previousTaskPage();
    }
  }

  private nextCardPage(isAiCard: boolean): void {
    if (isAiCard) {
      this.nextAiPage();
    } else {
      this.nextTaskPage();
    }
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
    this.taskPageIndex = 0;
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

  private selectedAiFocus(): AiFocusItem | undefined {
    return this.aiFocusItems.find((item: AiFocusItem) => item.id === this.selectedAiFocusId);
  }

  private selectedAiTask(): CareTaskData | undefined {
    if (this.selectedAiFocus() === undefined) {
      return undefined;
    }
    return this.taskData.find((task: CareTaskData) => task.id === this.selectedAiFocus()!.taskId);
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
    this.isTaskPanelOpen = true;
    this.onTaskPanelVisibilityChange(true);
  }

  private closeTaskPanel(): void {
    if (!this.isTaskPanelOpen) {
      return;
    }
    this.isTaskPanelOpen = false;
    this.onTaskPanelVisibilityChange(false);
  }

  private openAiFocusSheet(itemId: string): void {
    this.selectedAiFocusId = itemId;
    if (this.isAiFocusSheetOpen) {
      return;
    }
    this.isAiFocusSheetOpen = true;
    this.onTaskPanelVisibilityChange(true);
  }

  private closeAiFocusSheet(): void {
    if (!this.isAiFocusSheetOpen) {
      return;
    }
    this.isAiFocusSheetOpen = false;
    this.onTaskPanelVisibilityChange(false);
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
  private workOverviewCard() {
    Column({ space: this.useXlLayout() ? 16 : 12 }) {
      Row({ space: 16 }) {
        Column({ space: 4 }) {
          Text(this.greetingText())
            .fontSize(this.useXlLayout() ? 24 : 22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('早班 · 东区照护组 · 负责 28 位长者')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.dateText())
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor($r('sys.color.comp_background_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

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
    .constraintSize({ minHeight: this.summaryCardMinHeight() })
    .padding(this.cardPadding())
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private cardPagination(isAiCard: boolean) {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(14)
            .fontColor([this.currentCardPage(isAiCard) > 0 ? $r('sys.color.icon_primary') :
              $r('sys.color.icon_tertiary')])
          Text('上一页')
            .fontSize($r('sys.float.Body_M'))
            .fontColor(this.currentCardPage(isAiCard) > 0 ? $r('sys.color.font_primary') :
              $r('sys.color.font_tertiary'))
        }
      }
      .height(38)
      .padding({ left: 12, right: 14 })
      .borderRadius(19)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .enabled(this.currentCardPage(isAiCard) > 0)
      .keyboardFocusStyle()
      .onClick(() => this.previousCardPage(isAiCard))

      Text((this.currentCardPage(isAiCard) + 1) + ' / ' + this.totalCardPages(isAiCard))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 5 }) {
          Text('下一页')
            .fontSize($r('sys.float.Body_M'))
            .fontColor(this.currentCardPage(isAiCard) < this.totalCardPages(isAiCard) - 1 ?
              $r('sys.color.font_primary') :
              $r('sys.color.font_tertiary'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([this.currentCardPage(isAiCard) < this.totalCardPages(isAiCard) - 1 ?
              $r('sys.color.icon_primary') :
              $r('sys.color.icon_tertiary')])
        }
      }
      .height(38)
      .padding({ left: 14, right: 12 })
      .borderRadius(19)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .enabled(this.currentCardPage(isAiCard) < this.totalCardPages(isAiCard) - 1)
      .keyboardFocusStyle()
      .onClick(() => this.nextCardPage(isAiCard))
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 14 })
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private aiFocusCard() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        if (!this.isTabletDevice()) {
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
        }

        Column({ space: 3 }) {
          AiTitleLabel({ text: '康小伴 AI', compact: false, cardTitle: true })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 6 }) {
            Text('开始对话')
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
      .padding({ left: 22, right: 22, top: 22, bottom: 16 })
      .alignItems(VerticalAlign.Top)

      Column({ space: 4 }) {
        ForEach(this.pagedAiFocusItems(), (item: AiFocusItem, index: number) => {
          this.aiFocusRow(item, index === this.pagedAiFocusItems().length - 1)
        }, (item: AiFocusItem) => item.id)
      }
      .width('100%')
      .layoutWeight(this.useWorkSplitLayout() ? 1 : 0)
      .padding({ left: 10, right: 10, bottom: 8 })

      this.cardPagination(true)
    }
    .width('100%')
    .height(this.useWorkSplitLayout() && this.isTabletDevice() ? '100%' : undefined)
    .constraintSize({ minHeight: this.summaryCardMinHeight() })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
    .geometryTransition('aiReminderCard', { follow: true })
    .alignItems(HorizontalAlign.Start)
    .bindSheet(this.isAiFocusSheetOpen, this.aiFocusSheet, {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.CENTER,
      width: this.aiFocusSheetWidth(),
      showClose: true,
      dragBar: true,
      title: { title: '康小伴 AI' },
      backgroundColor: $r('sys.color.comp_background_primary'),
      onDisappear: () => {
        if (this.isAiFocusSheetOpen) {
          this.isAiFocusSheetOpen = false;
          this.onTaskPanelVisibilityChange(false);
        }
      }
    })
  }

  @Builder
  private aiFocusRow(item: AiFocusItem, isLast: boolean) {
    Row({ space: 12 }) {
      if (!this.isTabletDevice()) {
        Row()
          .width(4)
          .height(38)
          .borderRadius(2)
          .backgroundColor(this.priorityColor(item.priority))
      }

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.name)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(item.timeLabel)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor(this.priorityColor(item.priority))
        }
        Text(item.detail)
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
    .constraintSize({ minHeight: 78, maxHeight: 88 })
    .layoutWeight(this.useWorkSplitLayout() ? 1 : 0)
    .padding({
      left: 8,
      right: 8,
      top: 6,
      bottom: isLast ? 2 : 6
    })
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .borderRadius(12)
    .backgroundColor(this.pressedAiFocusId === item.id ? $r('sys.color.interactive_pressed') :
      this.hoveredAiFocusId === item.id ? $r('sys.color.interactive_hover') : Color.Transparent)
    .shadow(this.pressedAiFocusId === item.id ?
      { radius: 3, color: 'rgba(0,0,0,0.10)', offsetX: 0, offsetY: 1 } :
      this.hoveredAiFocusId === item.id ?
        { radius: 8, color: 'rgba(0,0,0,0.07)', offsetX: 0, offsetY: 2 } :
        { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    .scale({
      x: this.pressedAiFocusId === item.id ? 0.992 : 1,
      y: this.pressedAiFocusId === item.id ? 0.992 : 1
    })
    .alignItems(VerticalAlign.Center)
    .keyboardFocusStyle()
    .accessibilityText('康小伴 AI 提醒，' + item.name + '，' + item.timeLabel + '，' + item.detail)
    .onHover((isHover: boolean) => this.hoveredAiFocusId = isHover ? item.id : '')
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedAiFocusId = item.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedAiFocusId = '';
      }
    })
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.openAiFocusSheet(item.id)))
    .onClick(() => this.openAiFocusSheet(item.id))
  }

  @Builder
  private aiFocusSheet() {
    if (this.selectedAiFocus() !== undefined) {
      Column({ space: 0 }) {
        Scroll() {
          Column({ space: 18 }) {
            Row({ space: 14 }) {
              Row() {
                SymbolGlyph($r('sys.symbol.AI_message'))
                  .fontSize(26)
                  .fontColor([$r('app.color.brand_blue')])
              }
              .width(56)
              .height(56)
              .borderRadius(28)
              .backgroundColor($r('app.color.ai_feed_background'))
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)

              Column({ space: 7 }) {
                Text(this.selectedAiFocus()!.name)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))

                Row({ space: 8 }) {
                  Text(this.selectedAiFocus()!.location)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('sys.color.font_secondary'))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor($r('sys.color.comp_background_secondary'))

                  Text(this.selectedAiFocus()!.timeLabel)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.priorityColor(this.selectedAiFocus()!.priority))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor(this.priorityBackground(this.selectedAiFocus()!.priority))
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Column({ space: 8 }) {
              Row({ space: 7 }) {
                AiTitleLabel({ text: '康小伴 AI', compact: true })
                Text('本地演示提醒')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_tertiary'))
              }
              Text(this.selectedAiFocus()!.detail)
                .width('100%')
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
            }
            .width('100%')
            .padding(18)
            .borderRadius(18)
            .backgroundColor($r('app.color.ai_feed_background'))
            .alignItems(HorizontalAlign.Start)

            Column({ space: 10 }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.info_circle'))
                  .fontSize(18)
                  .fontColor([$r('app.color.brand_blue')])
                Text('提醒依据')
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
              }
              Text(this.selectedAiFocus()!.signal)
                .width('100%')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding(18)
            .borderRadius(16)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .alignItems(HorizontalAlign.Start)

            Column({ space: 10 }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([$r('app.color.status_warning')])
                Text('建议处理')
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
              }
              Text(this.selectedAiFocus()!.suggestion)
                .width('100%')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding(18)
            .borderRadius(16)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .alignItems(HorizontalAlign.Start)

            if (this.selectedAiTask() !== undefined) {
              Column({ space: 10 }) {
                Row() {
                  Text('关联工作')
                    .fontSize($r('sys.float.Body_L'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                  Blank()
                  Text(this.taskStateText(this.selectedAiTask()!))
                    .fontSize($r('sys.float.Caption_M'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.taskStateColor(this.selectedAiTask()!))
                }
                .width('100%')

                Row({ space: 12 }) {
                  Column({ space: 5 }) {
                    Text(this.selectedAiTask()!.title)
                      .fontSize($r('sys.float.Body_L'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Text(this.selectedAiTask()!.time + ' · 责任人 ' + this.selectedAiTask()!.owner)
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
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .padding(18)
              .borderRadius(16)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .alignItems(HorizontalAlign.Start)
              .keyboardFocusStyle()
              .accessibilityText('打开关联工作，' + this.selectedAiTask()!.title)
              .onClick(() => {
                const taskId: string = this.selectedAiTask()!.id;
                this.closeAiFocusSheet();
                setTimeout(() => this.openTask(taskId), 120);
              })
            }

            Text('康小伴仅整理本地演示数据，不替代护理规范、医嘱或现场人工判断。')
              .width('100%')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 12, bottom: 24 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        Row({ space: 12 }) {
          if (this.selectedAiTask() !== undefined) {
            Button('查看关联工作')
              .layoutWeight(1)
              .height(46)
              .borderRadius(23)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .keyboardFocusStyle()
              .onClick(() => {
                const taskId: string = this.selectedAiTask()!.id;
                this.closeAiFocusSheet();
                setTimeout(() => this.openTask(taskId), 120);
              })
          }

          Button('继续询问康小伴')
            .layoutWeight(1)
            .height(46)
            .borderRadius(23)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor($r('app.color.brand_blue'))
            .keyboardFocusStyle()
            .onClick(() => {
              this.closeAiFocusSheet();
              this.onOpenAiChat();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 12, bottom: 18 })
        .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
    }
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
          ForEach(this.pagedVisibleTasks(), (task: CareTaskData, index: number) => {
            this.taskQueueRow(task, index === this.pagedVisibleTasks().length - 1)
          }, (task: CareTaskData) => task.id)
        }
        .width('100%')
        .layoutWeight(this.useWorkSplitLayout() ? 1 : 0)
        .padding({ left: 10, right: 10, bottom: 8 })
      }

      this.cardPagination(false)
    }
    .width('100%')
    .height(this.useWorkSplitLayout() ? '100%' : undefined)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private taskQueueRow(task: CareTaskData, isLast: boolean) {
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

      if (!this.isTabletDevice()) {
        Row()
          .width(4)
          .height(42)
          .borderRadius(2)
          .backgroundColor(this.priorityColor(task.priority))
      }

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
    .constraintSize({ minHeight: 78, maxHeight: 88 })
    .layoutWeight(this.useWorkSplitLayout() ? 1 : 0)
    .padding({ left: 14, right: 14 })
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .borderRadius(14)
    .backgroundColor(this.pressedTaskId === task.id ? $r('sys.color.interactive_pressed') :
      this.hoveredTaskId === task.id ? $r('sys.color.interactive_hover') : Color.Transparent)
    .shadow(this.pressedTaskId === task.id ?
      { radius: 3, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 1 } :
      this.hoveredTaskId === task.id ?
        { radius: 8, color: 'rgba(0,0,0,0.07)', offsetX: 0, offsetY: 2 } :
        { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    .scale({
      x: this.pressedTaskId === task.id ? 0.992 : 1,
      y: this.pressedTaskId === task.id ? 0.992 : 1
    })
    .keyboardFocusStyle()
    .accessibilityText(task.time + '，' + task.resident + '，' + task.title + '，' + this.taskStateText(task))
    .onFocus(() => this.focusedTarget = task.id)
    .onBlur(() => this.focusedTarget = '')
    .onHover((isHover: boolean) => this.hoveredTaskId = isHover ? task.id : '')
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedTaskId = task.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedTaskId = '';
      }
    })
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.openTask(task.id)))
    .onClick(() => this.openTask(task.id))
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
    GridRow({ columns: 12, gutter: { x: this.sectionGap(), y: this.sectionGap() } }) {
      if (this.useWorkSplitLayout()) {
        GridCol({ span: 7 }) {
          this.taskQueueCard()
        }
        .height('100%')
        GridCol({ span: 5 }) {
          Column({ space: this.sectionGap() }) {
            this.aiFocusCard()
            if (!this.isTabletDevice()) {
              this.checkpointCard()
            }
          }
          .width('100%')
          .height('100%')
        }
        .height('100%')
      } else {
        GridCol({ span: 12 }) {
          this.aiFocusCard()
        }
        GridCol({ span: 12 }) {
          this.taskQueueCard()
        }
        if (!this.isTabletDevice()) {
          GridCol({ span: 12 }) {
            this.checkpointCard()
          }
        }
      }
    }
    .width('100%')
    .constraintSize({ minHeight: this.mainWorkAreaMinHeight() })
  }

  @Builder
  private taskDetailPanel(task: CareTaskData) {
    Column({ space: 0 }) {
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
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 12, bottom: 18 })
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .alignItems(VerticalAlign.Top)

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
                .barState(BarState.Off)
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
        .padding({
          left: 22,
          right: 22,
          top: 20,
          bottom: 20
        })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)

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
      .height(70)
      .padding({ left: 18, right: 18 })
      .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  private taskDetailSheet() {
    if (this.selectedTask() !== undefined) {
      this.taskDetailPanel(this.selectedTask()!)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll(this.pageScroller) {
        Column({ space: this.sectionGap() }) {
          if (!this.isTabletDevice()) {
            GridRow({ columns: 12, gutter: { x: this.sectionGap(), y: this.sectionGap() } }) {
              GridCol({ span: 12 }) {
                this.workOverviewCard()
              }
            }
            .width('100%')
          }

          this.mainWorkArea()
        }
        .width('100%')
        .constraintSize({ maxWidth: this.contentMaxWidth() })
        .padding({
          left: this.contentHorizontalPadding(),
          right: this.contentHorizontalPadding(),
          top: this.topBarHeight + (this.compactWidth ? 16 : 20),
          bottom: 28 + this.naviIndicatorHeight
        })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor($r('sys.color.background_secondary'))

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateLayoutSize(newValue.width, newValue.height);
    })
    .bindSheet(this.isTaskPanelOpen, this.taskDetailSheet, {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      preferType: SheetType.CENTER,
      width: 640,
      showClose: true,
      dragBar: true,
      title: { title: '任务详情' },
      backgroundColor: $r('sys.color.comp_background_primary'),
      onDisappear: () => {
        if (this.isTaskPanelOpen) {
          this.isTaskPanelOpen = false;
          this.onTaskPanelVisibilityChange(false);
        }
      }
    })
  }
}
