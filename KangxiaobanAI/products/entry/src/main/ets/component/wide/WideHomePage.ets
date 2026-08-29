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
import { Alert, Bed, CareTask as BackendCareTask, Elder, Room, Schedule, TaskStatusRequest } from '../../network/Dto';

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
  @Local backendTaskData: CareTaskData[] = [];
  @Local businessStore: BusinessStore = BusinessStore.getShared();

  private taskData: CareTaskData[] = [];

  @Local aiFocusItems: AiFocusItem[] = [];

  @Local checkpoints: CareCheckpoint[] = [];
  @Local riskTrendValues: number[] = [];
  @Local closureTrendValues: number[] = [];

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
    if (value === 'medication' || value === 'record' || value === 'family' || value === 'report') {
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
      return `今日排班未登记 · 当前可见 ${this.businessStore.elders.length} 位长者`;
    }
    const scope: string = schedule.room_scope && schedule.room_scope.length > 0 ? schedule.room_scope : '范围未登记';
    return `${schedule.shift} · ${scope} · 当前可见 ${this.businessStore.elders.length} 位长者`;
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
  private workOverviewCard() {
    Column({ space: this.useXlLayout() ? 16 : 12 }) {
      Row({ space: 16 }) {
        Column({ space: 4 }) {
          Text(this.greetingText())
            .fontSize(this.useXlLayout() ? 24 : 22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(this.shiftSummary())
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
          Text(this.completedCount() + ' / ' + this.activeTaskData().length + ' 项完成')
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

      if (this.aiFocusItems.length === 0) {
        Text(this.businessStore.loading ? '正在加载服务器告警' : '暂无未闭环风险告警')
          .width('100%')
          .height(150)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      } else {
        Column({ space: 4 }) {
          ForEach(this.pagedAiFocusItems(), (item: AiFocusItem, index: number) => {
            this.aiFocusRow(item, index === this.pagedAiFocusItems().length - 1)
          }, (item: AiFocusItem) => item.id)
        }
        .width('100%')
        .layoutWeight(this.useWorkSplitLayout() ? 1 : 0)
        .padding({ left: 10, right: 10, bottom: 8 })
      }

      this.cardPagination(true)
    }
    .width('100%')
    .height(this.useWorkSplitLayout() && this.isTabletDevice() ? '100%' : undefined)
    .constraintSize({ minHeight: this.summaryCardMinHeight() })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
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

      if (this.checkpoints.length === 0) {
        Text(this.businessStore.loading ? '正在加载服务器任务' : '暂无今日护理任务')
          .width('100%')
          .height(120)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.checkpoints, (checkpoint: CareCheckpoint, index: number) => {
          this.checkpointRow(checkpoint, index === this.checkpoints.length - 1)
        }, (checkpoint: CareCheckpoint) => checkpoint.id)
      }
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
        GridCol({ span: this.isTabletDevice() ? 12 : 8 }) {
          this.taskQueueCard()
        }
        .height('100%')
        if (!this.isTabletDevice()) {
          GridCol({ span: 4 }) {
            this.checkpointCard()
          }
          .height('100%')
        }
      } else {
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
                Text(task.room + ' · 关联长者档案')
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
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([$r('app.color.status_normal')])
                Text('任务状态已同步到服务器')
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .width('100%')
              .height(48)
              .alignItems(VerticalAlign.Center)
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
