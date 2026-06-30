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

import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig } from '../model/TabPageModel';
import { BreakpointType } from '../util/BreakpointSystem';

type StatusLevel = 'normal' | 'warning' | 'danger';
type TaskSource = 'ai' | 'elder' | 'staff';
type TaskStatus = 'todo' | 'doing' | 'done';
type EventType = 'ai' | 'alert' | 'care' | 'family';

interface BedSummary {
  total: number;
  occupied: number;
  empty: number;
  maintenance: number;
}

interface HealthRowData {
  id: string;
  name: string;
  age: number;
  room: string;
  bed: string;
  level: StatusLevel;
  status: string;
  mood: string;
  moodLevel: StatusLevel;
  lastUpdate: string;
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

interface ResidentData {
  id: string;
  name: string;
  age: number;
  room: string;
  bed: string;
  level: StatusLevel;
  status: string;
  emergencyContact: string;
  emergencyPhone: string;
  admissionDate: string;
  deviceIds: string[];
}

interface HealthRecord {
  time: string;
  type: string;
  operator: string;
  content: string;
}

interface MoodRecord {
  time: string;
  mood: string;
  level: StatusLevel;
  note: string;
}

interface RoomDeviceData {
  id: string;
  name: string;
  type: string;
  room: string;
  status: string;
  level: StatusLevel;
  battery?: number;
  lastUpdate: string;
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

interface SettingItemData {
  icon: Resource;
  label: string;
  value?: string;
  showArrow: boolean;
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
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local isProfileSheetOpen: boolean = false;
  @Local selectedResidentId: string = '';
  @Local selectedTaskId: string = '';
  @Local residentSearch: string = '';
  @Local residentFilter: 'all' | 'warning' | 'danger' = 'all';
  @Local taskFilter: 'all' | 'ai' | 'elder' | 'staff' = 'all';

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 68;
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
      return '#D92B2B';
    }
    if (level === 'warning') {
      return '#F5A623';
    }
    return '#2FA84F';
  }

  private statusBg(level: StatusLevel): ResourceColor {
    if (level === 'danger') {
      return '#FCE8E8';
    }
    if (level === 'warning') {
      return '#FDF3E0';
    }
    return '#E5F5EA';
  }

  private sourceText(source: TaskSource): string {
    if (source === 'ai') {
      return 'AI';
    }
    if (source === 'elder') {
      return '长者';
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

  private taskStatusLevel(status: TaskStatus): StatusLevel {
    if (status === 'done') {
      return 'normal';
    }
    if (status === 'doing') {
      return 'warning';
    }
    return 'danger';
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
      return '#1D63ED';
    }
    if (type === 'alert') {
      return '#D92B2B';
    }
    if (type === 'care') {
      return '#0F766E';
    }
    return '#B7791F';
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

  // ---------------- residents data ----------------

  private allResidents(): ResidentData[] {
    return [
      {
        id: 'r1', name: '肖爷爷', age: 82, room: '3F-302', bed: 'A床',
        level: 'danger', status: '情绪低落 · 拒交流',
        emergencyContact: '肖先生（子）', emergencyPhone: '138****1201',
        admissionDate: '2022-03-15', deviceIds: ['d1', 'd5']
      },
      {
        id: 'r2', name: '周奶奶', age: 78, room: '2F-215', bed: 'B床',
        level: 'warning', status: '夜间离床增加',
        emergencyContact: '周女士（女）', emergencyPhone: '139****2202',
        admissionDate: '2021-08-20', deviceIds: ['d3', 'd4']
      },
      {
        id: 'r3', name: '林爷爷', age: 85, room: '3F-306', bed: 'C床',
        level: 'warning', status: '社交回避',
        emergencyContact: '林先生（子）', emergencyPhone: '137****3303',
        admissionDate: '2020-11-02', deviceIds: ['d2', 'd6']
      },
      {
        id: 'r4', name: '王爷爷', age: 80, room: '2F-201', bed: 'A床',
        level: 'normal', status: '稳定观察',
        emergencyContact: '王女士（女）', emergencyPhone: '136****4404',
        admissionDate: '2023-01-10', deviceIds: ['d7']
      },
      {
        id: 'r5', name: '赵奶奶', age: 76, room: '2F-208', bed: 'A床',
        level: 'normal', status: '稳定观察',
        emergencyContact: '赵先生（子）', emergencyPhone: '135****5505',
        admissionDate: '2022-09-28', deviceIds: ['d8']
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

  private selectedResident(): ResidentData | undefined {
    return this.allResidents().find((item: ResidentData) => item.id === this.selectedResidentId);
  }

  private residentHealthRecords(): HealthRecord[] {
    return [
      { time: '2025-06-30 08:30', type: '早巡', operator: '刘婷', content: '血压 138/85，心率 72，精神状态平稳' },
      { time: '2025-06-29 20:15', type: '夜间巡房', operator: '王倩', content: '起夜 2 次，入睡潜伏期 35 分钟' },
      { time: '2025-06-29 14:00', type: '用药', operator: '系统', content: '降压药已按时服用，无异常反应' },
      { time: '2025-06-28 09:10', type: '医生查房', operator: '张医生', content: '调整降糖方案，建议增加午后血糖监测' }
    ];
  }

  private residentMoodRecords(): MoodRecord[] {
    return [
      { time: '10:24', mood: '低落', level: 'danger', note: 'AI 对话语调低沉，活动量下降 41%' },
      { time: '09:30', mood: '平静', level: 'normal', note: '早巡时能够简单应答' },
      { time: '昨天 20:10', mood: '焦虑', level: 'warning', note: '睡前反复询问家属何时来访' },
      { time: '昨天 15:00', mood: '愉快', level: 'normal', note: '参加书法角，主动展示作品' }
    ];
  }

  private residentDevices(resident: ResidentData): RoomDeviceData[] {
    const devices: RoomDeviceData[] = [
      { id: 'd1', name: '智能床垫', type: '睡眠体征', room: resident.room, status: '数据异常', level: 'warning', battery: 78, lastUpdate: '10:24' },
      { id: 'd5', name: '毫米波雷达', type: '离床跌倒', room: resident.room, status: '在线', level: 'normal', battery: 92, lastUpdate: '10:20' },
      { id: 'd6', name: '紧急呼叫器', type: '主动求助', room: resident.room, status: '在线', level: 'normal', battery: 45, lastUpdate: '09:50' }
    ];
    return devices.filter((d: RoomDeviceData) => resident.deviceIds.includes(d.id));
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
  private sectionHeader(title: string, count?: number) {
    Row() {
      Text(title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Blank()
      if (count !== undefined) {
        Text(`${count}`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .height(40)
  }

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

  @Builder
  private overviewGrid() {
    Grid() {
      GridItem() {
        this.overviewCard('入住人数', `${this.bedSummary().occupied}`, '人', '#2FA84F')
      }
      GridItem() {
        this.overviewCard('总床位', `${this.bedSummary().total}`, '床', $r('sys.color.font_primary'))
      }
      GridItem() {
        this.overviewCard('空床位', `${this.bedSummary().empty}`, '床', '#1D63ED')
      }
      GridItem() {
        this.overviewCard('设备在线', `${this.onlineDeviceCount()}`, '台', '#F5A623')
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
  private overviewCard(label: string, value: string, unit: string, valueColor: ResourceColor) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 2 }) {
        Text(value)
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(valueColor)
        Text(unit)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
          .margin({ bottom: 3 })
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private healthListRow(item: HealthRowData, isLast: boolean) {
    HdsListItemCard({
      textItem: {
        primaryText: {
          text: item.name
        },
        secondaryText: {
          text: `${item.age}岁 · ${item.room} · ${item.bed}`
        },
        description: {
          text: item.mood
        }
      },
      suffixItem: new SuffixText({
        text: item.status
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 76,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      onClick: () => {
        this.selectedResidentId = item.id;
      }
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private deviceRow(item: DeviceRowData, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2'))
            .fontColor([this.statusColor(item.level)])
        }
      }),
      textItem: {
        primaryText: {
          text: item.name
        },
        secondaryText: {
          text: `${item.type} · ${item.room}`
        }
      },
      suffixItem: new SuffixText({
        text: `${item.status} · ${item.lastUpdate}`
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 52,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private eventTimelineRow(item: EventRowData, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(this.eventTypeIcon(item.type))
            .fontColor([this.eventTypeColor(item.type)])
        }
      }),
      textItem: {
        primaryText: {
          text: item.title
        },
        secondaryText: {
          text: item.detail
        }
      },
      suffixItem: new SuffixText({
        text: item.time
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 64,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  // ---------------- resident builders ----------------

  @Builder
  private residentListRow(item: ResidentData, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
            .fontColor([this.statusColor(item.level)])
        }
      }),
      textItem: {
        primaryText: {
          text: item.name
        },
        secondaryText: {
          text: `${item.age}岁 · ${item.room} · ${item.bed}`
        }
      },
      suffixItem: new SuffixText({
        text: item.status
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: this.selectedResidentId === item.id ?
        $r('sys.color.comp_background_secondary') : 'rgba(0,0,0,0)',
      cardHeight: 52,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      onClick: () => {
        this.selectedResidentId = item.id;
      }
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private residentSearchBar() {
    Row({ space: 12 }) {
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
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(8)
  }

  @Builder
  private filterBar(options: string[], values: string[], selected: string, onChange: (value: string) => void) {
    Row({ space: 8 }) {
      ForEach(options, (label: string, index: number) => {
        Text(label)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(selected === values[index] ? $r('sys.color.font_on_primary') : $r('sys.color.font_secondary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(selected === values[index] ? $r('sys.color.font_primary') : $r('sys.color.comp_background_primary'))
          .borderRadius(6)
          .onClick(() => {
            onChange(values[index]);
          })
      }, (item: string, index: number) => index.toString())
    }
    .width('100%')
  }

  @Builder
  private residentDetailView(resident: ResidentData) {
    Scroll() {
      Column({ space: 16 }) {
        this.residentDetailHeader(resident)
        this.residentBasicInfo(resident)
        this.residentHealthTimeline()
        this.residentMoodList()
        this.residentDeviceTable(this.residentDevices(resident))
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private residentDetailHeader(resident: ResidentData) {
    Row() {
      Column({ space: 4 }) {
        Text(resident.name)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(`${resident.age}岁 · ${resident.room} · ${resident.bed}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.statusTag(resident.status, resident.level)
    }
    .width('100%')
  }

  @Builder
  private residentBasicInfo(resident: ResidentData) {
    Column({ space: 0 }) {
      Text('基础信息')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      this.descriptionRow('紧急联系人', resident.emergencyContact, false)
      this.descriptionRow('联系电话', resident.emergencyPhone, false)
      this.descriptionRow('入院日期', resident.admissionDate, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private descriptionRow(label: string, value: string, isLast: boolean) {
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
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 44,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private residentHealthTimeline() {
    Column({ space: 0 }) {
      Text('健康记录')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      Column({ space: 0 }) {
        Repeat(this.residentHealthRecords())
          .each((repeatItem: RepeatItem<HealthRecord>) => {
            this.healthRecordRow(repeatItem.item, repeatItem.index === this.residentHealthRecords().length - 1)
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
  private healthRecordRow(item: HealthRecord, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.checkmark_circle_fill'))
            .fontColor([$r('sys.color.font_secondary')])
        }
      }),
      textItem: {
        primaryText: {
          text: `${item.type} · ${item.operator}`
        },
        secondaryText: {
          text: item.content
        }
      },
      suffixItem: new SuffixText({
        text: item.time.split(' ')[0].slice(5) + ' ' + item.time.split(' ')[1]
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 64,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private residentMoodList() {
    Column({ space: 0 }) {
      Text('情绪记录')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      Column({ space: 0 }) {
        Repeat(this.residentMoodRecords())
          .each((repeatItem: RepeatItem<MoodRecord>) => {
            this.moodRecordRow(repeatItem.item, repeatItem.index === this.residentMoodRecords().length - 1)
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
  private moodRecordRow(item: MoodRecord, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.heart_fill'))
            .fontColor([this.statusColor(item.level)])
        }
      }),
      textItem: {
        primaryText: {
          text: item.mood
        },
        secondaryText: {
          text: item.note
        }
      },
      suffixItem: new SuffixText({
        text: item.time
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 52,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private residentDeviceTable(devices: RoomDeviceData[]) {
    Column({ space: 0 }) {
      Text('房间与设备')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      Column({ space: 0 }) {
        Repeat(devices)
          .each((repeatItem: RepeatItem<RoomDeviceData>) => {
            this.deviceTableRowSmall(repeatItem.item, repeatItem.index === devices.length - 1)
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
  private deviceTableRowSmall(item: RoomDeviceData, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2'))
            .fontColor([this.statusColor(item.level)])
        }
      }),
      textItem: {
        primaryText: {
          text: item.name
        },
        secondaryText: {
          text: item.type
        }
      },
      suffixItem: new SuffixText({
        text: `${item.status}${item.battery !== undefined ? ' · ' + item.battery + '%' : ''}`
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 44,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  // ---------------- task builders ----------------

  @Builder
  private taskListRow(item: CareTask, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(this.taskSourceIcon(item.source))
            .fontColor([this.statusColor(this.taskStatusLevel(item.status))])
        }
      }),
      textItem: {
        primaryText: {
          text: item.title
        },
        secondaryText: {
          text: `${item.elder} · ${item.room} · ${item.time}`
        },
        description: {
          text: item.assignee
        }
      },
      suffixItem: new SuffixText({
        text: `${this.statusText(item.status)} · ${this.priorityText(item.priority)}`
      }),
      cardBorderRadius: 0,
      cardBackgroundColor: this.selectedTaskId === item.id ?
        $r('sys.color.comp_background_secondary') : 'rgba(0,0,0,0)',
      cardHeight: 76,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      onClick: () => {
        this.selectedTaskId = item.id;
      }
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
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

  private taskSourceIcon(source: TaskSource): Resource {
    if (source === 'ai') {
      return $r('sys.symbol.ellipsis_message_fill');
    }
    if (source === 'elder') {
      return $r('sys.symbol.bell');
    }
    return $r('sys.symbol.person_fill');
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
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.clock_fill'))
            .fontColor([$r('sys.color.font_secondary')])
        }
      }),
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
      cardHeight: 60,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
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
      .fontColor(primary ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .backgroundColor(primary ? $r('sys.color.font_primary') : $r('sys.color.comp_background_primary'))
      .layoutWeight(1)
      .height(44)
      .onClick(onClick)
  }

  // ---------------- pages ----------------

  @Builder
  private homePage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        Column() {
          this.overviewGrid()
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.topPadding()
        })
      }

      ListItem() {
        Column({ space: 0 }) {
          Column({ space: 0 }) {
            this.sectionHeader('老人健康状态', this.healthRows().length)
            Column({ space: 0 }) {
              Repeat(this.healthRows())
                .each((repeatItem: RepeatItem<HealthRowData>) => {
                  this.healthListRow(repeatItem.item, repeatItem.index === this.healthRows().length - 1)
                })
            }
          }
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .clip(true)
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding()
        })
      }

      ListItem() {
        Column({ space: 0 }) {
          this.sectionHeader('设备状态', this.deviceRows().length)
          Column({ space: 0 }) {
            Repeat(this.deviceRows())
              .each((repeatItem: RepeatItem<DeviceRowData>) => {
                this.deviceRow(repeatItem.item, repeatItem.index === this.deviceRows().length - 1)
              })
          }
        }
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        Column({ space: 0 }) {
          this.sectionHeader('今日事件流', this.eventRows().length)
          Column({ space: 0 }) {
            Repeat(this.eventRows())
              .each((repeatItem: RepeatItem<EventRowData>) => {
                this.eventTimelineRow(repeatItem.item, repeatItem.index === this.eventRows().length - 1)
              })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)
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

  @Builder
  private elderPage() {
    if (this.isWideLayout()) {
      Row({ space: 0 }) {
        Column({ space: 0 }) {
          Text('长者管理')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('sys.color.comp_background_primary'))

          Column({ space: 12 }) {
            this.residentSearchBar()
            this.filterBar(['全部', '预警', '危险'], ['all', 'warning', 'danger'], this.residentFilter, (value: string) => {
              this.residentFilter = value as 'all' | 'warning' | 'danger';
            })
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('sys.color.background_secondary'))

          List({ scroller: this.currentScroller() }) {
            ListItem() {
              Column({ space: 0 }) {
                Repeat(this.filteredResidents())
                  .each((repeatItem: RepeatItem<ResidentData>) => {
                    this.residentListRow(repeatItem.item, repeatItem.index === this.filteredResidents().length - 1)
                  })
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .clip(true)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width(this.isExtraWideLayout() ? 380 : 320)
        .height('100%')
        .backgroundColor($r('sys.color.background_secondary'))

        if (this.selectedResident()) {
          this.residentDetailView(this.selectedResident()!)
        } else {
          Column() {
            Text('选择左侧长者查看详情')
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
      .padding({ top: this.topPadding() })
      .backgroundColor(this.pageBackgroundColor())
    } else {
      if (this.selectedResident()) {
        Column({ space: 0 }) {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([$r('sys.color.font_primary')])
              .onClick(() => {
                this.selectedResidentId = '';
              })
            Text(this.selectedResident()!.name)
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('sys.color.comp_background_primary'))

          this.residentDetailView(this.selectedResident()!)
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.topPadding() })
        .backgroundColor(this.pageBackgroundColor())
      } else {
        List({
          scroller: this.currentScroller(),
          space: 12
        }) {
          ListItem() {
            Column({ space: 12 }) {
              Text('长者管理')
                .fontSize($r('sys.float.Title_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .width('100%')
              this.residentSearchBar()
              this.filterBar(['全部', '预警', '危险'], ['all', 'warning', 'danger'], this.residentFilter, (value: string) => {
                this.residentFilter = value as 'all' | 'warning' | 'danger';
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.comp_background_primary'))
          }
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            top: this.topPadding()
          })

          ListItem() {
            Column({ space: 0 }) {
              Repeat(this.filteredResidents())
                .each((repeatItem: RepeatItem<ResidentData>) => {
                  this.residentListRow(repeatItem.item, repeatItem.index === this.filteredResidents().length - 1)
                })
            }
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
            .clip(true)
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
  }

  @Builder
  private taskPage() {
    if (this.isWideLayout()) {
      Row({ space: 0 }) {
        Column({ space: 0 }) {
          Text('任务系统')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('sys.color.comp_background_primary'))

          Column({ space: 12 }) {
            this.filterBar(['全部', 'AI', '长者', '护工'], ['all', 'ai', 'elder', 'staff'], this.taskFilter, (value: string) => {
              this.taskFilter = value as 'all' | 'ai' | 'elder' | 'staff';
            })
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('sys.color.background_secondary'))

          List({ scroller: this.currentScroller() }) {
            ListItem() {
              Column({ space: 0 }) {
                Repeat(this.filteredTasks())
                  .each((repeatItem: RepeatItem<CareTask>) => {
                    this.taskListRow(repeatItem.item, repeatItem.index === this.filteredTasks().length - 1)
                  })
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .clip(true)
            }
          }
          .width('100%')
          .layoutWeight(1)
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
      .padding({ top: this.topPadding() })
      .backgroundColor(this.pageBackgroundColor())
    } else {
      if (this.selectedTask()) {
        Column({ space: 0 }) {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([$r('sys.color.font_primary')])
              .onClick(() => {
                this.selectedTaskId = '';
              })
            Text(this.selectedTask()!.title)
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('sys.color.comp_background_primary'))

          this.taskDetailView(this.selectedTask()!)
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.topPadding() })
        .backgroundColor(this.pageBackgroundColor())
      } else {
        List({
          scroller: this.currentScroller(),
          space: 12
        }) {
          ListItem() {
            Column({ space: 12 }) {
              Text('任务系统')
                .fontSize($r('sys.float.Title_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .width('100%')
              this.filterBar(['全部', 'AI', '长者', '护工'], ['all', 'ai', 'elder', 'staff'], this.taskFilter, (value: string) => {
                this.taskFilter = value as 'all' | 'ai' | 'elder' | 'staff';
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.comp_background_primary'))
          }
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            top: this.topPadding()
          })

          ListItem() {
            Column({ space: 0 }) {
              Repeat(this.filteredTasks())
                .each((repeatItem: RepeatItem<CareTask>) => {
                  this.taskListRow(repeatItem.item, repeatItem.index === this.filteredTasks().length - 1)
                })
            }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
            .clip(true)
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
      }
    ];
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
    .border({
      width: {
        bottom: showDivider ? 0.5 : 0
      },
      color: $r('sys.color.comp_divider')
    })
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
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .backgroundColor('#FF3B30')
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
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(item.icon)
            .fontColor([$r('sys.color.font_primary')])
        }
      }),
      textItem: {
        primaryText: {
          text: item.label
        }
      },
      suffixItem: item.value ?
        new SuffixText({ text: item.value }) :
        new SuffixArrow({ color: $r('sys.color.font_tertiary') }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 52,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      onClick: () => {
      }
    })
    .border({
      width: {
        bottom: isLast ? 0 : 0.5
      },
      color: $r('sys.color.comp_divider')
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
        top: this.topPadding()
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

  build() {
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
}
