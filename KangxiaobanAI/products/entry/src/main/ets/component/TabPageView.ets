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
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { HomeSearchState } from '../model/HomeSearchState';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig } from '../model/TabPageModel';
import { BreakpointType } from '../util/BreakpointSystem';
import { HealthListCard, HealthListCardData, HealthListCardRow } from './HealthListCard';
import { DeviceListCard, DeviceListCardData, DeviceListCardRow } from './DeviceListCard';
import { EventListCard, EventListCardData, EventListCardRow } from './EventListCard';
import {
  HealthRowData,
  ResidentData,
  StatusLevel
} from '../model/DetailTypes';
import { HealthExpandPage } from '../pages/HealthExpandPage';

type TaskSource = 'ai' | 'elder' | 'staff';
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
  @Param onOpenSearch: () => void = () => {};
  @Event onOpenResidentDetail: (resident: ResidentData, geometryId: string) => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local homeSearchState: HomeSearchState =
    AppStorageV2.connect(HomeSearchState, StorageKey.HOME_SEARCH_STATE, () => new HomeSearchState()) ??
    new HomeSearchState();
  @Local isProfileSheetOpen: boolean = false;
  @Local selectedTaskId: string = '';
  @Local isTaskSheetOpen: boolean = false;
  @Local residentSearch: string = '';
  @Local residentFilter: 'all' | 'warning' | 'danger' = 'all';
  @Local taskFilter: 'all' | 'ai' | 'elder' = 'all';
  @Local homeSearchText: string = '';
  @Local isSearchPageShow: boolean = false;
  @Local geometryId: string = '';
  @Local isHealthExpandShow: boolean = false;

  @Monitor('homeSearchState.searchTrigger')
  onSearchTriggerChange(): void {
    this.geometryId = '';
    this.getUIContext().animateTo({
      duration: 300,
      curve: Curve.EaseInOut
    }, () => {
      this.isSearchPageShow = true;
      this.homeSearchState.isSearchOpen = true;
    })
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
    return this.topPadding() + this.titleBarHeight();
  }

  private homeContentTopPadding(): number {
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

  private deviceCardData(): DeviceListCardData {
    return {
      title: '设备状态',
      rows: this.deviceRows().map((item: DeviceRowData): DeviceListCardRow => {
        return {
          id: item.id,
          name: item.name,
          room: item.room,
          type: item.type,
          status: item.status,
          level: item.level,
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
    return 108;
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

  @Builder
  private overviewGrid() {
    Grid() {
      GridItem() {
        this.overviewCard('入住人数',
          `${this.bedSummary().occupied}`, `${this.bedSummary().total}`, '床', '#2FA84F')
      }
      GridItem() {
        this.overviewCard('总床位',
          `${this.bedSummary().total}`, `${this.bedSummary().total}`, '床', $r('sys.color.font_primary'))
      }
      GridItem() {
        this.overviewCard('空床位',
          `${this.bedSummary().empty}`, `${this.bedSummary().total}`, '床', '#1D63ED')
      }
      GridItem() {
        this.overviewCard('设备在线',
          `${this.onlineDeviceCount()}`, `${this.deviceRows().length}`, '台', '#F5A623')
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

  @Builder
  private homeSearchBar() {
    Search({ placeholder: '搜索姓名、房间或设备' })
      .width('100%')
      .height(44)
      .placeholderColor($r('sys.color.font_tertiary'))
      .backgroundColor($r('sys.color.comp_background_primary'))
      .textFont({ size: $r('sys.float.Body_M'), weight: FontWeight.Regular })
      .searchIcon({ src: $r('sys.media.ohos_ic_public_search_filled') })
      .focusOnTouch(false)
      .focusable(false)
      .enableKeyboardOnFocus(false)
      .borderRadius(10)
      .padding({ left: 12, right: 12 })
      .geometryTransition(this.geometryId, { follow: true })
      .transition(TransitionEffect.OPACITY.animation({
        duration: 200,
        curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1)
      }))
      .onClick(() => {
        this.onSearchClicked();
      })
      .bindContentCover(
        this.isSearchPageShow,
        this.searchCoverBuilder,
        {
          modalTransition: ModalTransition.NONE,
          backgroundColor: 'rgba(0,0,0,0)'
        }
      )
  }



  // ---------------- resident builders ----------------

  private residentGeometryId(id: string): string {
    return `resident_geo_${id}`;
  }

  @Builder
  private residentListRow(item: ResidentData, isLast: boolean) {
    ListItem() {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(item.name)
              .fontSize($r('sys.float.Subtitle_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(`${item.age}岁 · ${item.room} · ${item.bed}`)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          this.statusTag(this.residentPriorityText(item.level), item.level)
        }
        .width('100%')

        Text(item.status)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(this.residentCardHeight())
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .border({
        width: 0.5,
        color: $r('sys.color.comp_divider')
      })
      .geometryTransition(this.residentGeometryId(item.id), { follow: true })
      .onClick(() => {
        this.onOpenResidentDetail(item, this.residentGeometryId(item.id));
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
  private taskChipBar() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(['全部', '系统', '长者'], (label: string, index: number) => {
          Row({ space: 6 }) {
            Text(label)
              .fontSize($r('sys.float.Body_S'))
              .fontWeight(this.taskFilterIndex() === index ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.taskFilterIndex() === index ?
                $r('sys.color.font_on_primary') : $r('sys.color.font_secondary'))
          }
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.taskFilterIndex() === index ?
            $r('sys.color.font_primary') : $r('sys.color.comp_background_primary'))
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
    return 2;
  }

  private taskFilterValue(index: number): 'all' | 'ai' | 'elder' {
    if (index === 0) {
      return 'all';
    }
    if (index === 1) {
      return 'ai';
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
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 44,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
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
          text: `${this.statusText(item.status)} · ${this.priorityText(item.priority)}`
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 52,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        onClick: () => {
          this.selectedTaskId = item.id;
          this.isTaskSheetOpen = true;
        }
      })
    }
    .padding({ left: 16, right: 16 })
    .bindSheet(this.isTaskSheetOpen && this.selectedTaskId === item.id, this.taskSheetBuilder, {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      blurStyle: BlurStyle.Thick,
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
      .fontColor(primary ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .backgroundColor(primary ? $r('sys.color.font_primary') : $r('sys.color.comp_background_primary'))
      .layoutWeight(1)
      .height(44)
      .onClick(onClick)
  }

  // ---------------- search transition ----------------

  private onSearchClicked(): void {
    this.geometryId = 'search';
    this.getUIContext().animateTo({
      duration: 100,
      curve: curves.interpolatingSpring(0, 1, 324, 38)
    }, () => {
      this.isSearchPageShow = true;
      this.homeSearchState.isSearchOpen = true;
    })
  }

  private onArrowClicked(): void {
    const useGeo: boolean = this.geometryId !== '';
    if (useGeo) {
      this.getUIContext().animateTo({
        curve: curves.interpolatingSpring(0, 1, 342, 38)
      }, () => {
        this.isSearchPageShow = false;
        this.homeSearchState.isSearchOpen = false;
        this.homeSearchText = '';
        this.geometryId = '';
      })
    } else {
      this.getUIContext().animateTo({
        duration: 300,
        curve: Curve.EaseInOut
      }, () => {
        this.isSearchPageShow = false;
        this.homeSearchState.isSearchOpen = false;
        this.homeSearchText = '';
      })
    }
  }

  // ---------------- pages ----------------

  @Builder
  private searchCoverBuilder() {
    Column() {
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('sys.color.font_primary')])
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.opacity(0)
                .animation({ curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1), duration: 200, delay: 150 }),
              TransitionEffect.opacity(0)
                .animation({ curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1), duration: 200 }),
            ))
        }
        .justifyContent(FlexAlign.Center)
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .onClick(() => {
          this.onArrowClicked();
        })

        Search({ value: this.homeSearchText, placeholder: '搜索姓名、房间或设备' })
          .width('100%')
          .height(40)
          .placeholderColor($r('sys.color.font_tertiary'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .textFont({ size: $r('sys.float.Body_M'), weight: FontWeight.Regular })
          .searchIcon({ src: $r('sys.media.ohos_ic_public_search_filled') })
          .defaultFocus(true)
          .borderRadius(12)
          .geometryTransition(this.geometryId, { follow: true })
          .transition(TransitionEffect.OPACITY.animation({
            duration: 200,
            curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1)
          }))
          .layoutWeight(1)
          .margin({ left: 8 })
          .onChange((value: string) => {
            this.homeSearchText = value;
          })
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding() })
      .margin({ top: this.topPadding() })

      List() {
        ListItem() {
          Column() {
            Text('搜索历史')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
              .width('100%')
              .padding({ top: 12, bottom: 8 })

            Row({ space: 8 }) {
              Text('肖爷爷')
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(8)
                .onClick(() => {
                  this.homeSearchText = '肖爷爷';
                })

              Text('3F-302')
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(8)
                .onClick(() => {
                  this.homeSearchText = '3F-302';
                })

              Text('智能床垫')
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(8)
                .onClick(() => {
                  this.homeSearchText = '智能床垫';
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .transition(TransitionEffect.opacity(0))
    .backgroundColor($r('sys.color.background_secondary'))
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private homePage() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({
        scroller: this.currentScroller(),
        space: 12
      }) {
      ListItem() {
        Column() {
          this.homeSearchBar()
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.homeContentTopPadding()
        })
      }

      ListItem() {
        Column() {
          this.overviewGrid()
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding()
        })
      }

      ListItem() {
        Column() {
          HealthListCard({
            cardData: this.healthCardData(),
            widthBreakpoint: this.globalInfoModel.widthBreakpoint,
            isExpanded: this.isHealthExpandShow,
            onCardExpand: () => {
              this.openHealthExpand();
            }
          })
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding()
        })
      }

      ListItem() {
        Column() {
          DeviceListCard({
            cardData: this.deviceCardData(),
            widthBreakpoint: this.globalInfoModel.widthBreakpoint
          })
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding()
        })
      }

      ListItem() {
        Column() {
          EventListCard({
            cardData: this.eventCardData(),
            widthBreakpoint: this.globalInfoModel.widthBreakpoint
          })
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          bottom: this.bottomPadding()
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onWillScroll(() => {
      const scroller: Scroller | undefined = this.currentScroller();
      this.homeSearchState.scrollY = scroller ? scroller.currentOffset().yOffset : 0;
    })
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
    Column({ space: 0 }) {
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
        cardPrefixMargin: 10,
        cardSuffixMargin: 10,
        onClick: () => {
        }
      })
      if (!isLast) {
        Divider()
          .width('100%')
          .height(0.5)
          .color($r('sys.color.comp_divider'))
          .margin({ left: 52, right: 16 })
      }
    }
    .width('100%')
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

  build() {
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
    .bindContentCover(this.isHealthExpandShow, this.healthExpandCover,
      { modalTransition: ModalTransition.NONE, backgroundColor: 'rgba(0,0,0,0)' })
  }
}
