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

import { AppStorageV2, SymbolGlyphModifier, curves } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixText,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import Logger from '../util/Logger';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig } from '../model/TabPageModel';
import { BreakpointType, BreakpointUtil } from '../util/BreakpointSystem';
import { WindowUtil } from '../util/WindowUtil';
import AuthStore from '../network/AuthStore';
import { BusinessStore } from '../network/BusinessStore';
import { Alert, Bed, CareTask as BackendCareTask, Elder, HealthRecord, IotDevice, MedicationRecord, MessageContact, Room, UserMessage } from '../network/Dto';
import { HealthListCard, HealthListCardData, HealthListCardRow } from './HealthListCard';

import { EventListCard, EventListCardData, EventListCardRow } from './EventListCard';
import {
  HealthRowData,
  MedicationProgress,
  ResidentData,
  StatusLevel,
  VitalSign
} from '../model/DetailTypes';
import { HealthExpandPage } from '../pages/HealthExpandPage';
import { AiTitleLabel } from './AiTitleLabel';
import {
  RESIDENT_SUMMARY_CARD_HEIGHT,
  ResidentSummaryCard
} from './ResidentSummaryCard';
import { PhoneLocalMessageRecord, PhoneMessageChatPage } from './PhoneMessageChatPage';

type TaskSource = 'ai' | 'elder' | 'staff' | 'plan';
type TaskStatus = 'todo' | 'doing' | 'done';
type EventType = 'ai' | 'alert' | 'care' | 'family';
type MessageKind = 'handoff' | 'family' | 'notice';
type MessageFilter = 'all' | 'unread' | MessageKind;

interface InboxMessage {
  id: string;
  kind: MessageKind;
  sender: string;
  preview: string;
  content: string;
  time: string;
  unread: boolean;
}

interface MessageFilterOption {
  label: string;
  value: MessageFilter;
}

interface BedSummary {
  total: number;
  occupied: number;
  empty: number;
  maintenance: number;
}

interface DeviceRowData {
  id: string;
  name: string;
  room: string;
  type: string;
  status: string;
  level: StatusLevel;
  lastUpdate: string;
}

interface EventRowData {
  time: string;
  type: EventType;
  title: string;
  detail: string;
}

interface CareTask {
  id: string;
  source: TaskSource;
  priority: StatusLevel;
  status: TaskStatus;
  title: string;
  elder: string;
  room: string;
  time: string;
  assignee: string;
  detail: string;
}

interface TaskTimelineItem {
  time: string;
  actor: string;
  action: string;
}

interface QuickActionData {
  icon: Resource;
  label: string;
  subLabel?: string;
  badge?: string;
}

interface AiReminder {
  id: string;
  level: StatusLevel;
  location: string;
  name: string;
  title: string;
  detail: string;
  signal: string;
  suggestion: string;
}

interface QuickListRow {
  id: string;
  title: string;
  sub: string;
  time?: string;
  tag?: string;
  tagColor?: ResourceColor;
  tagBg?: ResourceColor;
}

interface TaskGroup {
  status: TaskStatus;
  label: string;
  level: StatusLevel;
  tasks: CareTask[];
}

interface MedicationTimeGroup {
  period: string;
  timeRange: string;
  items: QuickListRow[];
}

interface SettingItemData {
  icon: Resource;
  label: string;
  value?: string;
  showArrow: boolean;
  isDanger?: boolean;
  action?: () => void;
}

interface SettingGroupData {
  title: string;
  items: SettingItemData[];
}

interface ProfileSheetItem {
  label: string;
  value?: string;
  isAvatar?: boolean;
  tag?: string;
}

@ComponentV2
export struct TabPageView {
  @Param @Require currentTabIndex: number;
  @Param @Require pageKey: PageKeyEnum;
  @Param @Require config: TabPageConfig;
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Event onSwitchTab: (index: number) => void = () => {};
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenResidentDetail: (resident: ResidentData, vitalSign: VitalSign,
    medicationProgress: MedicationProgress, geometryId: string) => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local isProfileSheetOpen: boolean = false;
  @Local selectedTaskId: string = '';
  @Local isTaskSheetOpen: boolean = false;
  @Local selectedQuickRowId: string = '';
  @Local isQuickRowSheetOpen: boolean = false;
  @Local isExpandSheetOpen: boolean = false;
  @Local residentSearch: string = '';
  @Local residentFilter: 'all' | 'warning' | 'danger' = 'all';
  @Local taskFilter: 'all' | 'ai' | 'elder' | 'plan' = 'all';
  @Local messageFilter: MessageFilter = 'all';
  @Local selectedMessageId: string = '';
  @Local readMessageIds: string[] = [];
  @Local isPhoneMessageChatOpen: boolean = false;
  @Local phoneLocalMessageRecords: PhoneLocalMessageRecord[] = [];
  @Local selectedAiReminderId: string = '';
  @Local isAiReminderSheetOpen: boolean = false;
  @Local selectedQuickActionIndex: number = 0;
  @Local isHealthExpandShow: boolean = false;
  @Local isTaskExpandShow: boolean = false;
  @Local businessStore: BusinessStore = BusinessStore.getShared();

  aboutToAppear(): void {
    if (AuthStore.getToken().length > 0) {
      this.businessStore.load();
    }
  }

  private openAiChat(): void {
    this.onOpenAiChat();
  }

  private selectedAiReminder(): AiReminder | undefined {
    return this.aiReminders().find((item: AiReminder) => item.id === this.selectedAiReminderId);
  }

  private openAiReminderSheet(itemId: string): void {
    this.selectedAiReminderId = itemId;
    this.isAiReminderSheetOpen = true;
  }

  private closeAiReminderSheet(): void {
    this.isAiReminderSheetOpen = false;
  }

  private openHealthExpand(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 328, 36)
    }, () => {
      this.isHealthExpandShow = true;
    })
  }

  private closeHealthExpand(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isHealthExpandShow = false;
    })
  }

  private openResidentDetail(item: ResidentData): void {
    this.onOpenResidentDetail(item, this.residentVitalSign(item),
      this.residentMedicationProgress(item), this.residentGeometryId(item.id));
  }

  private openTaskExpand(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 328, 36)
    }, () => {
      this.isTaskExpandShow = true;
    })
  }

  private closeTaskExpand(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isTaskExpandShow = false;
    })
  }

  private quickExpandGeometryId(): string {
    return `quick_expand_geo_${this.selectedQuickActionIndex}`;
  }

  private quickExpandTitle(): string {
    if (this.selectedQuickActionIndex === 0) {
      return '待办任务';
    } else if (this.selectedQuickActionIndex === 1) {
      return '用药提醒';
    }
    return '';
  }

  private quickExpandRows(): QuickListRow[] {
    if (this.selectedQuickActionIndex === 0) {
      return this.taskListRows();
    } else if (this.selectedQuickActionIndex === 1) {
      return this.medicationItems();
    }
    return [];
  }

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 16;
  }

  private titleBarHeight(): number {
    return 40;
  }

  private homeTitleBarHeight(): number {
    return 33;
  }

  private contentTopPadding(): number {
    if (this.isWideLayout()) {
      return 0;
    }
    return this.topPadding() + this.titleBarHeight();
  }

  private homeContentTopPadding(): number {
    if (this.isWideLayout()) {
      return 0;
    }
    return this.topPadding() + this.homeTitleBarHeight();
  }

  private currentScroller(): Scroller | undefined {
    return PAGE_SCROLLER_MAP.get(this.pageKey)?.[this.currentTabIndex];
  }

  private isWideLayout(): boolean {
    return BreakpointUtil.usesWideWorkspace(
      this.globalInfoModel.deviceWidth,
      this.globalInfoModel.widthBreakpoint
    );
  }

  private isExtraWideLayout(): boolean {
    return this.isWideLayout() && BreakpointUtil.isExtraWide(this.globalInfoModel.widthBreakpoint);
  }

  private pagePadding(): number {
    return new BreakpointType<number>({
      sm: 16,
      md: 24,
      lg: 28,
      xl: 32
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  private bottomPadding(): number {
    return this.isWideLayout() ? 36 : 124;
  }

  private pageBackgroundColor(): ResourceColor {
    return $r('sys.color.background_secondary');
  }

  private statusColor(level: StatusLevel): ResourceColor {
    if (level === 'danger') {
      return $r('app.color.status_danger');
    }
    if (level === 'warning') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.status_normal');
  }

  private statusBg(level: StatusLevel): ResourceColor {
    if (level === 'danger') {
      return $r('app.color.status_danger_bg');
    }
    if (level === 'warning') {
      return $r('app.color.status_warning_bg');
    }
    return $r('app.color.status_normal_bg');
  }

  @Styles
  itemNormalStyle() {
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .shadow({ radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    .scale({ x: 1, y: 1 })
  }

  @Styles
  itemPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
    .shadow({ radius: 7, color: 'rgba(0,0,0,0.10)', offsetX: 0, offsetY: 2 })
    .scale({ x: 0.992, y: 0.992 })
  }

  @Styles
  residentCardNormalStyle() {
    .opacity(1)
  }

  @Styles
  residentCardPressedStyle() {
    .opacity(0.72)
  }

  private sheetWidthForWide(): number | undefined {
    return this.isWideLayout() ? 480 : undefined;
  }

  private expandMaxWidth(): number {
    return this.isWideLayout() ? 880 : 9999;
  }

  private sourceText(source: TaskSource): string {
    if (source === 'ai') {
      return '系统';
    }
    if (source === 'elder') {
      return '长者';
    }
    if (source === 'plan') {
      return '计划';
    }
    return '护工';
  }

  private statusText(status: TaskStatus): string {
    if (status === 'todo') {
      return '待办';
    }
    if (status === 'doing') {
      return '进行中';
    }
    return '已完成';
  }

  private eventTypeIcon(type: EventType): Resource {
    if (type === 'ai') {
      return $r('sys.symbol.ellipsis_message_fill');
    }
    if (type === 'alert') {
      return $r('sys.symbol.exclamationmark_triangle_fill');
    }
    if (type === 'care') {
      return $r('sys.symbol.heart_fill');
    }
    return $r('sys.symbol.phone_fill');
  }

  private eventTypeColor(type: EventType): ResourceColor {
    if (type === 'ai') {
      return $r('app.color.brand_blue');
    }
    if (type === 'alert') {
      return $r('app.color.status_danger');
    }
    if (type === 'care') {
      return $r('app.color.event_care');
    }
    return $r('app.color.event_family');
  }

  // ---------------- home data ----------------

  private bedSummary(): BedSummary {
    if (this.businessStore.loaded) {
      const total: number = this.businessStore.beds.length;
      const occupied: number = this.businessStore.beds.filter((item: Bed) => item.status === 'occupied').length;
      const maintenance: number = this.businessStore.beds.filter((item: Bed) => item.status === 'maintenance').length;
      return { total: total, occupied: occupied, empty: Math.max(0, total - occupied - maintenance), maintenance: maintenance };
    }
    return { total: 156, occupied: 128, empty: 24, maintenance: 4 };
  }

  private bedOccupiedPercent(): number {
    const bed: BedSummary = this.bedSummary();
    return Math.round(bed.occupied / bed.total * 100);
  }

  private bedPercent(value: number): number {
    const bed: BedSummary = this.bedSummary();
    return Math.round(value / bed.total * 100);
  }

  private healthRows(): HealthRowData[] {
    if (this.businessStore.loaded) {
      return this.businessStore.elders.map((elder: Elder): HealthRowData => this.healthRowFromElder(elder));
    }
    return [];
  }

  private healthRowFromElder(elder: Elder): HealthRowData {
    const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder.bed_id);
    const room: Room | undefined = bed ? this.businessStore.rooms.find((item: Room) => item.id === bed.room_id) : undefined;
    const latest: HealthRecord | undefined = this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === elder.id)
      .sort((left: HealthRecord, right: HealthRecord): number => right.record_time.localeCompare(left.record_time))[0];
    const abnormal: boolean = latest?.is_abnormal ?? false;
    return {
      id: `${elder.id}`, name: elder.name, age: this.ageFromBirthDate(elder.birth_date),
      room: room ? `${room.floor}F-${room.room_no}` : '未分配', bed: bed ? `${bed.bed_no}床` : '未分配',
      level: abnormal ? 'warning' : 'normal', status: abnormal ? '体征需要关注' : '稳定观察',
      mood: abnormal ? '需关注' : '平稳', moodLevel: abnormal ? 'warning' : 'normal',
      lastUpdate: latest ? latest.record_time.slice(11, 16) : '--'
    };
  }

  private ageFromBirthDate(value?: string): number {
    return value && value.length >= 4 ? new Date().getFullYear() - Number(value.slice(0, 4)) : 0;
  }

  private healthCardData(): HealthListCardData {
    return {
      title: '老人健康状态',
      rows: this.healthRows().map((item: HealthRowData): HealthListCardRow => {
        return {
          id: item.id,
          name: item.name,
          age: item.age,
          room: item.room,
          bed: item.bed,
          status: item.status,
          level: item.level,
          mood: item.mood,
          lastUpdate: item.lastUpdate
        };
      })
    };
  }

  private eventCardData(): EventListCardData {
    return {
      title: '今日事件流',
      rows: this.eventRows().map((item: EventRowData): EventListCardRow => {
        return {
          time: item.time,
          type: item.type,
          title: item.title,
          detail: item.detail
        };
      })
    };
  }

  private deviceRows(): DeviceRowData[] {
    if (this.businessStore.loaded) {
      return this.businessStore.devices.map((device: IotDevice): DeviceRowData => {
        const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === device.elder_id);
        return { id: `${device.id}`, name: device.product, room: device.room || elder?.name || '未绑定',
          type: device.protocol, status: device.online === 1 ? '在线' : '离线',
          level: device.online === 1 ? 'normal' : 'danger', lastUpdate: device.last_seen ? device.last_seen.slice(11, 16) : '--' };
      });
    }
    return [];
  }

  private eventRows(): EventRowData[] {
    if (this.businessStore.loaded) {
      return this.businessStore.alerts.map((alert: Alert): EventRowData => {
        const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === alert.elder_id);
        const type: EventType = alert.level === 'emergency' ? 'alert' : alert.type.indexOf('offline') >= 0 ? 'alert' : 'ai';
        return { time: alert.create_time.slice(11, 16), type: type, title: alert.type, detail: `${elder?.name ?? '机构设备'}：${alert.content}` };
      });
    }
    return [];
  }

  private medicationItems(): QuickListRow[] {
    if (this.businessStore.loaded) {
      return this.businessStore.medications.map((medication: MedicationRecord): QuickListRow => {
        const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === medication.elder_id);
        return { id: `${medication.id}`, title: medication.medicine_name, sub: `${elder?.name ?? '未知长者'} · ${medication.dosage}`,
          time: medication.plan_time ? medication.plan_time.slice(11, 16) : '--', tag: medication.status === 'taken' ? '已完成' : medication.status,
          tagColor: medication.status === 'taken' ? $r('sys.color.font_tertiary') : $r('app.color.brand_blue'),
          tagBg: medication.status === 'taken' ? $r('sys.color.comp_background_tertiary') : $r('app.color.status_normal_bg') };
      });
    }
    return [];
  }

  private recordItems(): QuickListRow[] {
    return [];
  }

  private familyItems(): QuickListRow[] {
    return [];
  }

  private reportItems(): QuickListRow[] {
    if (this.businessStore.loaded) {
      return this.businessStore.alerts.map((alert: Alert): QuickListRow => {
        const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === alert.elder_id);
        const handled: boolean = alert.status === 'handled' || alert.status === 'closed';
        return { id: `${alert.id}`, title: alert.content, sub: elder?.name ?? alert.device_id, time: alert.create_time.slice(11, 16),
          tag: handled ? '已跟进' : '待处理', tagColor: handled ? $r('app.color.status_normal') : $r('app.color.status_danger'),
          tagBg: handled ? $r('app.color.status_normal_bg') : $r('app.color.status_danger_bg') };
      });
    }
    return [];
  }

  // ---------------- residents data ----------------

  private allResidents(): ResidentData[] {
    if (this.businessStore.loaded) {
      return this.businessStore.elders.map((elder: Elder): ResidentData => {
        const row: HealthRowData = this.healthRowFromElder(elder);
        return { id: row.id, name: row.name, age: row.age, gender: elder.gender === 'F' ? 'female' : 'male', room: row.room, bed: row.bed,
          level: row.level, status: row.status, emergencyContact: elder.emergency_contacts?.[0]?.name ?? '未登记',
          emergencyPhone: elder.emergency_contacts?.[0]?.phone ?? '', admissionDate: elder.created_at ?? '',
          careLevel: `${elder.care_level}级护理`, diagnosis: elder.remark ? elder.remark.split('；') : [], allergies: [],
          deviceIds: this.businessStore.devices.filter((device: IotDevice) => device.elder_id === elder.id).map((device: IotDevice): string => device.device_id), avatarText: elder.name.slice(0, 1) };
      });
    }
    return [];
  }

  private filteredResidents(): ResidentData[] {
    return this.allResidents().filter((item: ResidentData) => {
      const matchSearch: boolean = !this.residentSearch ||
        item.name.includes(this.residentSearch) ||
        item.room.includes(this.residentSearch);
      const matchFilter: boolean = this.residentFilter === 'all' || item.level === this.residentFilter;
      return matchSearch && matchFilter;
    });
  }

  // ---------------- tasks data ----------------

  private allTasks(): CareTask[] {
    if (this.businessStore.loaded) {
      return this.businessStore.tasks.map((task: BackendCareTask): CareTask => {
        const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === task.elder_id);
        const status: TaskStatus = task.status === 'doing' || task.status === 'done' ? task.status : 'todo';
        return { id: `${task.id}`, source: task.kind === 'medication' ? 'plan' : 'elder', priority: 'normal', status: status,
          title: task.title, elder: elder?.name ?? '未知长者', room: '未分配', time: task.due_at ? task.due_at.slice(11, 16) : '--',
          assignee: task.assignee ?? '', detail: task.remark ?? '' };
      });
    }
    return [];
  }

  private filteredTasks(): CareTask[] {
    return this.allTasks().filter((item: CareTask) => {
      return this.taskFilter === 'all' || item.source === this.taskFilter;
    });
  }

  private selectedTask(): CareTask | undefined {
    return this.allTasks().find((item: CareTask) => item.id === this.selectedTaskId);
  }

  private taskTimeline(): TaskTimelineItem[] {
    return [];
  }

  // ---------------- shared builders ----------------

  @Builder
  private statusTag(text: string, level: StatusLevel) {
    Text(text)
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(this.statusColor(level))
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .backgroundColor(this.statusBg(level))
      .borderRadius(4)
  }

  @Builder
  private divider(isLast: boolean) {
    if (!isLast) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
    }
  }

  // ---------------- home builders ----------------

  private onlineDeviceCount(): number {
    return this.deviceRows().filter((item: DeviceRowData) => item.level === 'normal').length;
  }

  private residentCardHeight(): number {
    return RESIDENT_SUMMARY_CARD_HEIGHT;
  }

  /** 模拟长者最新体征快照（后续接真实数据源） */
  private residentVitalSign(resident: ResidentData): VitalSign {
    const map: Record<string, VitalSign> = {
      'r1': {
        heartRate: 72, systolic: 138, diastolic: 85, oxygen: 96,
        temperature: 36.5, respiratory: 18, steps: 1240, sleepHours: 5.2,
        measuredAt: '10:24'
      },
      'r2': {
        heartRate: 78, systolic: 125, diastolic: 80, oxygen: 97,
        temperature: 36.4, respiratory: 17, steps: 2100, sleepHours: 6.8,
        measuredAt: '09:46'
      },
      'r3': {
        heartRate: 70, systolic: 142, diastolic: 88, oxygen: 95,
        temperature: 36.6, respiratory: 19, steps: 380, sleepHours: 4.5,
        measuredAt: '09:12'
      },
      'r4': {
        heartRate: 68, systolic: 118, diastolic: 76, oxygen: 98,
        temperature: 36.3, respiratory: 16, steps: 3200, sleepHours: 7.2,
        measuredAt: '08:30'
      },
      'r5': {
        heartRate: 75, systolic: 122, diastolic: 78, oxygen: 98,
        temperature: 36.4, respiratory: 17, steps: 2800, sleepHours: 7.0,
        measuredAt: '08:15'
      }
    };
    return map[resident.id] ?? {
      heartRate: 0, systolic: 0, diastolic: 0, oxygen: 0,
      temperature: 0, respiratory: 0, steps: 0, sleepHours: 0,
      measuredAt: '--'
    };
  }

  /** 模拟今日用药进度（已完成/总数） */
  private residentMedicationProgress(resident: ResidentData): MedicationProgress {
    const map: Record<string, MedicationProgress> = {
      'r1': { done: 3, total: 5 },
      'r2': { done: 4, total: 4 },
      'r3': { done: 2, total: 6 },
      'r4': { done: 2, total: 3 },
      'r5': { done: 3, total: 3 }
    };
    return map[resident.id] ?? { done: 0, total: 0 };
  }

  @Builder
  private overviewGrid() {
    Grid() {
      GridItem() {
        this.overviewCard('入住人数',
          `${this.bedSummary().occupied}`, `${this.bedSummary().total}`, '床', $r('app.color.status_normal'))
      }
      GridItem() {
        this.overviewCard('总床位',
          `${this.bedSummary().total}`, `${this.bedSummary().total}`, '床', $r('sys.color.font_primary'))
      }
      GridItem() {
        this.overviewCard('空床位',
          `${this.bedSummary().empty}`, `${this.bedSummary().total}`, '床', $r('app.color.brand_blue'))
      }
      GridItem() {
        this.overviewCard('设备在线',
          `${this.onlineDeviceCount()}`, `${this.deviceRows().length}`, '台', $r('app.color.status_warning'))
      }
    }
    .width('100%')
    .columnsTemplate('1fr 1fr')
    .rowsTemplate('1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .scrollBar(BarState.Off)
    .height(176)
  }

  @Builder
  private overviewCard(label: string, numerator: string, denominator: string, unit: string, valueColor: ResourceColor) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))

      Row({ space: 4 }) {
        Text(numerator)
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(valueColor)

        Text('/')
          .fontSize($r('sys.float.Title_L'))
          .fontColor($r('sys.color.font_secondary'))
          .margin({ bottom: 2 })

        Text(denominator)
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))

        Text(unit)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .margin({ bottom: 4 })
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  // ---------------- home: AI reminders ----------------

  private aiReminders(): AiReminder[] {
    return [];
  }

  @Builder
  private aiReminderCard() {
    Column({ space: 0 }) {
      Row({ space: 6 }) {
        AiTitleLabel({ compact: true })
        Blank()
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            Text('开始对话')
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_blue'))
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([$r('app.color.brand_blue')])
          }
        }
          .height(36)
          .padding({ left: 13, right: 11 })
          .borderRadius(18)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .shadow({ radius: 7, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 2 })
          .focusable(true)
          .accessibilityText('开始与康小伴 AI 对话')
          .onClick(() => {
            this.openAiChat();
          })
      }
      .width('100%')
      .margin({ bottom: 14 })

      Column({ space: 0 }) {
        ForEach(this.aiReminders(), (item: AiReminder, index: number) => {
          this.aiReminderRow(item, index === this.aiReminders().length - 1)
        }, (item: AiReminder, index: number) => `ai-${index}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .geometryTransition('aiReminderCard', { follow: true })
    .bindSheet(this.isAiReminderSheetOpen, this.aiReminderSheetBuilder, this.aiReminderSheetOptions())
  }

  @Builder
  private aiReminderRow(item: AiReminder, isLast: boolean) {
    Column({ space: 5 }) {
      Text(item.title)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`${item.location} ${item.name} · ${item.detail}`)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('calc(100% + 16vp)')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .alignItems(HorizontalAlign.Start)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .borderRadius(12)
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText('康小伴 AI 提醒，' + item.title + '，' + item.location + ' ' + item.name + '，' + item.detail)
    .onClick(() => this.openAiReminderSheet(item.id))
  }

  private aiReminderSheetOptions(): SheetOptions {
    if (this.isWideLayout()) {
      return {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        preferType: SheetType.CENTER,
        width: 520,
        showClose: true,
        dragBar: true,
        title: { title: '康小伴 AI' },
        backgroundColor: $r('sys.color.comp_background_primary'),
        onDisappear: () => {
          this.isAiReminderSheetOpen = false;
        }
      };
    }
    return {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: true,
      dragBar: true,
      title: { title: '康小伴 AI' },
      backgroundColor: $r('sys.color.comp_background_primary'),
      onDisappear: () => {
        this.isAiReminderSheetOpen = false;
      }
    };
  }

  @Builder
  private aiReminderSheetBuilder() {
    if (this.selectedAiReminder() !== undefined) {
      Column({ space: 0 }) {
        Scroll() {
          Column({ space: 18 }) {
            Row({ space: 14 }) {
              Row() {
                SymbolGlyph($r('sys.symbol.AI_message'))
                  .fontSize(24)
                  .fontColor([$r('app.color.brand_blue')])
              }
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor($r('app.color.ai_feed_background'))
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)

              Column({ space: 5 }) {
                Text(this.selectedAiReminder()!.title)
                  .fontSize($r('sys.float.Title_S'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Text(this.selectedAiReminder()!.location + ' ' + this.selectedAiReminder()!.name)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Column({ space: 8 }) {
              Row() {
                Text('康小伴提示')
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Text(this.selectedAiReminder()!.level === 'danger' ? '优先关注' : '持续观察')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.statusColor(this.selectedAiReminder()!.level))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor(this.statusBg(this.selectedAiReminder()!.level))
              }
              .width('100%')

              Text(this.selectedAiReminder()!.detail)
                .width('100%')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              Text('提醒依据')
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text(this.selectedAiReminder()!.signal)
                .width('100%')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              Text('建议处理')
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text(this.selectedAiReminder()!.suggestion)
                .width('100%')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .alignItems(HorizontalAlign.Start)

            Text('康小伴仅整理本地演示数据，不替代护理规范、医嘱或现场人工判断。')
              .width('100%')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 10, bottom: 20 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        Button('继续询问康小伴')
          .width('100%')
          .height(48)
          .margin({ left: 20, right: 20, bottom: 16 })
          .borderRadius(24)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
          .backgroundColor($r('app.color.brand_blue'))
          .onClick(() => {
            this.closeAiReminderSheet();
            this.openAiChat();
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
    }
  }

  // ---------------- home: quick actions ----------------

  private quickActionLabels(): string[] {
    return ['待办任务', '用药', '记录', '家属', '上报'];
  }

  @Builder
  private quickActionSection() {
    Column({ space: 16 }) {
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.quickActionLabels(), (label: string, index: number) => {
            Row() {
              Text(label)
                .fontSize($r('sys.float.Body_L'))
                .fontWeight(this.selectedQuickActionIndex === index ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.selectedQuickActionIndex === index ? $r('app.color.text_on_brand') :
                  $r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .padding({ left: 22, right: 22, top: 12, bottom: 12 })
            .borderRadius(64)
            .backgroundColor(this.selectedQuickActionIndex === index ? $r('app.color.brand_blue') :
              $r('sys.color.comp_background_primary'))
            .height(48)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.selectedQuickActionIndex = index;
            })
          }, (label: string, index: number) => `quick-action-${index}`)
        }
      }
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')

      this.quickActionContent()
    }
    .width('100%')
  }

  @Builder
  private quickActionContent() {
    Column({ space: 0 }) {
      if (this.selectedQuickActionIndex === 0) {
        this.quickListPage('待办任务', this.taskListRows(), () => {
          this.openTaskExpand();
        })
      } else if (this.selectedQuickActionIndex === 1) {
        this.quickListPage('用药提醒', this.medicationItems(), () => {
          this.openTaskExpand();
        })
      } else if (this.selectedQuickActionIndex === 2) {
        this.quickListPage('服务记录', this.recordItems())
      } else if (this.selectedQuickActionIndex === 3) {
        this.quickListPage('家属联系', this.familyItems())
      } else if (this.selectedQuickActionIndex === 4) {
        this.quickListPage('上报事项', this.reportItems())
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .geometryTransition(this.quickExpandGeometryId(), { follow: true })
    .transition(TransitionEffect.OPACITY)
    .bindContentCover(this.isTaskExpandShow, this.taskExpandCover,
      {
        modalTransition: ModalTransition.NONE,
        backgroundColor: 'rgba(0,0,0,0)',
        onWillDismiss: (action: DismissContentCoverAction) => {
          if (action.reason === DismissReason.PRESS_BACK) {
            this.closeTaskExpand();
          }
        }
      })
  }

  @Builder
  private quickListPage(title: string, rows: QuickListRow[], onViewAll?: () => void) {
    Column({ space: 0 }) {
      Row({ space: 6 }) {
        Text(title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontColor([$r('sys.color.font_tertiary')])
          .onClick(onViewAll ?? (() => {}))
      }
      .width('100%')
      .margin({ bottom: 14 })

      Column({ space: 0 }) {
        ForEach(rows, (item: QuickListRow, index: number) => {
          this.quickListRow(item, index === rows.length - 1)
        }, (item: QuickListRow, index: number) => `${title}-${index}`)
      }
      .width('100%')
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private quickListRow(item: QuickListRow, isLast: boolean) {
    Row({ space: 10 }) {
      Column({ space: 5 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.sub)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.time) {
        Text(item.time)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }

      if (item.tag) {
        Text(item.tag)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(item.tagColor ?? $r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(item.tagBg ?? $r('sys.color.comp_background_secondary'))
          .borderRadius(8)
      }
    }
    .width('calc(100% + 16vp)')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .borderRadius(12)
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.selectedQuickRowId = item.id;
      this.isQuickRowSheetOpen = true;
    })
    .bindSheet(this.isQuickRowSheetOpen && this.selectedQuickRowId === item.id, this.quickRowSheetBuilder,
      this.quickRowSheetOptions(item))
  }

  private quickRowSheetOptions(item: QuickListRow): SheetOptions {
    if (this.allTasks().some((task: CareTask) => task.id === item.id)) {
      return {
        detents: [SheetSize.LARGE, SheetSize.MEDIUM],
        showClose: true,
        dragBar: true,
        title: { title: item.title },
        backgroundColor: $r('sys.color.background_secondary'),
        onDisappear: () => {
          this.isQuickRowSheetOpen = false;
        }
      };
    }
    return {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      title: { title: item.title },
      backgroundColor: $r('sys.color.background_secondary'),
      onDisappear: () => {
        this.isQuickRowSheetOpen = false;
      }
    };
  }

  private selectedQuickRow(): QuickListRow | undefined {
    const all: QuickListRow[] = [
      ...this.taskListRows(),
      ...this.medicationItems(),
      ...this.recordItems(),
      ...this.familyItems(),
      ...this.reportItems()
    ];
    return all.find((item: QuickListRow) => item.id === this.selectedQuickRowId);
  }

  private selectedTaskByQuickRow(): CareTask | undefined {
    return this.allTasks().find((t: CareTask) => t.id === this.selectedQuickRowId);
  }

  @Builder
  private quickRowSheetBuilder() {
    if (this.selectedQuickRow()) {
      if (this.selectedTaskByQuickRow()) {
        Column({ space: 0 }) {
          List({ space: 16 }) {
            ListItem() {
              this.taskDetailHeader(this.selectedTaskByQuickRow()!, false)
            }
            ListItem() {
              this.taskDetailForm(this.selectedTaskByQuickRow()!)
            }
            ListItem() {
              this.taskDetailTimeline()
            }
            ListItem() {
              this.taskActionButtons(this.selectedTaskByQuickRow()!)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8, bottom: 36 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.background_secondary'))
      } else {
        Column({ space: 0 }) {
          Text(this.selectedQuickRow()!.sub)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 14 })

          if (this.selectedQuickRow()!.time) {
            Row() {
              Text('时间')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
              Blank()
              Text(this.selectedQuickRow()!.time!)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
          }

          if (this.selectedQuickRow()!.tag) {
            Row() {
              Text('状态')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
              Blank()
              Text(this.selectedQuickRow()!.tag!)
                .fontSize($r('sys.float.Body_S'))
                .fontColor(this.selectedQuickRow()!.tagColor ?? $r('sys.color.font_secondary'))
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(this.selectedQuickRow()!.tagBg ?? $r('sys.color.comp_background_secondary'))
                .borderRadius(8)
            }
            .width('100%')
            .height(48)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 12 })
        .backgroundColor($r('sys.color.background_secondary'))
      }
    }
  }

  // ---------------- task helper ----------------

  private taskTag(status: TaskStatus, priority: StatusLevel): string {
    if (priority === 'danger' && status !== 'done') {
      return '紧急';
    }
    if (priority === 'warning' && status !== 'done') {
      return '重要';
    }
    if (status === 'done') {
      return '已完成';
    }
    return '';
  }

  private taskListRows(): QuickListRow[] {
    return this.allTasks().map((item: CareTask): QuickListRow => {
      const tag: string = this.taskTag(item.status, item.priority);
      const isDone: boolean = item.status === 'done';
      return {
        id: item.id,
        title: item.title,
        sub: `${item.elder} · ${item.room}`,
        time: item.time,
        tag: tag === '' ? undefined : tag,
        tagColor: isDone ? $r('sys.color.font_tertiary') :
          (item.priority === 'danger' ? $r('app.color.status_danger') : $r('app.color.status_warning')),
        tagBg: isDone ? $r('sys.color.comp_background_tertiary') :
          (item.priority === 'danger' ? $r('app.color.status_danger_bg') : $r('app.color.status_warning_bg'))
      };
    });
  }

  private taskStatusLevel(status: TaskStatus): StatusLevel {
    if (status === 'todo') {
      return 'danger';
    }
    if (status === 'doing') {
      return 'warning';
    }
    return 'normal';
  }

  private taskGroups(): TaskGroup[] {
    const tasks: CareTask[] = this.allTasks();
    const order: TaskStatus[] = ['doing', 'todo', 'done'];
    const groups: TaskGroup[] = order.map((status: TaskStatus): TaskGroup => {
      return {
        status,
        label: this.statusText(status),
        level: this.taskStatusLevel(status),
        tasks: tasks.filter((t: CareTask) => t.status === status)
      };
    });
    return groups.filter((g: TaskGroup) => g.tasks.length > 0);
  }

  private taskCountByStatus(status: TaskStatus): number {
    return this.allTasks().filter((t: CareTask) => t.status === status).length;
  }

  private medicationTimeGroups(): MedicationTimeGroup[] {
    const items: QuickListRow[] = this.medicationItems();
    const periods: MedicationTimeGroup[] = [
      { period: '早晨', timeRange: '06:00 - 10:00', items: [] as QuickListRow[] },
      { period: '中午', timeRange: '10:00 - 14:00', items: [] as QuickListRow[] },
      { period: '晚上', timeRange: '14:00 - 22:00', items: [] as QuickListRow[] }
    ];
    items.forEach((item: QuickListRow) => {
      const hourStr: string = item.time ? item.time.split(':')[0] : '0';
      const hour: number = parseInt(hourStr, 10);
      let idx: number = 2;
      if (hour < 10) {
        idx = 0;
      } else if (hour < 14) {
        idx = 1;
      }
      periods[idx].items.push(item);
    });
    return periods.filter((g: MedicationTimeGroup) => g.items.length > 0);
  }

  private medicationCountByTag(tag: string): number {
    return this.medicationItems().filter((m: QuickListRow) => m.tag === tag).length;
  }

  // ---------------- resident builders ----------------

  private residentGeometryId(id: string): string {
    return `resident_geo_${id}`;
  }

  @Builder
  private residentListRow(item: ResidentData, isLast: boolean) {
    ListItem() {
      Column() {
        ResidentSummaryCard({
          resident: item,
          vitalSign: this.residentVitalSign(item),
          medicationProgress: this.residentMedicationProgress(item),
          mode: 'compact'
        })
      }
      .width('100%')
      .height(this.residentCardHeight())
      .geometryTransition(this.residentGeometryId(item.id), { follow: true })
      .transition(TransitionEffect.OPACITY)
      .stateStyles({
        pressed: this.residentCardPressedStyle,
        normal: this.residentCardNormalStyle
      })
      .focusable(true)
      .focusOnTouch(true)
      .onClick(() => {
        this.openResidentDetail(item);
      })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private residentSearchWithDropdown() {
    Row({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
        TextInput({ placeholder: '搜索姓名或房间号', text: $$this.residentSearch })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .height(40)
          .backgroundColor('rgba(0,0,0,0)')
          .layoutWeight(1)
      }
      .layoutWeight(1)
      .height(44)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(10)

      Select([
        { value: '全部' },
        { value: '预警' },
        { value: '危险' }
      ])
        .selected(this.residentFilter === 'all' ? 0 : (this.residentFilter === 'warning' ? 1 : 2))
        .value(this.residentFilter === 'all' ? '全部' : (this.residentFilter === 'warning' ? '预警' : '危险'))
        .onSelect((index: number) => {
          if (index === 0) {
            this.residentFilter = 'all';
          } else if (index === 1) {
            this.residentFilter = 'warning';
          } else {
            this.residentFilter = 'danger';
          }
        })
        .height(44)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(10)
        .padding({ left: 12, right: 8 })
    }
    .width('100%')
  }

  @Builder
  private filterBar(options: string[], values: string[], selected: string, onChange: (value: string) => void) {
    Row({ space: 8 }) {
      ForEach(options, (label: string, index: number) => {
        Text(label)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(selected === values[index] ? $r('app.color.text_on_brand') : $r('sys.color.font_secondary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(selected === values[index] ? $r('app.color.brand_blue') : $r('sys.color.comp_background_primary'))
          .borderRadius(6)
          .onClick(() => {
            onChange(values[index]);
          })
      }, (item: string, index: number) => index.toString())
    }
    .width('100%')
  }

  @Builder
  private taskChipBar() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(['全部', '系统', '计划', '长者'], (label: string, index: number) => {
          Row({ space: 6 }) {
            Text(label)
              .fontSize($r('sys.float.Body_S'))
              .fontWeight(this.taskFilterIndex() === index ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.taskFilterIndex() === index ?
                $r('app.color.text_on_brand') : $r('sys.color.font_secondary'))
          }
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.taskFilterIndex() === index ?
            $r('app.color.brand_blue') : $r('sys.color.comp_background_primary'))
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.taskFilter = this.taskFilterValue(index);
          })
        }, (item: string, index: number) => `task-chip-${index}`)
      }
      .padding({ left: 0, right: 0 })
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width('100%')
    .align(Alignment.Start)
  }

  private taskFilterIndex(): number {
    if (this.taskFilter === 'all') {
      return 0;
    }
    if (this.taskFilter === 'ai') {
      return 1;
    }
    if (this.taskFilter === 'plan') {
      return 2;
    }
    return 3;
  }

  private taskFilterValue(index: number): 'all' | 'ai' | 'plan' | 'elder' {
    if (index === 0) {
      return 'all';
    }
    if (index === 1) {
      return 'ai';
    }
    if (index === 2) {
      return 'plan';
    }
    return 'elder';
  }

  @Builder
  private descriptionRow(label: string, value: string, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: {
            text: label
          }
        },
        suffixItem: new SuffixText({
          text: value
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 44,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  // ---------------- task builders ----------------

  @Builder
  private taskListRow(item: CareTask) {
    ListItem() {
      HdsListItemCard({
        textItem: {
          primaryText: {
            text: item.title
          },
          secondaryText: {
            text: `${item.elder} · ${item.room} · ${item.time}`
          }
        },
        suffixItem: new SuffixText({
          text: this.statusText(item.status)
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 52,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
    }
    .padding({ left: 16, right: 16 })
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.selectedTaskId = item.id;
      this.isTaskSheetOpen = true;
    })
    .bindSheet(this.isTaskSheetOpen && this.selectedTaskId === item.id, this.taskSheetBuilder, {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      showClose: true,
      dragBar: true,
      title: { title: '任务详情' },
      backgroundColor: $r('sys.color.background_secondary'),
      onDisappear: () => {
        this.isTaskSheetOpen = false;
      }
    })
  }

  private priorityText(priority: StatusLevel): string {
    if (priority === 'danger') {
      return '高';
    }
    if (priority === 'warning') {
      return '中';
    }
    return '低';
  }

  @Builder
  private taskSheetBuilder() {
    Column({ space: 0 }) {
      if (this.selectedTask()) {
        List({ space: 16 }) {
          ListItem() {
            this.taskDetailHeader(this.selectedTask()!)
          }

          ListItem() {
            this.taskDetailForm(this.selectedTask()!)
          }

          ListItem() {
            this.taskDetailTimeline()
          }

          ListItem() {
            this.taskActionButtons(this.selectedTask()!)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8, bottom: 36 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private taskDetailView(task: CareTask) {
    Scroll() {
      Column({ space: 16 }) {
        this.taskDetailHeader(task)
        this.taskDetailForm(task)
        this.taskDetailTimeline()
        this.taskActionButtons(task)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private taskDetailHeader(task: CareTask, showTitle: boolean = true) {
    Row() {
      Column({ space: 4 }) {
        if (showTitle) {
          Text(task.title)
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        Text(`${task.elder} · ${task.room} · ${task.time}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.statusTag(this.statusText(task.status), task.status === 'done' ? 'normal' :
        (task.status === 'doing' ? 'warning' : 'danger'))
    }
    .width('100%')
  }

  @Builder
  private taskDetailForm(task: CareTask) {
    Column({ space: 0 }) {
      Text('任务信息')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      this.descriptionRow('来源', this.sourceText(task.source), false)
      this.descriptionRow('优先级', task.priority === 'danger' ? '高' : (task.priority === 'warning' ? '中' : '低'), false)
      this.descriptionRow('执行人', task.assignee, false)
      this.descriptionRow('创建时间', task.time, true)
      Text(task.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .padding({ top: 12, bottom: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private taskDetailTimeline() {
    Column({ space: 0 }) {
      Text('处理记录')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      Column({ space: 0 }) {
        Repeat(this.taskTimeline())
          .each((repeatItem: RepeatItem<TaskTimelineItem>) => {
            this.taskTimelineRow(repeatItem.item, repeatItem.index === this.taskTimeline().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private taskTimelineRow(item: TaskTimelineItem, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: {
            text: item.actor
          },
          secondaryText: {
            text: item.action
          }
        },
        suffixItem: new SuffixText({
          text: item.time
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 56,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  @Builder
  private taskActionButtons(task: CareTask) {
    Row({ space: 12 }) {
      if (task.status !== 'done') {
        this.actionButton('接单/执行', true, () => {
        })
      }
      this.actionButton('转交', false, () => {
      })
      this.actionButton('完成', task.status === 'done', () => {
      })
    }
    .width('100%')
  }

  @Builder
  private actionButton(label: string, primary: boolean, onClick: () => void) {
    Button(label)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(primary ? $r('app.color.text_on_brand') : $r('sys.color.font_primary'))
      .backgroundColor(primary ? $r('app.color.brand_blue') : $r('sys.color.comp_background_primary'))
      .layoutWeight(1)
      .height(44)
      .onClick(onClick)
  }

  // ---------------- pages ----------------

  @Builder
  private homePage() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({
        scroller: this.currentScroller(),
        space: 16
      }) {
        ListItem() {
          Column() {
            this.aiReminderCard()
          }
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            top: this.contentTopPadding()
          })
        }

        ListItem() {
          Column() {
            this.quickActionSection()
          }
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding()
          })
        }

        ListItem() {
          Column() {
            Blank()
          }
          .height(this.bottomPadding())
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackgroundColor())
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private elderPage() {
    if (this.isWideLayout()) {
      Row({ space: 0 }) {
        Column({ space: 0 }) {
          Column({ space: 12 }) {
            this.residentSearchWithDropdown()
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('sys.color.background_secondary'))

          List({ scroller: this.currentScroller(), space: 12 }) {
            Repeat(this.filteredResidents())
              .each((repeatItem: RepeatItem<ResidentData>) => {
                this.residentListRow(
                  repeatItem.item,
                  repeatItem.index === this.filteredResidents().length - 1
                )
              })
              .key((item: ResidentData) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ bottom: 8 })
          .backgroundColor($r('sys.color.background_secondary'))
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width(this.isExtraWideLayout() ? 380 : 320)
        .height('100%')
        .backgroundColor($r('sys.color.background_secondary'))
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.contentTopPadding() })
      .backgroundColor(this.pageBackgroundColor())
    } else {
      List({
        scroller: this.currentScroller(),
        space: 12
      }) {
        ListItem() {
          this.residentSearchWithDropdown()
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.contentTopPadding()
        })

        Repeat(this.filteredResidents())
          .each((repeatItem: RepeatItem<ResidentData>) => {
            this.residentListRow(
              repeatItem.item,
              repeatItem.index === this.filteredResidents().length - 1
            )
          })
          .key((item: ResidentData) => item.id)

        ListItem() {
          Column() {
            Blank()
          }
          .height(this.bottomPadding())
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackgroundColor())
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  private inboxMessages(): InboxMessage[] {
    if (this.businessStore.loaded) {
      const currentUserId: number = AuthStore.getUser()?.id ?? 0;
      return this.businessStore.messageContacts.map((contact: MessageContact): InboxMessage => {
        const related: UserMessage[] = this.businessStore.messages
          .filter((message: UserMessage) =>
            (message.sender_id === currentUserId && message.receiver_id === contact.id) ||
            (message.sender_id === contact.id && message.receiver_id === currentUserId));
        const latest: UserMessage | undefined = related.length > 0 ? related[related.length - 1] : undefined;
        const kind: MessageKind = contact.roles.some((role) => role.code === 'family') ? 'family' : 'handoff';
        return { id: `user-${contact.id}`, kind: kind,
          sender: contact.real_name || contact.username, preview: latest?.content ?? '暂无消息',
          content: latest?.content ?? '暂无消息', time: latest ? latest.sent_at.slice(11, 16) : '--',
          unread: related.some((message: UserMessage) => message.receiver_id === currentUserId && !message.read_at) };
      });
    }
    return [];
  }

  private messageFilterOptions(): MessageFilterOption[] {
    return [
      { label: '全部', value: 'all' },
      { label: '未读', value: 'unread' },
      { label: '交接', value: 'handoff' },
      { label: '家属', value: 'family' },
      { label: '通知', value: 'notice' }
    ];
  }

  private isMessageUnread(item: InboxMessage): boolean {
    return item.unread && !this.readMessageIds.includes(item.id);
  }

  private filteredInboxMessages(): InboxMessage[] {
    const messages: InboxMessage[] = this.inboxMessages();
    if (this.messageFilter === 'all') {
      return messages;
    }
    if (this.messageFilter === 'unread') {
      return messages.filter((item: InboxMessage) => this.isMessageUnread(item));
    }
    return messages.filter((item: InboxMessage) => item.kind === this.messageFilter);
  }

  private selectedMessage(): InboxMessage | undefined {
    return this.inboxMessages().find((item: InboxMessage) => item.id === this.selectedMessageId);
  }

  private latestPhoneMessage(item: InboxMessage): PhoneLocalMessageRecord | undefined {
    const records: PhoneLocalMessageRecord[] = this.phoneLocalMessageRecords.filter((record: PhoneLocalMessageRecord) =>
      record.conversationId === item.id);
    return records.length > 0 ? records[records.length - 1] : undefined;
  }

  private messagePreview(item: InboxMessage): string {
    return this.latestPhoneMessage(item)?.content ?? item.preview;
  }

  private messageTime(item: InboxMessage): string {
    return this.latestPhoneMessage(item)?.time ?? item.time;
  }

  private messageKindLabel(kind: MessageKind): string {
    if (kind === 'handoff') {
      return '交接消息';
    }
    if (kind === 'family') {
      return '家属沟通';
    }
    return '通知';
  }

  private messageIcon(kind: MessageKind): Resource {
    if (kind === 'handoff') {
      return $r('sys.symbol.person_2_fill');
    }
    if (kind === 'family') {
      return $r('sys.symbol.phone_fill');
    }
    return $r('sys.symbol.bell_fill');
  }

  private messageIconColor(kind: MessageKind): ResourceColor {
    if (kind === 'family') {
      return $r('app.color.status_normal');
    }
    if (kind === 'notice') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.brand_blue');
  }

  private messageIconBackground(kind: MessageKind): ResourceColor {
    if (kind === 'family') {
      return 0xFFE9F7EF;
    }
    if (kind === 'notice') {
      return 0xFFFFF4DC;
    }
    return 0xFFEAF1FF;
  }

  private openMessage(item: InboxMessage): void {
    this.selectedMessageId = item.id;
    if (this.isMessageUnread(item)) {
      this.readMessageIds = [...this.readMessageIds, item.id];
    }
    if (!this.isWideLayout()) {
      this.isPhoneMessageChatOpen = true;
    }
  }

  @Builder
  private messageChipBar() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.messageFilterOptions(), (option: MessageFilterOption) => {
          Row() {
            Text(option.label)
              .fontSize($r('sys.float.Body_S'))
              .fontWeight(this.messageFilter === option.value ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.messageFilter === option.value ? $r('app.color.text_on_brand') :
                $r('sys.color.font_secondary'))
          }
          .height(36)
          .padding({ left: 16, right: 16 })
          .justifyContent(FlexAlign.Center)
          .borderRadius(18)
          .backgroundColor(this.messageFilter === option.value ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_primary'))
          .onClick(() => {
            this.messageFilter = option.value;
          })
        }, (option: MessageFilterOption) => option.value)
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private messageRow(item: InboxMessage, isLast: boolean) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Row() {
          if (item.kind === 'family') {
            Text(item.sender.substring(0, 1))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.messageIconColor(item.kind))
          } else {
            SymbolGlyph($r('sys.symbol.bell_fill'))
              .fontSize(20)
              .fontColor([this.messageIconColor(item.kind)])
          }
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.messageIconBackground(item.kind))

        if (this.isMessageUnread(item)) {
          Row()
            .width(9)
            .height(9)
            .borderRadius(5)
            .backgroundColor($r('app.color.brand_blue'))
            .border({ width: 2, color: $r('sys.color.comp_background_primary') })
        }
      }
      .width(44)
      .height(44)

      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(item.sender)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(this.isMessageUnread(item) ? FontWeight.Medium : FontWeight.Regular)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.messageTime(item))
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')

        Text(this.messagePreview(item))
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.isMessageUnread(item) ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(74)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText(item.sender + '，' + this.messagePreview(item))
    .onClick(() => {
      this.openMessage(item);
    })
  }

  @Builder
  private messageEmptyState() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.message_on_message_fill'))
        .fontSize(42)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text('暂无消息')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      Text('新的沟通和通知会显示在这里')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ top: 56, bottom: 56 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private messageListCard() {
    Column({ space: 0 }) {
      if (this.filteredInboxMessages().length === 0) {
        this.messageEmptyState()
      } else {
        ForEach(this.filteredInboxMessages(), (item: InboxMessage, index: number) => {
          this.messageRow(item, index === this.filteredInboxMessages().length - 1)
        }, (item: InboxMessage) => item.id)
      }
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private messageDetailPane() {
    if (this.selectedMessage()) {
      Scroll() {
        Column({ space: 20 }) {
          Row({ space: 14 }) {
            Row() {
              SymbolGlyph(this.messageIcon(this.selectedMessage()!.kind))
                .fontSize(24)
                .fontColor([this.messageIconColor(this.selectedMessage()!.kind)])
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.messageIconBackground(this.selectedMessage()!.kind))

            Column({ space: 4 }) {
              Text(this.selectedMessage()!.sender)
                .fontSize($r('sys.float.Title_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              Text(`${this.messageKindLabel(this.selectedMessage()!.kind)} · ${this.selectedMessage()!.time}`)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Text(this.selectedMessage()!.content)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(28)
            .width('100%')
            .padding(20)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .padding(24)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    } else {
      Column({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.message_on_message_fill'))
          .fontSize(52)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('选择一条消息查看内容')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text('这里用于查看完整的沟通和通知内容')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private messagePage() {
    if (this.isWideLayout()) {
      Row({ space: 0 }) {
        List({ scroller: this.currentScroller(), space: 12 }) {
          ListItem() {
            this.messageChipBar()
          }
          ListItem() {
            this.messageListCard()
          }
        }
        .width(this.isExtraWideLayout() ? 440 : 380)
        .height('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 24 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor($r('sys.color.background_secondary'))

        Column() {
          this.messageDetailPane()
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(this.pageBackgroundColor())
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.contentTopPadding() })
      .backgroundColor(this.pageBackgroundColor())
    } else {
      List({ scroller: this.currentScroller(), space: 12 }) {
        ListItem() {
          this.messageChipBar()
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.contentTopPadding()
        })

        ListItem() {
          this.messageListCard()
        }
        .padding({ left: this.pagePadding(), right: this.pagePadding() })

        ListItem() {
          Row()
            .width('100%')
            .height(this.bottomPadding())
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackgroundColor())
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  private phoneMessageChatCover() {
    if (this.selectedMessage()) {
      Column() {
        PhoneMessageChatPage({
          conversationId: this.selectedMessage()!.id,
          title: this.selectedMessage()!.sender,
          subtitle: this.messageKindLabel(this.selectedMessage()!.kind),
          kind: this.selectedMessage()!.kind,
          initialContent: this.selectedMessage()!.content,
          replyable: this.selectedMessage()!.kind !== 'notice',
          localRecords: this.phoneLocalMessageRecords,
          onClose: () => {
            this.isPhoneMessageChatOpen = false;
          },
          onSend: (record: PhoneLocalMessageRecord) => {
            this.phoneLocalMessageRecords = [...this.phoneLocalMessageRecords, record];
          }
        })
      }
      .width('100%')
      .height('100%')
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.move(TransitionEdge.END)
          .animation({ duration: 250, curve: Curve.LinearOutSlowIn }),
        TransitionEffect.move(TransitionEdge.END)
          .animation({ duration: 200, curve: Curve.FastOutLinearIn })
      ))
    }
  }

  @Builder
  private taskPage() {
    if (this.isWideLayout()) {
      Row({ space: 0 }) {
        Column({ space: 0 }) {
          Column({ space: 12 }) {
            this.taskChipBar()
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('sys.color.background_secondary'))

          List({ scroller: this.currentScroller(), space: 0 }) {
            Repeat(this.filteredTasks())
              .each((repeatItem: RepeatItem<CareTask>) => {
                this.taskListRow(repeatItem.item)
              })
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .clip(true)
          .divider({
            strokeWidth: 0.5,
            color: $r('sys.color.comp_divider'),
            startMargin: 16,
            endMargin: 16
          })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width(this.isExtraWideLayout() ? 420 : 360)
        .height('100%')
        .backgroundColor($r('sys.color.background_secondary'))

        if (this.selectedTask()) {
          this.taskDetailView(this.selectedTask()!)
        } else {
          Column() {
            Text('选择左侧任务查看详情')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('sys.color.background_secondary'))
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.contentTopPadding() })
      .backgroundColor(this.pageBackgroundColor())
    } else {
      List({
        scroller: this.currentScroller(),
        space: 12
      }) {
        ListItem() {
          this.taskChipBar()
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.contentTopPadding()
        })

        ListItem() {
          List({ space: 0 }) {
            Repeat(this.filteredTasks())
              .each((repeatItem: RepeatItem<CareTask>) => {
                this.taskListRow(repeatItem.item)
              })
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .clip(true)
          .divider({
            strokeWidth: 0.5,
            color: $r('sys.color.comp_divider'),
            startMargin: 16,
            endMargin: 16
          })
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          bottom: this.bottomPadding()
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackgroundColor())
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  // ---------------- mine builders (preserved) ----------------

  private quickActions(): QuickActionData[] {
    return [
      { icon: $r('sys.symbol.paintpalette'), label: '培训学习' },
      { icon: $r('sys.symbol.calendar_badge_clock'), label: '排班表' },
      { icon: $r('sys.symbol.doc_text'), label: '服务记录' },
      { icon: $r('sys.symbol.questionmark_circle'), label: '帮助中心' }
    ];
  }

  private settingGroups(): SettingGroupData[] {
    return [
      {
        title: '',
        items: [
          { icon: $r('sys.symbol.lock'), label: '账号安全', value: 'L3 权限', showArrow: true },
          { icon: $r('sys.symbol.bell'), label: '通知提醒', value: '关键提醒', showArrow: true },
          { icon: $r('sys.symbol.share'), label: '登录设备', value: '2 台', showArrow: true },
          {
            icon: $r('sys.symbol.info_circle'),
            label: '关于我们',
            showArrow: true,
            action: () => {
              this.pathStack.pushPath({ name: 'AboutPage' });
            }
          },
          {
            icon: $r('sys.symbol.gearshape'),
            label: '通用设置',
            showArrow: true,
            action: () => {
              this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
            }
          }
        ]
      },
      {
        title: '',
        items: [
          {
            icon: $r('sys.symbol.xmark'),
            label: '退出登录',
            showArrow: false,
            isDanger: true,
            action: () => {
              this.handleLogout();
            }
          }
        ]
      }
    ];
  }

  private async handleLogout(): Promise<void> {
    try {
      AuthStore.clear();
      BusinessStore.getShared().clear();
      await WindowUtil.setImmersiveMode(false);
      await this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
    } catch (err) {
      await WindowUtil.setImmersiveMode(true);
      Logger.error('[TabPageView]', `logout failed: ${JSON.stringify(err)}`);
    }
  }

  @Builder
  private mineHero() {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(64)
            .height(64)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .borderRadius(32)
          Text('LT')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }

        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text('刘婷')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Row({ space: 2 }) {
              SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
                .fontSize(11)
                .fontColor([$r('sys.color.font_tertiary')])
              Text('L3')
                .fontSize(11)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .borderRadius(8)
          }
          .alignItems(VerticalAlign.Center)

          Text('阳光护士（2024）')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({
      width: 0.5,
      color: $r('sys.color.comp_divider')
    })
    .onClick(() => {
      this.isProfileSheetOpen = true;
    })
    .bindSheet(this.isProfileSheetOpen, this.profileSheetBuilder, {
      height: SheetSize.MEDIUM,
      backgroundColor: $r('sys.color.background_secondary'),
      title: { title: '个人信息' },
      showClose: true,
      dragBar: true,
      onDisappear: () => {
        this.isProfileSheetOpen = false;
      }
    })
  }

  @Builder
  private profileSheetBuilder() {
    Column({ space: 16 }) {
      this.profileSheetGroup([
        { label: '形象', value: '', isAvatar: true }
      ])

      this.profileSheetGroup([
        { label: '昵称', value: '刘婷' },
        { label: '性别', value: '女' },
        { label: '出生日期', value: '1995-08-12' }
      ])

      this.profileSheetGroup([
        { label: '手机号', value: '138****8021' },
        { label: '实名认证', value: '**婷', tag: '已实名' }
      ])
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private profileSheetGroup(items: ProfileSheetItem[]) {
    Column({ space: 0 }) {
      ForEach(items, (item: ProfileSheetItem, index: number) => {
        this.profileSheetRow(item, index !== items.length - 1)
      }, (item: ProfileSheetItem, index: number) => index.toString())
    }
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .width('100%')
  }

  @Builder
  private profileSheetRow(item: ProfileSheetItem, showDivider: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(item.label)
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        if (item.isAvatar) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(56)
              .height(56)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .borderRadius(28)
            Text('LT')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
          }
        } else {
          Row({ space: 8 }) {
            Text(item.value)
              .fontSize(16)
              .fontColor($r('sys.color.font_secondary'))

            if (item.tag) {
              Text(item.tag)
                .fontSize(12)
                .fontColor($r('sys.color.font_emphasize'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(6)
            }
          }
          .alignItems(VerticalAlign.Center)
        }

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width('100%')
      .height(item.isAvatar ? 76 : 56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.comp_background_primary'))

      if (showDivider) {
        Divider()
          .width('100%')
          .height(0.5)
          .color($r('sys.color.comp_divider'))
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  private mineStatsCard() {
    Row({ space: 0 }) {
      Column({ space: 4 }) {
        Text('28')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('负责长者')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('92%')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('班次完成')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('4.9')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('服务评分')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('12h')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('培训时长')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({
      width: 0.5,
      color: $r('sys.color.comp_divider')
    })
  }

  @Builder
  private quickActionItem(item: QuickActionData) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph(item.icon)
          .fontSize(26)
          .fontColor([$r('sys.color.font_primary')])
          .opacity(0.75)
        if (item.badge) {
          Text(item.badge)
            .fontSize(10)
            .fontColor($r('app.color.text_on_brand'))
            .fontWeight(FontWeight.Medium)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .backgroundColor($r('app.color.status_danger'))
            .borderRadius(8)
            .offset({ x: 8, y: -4 })
        }
      }

      Text(item.label)
        .fontSize(13)
        .fontColor($r('sys.color.font_primary'))

      if (item.subLabel) {
        Text(item.subLabel)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  private settingItem(item: SettingItemData, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(item.icon)
              .fontColor([item.isDanger ? $r('app.color.status_danger') : $r('sys.color.font_primary')])
          }
        }),
        textItem: {
          primaryText: {
            text: item.label
          }
        },
        suffixItem: item.value ?
          new SuffixText({ text: item.value }) :
          (item.showArrow ? new SuffixArrow({ color: $r('sys.color.font_tertiary') }) : undefined),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 52,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      if (!isLast) {
        Divider()
          .width('100%')
          .height(0.5)
          .color($r('sys.color.comp_divider'))
          .margin({ left: 36, right: 0 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      if (item.action) {
        item.action();
      }
    })
  }

  @Builder
  private settingGroup(group: SettingGroupData) {
    Column({ space: 0 }) {
      if (group.title !== '') {
        Text(group.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      }

      Column({ space: 0 }) {
        Repeat(group.items)
          .each((repeatItem: RepeatItem<SettingItemData>) => {
            this.settingItem(repeatItem.item, repeatItem.index === group.items.length - 1)
          })
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private minePage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        this.mineHero()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        top: this.contentTopPadding()
      })

      ListItem() {
        this.mineStatsCard()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        Column({ space: 0 }) {
          Text('常用功能')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)
            .padding({ left: 16, right: 16, top: 14, bottom: 10 })

          Row({ space: 0 }) {
            this.quickActionItem(this.quickActions()[0])
            this.quickActionItem(this.quickActions()[1])
            this.quickActionItem(this.quickActions()[2])
            this.quickActionItem(this.quickActions()[3])
          }
          .width('100%')
        }
        .padding({ bottom: 6 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .border({
          width: 0.5,
          color: $r('sys.color.comp_divider')
        })
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        this.settingGroup(this.settingGroups()[0])
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        this.settingGroup(this.settingGroups()[1])
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        bottom: this.bottomPadding()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private healthExpandCover() {
    HealthExpandPage({
      onClose: () => {
        this.closeHealthExpand();
      }
    })
  }

  @Builder
  private expandOverviewCard() {
    Row() {
      if (this.selectedQuickActionIndex === 0) {
        this.overviewSegment(this.taskCountByStatus('todo'), '待办', 'danger')
        this.overviewDivider()
        this.overviewSegment(this.taskCountByStatus('doing'), '进行中', 'warning')
        this.overviewDivider()
        this.overviewSegment(this.taskCountByStatus('done'), '已完成', 'normal')
      } else {
        this.overviewSegment(this.medicationCountByTag('待服用'), '待服用', 'warning')
        this.overviewDivider()
        this.overviewSegment(this.medicationCountByTag('已完成'), '已完成', 'normal')
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private overviewSegment(count: number, label: string, level: StatusLevel) {
    Column({ space: 4 }) {
      Text(count.toString())
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.statusColor(level))
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private overviewDivider() {
    Divider()
      .vertical(true)
      .height(32)
      .width(0.5)
      .color($r('sys.color.comp_divider'))
  }

  @Builder
  private expandGroupTitle(title: string, subtitle?: string) {
    Row({ space: 6 }) {
      Text(title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      if (subtitle) {
        Text(`· ${subtitle}`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .padding({ left: 4, bottom: 8 })
  }

  @Builder
  private expandTaskRow(task: CareTask, isLast: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(task.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${task.elder} · ${task.room} · ${task.time}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.statusText(task.status))
        .fontSize($r('sys.float.Caption_M'))
        .fontColor(this.statusColor(this.taskStatusLevel(task.status)))
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.statusBg(this.taskStatusLevel(task.status)))
        .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.selectedQuickRowId = task.id;
      this.isExpandSheetOpen = true;
    })
    .bindSheet(this.isExpandSheetOpen && this.selectedQuickRowId === task.id, this.quickRowSheetBuilder, {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      showClose: true,
      dragBar: true,
      title: { title: task.title },
      backgroundColor: $r('sys.color.background_secondary'),
      onDisappear: () => {
        this.isExpandSheetOpen = false;
      }
    })
  }

  @Builder
  private expandMedicationRow(item: QuickListRow, isLast: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.sub)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.time) {
        Text(item.time)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      if (item.tag) {
        Text(item.tag)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(item.tag === '已完成' ? this.statusColor('normal') : this.statusColor('warning'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(item.tag === '已完成' ? this.statusBg('normal') : this.statusBg('warning'))
          .borderRadius(10)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
    .stateStyles({
      pressed: this.itemPressedStyle,
      normal: this.itemNormalStyle
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.selectedQuickRowId = item.id;
      this.isExpandSheetOpen = true;
    })
    .bindSheet(this.isExpandSheetOpen && this.selectedQuickRowId === item.id, this.quickRowSheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      title: { title: item.title },
      backgroundColor: $r('sys.color.background_secondary'),
      onDisappear: () => {
        this.isExpandSheetOpen = false;
      }
    })
  }

  private taskExpandTitleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  @Builder
  private taskExpandTitleBuilder() {
    Row() {
      Text(this.quickExpandTitle())
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .ellipsisMode(EllipsisMode.END)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 64 })
    .alignItems(VerticalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private taskExpandTitleBarContent(): TitleBarContentOptions {
    return {
      stackBuilder: (): void => this.taskExpandTitleBuilder(),
      menu: {
        value: [{
          content: {
            icon: $r('sys.symbol.xmark'),
            isEnabled: true,
            action: () => {
              this.closeTaskExpand();
            }
          }
        }]
      }
    };
  }

  @Builder
  private taskExpandCover() {
    Column() {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll() {
          Row() {
            Column({ space: 16 }) {
              if (this.selectedQuickActionIndex === 1) {
                this.expandOverviewCard()
              }

              if (this.selectedQuickActionIndex === 0) {
                ForEach(this.taskGroups(), (group: TaskGroup) => {
                  Column({ space: 0 }) {
                    this.expandGroupTitle(group.label, `${group.tasks.length}条`)
                    Column({ space: 0 }) {
                      ForEach(group.tasks, (task: CareTask, index: number) => {
                        this.expandTaskRow(task, index === group.tasks.length - 1)
                      }, (task: CareTask) => task.id)
                    }
                    .width('100%')
                    .backgroundColor($r('sys.color.comp_background_primary'))
                    .borderRadius(16)
                    .clip(true)
                    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
                  }
                  .width('100%')
                }, (group: TaskGroup) => group.status)
              } else if (this.selectedQuickActionIndex === 1) {
                ForEach(this.medicationTimeGroups(), (group: MedicationTimeGroup) => {
                  Column({ space: 0 }) {
                    this.expandGroupTitle(group.period, group.timeRange)
                    Column({ space: 0 }) {
                      ForEach(group.items, (item: QuickListRow, index: number) => {
                        this.expandMedicationRow(item, index === group.items.length - 1)
                      }, (item: QuickListRow) => `med-${item.id}`)
                    }
                    .width('100%')
                    .backgroundColor($r('sys.color.comp_background_primary'))
                    .borderRadius(16)
                    .clip(true)
                    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
                  }
                  .width('100%')
                }, (group: MedicationTimeGroup) => group.period)
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: this.expandMaxWidth() })
            .padding({
              left: this.pagePadding(),
              right: this.pagePadding(),
              top: 104,
              bottom: 16
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.Top)
          .width('100%')
          .height('100%')
          .expandSafeArea(
            [SafeAreaType.SYSTEM],
            [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
          )
        }
        .width('100%')
        .height('100%')
        .expandSafeArea(
          [SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
        )
      }
      .backgroundColor($r('sys.color.background_secondary'))
      .expandSafeArea(
        [SafeAreaType.SYSTEM],
        [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
      )
      .hideBackButton(true)
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false,
        style: this.taskExpandTitleBarStyle(),
        content: this.taskExpandTitleBarContent()
      })
      .ignoreLayoutSafeArea(
        [LayoutSafeAreaType.SYSTEM],
        [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea(
      [SafeAreaType.SYSTEM],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]
    )
    .geometryTransition(this.quickExpandGeometryId(), { follow: true })
    .transition(TransitionEffect.OPACITY)
  }

  build() {
    Stack() {
      Column() {
        Column() {
          if (this.currentTabIndex === 0) {
            this.homePage();
          } else if (this.currentTabIndex === 1) {
            this.elderPage();
          } else if (this.currentTabIndex === 2) {
            this.messagePage();
          } else {
            this.minePage();
          }
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .bindContentCover(this.isHealthExpandShow, this.healthExpandCover,
        {
          modalTransition: ModalTransition.NONE,
          backgroundColor: 'rgba(0,0,0,0)',
          onWillDismiss: (action: DismissContentCoverAction) => {
            if (action.reason === DismissReason.PRESS_BACK) {
              this.closeHealthExpand();
            }
          }
        })
      .bindContentCover(this.isPhoneMessageChatOpen, this.phoneMessageChatCover,
        {
          modalTransition: ModalTransition.NONE,
          backgroundColor: 'rgba(0,0,0,0)',
          onWillDismiss: (action: DismissContentCoverAction) => {
            if (action.reason === DismissReason.PRESS_BACK) {
              this.isPhoneMessageChatOpen = false;
            }
          }
        })

    }
    .width('100%')
    .height('100%')
  }
}
