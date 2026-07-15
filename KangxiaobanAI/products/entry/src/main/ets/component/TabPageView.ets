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

import { AppStorageV2, SymbolGlyphModifier, curves, router } from '@kit.ArkUI';
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import Logger from '../util/Logger';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig } from '../model/TabPageModel';
import { BreakpointType } from '../util/BreakpointSystem';
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
import { ResidentDetailPage } from '../pages/ResidentDetailPage';

type TaskSource = 'ai' | 'elder' | 'staff' | 'plan';
type TaskStatus = 'todo' | 'doing' | 'done';
type EventType = 'ai' | 'alert' | 'care' | 'family';

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
  level: StatusLevel;
  location: string;
  name: string;
  title: string;
  detail: string;
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
  @Event onSwitchTab: (index: number) => void = () => {};
  @Event onOpenAiChat: () => void = () => {};
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
  @Local selectedQuickActionIndex: number = 0;
  @Local currentTime: Date = new Date();
  @Local isClockedIn: boolean = false;
  @Local clockInTime: Date | null = null;
  @Local isClockedOut: boolean = false;
  @Local clockOutTime: Date | null = null;
  private timerId: number = -1;
  @Local isHealthExpandShow: boolean = false;
  @Local isResidentDetailShow: boolean = false;
  @Local isTaskExpandShow: boolean = false;
  @Local selectedResidentId: string = '';
  @Local selectedResident: ResidentData = {
    id: '',
    name: '',
    age: 0,
    gender: 'male',
    room: '',
    bed: '',
    level: 'normal',
    status: '',
    emergencyContact: '',
    emergencyPhone: '',
    admissionDate: '',
    careLevel: '',
    diagnosis: [],
    allergies: [],
    deviceIds: [],
    avatarText: ''
  } as ResidentData;
  @Local activeResidentGeometryId: string = '';

  private openAiChat(): void {
    this.onOpenAiChat();
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
    this.selectedResident = item;
    this.selectedResidentId = item.id;
    this.activeResidentGeometryId = this.residentGeometryId(item.id);
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 328, 36)
    }, () => {
      this.isResidentDetailShow = true;
    })
  }

  private closeResidentDetail(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isResidentDetailShow = false;
    })
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
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
      widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private isExtraWideLayout(): boolean {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_LG || widthBreakpoint === WidthBreakpoint.WIDTH_XL;
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
  }

  @Styles
  itemPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
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
    return [
      {
        id: 'r1', name: '肖爷爷', age: 82, room: '3F-302', bed: 'A床',
        level: 'danger', status: '情绪低落 · 拒交流', mood: '低落', moodLevel: 'danger',
        lastUpdate: '10:24'
      },
      {
        id: 'r2', name: '周奶奶', age: 78, room: '2F-215', bed: 'B床',
        level: 'warning', status: '夜间离床增加', mood: '焦虑', moodLevel: 'warning',
        lastUpdate: '09:46'
      },
      {
        id: 'r3', name: '林爷爷', age: 85, room: '3F-306', bed: 'C床',
        level: 'warning', status: '社交回避', mood: '回避', moodLevel: 'warning',
        lastUpdate: '09:12'
      },
      {
        id: 'r4', name: '王爷爷', age: 80, room: '2F-201', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '平静', moodLevel: 'normal',
        lastUpdate: '08:30'
      },
      {
        id: 'r5', name: '赵奶奶', age: 76, room: '2F-208', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '愉快', moodLevel: 'normal',
        lastUpdate: '08:15'
      }
    ];
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
    return [
      {
        id: 'd1', name: '智能床垫', room: '3F-302', type: '睡眠体征',
        status: '数据异常', level: 'warning', lastUpdate: '10:24'
      },
      {
        id: 'd2', name: '毫米波雷达', room: '3F-306', type: '离床跌倒',
        status: '离线', level: 'danger', lastUpdate: '14:20'
      },
      {
        id: 'd3', name: '紧急呼叫器', room: '2F-215', type: '主动求助',
        status: '在线', level: 'normal', lastUpdate: '09:46'
      },
      {
        id: 'd4', name: '智能床垫', room: '2F-215', type: '睡眠体征',
        status: '在线', level: 'normal', lastUpdate: '09:40'
      }
    ];
  }

  private eventRows(): EventRowData[] {
    return [
      { time: '10:24', type: 'ai', title: 'AI 情绪预警', detail: '3F-302 肖爷爷活动量下降 41%，建议人工接手' },
      { time: '09:46', type: 'alert', title: '呼叫器触发', detail: '2F-215 周奶奶反馈夜间不适，已生成评估任务' },
      { time: '09:30', type: 'care', title: '早巡完成', detail: '2F 东区 36 位长者体征正常' },
      { time: '09:12', type: 'family', title: '家属回访', detail: '3F-306 林爷爷家属电话未接通' },
      { time: '08:45', type: 'ai', title: 'AI 睡眠摘要', detail: '3F-306 林爷爷深睡时长低于均值 23%' },
      { time: '08:00', type: 'care', title: '用药提醒', detail: '3F 西区早间用药已完成' }
    ];
  }

  private medicationItems(): QuickListRow[] {
    return [
      { id: 'med-1', title: '降压药', sub: '李秀英 · 1片', time: '08:00', tag: '待服用', tagColor: $r('app.color.brand_blue'),
        tagBg: $r('app.color.status_normal_bg') },
      { id: 'med-2', title: '钙片', sub: '王德林 · 2片', time: '08:00', tag: '待服用', tagColor: $r('app.color.brand_blue'),
        tagBg: $r('app.color.status_normal_bg') },
      { id: 'med-3', title: '二甲双胍', sub: '张明华 · 0.5g', time: '12:00', tag: '待服用', tagColor: $r('app.color.brand_blue'),
        tagBg: $r('app.color.status_normal_bg') },
      { id: 'med-4', title: '维生素D', sub: '肖爷爷 · 1粒', time: '07:00', tag: '已完成', tagColor: $r('sys.color.font_tertiary'),
        tagBg: $r('sys.color.comp_background_tertiary') }
    ];
  }

  private recordItems(): QuickListRow[] {
    return [
      { id: 'rec-1', title: '体征测量', sub: '3F-302 肖爷爷', time: '10:24', tag: '已记录',
        tagColor: $r('app.color.status_normal'), tagBg: $r('app.color.status_normal_bg') },
      { id: 'rec-2', title: '翻身护理', sub: '2F-215 周奶奶', time: '09:46', tag: '已记录',
        tagColor: $r('app.color.status_normal'), tagBg: $r('app.color.status_normal_bg') },
      { id: 'rec-3', title: '用药执行', sub: '3F-306 林爷爷', time: '09:12', tag: '已记录',
        tagColor: $r('app.color.status_normal'), tagBg: $r('app.color.status_normal_bg') },
      { id: 'rec-4', title: '夜间巡查', sub: '2F 东区', time: '06:30', tag: '已记录',
        tagColor: $r('app.color.status_normal'), tagBg: $r('app.color.status_normal_bg') }
    ];
  }

  private familyItems(): QuickListRow[] {
    return [
      { id: 'fam-1', title: '张建国', sub: '李秀英儿子 · 13800138000' },
      { id: 'fam-2', title: '李秀兰', sub: '王德林女儿 · 13900139000' },
      { id: 'fam-3', title: '林涛', sub: '林爷爷儿子 · 13700137000' },
      { id: 'fam-4', title: '周敏', sub: '周奶奶女儿 · 13600136000' }
    ];
  }

  private reportItems(): QuickListRow[] {
    return [
      { id: 'rep-1', title: '智能床垫离线', sub: '3F-306', time: '14:20', tag: '待处理',
        tagColor: $r('app.color.status_danger'), tagBg: $r('app.color.status_danger_bg') },
      { id: 'rep-2', title: '血压异常偏高', sub: '3F-302 肖爷爷', time: '10:24', tag: '已跟进',
        tagColor: $r('app.color.status_normal'), tagBg: $r('app.color.status_normal_bg') },
      { id: 'rep-3', title: '离床频次增加', sub: '2F-215 周奶奶', time: '09:46', tag: '已跟进',
        tagColor: $r('app.color.status_normal'), tagBg: $r('app.color.status_normal_bg') },
      { id: 'rep-4', title: '卫生间滞留超时', sub: '3F-308', time: '08:15', tag: '待处理',
        tagColor: $r('app.color.status_danger'), tagBg: $r('app.color.status_danger_bg') }
    ];
  }

  // ---------------- residents data ----------------

  private allResidents(): ResidentData[] {
    return [
      {
        id: 'r1', name: '肖爷爷', age: 82, gender: 'male', room: '3F-302', bed: 'A床',
        level: 'danger', status: '情绪低落 · 拒交流',
        emergencyContact: '肖先生（子）', emergencyPhone: '138****1201',
        admissionDate: '2022-03-15', careLevel: '一级护理',
        diagnosis: ['高血压', '2型糖尿病', '轻度抑郁'],
        allergies: ['青霉素'],
        deviceIds: ['d1', 'd5', 'd6'], avatarText: '肖'
      },
      {
        id: 'r2', name: '周奶奶', age: 78, gender: 'female', room: '2F-215', bed: 'B床',
        level: 'warning', status: '夜间离床增加',
        emergencyContact: '周女士（女）', emergencyPhone: '139****2202',
        admissionDate: '2021-08-20', careLevel: '二级护理',
        diagnosis: ['冠心病', '骨质疏松'],
        allergies: ['海鲜'],
        deviceIds: ['d3', 'd4'], avatarText: '周'
      },
      {
        id: 'r3', name: '林爷爷', age: 85, gender: 'male', room: '3F-306', bed: 'C床',
        level: 'warning', status: '社交回避',
        emergencyContact: '林先生（子）', emergencyPhone: '137****3303',
        admissionDate: '2020-11-02', careLevel: '一级护理',
        diagnosis: ['脑梗后遗症', '高血压'],
        allergies: [],
        deviceIds: ['d2', 'd6'], avatarText: '林'
      },
      {
        id: 'r4', name: '王爷爷', age: 80, gender: 'male', room: '2F-201', bed: 'A床',
        level: 'normal', status: '稳定观察',
        emergencyContact: '王女士（女）', emergencyPhone: '136****4404',
        admissionDate: '2023-01-10', careLevel: '三级护理',
        diagnosis: ['高血压'],
        allergies: [],
        deviceIds: ['d7'], avatarText: '王'
      },
      {
        id: 'r5', name: '赵奶奶', age: 76, gender: 'female', room: '2F-208', bed: 'A床',
        level: 'normal', status: '稳定观察',
        emergencyContact: '赵先生（子）', emergencyPhone: '135****5505',
        admissionDate: '2022-09-28', careLevel: '三级护理',
        diagnosis: ['2型糖尿病'],
        allergies: ['坚果'],
        deviceIds: ['d8'], avatarText: '赵'
      }
    ];
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
    return [
      {
        id: 't1', source: 'ai', priority: 'danger', status: 'todo',
        title: '情绪安抚与人工接手', elder: '肖爷爷', room: '3F-302',
        time: '现在', assignee: '刘婷',
        detail: 'AI 识别到肖爷爷语调低沉、活动量下降 41%，已由语音关怀过渡，需要熟悉护工人工接手，避免重复询问。'
      },
      {
        id: 't2', source: 'elder', priority: 'warning', status: 'todo',
        title: '夜间不适评估', elder: '周奶奶', room: '2F-215',
        time: '09:46', assignee: '王倩',
        detail: '周奶奶通过床头呼叫器反馈昨晚没睡好，希望安排午休和疼痛评估。'
      },
      {
        id: 't3', source: 'staff', priority: 'normal', status: 'doing',
        title: '组织书法角活动', elder: '林爷爷', room: '3F-306',
        time: '15:40', assignee: '赵晨',
        detail: '确认活动人数，安排护工陪同，重点鼓励低社交长者参与。'
      },
      {
        id: 't4', source: 'ai', priority: 'warning', status: 'doing',
        title: '毫米波雷达离线巡检', elder: '林爷爷', room: '3F-306',
        time: '14:20', assignee: '维修组',
        detail: '3F-306 毫米波雷达 14:20 离线，已派巡检，需确认设备电源与网络。'
      },
      {
        id: 't5', source: 'elder', priority: 'normal', status: 'done',
        title: '活动报名确认', elder: '林爷爷', room: '3F-306',
        time: '09:12', assignee: '赵晨',
        detail: '林爷爷主动要求参加书法角活动，已确认并安排陪同。'
      },
      {
        id: 't6', source: 'plan', priority: 'normal', status: 'todo',
        title: '半护理上午巡房', elder: '李奶奶', room: '2F-208',
        time: '10:00', assignee: '刘婷',
        detail: '半护理套餐包含每日上午巡房、血压测量与用药提醒。'
      },
      {
        id: 't7', source: 'plan', priority: 'normal', status: 'doing',
        title: '全护理翻身护理', elder: '王爷爷', room: '3F-309',
        time: '09:00', assignee: '刘婷',
        detail: '全护理套餐包含每两小时翻身一次，预防压疮。'
      }
    ];
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
    return [
      { time: '10:24', actor: 'AI 关怀系统', action: '识别异常并发起语音关怀' },
      { time: '10:25', actor: '护理站', action: '自动派单给责任护工刘婷' },
      { time: '10:30', actor: '刘婷', action: '接单，准备进入房间' }
    ];
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
    return 148;
  }

  private residentPriorityText(level: StatusLevel): string {
    if (level === 'danger') {
      return '危险';
    }
    if (level === 'warning') {
      return '关注';
    }
    return '稳定';
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

  // ---------------- home: clock in ----------------

  @Builder
  private taskOverviewGrid() {
    Column({ space: 0 }) {
      Row({ space: 0 }) {
        Column({ space: 5 }) {
          Text(this.currentTimeString())
            .fontSize(44)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .height(52)
          Text(this.clockInStatusText())
            .fontSize($r('sys.float.Body_M'))
            .fontColor(this.workStatusColor())
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 8 }) {
          if (!this.isClockedIn) {
            Button('上班打卡')
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('app.color.text_on_brand'))
              .backgroundColor($r('app.color.brand_blue'))
              .height(52)
              .padding({ left: 26, right: 26 })
              .borderRadius(26)
              .onClick(() => {
                this.handleClockIn();
              })
          } else if (this.isClockedIn && !this.isClockedOut) {
            Button('下班打卡')
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('app.color.text_on_brand'))
              .backgroundColor($r('app.color.status_danger'))
              .height(52)
              .padding({ left: 26, right: 26 })
              .borderRadius(26)
              .onClick(() => {
                this.handleClockOut();
              })
          } else {
            Button('已下班')
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('sys.color.font_tertiary'))
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .height(52)
              .padding({ left: 26, right: 26 })
              .borderRadius(26)
              .enabled(false)
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  private currentTimeString(): string {
    const h: string = this.currentTime.getHours().toString().padStart(2, '0');
    const m: string = this.currentTime.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  private clockInStatusText(): string {
    if (!this.isClockedIn) {
      return '今日未打卡';
    }
    if (this.isClockedOut && this.clockInTime && this.clockOutTime) {
      const diffMs: number = this.clockOutTime.getTime() - this.clockInTime.getTime();
      const diffMin: number = Math.floor(diffMs / 60000);
      const h: number = Math.floor(diffMin / 60);
      const m: number = diffMin % 60;
      return `今日工作 ${h}小时${m}分`;
    }
    if (this.clockInTime) {
      const diffMs: number = this.currentTime.getTime() - this.clockInTime.getTime();
      const diffMin: number = Math.floor(diffMs / 60000);
      const h: number = Math.floor(diffMin / 60);
      const m: number = diffMin % 60;
      return `已上班 ${h}小时${m}分`;
    }
    return '';
  }

  private workStatusColor(): ResourceColor {
    if (!this.isClockedIn) {
      return $r('sys.color.font_secondary');
    }
    if (this.isClockedOut) {
      return $r('sys.color.font_tertiary');
    }
    return $r('app.color.status_normal');
  }

  private handleClockIn(): void {
    this.isClockedIn = true;
    this.clockInTime = new Date();
  }

  private handleClockOut(): void {
    this.isClockedOut = true;
    this.clockOutTime = new Date();
  }

  // ---------------- home: AI reminders ----------------

  private aiReminders(): AiReminder[] {
    return [
      {
        level: 'danger',
        location: '302-1',
        name: '张明华',
        title: '血压连续3天偏高',
        detail: '建议今日重点观察'
      },
      {
        level: 'normal',
        location: '305-2',
        name: '李秀英',
        title: '康复训练完成率87%',
        detail: '继续保持'
      }
    ];
  }

  @Builder
  private aiReminderCard() {
    Column({ space: 0 }) {
      Row({ space: 6 }) {
        Text('康小伴智能守护')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(`· ${this.aiReminders().length}条`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
          .padding(8)
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
    .width('100%')
    .padding({ top: 14, bottom: isLast ? 0 : 14 })
    .alignItems(HorizontalAlign.Start)
    .border({
      width: { bottom: isLast ? 0 : 0.5 },
      color: { bottom: $r('sys.color.comp_divider') }
    })
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
  }

  @Builder
  private quickListPage(title: string, rows: QuickListRow[], onViewAll?: () => void) {
    Column({ space: 0 }) {
      Row({ space: 6 }) {
        Text(title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(`· ${rows.length}条`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_tertiary'))
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
    .width('100%')
    .padding({ top: 14, bottom: isLast ? 0 : 14 })
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
      this.isQuickRowSheetOpen = true;
    })
    .bindSheet(this.isQuickRowSheetOpen && this.selectedQuickRowId === item.id, this.quickRowSheetBuilder, {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      showClose: true,
      dragBar: true,
      title: { title: item.title },
      backgroundColor: $r('sys.color.background_secondary'),
      onDisappear: () => {
        this.isQuickRowSheetOpen = false;
      }
    })
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
    Column({ space: 0 }) {
      if (this.selectedQuickRow()) {
        if (this.selectedTaskByQuickRow()) {
          List({ space: 16 }) {
            ListItem() {
              this.taskDetailHeader(this.selectedTaskByQuickRow()!)
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
        } else {
          List({ space: 0 }) {
            ListItem() {
              Column({ space: 8 }) {
                Text(this.selectedQuickRow()!.title)
                  .fontSize($r('sys.float.Title_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(this.selectedQuickRow()!.sub)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .width('100%')
              .padding({ top: 16, bottom: 16 })
            }

            if (this.selectedQuickRow()!.time) {
              ListItem() {
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
                .padding({ top: 14, bottom: 14 })
                .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
              }
            }

            if (this.selectedQuickRow()!.tag) {
              ListItem() {
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
                .padding({ top: 14, bottom: 14 })
                .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
              }
            }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 20, right: 20 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
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
      if (this.isResidentDetailShow && this.selectedResidentId === item.id) {
        Column()
          .width('100%')
          .height(this.residentCardHeight())
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .border({
            width: 0.5,
            color: $r('sys.color.comp_divider')
          })
      } else {
        Column({ space: 12 }) {
          // 行1：姓名 + 年龄·性别 + 房间床号 + 状态色块 + 更新时间
          Row() {
            Text(item.name)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(`${item.age}岁·${item.gender === 'male' ? '男' : '女'}`)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
              .margin({ left: 8 })

            Text(`${item.room} ${item.bed}`)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
              .margin({ left: 8 })
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.residentPriorityText(item.level))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor(this.statusColor(item.level))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.statusBg(item.level))
              .borderRadius(6)
              .margin({ right: 6 })

            Text(this.residentVitalSign(item).measuredAt)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 行2：状态描述 + 诊断标签
          Row({ space: 8 }) {
            Text(item.status)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (item.diagnosis.length > 0) {
              Text(item.diagnosis.slice(0, 2).join('·'))
                .fontSize($r('sys.float.Caption_M'))
                .fontColor($r('sys.color.font_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 行3：核心体征（心率/血压/步数/用药），4列居中布局
          Column({ space: 8 }) {
            Row() {
              this.vitalMiniItem('心率', `${this.residentVitalSign(item).heartRate}`, 'bpm', this.heartRateMiniLevel(item), false)
              this.vitalMiniItem('血压', `${this.residentVitalSign(item).systolic}/${this.residentVitalSign(item).diastolic}`, '', this.bpMiniLevel(item), false)
              this.vitalMiniItem('步数', `${this.residentVitalSign(item).steps}`, '步', 'normal', false)
              this.vitalMiniItem('用药', `${this.residentMedicationProgress(item).done}/${this.residentMedicationProgress(item).total}`, '次', 'normal', true)
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height(this.residentCardHeight())
        .padding({ left: 14, right: 14, top: 14, bottom: 14 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .border({
          width: 0.5,
          color: $r('sys.color.comp_divider')
        })
        .geometryTransition(this.residentGeometryId(item.id), { follow: true })
        .transition(TransitionEffect.OPACITY)
        .stateStyles({
          pressed: this.itemPressedStyle,
          normal: this.itemNormalStyle
        })
        .focusable(true)
        .focusOnTouch(true)
        .onClick(() => {
          this.openResidentDetail(item);
        })
      }
    }
    .padding({ left: 16, right: 16 })
  }

  private heartRateMiniLevel(item: ResidentData): StatusLevel {
    const hr: number = this.residentVitalSign(item).heartRate;
    if (hr > 100 || hr < 60) {
      return 'warning';
    }
    return 'normal';
  }

  private bpMiniLevel(item: ResidentData): StatusLevel {
    const s: number = this.residentVitalSign(item).systolic;
    if (s >= 140) {
      return 'danger';
    }
    if (s >= 130) {
      return 'warning';
    }
    return 'normal';
  }

  @Builder
  private vitalMiniItem(label: string, value: string, unit: string, level: StatusLevel, isLast: boolean) {
    Row() {
      Column({ space: 3 }) {
        Row({ space: 2 }) {
          Text(value)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor(level === 'normal' ? $r('sys.color.font_primary') : this.statusColor(level))
          if (unit !== '') {
            Text(unit)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
        .alignItems(VerticalAlign.Bottom)

        Text(label)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(VerticalAlign.Center)
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
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private taskDetailHeader(task: CareTask) {
    Row() {
      Column({ space: 4 }) {
        Text(task.title)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
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
            this.taskOverviewGrid()
          }
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            top: this.contentTopPadding()
          })
        }

        ListItem() {
          Column() {
            this.aiReminderCard()
          }
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding()
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
      { icon: $r('sys.symbol.square_and_pencil'), label: '入住登记' },
      { icon: $r('sys.symbol.person_2'), label: '我的长者' },
      { icon: $r('sys.symbol.bell'), label: '消息通知' },
      { icon: $r('sys.symbol.paintpalette'), label: '培训学习' },
      { icon: $r('sys.symbol.hand_thumbsup'), label: '我的评价' },
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
          { icon: $r('sys.symbol.questionmark_circle'), label: '关于我们', showArrow: true },
          { icon: $r('sys.symbol.gearshape'), label: '通用设置', showArrow: true }
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
    // 预留：清空登录态、token、缓存
    try {
      await router.replaceUrl({ url: 'pages/LoginPage' });
    } catch (err) {
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

          Row({ space: 0 }) {
            this.quickActionItem(this.quickActions()[4])
            this.quickActionItem(this.quickActions()[5])
            this.quickActionItem(this.quickActions()[6])
            this.quickActionItem(this.quickActions()[7])
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
  private residentDetailCover() {
    ResidentDetailPage({
      resident: this.selectedResident,
      geometryId: this.activeResidentGeometryId,
      onClose: () => {
        this.closeResidentDetail();
      }
    })
  }

  @Builder
  private expandLargeTitle() {
    Column({ space: 4 }) {
      Text(this.quickExpandTitle())
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(this.expandSubtitle())
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private expandSubtitle(): string {
    if (this.selectedQuickActionIndex === 0) {
      return '今日护理任务概览';
    }
    return '今日用药计划概览';
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
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      if (subtitle) {
        Text(`· ${subtitle}`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
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
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(item.tag === '已完成' ? this.statusColor('normal') : this.statusColor('warning'))

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
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      showClose: true,
      dragBar: true,
      title: { title: item.title },
      backgroundColor: $r('sys.color.background_secondary'),
      onDisappear: () => {
        this.isExpandSheetOpen = false;
      }
    })
  }

  @Builder
  private taskExpandCover() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll() {
          Row() {
            Column({ space: 16 }) {
              if (this.selectedQuickActionIndex === 1) {
                this.expandLargeTitle()
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
              top: this.topPadding() + 56,
              bottom: this.bottomPadding()
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.pageBackgroundColor())
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        Row() {
          Text(this.quickExpandTitle())
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)

          Row() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([$r('sys.color.font_primary')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .justifyContent(FlexAlign.Center)
          .stateStyles({
            normal: this.itemNormalStyle,
            pressed: this.itemPressedStyle
          })
          .onClick(() => {
            this.closeTaskExpand();
          })
        }
        .width('100%')
        .padding({ left: this.pagePadding(), right: this.pagePadding() })
        .margin({ top: this.topPadding() })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .geometryTransition(this.quickExpandGeometryId())
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
            this.taskPage();
          } else {
            this.minePage();
          }
        }
        .width('100%')
        .height('100%')
        .bindContentCover(this.isResidentDetailShow, this.residentDetailCover,
          {
            modalTransition: ModalTransition.NONE,
            backgroundColor: 'rgba(0,0,0,0)',
            onWillDismiss: (action: DismissContentCoverAction) => {
              if (action.reason === DismissReason.PRESS_BACK) {
                this.closeResidentDetail();
              }
            }
          })
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
    .width('100%')
    .height('100%')
  }
}
