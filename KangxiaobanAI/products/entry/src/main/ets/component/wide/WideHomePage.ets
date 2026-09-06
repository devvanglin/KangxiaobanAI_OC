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
import { BusinessStore } from '../../network/BusinessStore';
import ApiClient from '../../network/ApiClient';
import AuthStore from '../../network/AuthStore';
import { MessageApi } from '../../network/MessageApi';
import { Alert, Bed, CareTask as BackendCareTask, Elder, MessageContact, Room, RoleInfo, Schedule, TaskStatusRequest, UserMessage } from '../../network/Dto';

const HOME_LG_MIN_WIDTH: number = 840;
const HOME_SUMMARY_SPLIT_MIN_WIDTH: number = 960;
const HOME_WORK_SPLIT_MIN_WIDTH: number = 1180;
const HOME_FULL_WIDTH_RATIO: number = 0.9;
const HOME_XL_MIN_WIDTH: number = 1440;
const HOME_XL_MAX_CONTENT_WIDTH: number = 1600;

type CarePriority = 'danger' | 'warning' | 'normal';
type CareTaskState = 'pending' | 'doing' | 'done';
type CareTaskCategory = 'todo' | 'medication' | 'record' | 'report';
type CareWorkFilter = CareTaskCategory | 'priority' | 'completed';
type CareCardSize = 'long' | 'short';
type TodayPlanFilter = 'all' | CareTaskCategory | 'completed';

interface CareTaskData {
  id: string;
  category: CareTaskCategory;
  dueDate: string;
  title: string;
  residentId: string;
  resident: string;
  room: string;
  summary: string;
  instructions: string;
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

/** 关注老人行：按未闭环告警严重度归并到每位长者。 */
interface HomeStat {
  big: string;
  label: string;
  sub: string;
  subDanger: boolean;
}

interface FocusElderRow {
  elderId: number;
  name: string;
  location: string;
  priority: CarePriority;
}

/** 快捷操作的异常上报创建请求（ elder_id 与 title 服务端必填）。 */
interface ReportTaskRequest {
  elder_id: number;
  title: string;
  kind: string;
  category: string;
  priority: string;
  remark: string;
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
  @Local todayPlanFilter: TodayPlanFilter = 'all';
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
  @Local expandedTaskCategory: string = '';
  @Local riskCardExpanded: boolean = false;
  @Local inProgressTaskIds: string[] = [];
  @Local completedTaskIds: string[] = [];
  @Local noteDrafts: Map<string, string> = new Map<string, string>();
  @Local validationTaskId: string = '';
  @Local backendTaskData: CareTaskData[] = [];
  @Local businessStore: BusinessStore = BusinessStore.getShared();

  private taskData: CareTaskData[] = [];

  @Local aiFocusItems: AiFocusItem[] = [];

  @Local checkpoints: CareCheckpoint[] = [];
  @Local riskTrendValues: number[] = [];
  @Local closureTrendValues: number[] = [];
  @Local showAllTasks: boolean = false;
  @Local quickActionDialog: string = '';
  @Local assistTargetId: number = 0;
  @Local assistText: string = '';
  @Local assistError: string = '';
  @Local assistSending: boolean = false;
  @Local reportElderId: number = 0;
  @Local reportText: string = '';
  @Local reportError: string = '';
  @Local reportSending: boolean = false;

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
    if (this.quickActionDialog.length > 0) {
      this.closeQuickActionDialog();
    } else if (this.isTaskPanelOpen) {
      this.closeTaskPanel();
    } else if (this.isAiFocusSheetOpen) {
      this.closeAiFocusSheet();
    }
  }

  @Monitor('businessStore.tasks', 'businessStore.elders', 'businessStore.beds', 'businessStore.rooms',
    'businessStore.alerts', 'businessStore.schedules')
  onBusinessDataChange(): void {
    this.syncBackendTasks();
  }

  aboutToAppear(): void {
    this.loadBackendTasks();
    this.reportTaskProgress();
  }

  private async loadBackendTasks(): Promise<void> {
    await this.businessStore.load();
    if (!this.businessStore.loaded) {
      return;
    }
    this.syncBackendTasks();
  }

  private serverTaskPriority(value?: string): CarePriority {
    if (value === 'danger' || value === 'high' || value === 'critical') {
      return 'danger';
    }
    if (value === 'warning' || value === 'medium') {
      return 'warning';
    }
    return 'normal';
  }

  private serverTaskCategory(task: BackendCareTask): CareTaskCategory {
    const value: string = task.category ?? '';
    if (value === 'medication' || value === 'record' || value === 'report') {
      return value;
    }
    return task.kind === 'medication' ? 'medication' : 'todo';
  }

  private serverTaskInstructions(task: BackendCareTask): string {
    const planInstructions: string = task.plan_item?.instructions?.trim() ?? '';
    if (planInstructions.length > 0) {
      return planInstructions;
    }
    return task.remark?.trim() ?? '';
  }

  private syncBackendTasks(): void {
    this.backendTaskData = this.businessStore.tasks.map((task: BackendCareTask): CareTaskData => {
      const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === task.elder_id);
      const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder?.bed_id);
      const room: Room | undefined = bed === undefined ? undefined :
        this.businessStore.rooms.find((item: Room) => item.id === bed.room_id);
      const state: CareTaskState = task.status === 'doing' ? 'doing' : task.status === 'done' ? 'done' : 'pending';
      return { id: `${task.id}`, category: this.serverTaskCategory(task), title: task.title,
        dueDate: task.due_at ? this.trendDayKey(task.due_at) : '',
        residentId: `${task.elder_id}`, resident: elder?.name ?? '未知长者', room: room && bed ?
          `${room.floor}F-${room.room_no}-${bed.bed_no}` : '未分配',
        summary: task.remark ?? '', instructions: this.serverTaskInstructions(task),
        time: task.due_at ? task.due_at.slice(11, 16) : '--', owner: task.assignee ?? '',
        priority: this.serverTaskPriority(task.priority), state: state };
    });
    this.syncSupportCards();
    this.reportTaskProgress();
  }

  /** Build the supporting cards from the same tenant-scoped records as the task queue. */
  private syncSupportCards(): void {
    const openAlerts: Alert[] = this.businessStore.alerts
      .filter((item: Alert) => item.status !== 'handled' && item.status !== 'closed')
      .sort((left: Alert, right: Alert): number => right.create_time.localeCompare(left.create_time));
    this.aiFocusItems = openAlerts.map((alert: Alert): AiFocusItem => {
      const relatedTask: BackendCareTask | undefined = alert.elder_id === undefined ? undefined :
        this.businessStore.tasks.find((task: BackendCareTask) => task.elder_id === alert.elder_id && task.status !== 'done');
      const priority: CarePriority = this.serverAlertPriority(alert.level);
      const sourceParts: string[] = [];
      if (alert.type.trim().length > 0) {
        sourceParts.push(alert.type.trim());
      }
      if (alert.device_id.trim().length > 0) {
        sourceParts.push(alert.device_id.trim());
      }
      return {
        id: `alert-${alert.id}`,
        taskId: relatedTask === undefined ? '' : `${relatedTask.id}`,
        name: alert.elder_id === undefined ? '机构设备' : this.elderName(alert.elder_id),
        location: alert.elder_id === undefined ? (alert.device_id || '机构范围') : this.elderLocation(alert.elder_id),
        detail: alert.content.trim().length > 0 ? alert.content : '服务器未提供告警详情',
        signal: sourceParts.length > 0 ? sourceParts.join(' · ') : '服务器告警记录',
        suggestion: priority === 'danger' ? '请立即核实现场，并按机构应急流程完成处置记录。' :
          '请在本班次内核实现场并记录处置结果。',
        timeLabel: this.serverTimeLabel(alert.create_time),
        priority: priority
      };
    });

    const scheduledTasks: BackendCareTask[] = this.businessStore.tasks
      .filter((task: BackendCareTask) => task.due_at !== undefined && task.due_at.trim().length > 0 &&
        this.trendDayKey(task.due_at) === this.dateValue())
      .sort((left: BackendCareTask, right: BackendCareTask): number =>
        (left.due_at ?? '').localeCompare(right.due_at ?? ''));
    this.checkpoints = scheduledTasks.map((task: BackendCareTask): CareCheckpoint => {
      const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === task.elder_id);
      const location: string = this.elderLocation(task.elder_id);
      const noteParts: string[] = [];
      if (elder !== undefined) {
        noteParts.push(elder.name);
      }
      if (location !== '未分配') {
        noteParts.push(location);
      }
      if ((task.remark ?? '').trim().length > 0) {
        noteParts.push((task.remark ?? '').trim());
      }
      return {
        id: `task-${task.id}`,
        time: this.serverTimeOnly(task.due_at),
        title: task.title,
        note: noteParts.length > 0 ? noteParts.join(' · ') : '服务器任务记录',
        completed: task.status === 'done'
      };
    });
    this.riskTrendValues = this.buildAlertTrend(openAlerts);
    this.closureTrendValues = this.buildTaskTrend(this.businessStore.tasks);
  }

  private serverAlertPriority(value: string): CarePriority {
    if (value === 'emergency' || value === 'critical' || value === 'high') {
      return 'danger';
    }
    if (value === 'important' || value === 'warning' || value === 'medium') {
      return 'warning';
    }
    return 'normal';
  }

  private elderName(elderId: number): string {
    return this.businessStore.elders.find((item: Elder) => item.id === elderId)?.name ?? '未知长者';
  }

  private elderLocation(elderId: number): string {
    const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === elderId);
    const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder?.bed_id);
    const room: Room | undefined = bed === undefined ? undefined :
      this.businessStore.rooms.find((item: Room) => item.id === bed.room_id);
    return bed !== undefined && room !== undefined ? `${room.floor}F-${room.room_no}-${bed.bed_no}` : '未分配';
  }

  private serverTimeLabel(value: string): string {
    const normalized: string = value.replace('T', ' ');
    return normalized.length >= 16 ? normalized.slice(5, 16) : (normalized || '--');
  }

  private serverTimeOnly(value?: string): string {
    if (value === undefined || value.trim().length === 0) {
      return '--';
    }
    const normalized: string = value.replace('T', ' ');
    return normalized.length >= 16 ? normalized.slice(11, 16) : normalized;
  }

  private trendDayKey(value: string): string {
    const parsed: Date = new Date(value.replace('T', ' '));
    if (isNaN(parsed.getTime())) {
      return '';
    }
    const month: string = (parsed.getMonth() + 1).toString().padStart(2, '0');
    const day: string = parsed.getDate().toString().padStart(2, '0');
    return `${parsed.getFullYear()}-${month}-${day}`;
  }

  private recentDayKeys(): string[] {
    const keys: string[] = [];
    const today: Date = new Date();
    for (let offset: number = 6; offset >= 0; offset--) {
      const date: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - offset);
      const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
      const day: string = date.getDate().toString().padStart(2, '0');
      keys.push(`${date.getFullYear()}-${month}-${day}`);
    }
    return keys;
  }

  private scaleTrend(counts: number[]): number[] {
    const maxCount: number = Math.max(...counts);
    if (maxCount <= 0) {
      return [];
    }
    return counts.map((count: number): number => count === 0 ? 0 : Math.max(8, Math.round(count / maxCount * 100)));
  }

  private buildAlertTrend(alerts: Alert[]): number[] {
    const keys: string[] = this.recentDayKeys();
    const counts: number[] = keys.map((key: string): number => alerts.filter((item: Alert) =>
      this.trendDayKey(item.create_time) === key).length);
    return this.scaleTrend(counts);
  }

  private buildTaskTrend(tasks: BackendCareTask[]): number[] {
    const keys: string[] = this.recentDayKeys();
    const counts: number[] = keys.map((key: string): number => {
      const dayTasks: BackendCareTask[] = tasks.filter((item: BackendCareTask) =>
        this.trendDayKey(item.due_at ?? '') === key);
      if (dayTasks.length === 0) {
        return 0;
      }
      const completed: number = dayTasks.filter((item: BackendCareTask) => item.status === 'done').length;
      return Math.round(completed / dayTasks.length * 100);
    });
    return this.scaleTrend(counts);
  }

  private activeTaskData(): CareTaskData[] {
    return this.backendTaskData;
  }

  private todayPlanTasks(): CareTaskData[] {
    const tasks: CareTaskData[] = this.activeTaskData()
      .filter((task: CareTaskData) => task.dueDate === this.dateValue())
      .sort((left: CareTaskData, right: CareTaskData): number => {
        const leftTime: string = left.time === '--' ? '99:99' : left.time;
        const rightTime: string = right.time === '--' ? '99:99' : right.time;
        return leftTime.localeCompare(rightTime);
      });
    if (this.todayPlanFilter === 'all') {
      return tasks;
    }
    if (this.todayPlanFilter === 'completed') {
      return tasks.filter((task: CareTaskData) => this.effectiveTaskState(task) === 'done');
    }
    if (this.todayPlanFilter === 'todo') {
      return tasks.filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done');
    }
    return tasks.filter((task: CareTaskData) => task.category === this.todayPlanFilter);
  }

  private allTodayPlanTasks(): CareTaskData[] {
    return this.activeTaskData()
      .filter((task: CareTaskData) => task.dueDate === this.dateValue())
      .sort((left: CareTaskData, right: CareTaskData): number => {
        const leftTime: string = left.time === '--' ? '99:99' : left.time;
        const rightTime: string = right.time === '--' ? '99:99' : right.time;
        return leftTime.localeCompare(rightTime);
      });
  }

  private todayPlanFilterItems(): WideSlidingCapsuleItem[] {
    const all: CareTaskData[] = this.allTodayPlanTasks();
    return [
      { title: '全部', index: 0, badgeText: all.length.toString() },
      { title: '待办', index: 1, badgeText: all.filter((task: CareTaskData) =>
        this.effectiveTaskState(task) !== 'done').length.toString() },
      { title: '用药', index: 2, badgeText: all.filter((task: CareTaskData) => task.category === 'medication').length.toString() },
      { title: '记录', index: 3, badgeText: all.filter((task: CareTaskData) => task.category === 'record').length.toString() },
      { title: '上报', index: 4, badgeText: all.filter((task: CareTaskData) => task.category === 'report').length.toString() },
      { title: '完成', index: 5, badgeText: all.filter((task: CareTaskData) =>
        this.effectiveTaskState(task) === 'done').length.toString() }
    ];
  }

  private todayPlanFilterIndex(): number {
    const filters: TodayPlanFilter[] = ['all', 'todo', 'medication', 'record', 'report', 'completed'];
    return filters.indexOf(this.todayPlanFilter);
  }

  private selectTodayPlanFilter(index: number): void {
    const filters: TodayPlanFilter[] = ['all', 'todo', 'medication', 'record', 'report', 'completed'];
    this.todayPlanFilter = filters[index] ?? 'all';
  }

  private todayPendingCount(): number {
    return this.allTodayPlanTasks()
      .filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done').length;
  }

  private todayCompletedCount(): number {
    return this.allTodayPlanTasks()
      .filter((task: CareTaskData) => this.effectiveTaskState(task) === 'done').length;
  }

  private nextTodayTask(): CareTaskData | undefined {
    return this.allTodayPlanTasks()
      .find((task: CareTaskData) => this.effectiveTaskState(task) !== 'done');
  }

  private taskCategoryText(category: CareTaskCategory): string {
    if (category === 'medication') {
      return '服药照护';
    }
    if (category === 'record') {
      return '护理记录';
    }
    if (category === 'report') {
      return '异常上报';
    }
    return '日常待办';
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
    // The overview is a content card, not a viewport-sized dashboard row.
    // A fixed minimum here leaves a large blank band when the server returns
    // only a short summary (especially on wide 2-in-1 windows).
    // Keep the compact/medium summary behavior, but never let the wide
    // workbench reserve a second viewport-sized band above its card grid.
    if (!this.useSummarySplitLayout() || this.useWorkSplitLayout()) {
      return 0;
    }
    return this.useXlLayout() ? 276 : 252;
  }

  private wideUtilityCardHeight(): number {
    return this.useXlLayout() ? 76 : 68;
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
    const user = AuthStore.getUser();
    const displayName: string = user?.real_name || user?.username || '当前用户';
    if (hour < 11) {
      return `早上好，${displayName}`;
    }
    if (hour < 14) {
      return `中午好，${displayName}`;
    }
    if (hour < 18) {
      return `下午好，${displayName}`;
    }
    return `晚上好，${displayName}`;
  }

  private dateValue(): string {
    const year: string = this.currentTime.getFullYear().toString();
    const month: string = (this.currentTime.getMonth() + 1).toString().padStart(2, '0');
    const day: string = this.currentTime.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private shiftSummary(): string {
    const user = AuthStore.getUser();
    const names: string[] = [user?.real_name ?? '', user?.username ?? ''];
    const schedule: Schedule | undefined = this.businessStore.schedules.find((item: Schedule) =>
      item.work_date === this.dateValue() && names.includes(item.staff));
    if (!schedule) {
      return `今日排班未登记 · 当前可见 ${this.visibleResidentCount()} 位长者`;
    }
    const scope: string = schedule.room_scope && schedule.room_scope.length > 0 ? schedule.room_scope : '范围未登记';
    return `${schedule.shift} · ${scope} · 当前可见 ${this.visibleResidentCount()} 位长者`;
  }

  private visibleResidentCount(): number {
    if (this.businessStore.elders.length > 0) {
      return this.businessStore.elders.length;
    }
    const residentIds: string[] = [];
    this.backendTaskData.forEach((task: CareTaskData): void => {
      if (task.residentId.length > 0 && !residentIds.includes(task.residentId)) {
        residentIds.push(task.residentId);
      }
    });
    return residentIds.length;
  }

  private isInitialLoading(): boolean {
    // A core snapshot can already contain tasks while the store finishes a
    // secondary refresh. In that state an empty category is a real empty
    // state, not a page-level spinner.
    return this.businessStore.loading && !this.businessStore.loaded && this.activeTaskData().length === 0;
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
      return this.activeTaskData().filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done');
    }
    if (filter === 'priority') {
      return this.activeTaskData().filter((task: CareTaskData) =>
        this.effectiveTaskState(task) !== 'done' && task.priority === 'danger');
    }
    if (filter === 'completed') {
      return this.activeTaskData().filter((task: CareTaskData) => this.effectiveTaskState(task) === 'done');
    }
    return this.activeTaskData().filter((task: CareTaskData) => task.category === filter);
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
    // Wide workspaces have enough room to keep the whole task set in one card.
    // Pagination remains the compact-layout behavior only.
    if (this.useWorkSplitLayout()) {
      return this.visibleTasks();
    }
    const start: number = this.currentTaskPage() * this.cardPageSize();
    return this.visibleTasks().slice(start, start + this.cardPageSize());
  }

  private pagedAiFocusItems(): AiFocusItem[] {
    if (this.useWorkSplitLayout()) {
      return this.aiFocusItems;
    }
    const start: number = this.currentAiPage() * this.cardPageSize();
    return this.aiFocusItems.slice(start, start + this.cardPageSize());
  }

  private showCardPagination(): boolean {
    return !this.useWorkSplitLayout();
  }

  private taskCardMinHeight(task: CareTaskData): number {
    if (task.category === 'medication' || task.category === 'record' || task.category === 'report') {
      return 112;
    }
    return 92;
  }

  private aiCardMinHeight(): number {
    // Wide cards should size themselves from the alert content.  Reusing the
    // overview-card minimum here makes a short alert list occupy most of the
    // viewport and creates the large blank area visible on 2-in-1 screens.
    return this.useWorkSplitLayout() ? 0 : 78;
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
      { title: '上报', index: 4, badgeText: this.tasksForFilter('report').length.toString() },
      { title: '完成', index: 5, badgeText: this.tasksForFilter('completed').length.toString() }
    ];
  }

  private filterIndex(): number {
    const filters: CareWorkFilter[] = ['todo', 'priority', 'medication', 'record', 'report', 'completed'];
    return filters.indexOf(this.activeFilter);
  }

  private selectFilter(index: number): void {
    const filters: CareWorkFilter[] = ['todo', 'priority', 'medication', 'record', 'report', 'completed'];
    this.activeFilter = filters[index] ?? 'todo';
    this.taskPageIndex = 0;
  }

  private categoryTasks(category: CareTaskCategory): CareTaskData[] {
    return this.activeTaskData()
      .filter((task: CareTaskData) => task.category === category)
      .sort((left: CareTaskData, right: CareTaskData): number => {
        const leftDone: number = this.effectiveTaskState(left) === 'done' ? 1 : 0;
        const rightDone: number = this.effectiveTaskState(right) === 'done' ? 1 : 0;
        if (leftDone !== rightDone) {
          return leftDone - rightDone;
        }
        return left.time.localeCompare(right.time);
      });
  }

  private visibleCategoryTasks(category: CareTaskCategory, size: CareCardSize = 'short'): CareTaskData[] {
    const tasks: CareTaskData[] = this.categoryTasks(category);
    const limit: number = size === 'long' ? 3 : 2;
    return this.expandedTaskCategory === category ? tasks : tasks.slice(0, limit);
  }

  private categoryCardMinHeight(category: CareTaskCategory, size: CareCardSize): number {
    const total: number = this.categoryTasks(category).length;
    const limit: number = size === 'long' ? 3 : 2;
    if (total === 0) {
      return size === 'long' ? 154 : 146;
    }
    const rows: number = this.expandedTaskCategory === category ? total : Math.min(total, limit);
    return (size === 'long' ? 88 : 84) + rows * 74 +
      (this.expandedTaskCategory !== category && total > limit ? 40 : 0);
  }

  private categoryPendingCount(category: CareTaskCategory): number {
    return this.categoryTasks(category)
      .filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done').length;
  }

  private categoryCountText(category: CareTaskCategory): string {
    const pending: number = this.categoryPendingCount(category);
    const total: number = this.categoryTasks(category).length;
    if (total === 0) {
      return '0 项';
    }
    return pending > 0 ? `${pending} 项待处理` : `${total} 项已完成`;
  }

  private toggleTaskCategory(category: CareTaskCategory): void {
    this.expandedTaskCategory = this.expandedTaskCategory === category ? '' : category;
  }

  private categoryTone(category: CareTaskCategory): ResourceColor {
    if (category === 'medication') {
      return $r('app.color.status_warning');
    }
    if (category === 'record') {
      return $r('app.color.status_normal');
    }
    if (category === 'report') {
      return $r('app.color.status_danger');
    }
    return $r('app.color.brand_blue');
  }

  private visibleRiskItems(): AiFocusItem[] {
    return this.riskCardExpanded ? this.aiFocusItems : this.aiFocusItems.slice(0, 2);
  }

  private riskCardMinHeight(): number {
    if (this.aiFocusItems.length === 0) {
      return 146;
    }
    const rows: number = this.riskCardExpanded ? this.aiFocusItems.length : Math.min(2, this.aiFocusItems.length);
    return 88 + rows * 74 + (!this.riskCardExpanded && this.aiFocusItems.length > 2 ? 40 : 0);
  }

  private pendingCount(): number {
    return this.activeTaskData().filter((task: CareTaskData) => this.effectiveTaskState(task) !== 'done').length;
  }

  private urgentCount(): number {
    return this.tasksForFilter('priority').length;
  }

  private completedCount(): number {
    return this.tasksForFilter('completed').length;
  }

  private progressPercent(): number {
    return this.activeTaskData().length > 0 ?
      Math.round(this.completedCount() / this.activeTaskData().length * 100) : 0;
  }

  private reportTaskProgress(): void {
    this.onTaskProgressChange(this.completedCount(), this.activeTaskData().length);
  }

  private selectedTask(): CareTaskData | undefined {
    return this.activeTaskData().find((task: CareTaskData) => task.id === this.selectedTaskId);
  }

  private selectedAiFocus(): AiFocusItem | undefined {
    return this.aiFocusItems.find((item: AiFocusItem) => item.id === this.selectedAiFocusId);
  }

  private selectedAiTask(): CareTaskData | undefined {
    if (this.selectedAiFocus() === undefined) {
      return undefined;
    }
    return this.activeTaskData().find((task: CareTaskData) => task.id === this.selectedAiFocus()!.taskId);
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

  private async handleTaskAction(task: CareTaskData): Promise<void> {
    const state: CareTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return;
    }
    const nextStatus: CareTaskState = state === 'pending' ? 'doing' : 'done';
    try {
      const request: TaskStatusRequest = { status: nextStatus === 'doing' ? 'doing' : 'done' };
      const response = await ApiClient.patch<Object>(`/tasks/${task.id}/status`, request);
      if (response.code !== 0) {
        this.showToast(response.msg || '任务状态更新失败');
        return;
      }
      this.backendTaskData = this.backendTaskData.map((item: CareTaskData): CareTaskData => {
        if (item.id !== task.id) {
          return item;
        }
        return {
          id: item.id,
          category: item.category,
          dueDate: item.dueDate,
          title: item.title,
          residentId: item.residentId,
          resident: item.resident,
          room: item.room,
          summary: item.summary,
          instructions: item.instructions,
          time: item.time,
          owner: item.owner,
          priority: item.priority,
          state: nextStatus
        };
      });
      this.businessStore.tasks = this.businessStore.tasks.map((item: BackendCareTask): BackendCareTask => {
        if (`${item.id}` !== task.id) {
          return item;
        }
        return {
          id: item.id,
          elder_id: item.elder_id,
          plan_item_id: item.plan_item_id,
          title: item.title,
          kind: item.kind,
          priority: item.priority,
          category: item.category,
          assignee: item.assignee,
          due_at: item.due_at,
          status: nextStatus === 'doing' ? 'doing' : 'done',
          remark: item.remark,
          plan_item: item.plan_item
        };
      });
      this.reportTaskProgress();
      this.showToast(nextStatus === 'done' ? '任务已完成' : '任务已开始');
    } catch (_error) {
      this.showToast('无法连接服务器，请稍后重试');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
    }
  }

  private executionSteps(task: CareTaskData): string[] {
    const rawSteps: string[] = task.instructions.split(/[\r\n；;]+/);
    const steps: string[] = [];
    for (let index: number = 0; index < rawSteps.length; index++) {
      const step: string = rawSteps[index].trim();
      if (step.length > 0) {
        steps.push(step);
      }
    }
    return steps;
  }

  @Builder
  private wideDashboard() {
    Column({ space: this.sectionGap() }) {
      this.homeHeader()
      this.homeStatCards()
      if (this.useWorkSplitLayout()) {
        Row({ space: this.sectionGap() }) {
          Column() {
            this.todayTaskCard()
          }.layoutWeight(2)
          Column({ space: this.sectionGap() }) {
            this.quickActionsCard()
            this.focusEldersCard()
          }.layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      } else {
        Column({ space: this.sectionGap() }) {
          this.todayTaskCard()
          this.quickActionsCard()
          this.focusEldersCard()
        }.width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private myScheduleToday(): Schedule | undefined {
    const user = AuthStore.getUser();
    const names: string[] = [user?.real_name ?? '', user?.username ?? ''];
    return this.businessStore.schedules.find((item: Schedule) =>
      item.work_date === this.dateValue() && names.includes(item.staff));
  }

  private shiftLabel(value: string): string {
    if (value === 'morning') {
      return '白班';
    }
    if (value === 'afternoon') {
      return '晚班';
    }
    if (value === 'night') {
      return '夜班';
    }
    return value;
  }

  private headerSubtitle(): string {
    const schedule: Schedule | undefined = this.myScheduleToday();
    if (!schedule) {
      return `今天是${this.dateText()} · 今日排班未登记`;
    }
    const scope: string = schedule.room_scope && schedule.room_scope.length > 0 ?
      ` · 负责区域 ${schedule.room_scope}` : '';
    return `今天是${this.dateText()} · ${this.shiftLabel(schedule.shift)}${scope}`;
  }

  /** 负责长者的楼栋与楼层概览，全部来自服务器房间记录。 */
  private areaSummaryText(): string {
    const buildings: string[] = [];
    let minFloor: number = 0;
    let maxFloor: number = 0;
    this.businessStore.elders.forEach((elder: Elder): void => {
      const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder.bed_id);
      const room: Room | undefined = bed === undefined ? undefined :
        this.businessStore.rooms.find((item: Room) => item.id === bed.room_id);
      if (room === undefined) {
        return;
      }
      if (room.building.trim().length > 0 && !buildings.includes(room.building.trim())) {
        buildings.push(room.building.trim());
      }
      if (minFloor === 0 || room.floor < minFloor) {
        minFloor = room.floor;
      }
      if (room.floor > maxFloor) {
        maxFloor = room.floor;
      }
    });
    if (buildings.length === 0 && maxFloor === 0) {
      return '床位待分配';
    }
    const floorText: string = maxFloor > 0 ? `${minFloor}-${maxFloor} 楼` : '';
    return `${buildings.join('、')}${buildings.length > 0 && floorText.length > 0 ? ' ' : ''}${floorText}`;
  }

  private currentUserId(): number {
    return AuthStore.getUser()?.id ?? 0;
  }

  private unreadMessages(): UserMessage[] {
    const me: number = this.currentUserId();
    return this.businessStore.messages
      .filter((item: UserMessage) => item.receiver_id === me && !item.read_at);
  }

  private unreadFromDoctorCount(): number {
    const unread: UserMessage[] = this.unreadMessages();
    if (unread.length === 0) {
      return 0;
    }
    return unread.filter((item: UserMessage) => {
      const contact: MessageContact | undefined =
        this.businessStore.messageContacts.find((peer: MessageContact) => peer.id === item.sender_id);
      return contact !== undefined && contact.roles.some((role: RoleInfo) =>
        role.code === 'doctor' || role.name.includes('医师') || role.name.includes('医生'));
    }).length;
  }

  private priorityRank(priority: CarePriority): number {
    return priority === 'danger' ? 0 : priority === 'warning' ? 1 : 2;
  }

  /** 关注老人：按未闭环告警的严重度归并到每位长者，无告警即为正常。 */
  private focusElderRows(): FocusElderRow[] {
    const worstByElder: Map<number, CarePriority> = new Map();
    const openAlerts: Alert[] = this.businessStore.alerts
      .filter((item: Alert) => item.status !== 'handled' && item.status !== 'closed');
    openAlerts.forEach((alert: Alert): void => {
      const elderId: number | undefined = alert.elder_id;
      if (elderId === undefined) {
        return;
      }
      const priority: CarePriority = this.serverAlertPriority(alert.level);
      const current: CarePriority | undefined = worstByElder.get(elderId);
      if (current === undefined || this.priorityRank(priority) < this.priorityRank(current)) {
        worstByElder.set(elderId, priority);
      }
    });
    const rows: FocusElderRow[] = this.businessStore.elders.map((elder: Elder): FocusElderRow => {
      return {
        elderId: elder.id,
        name: elder.name,
        location: this.elderLocation(elder.id),
        priority: worstByElder.get(elder.id) ?? 'normal'
      };
    });
    rows.sort((left: FocusElderRow, right: FocusElderRow): number =>
      this.priorityRank(left.priority) - this.priorityRank(right.priority));
    return rows.slice(0, 6);
  }

  private focusElderText(priority: CarePriority): string {
    if (priority === 'danger') {
      return '需关注';
    }
    return priority === 'warning' ? '观察中' : '正常';
  }

  private taskBadgeText(task: CareTaskData): string {
    const state: CareTaskState = this.effectiveTaskState(task);
    if (state === 'done') {
      return '已完成';
    }
    if (state === 'doing') {
      return '进行中';
    }
    return task.priority === 'danger' ? '紧急' : '待处理';
  }

  private homeTaskList(): CareTaskData[] {
    if (this.showAllTasks) {
      return this.activeTaskData()
        .slice()
        .sort((left: CareTaskData, right: CareTaskData): number =>
          `${left.dueDate} ${left.time}`.localeCompare(`${right.dueDate} ${right.time}`));
    }
    return this.allTodayPlanTasks();
  }

  private openQuickAction(action: string): void {
    this.assistError = '';
    this.reportError = '';
    this.quickActionDialog = action;
  }

  private closeQuickActionDialog(): void {
    this.quickActionDialog = '';
    this.assistError = '';
    this.reportError = '';
    this.assistSending = false;
    this.reportSending = false;
  }

  private quickActionTitle(): string {
    if (this.quickActionDialog === 'checkin') {
      return '签到打卡';
    }
    if (this.quickActionDialog === 'schedule') {
      return '查看排班';
    }
    return this.quickActionDialog === 'report' ? '上报异常' : '申请协助';
  }

  private async sendAssistRequest(): Promise<void> {
    const content: string = this.assistText.trim();
    if (this.assistTargetId <= 0 || content.length === 0 || this.assistSending) {
      return;
    }
    this.assistSending = true;
    try {
      const response = await MessageApi.send(this.assistTargetId, content, undefined, 'chat');
      if (response.code !== 0) {
        this.assistError = response.msg.length > 0 ? response.msg : '协助请求发送失败';
      } else {
        this.closeQuickActionDialog();
      }
    } catch (_error) {
      this.assistError = '协助请求发送失败，请检查网络';
    }
    this.assistSending = false;
  }

  private async submitReport(): Promise<void> {
    const remark: string = this.reportText.trim();
    if (this.reportElderId <= 0 || remark.length === 0 || this.reportSending) {
      return;
    }
    this.reportSending = true;
    const payload: ReportTaskRequest = {
      elder_id: this.reportElderId,
      title: '异常上报',
      kind: 'report',
      category: 'report',
      priority: 'warning',
      remark: remark
    };
    try {
      const response = await ApiClient.post<Object>('/tasks', payload);
      if (response.code !== 0) {
        this.reportError = response.msg.length > 0 ? response.msg : '异常上报失败';
      } else {
        this.closeQuickActionDialog();
        await this.loadBackendTasks();
      }
    } catch (_error) {
      this.reportError = '异常上报失败，请检查网络';
    }
    this.reportSending = false;
  }

  @Builder
  private homeHeader() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.greetingText())
          .fontSize(this.useXlLayout() ? 26 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(this.headerSubtitle())
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.myScheduleToday() ? this.shiftLabel(this.myScheduleToday()!.shift) : '未排班')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor(this.myScheduleToday() ? '#111111' : $r('sys.color.comp_background_secondary'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private homeMetricCard(big: string, label: string, sub: string, subDanger: boolean) {
    Column({ space: 8 }) {
      Text(big)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text(label)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text(sub)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor(subDanger ? $r('app.color.doctor_workspace_danger') : $r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  private homeStats(): HomeStat[] {
    const dangerCount: number = this.aiFocusItems.filter((item: AiFocusItem) => item.priority === 'danger').length;
    return [
      { big: `${this.todayCompletedCount()}/${this.allTodayPlanTasks().length}`, label: '今日任务',
        sub: `剩余 ${this.todayPendingCount()} 项`, subDanger: false },
      { big: `${this.visibleResidentCount()}`, label: '负责老人', sub: this.areaSummaryText(), subDanger: false },
      { big: `${this.aiFocusItems.length}`, label: '待处理',
        sub: dangerCount > 0 ? `${dangerCount} 项紧急` : '暂无紧急', subDanger: dangerCount > 0 },
      { big: `${this.unreadMessages().length}`, label: '未读消息', sub: this.unreadMessages().length === 0 ? '已全部阅读' :
          `${this.unreadFromDoctorCount()} 条来自医师`, subDanger: false }
    ];
  }

  @Builder
  private homeStatCards() {
    GridRow({ columns: 4, gutter: { x: this.sectionGap(), y: this.sectionGap() } }) {
      ForEach(this.homeStats(), (stat: HomeStat) => {
        GridCol({ span: { xs: 2, sm: 2, md: 2, lg: 1, xl: 1 } }) {
          this.homeMetricCard(stat.big, stat.label, stat.sub, stat.subDanger)
        }
      }, (stat: HomeStat) => `home-stat-${stat.label}`)
    }
    .width('100%')
  }

  @Builder
  private taskStateBadge(task: CareTaskData) {
    Text(this.taskBadgeText(task))
      .fontSize($r('sys.float.Caption_M'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.effectiveTaskState(task) === 'done' ? $r('sys.color.font_secondary') :
        this.effectiveTaskState(task) === 'doing' || this.taskBadgeText(task) === '紧急' ?
          Color.White : $r('sys.color.font_primary'))
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor(this.effectiveTaskState(task) === 'doing' ? '#1D1D1D' :
        this.taskBadgeText(task) === '紧急' ? '#E5484D' : $r('sys.color.comp_background_secondary'))
  }

  @Builder
  private homeTaskRow(task: CareTaskData, isLast: boolean) {
    Row({ space: 14 }) {
      Text(task.time)
        .width(52)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(task.title)
        .layoutWeight(2)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(task.resident)
        .layoutWeight(1)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(task.room)
        .width(84)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.taskStateBadge(task)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 13, bottom: 13 })
    .alignItems(VerticalAlign.Center)
    .keyboardFocusStyle()
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.openTask(task.id)))
    .onClick(() => this.openTask(task.id))
    if (!isLast) {
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
    }
  }

  @Builder
  private todayTaskCard() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Text('今日任务')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        this.actionTextButton(this.showAllTasks ? '今日' : '全部', () => this.showAllTasks = !this.showAllTasks)
      }
      .width('100%')
      .padding({ left: 18, right: 12, top: 16, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.homeTaskList().length === 0) {
        Text(this.isInitialLoading() ? '正在加载服务器任务' :
          (this.showAllTasks ? '暂无任务记录' : '今日暂无任务'))
          .width('100%')
          .padding({ top: 32, bottom: 32 })
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.homeTaskList(), (task: CareTaskData, index: number) => {
          this.homeTaskRow(task, index === this.homeTaskList().length - 1)
        }, (task: CareTaskData) => `home-task-${task.id}`)
      }
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private actionTextButton(label: string, onTap: () => void) {
    Text(label)
      .fontSize($r('sys.float.Body_M'))
      .fontColor($r('sys.color.font_secondary'))
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(8)
      .keyboardFocusStyle()
      .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, onTap))
      .onClick(() => onTap())
  }

  @Builder
  private quickActionButton(label: string, action: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .height(62)
    .layoutWeight(1)
    .borderRadius(10)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .keyboardFocusStyle()
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.openQuickAction(action)))
    .onClick(() => this.openQuickAction(action))
  }

  @Builder
  private quickActionsCard() {
    Column({ space: 14 }) {
      Text('快捷操作')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      Row({ space: 12 }) {
        this.quickActionButton('签到打卡', 'checkin')
        this.quickActionButton('申请协助', 'assist')
      }.width('100%')
      Row({ space: 12 }) {
        this.quickActionButton('上报异常', 'report')
        this.quickActionButton('查看排班', 'schedule')
      }.width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private focusElderBadge(priority: CarePriority) {
    Text(this.focusElderText(priority))
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(priority === 'danger' ? $r('app.color.doctor_workspace_danger') :
        priority === 'warning' ? '#B45309' : $r('app.color.doctor_workspace_success'))
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor(priority === 'danger' ? '#FDEBEC' :
        priority === 'warning' ? '#FDF3E7' : '#E8F5EE')
  }

  @Builder
  private focusElderRow(row: FocusElderRow, isLast: boolean) {
    Row({ space: 10 }) {
      Text(row.name)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(row.location)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      this.focusElderBadge(row.priority)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .keyboardFocusStyle()
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.onOpenResident(`${row.elderId}`)))
    .onClick(() => this.onOpenResident(`${row.elderId}`))
    if (!isLast) {
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
    }
  }

  @Builder
  private focusEldersCard() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Text('关注老人')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        this.actionTextButton('更多', () => this.isAiFocusSheetOpen = true)
      }
      .width('100%')
      .padding({ left: 18, right: 12, top: 16, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.businessStore.elders.length === 0) {
        Text(this.isInitialLoading() ? '正在加载长者档案' : '暂无长者档案')
          .width('100%')
          .padding({ top: 24, bottom: 24 })
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.focusElderRows(), (row: FocusElderRow, index: number) => {
          this.focusElderRow(row, index === this.focusElderRows().length - 1)
        }, (row: FocusElderRow) => `focus-elder-${row.elderId}`)
      }
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private quickActionOverlay() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text(this.quickActionTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        this.actionTextButton('关闭', () => this.closeQuickActionDialog())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 12 }) {
          if (this.quickActionDialog === 'checkin') {
            this.checkinDialogContent()
          }
          if (this.quickActionDialog === 'schedule') {
            this.scheduleDialogContent()
          }
          if (this.quickActionDialog === 'assist') {
            this.assistDialogContent()
          }
          if (this.quickActionDialog === 'report') {
            this.reportDialogContent()
          }
        }.width('100%')
      }
      .constraintSize({ maxHeight: 380 })
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width(this.compactWidth ? '92%' : 480)
    .padding(22)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private checkinDialogContent() {
    if (this.myScheduleToday()) {
      Text(`今天(${this.dateText()})已登记 ${this.shiftLabel(this.myScheduleToday()!.shift)}` +
        (this.myScheduleToday()!.room_scope && this.myScheduleToday()!.room_scope!.length > 0 ?
          ` · 负责区域 ${this.myScheduleToday()!.room_scope}` : ''))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
    } else {
      Text('今天没有你的排班记录。')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
    }
    Text('考勤打卡由机构考勤系统统一记录，能力开通前请以线下签到为准。')
      .fontSize($r('sys.float.Caption_M'))
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
  }

  @Builder
  private scheduleDialogContent() {
    if (this.businessStore.schedules.length === 0) {
      Text('服务器暂无排班记录。')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
    } else {
      ForEach(this.businessStore.schedules
        .slice()
        .sort((left: Schedule, right: Schedule): number => left.work_date.localeCompare(right.work_date)),
        (item: Schedule, index: number) => {
          Column({ space: 3 }) {
            Text(`${item.work_date} · ${item.staff}`)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text(`${this.shiftLabel(item.shift)}` +
              (item.room_scope && item.room_scope.length > 0 ? ` · 负责区域 ${item.room_scope}` : ''))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 8, bottom: 8 })
          if (index < this.businessStore.schedules.length - 1) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          }
        }, (item: Schedule) => `home-schedule-${item.id}`)
    }
  }

  @Builder
  private selectableRow(label: string, detail: string, selected: boolean, onSelect: () => void) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (detail.length > 0) {
          Text(detail)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (selected) {
        Text('已选择')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('app.color.brand_blue'))
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(10)
    .border({ width: 0.5, color: selected ? $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
    .backgroundColor(selected ? '#F0F5FF' : $r('sys.color.comp_background_primary'))
    .keyboardFocusStyle()
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, onSelect))
    .onClick(() => onSelect())
  }

  @Builder
  private assistDialogContent() {
    Text('选择协助对象')
      .fontSize($r('sys.float.Caption_M'))
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
    if (this.businessStore.messageContacts.length === 0) {
      Text('暂无可联系的人员，请先在消息页确认联系人。')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
    } else {
      Column({ space: 8 }) {
        ForEach(this.businessStore.messageContacts, (contact: MessageContact) => {
          this.selectableRow(contact.real_name || contact.username,
            contact.roles.map((role: RoleInfo) => role.name).join('、'),
            this.assistTargetId === contact.id,
            () => this.assistTargetId = contact.id)
        }, (contact: MessageContact) => `assist-contact-${contact.id}`)
      }.width('100%')
    }
    TextArea({ placeholder: '描述需要的协助内容…', text: $$this.assistText })
      .height(90)
      .fontSize($r('sys.float.Body_M'))
    if (this.assistError.length > 0) {
      Text(this.assistError)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('app.color.doctor_workspace_danger'))
        .width('100%')
    }
    Button(this.assistSending ? '发送中…' : '发送协助请求')
      .width('100%')
      .height(42)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(Color.White)
      .backgroundColor($r('app.color.brand_blue'))
      .enabled(this.assistTargetId > 0 && this.assistText.trim().length > 0 && !this.assistSending)
      .onClick(() => this.sendAssistRequest())
  }

  @Builder
  private reportDialogContent() {
    Text('选择相关长者')
      .fontSize($r('sys.float.Caption_M'))
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
    if (this.businessStore.elders.length === 0) {
      Text('暂无长者档案，无法上报异常。')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
    } else {
      Column({ space: 8 }) {
        ForEach(this.businessStore.elders, (elder: Elder) => {
          this.selectableRow(elder.name, this.elderLocation(elder.id),
            this.reportElderId === elder.id,
            () => this.reportElderId = elder.id)
        }, (elder: Elder) => `report-elder-${elder.id}`)
      }.width('100%')
    }
    TextArea({ placeholder: '描述异常情况（时间、地点、现象、已采取措施）…', text: $$this.reportText })
      .height(90)
      .fontSize($r('sys.float.Body_M'))
    if (this.reportError.length > 0) {
      Text(this.reportError)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('app.color.doctor_workspace_danger'))
        .width('100%')
    }
    Button(this.reportSending ? '提交中…' : '提交异常上报')
      .width('100%')
      .height(42)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(Color.White)
      .backgroundColor('#E5484D')
      .enabled(this.reportElderId > 0 && this.reportText.trim().length > 0 && !this.reportSending)
      .onClick(() => this.submitReport())
  }

  @Builder
  private aiFocusSheet() {
    if (this.selectedAiFocus() !== undefined) {
      Column({ space: 0 }) {
        Scroll() {
          Column({ space: 18 }) {
            Row({ space: 14 }) {
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
                Text('护理安全提醒')
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
              Text('提醒依据')
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
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
              Text('建议处理')
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
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

            Text('康小伴根据服务器授权数据提供辅助整理，不替代护理规范、医嘱或现场人工判断。')
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
                Text(task.room + ' · 关联长者档案')
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
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
            if (this.executionSteps(task).length === 0) {
              Text('暂无执行要点，请联系负责人补充护理要求')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
            } else {
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
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('处理记录')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            if (this.effectiveTaskState(task) === 'done') {
              Text('任务状态已同步到服务器')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
                .padding({ top: 12, bottom: 12 })
              .width('100%')
            } else {
              Text('当前服务仅支持同步任务状态，处理记录接口尚未开放。')
                .width('100%')
                .padding(12)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
                .backgroundColor($r('sys.color.comp_background_secondary'))
                .borderRadius(14)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('康小伴建议')
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
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
          this.wideDashboard()
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
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
      .backgroundColor($r('sys.color.background_secondary'))

      if (this.quickActionDialog.length > 0) {
        Row() {
          this.quickActionOverlay()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center)
      }
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
    .bindSheet(this.isAiFocusSheetOpen, this.aiFocusSheet, {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.CENTER,
      width: this.aiFocusSheetWidth(),
      showClose: true,
      dragBar: true,
      title: { title: '风险提醒' },
      backgroundColor: $r('sys.color.comp_background_primary'),
      onDisappear: () => {
        if (this.isAiFocusSheetOpen) {
          this.isAiFocusSheetOpen = false;
        }
      }
    })
  }
}
