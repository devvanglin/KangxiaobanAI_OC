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
import {
  MedicationProgress,
  ResidentData,
  RoomDeviceData,
  StatusLevel,
  VitalSign
} from '../../model/DetailTypes';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

type ResidentFilter = 'all' | 'warning' | 'danger';
type ResidentDetailTab = 'overview' | 'vitals' | 'care' | 'devices';

interface ResidentTabOption {
  value: ResidentDetailTab;
  label: string;
}

interface VitalTrendRow {
  time: string;
  heartRate: number;
  systolic: number;
  diastolic: number;
}

interface CareRecordRow {
  time: string;
  project: string;
  operator: string;
  result: string;
  level: StatusLevel;
}

interface RiskRow {
  label: string;
  value: string;
  level: StatusLevel;
}

@ComponentV2
export struct WideResidentPage {
  @Local residentFilterIndex: number = 0;
  private residentFilterItems: WideSlidingCapsuleItem[] = [
    { title: '全部 5', index: 0 },
    { title: '关注 2', index: 1 },
    { title: '危险 1', index: 2 }
  ];
  @Local selectedResidentId: string = 'r1';
  @Local selectedTab: ResidentDetailTab = 'overview';
  @Local hoveredResidentId: string = '';

  private allResidents(): ResidentData[] {
    return [
      {
        id: 'r1', name: '肖爷爷', age: 82, gender: 'male', room: '3F-302', bed: 'A床',
        level: 'danger', status: '情绪低落 · 拒交流',
        emergencyContact: '肖先生（子）', emergencyPhone: '138****1201',
        admissionDate: '2022-03-15', careLevel: '一级护理',
        diagnosis: ['高血压', '2型糖尿病', '轻度抑郁'], allergies: ['青霉素'],
        deviceIds: ['d1', 'd5', 'd6'], avatarText: '肖'
      },
      {
        id: 'r2', name: '周奶奶', age: 78, gender: 'female', room: '2F-215', bed: 'B床',
        level: 'warning', status: '夜间离床增加',
        emergencyContact: '周女士（女）', emergencyPhone: '139****2202',
        admissionDate: '2021-08-20', careLevel: '二级护理',
        diagnosis: ['冠心病', '骨质疏松'], allergies: ['海鲜'],
        deviceIds: ['d3', 'd4'], avatarText: '周'
      },
      {
        id: 'r3', name: '林爷爷', age: 85, gender: 'male', room: '3F-306', bed: 'C床',
        level: 'warning', status: '社交回避',
        emergencyContact: '林先生（子）', emergencyPhone: '137****3303',
        admissionDate: '2020-11-02', careLevel: '一级护理',
        diagnosis: ['脑梗后遗症', '高血压'], allergies: [],
        deviceIds: ['d2', 'd6'], avatarText: '林'
      },
      {
        id: 'r4', name: '王爷爷', age: 80, gender: 'male', room: '2F-201', bed: 'A床',
        level: 'normal', status: '稳定观察',
        emergencyContact: '王女士（女）', emergencyPhone: '136****4404',
        admissionDate: '2023-01-10', careLevel: '三级护理',
        diagnosis: ['高血压'], allergies: [],
        deviceIds: ['d7'], avatarText: '王'
      },
      {
        id: 'r5', name: '赵奶奶', age: 76, gender: 'female', room: '2F-208', bed: 'A床',
        level: 'normal', status: '稳定观察',
        emergencyContact: '赵先生（子）', emergencyPhone: '135****5505',
        admissionDate: '2022-09-28', careLevel: '三级护理',
        diagnosis: ['2型糖尿病'], allergies: ['坚果'],
        deviceIds: ['d8'], avatarText: '赵'
      }
    ];
  }

  private residentVitalSign(resident: ResidentData): VitalSign {
    const map: Record<string, VitalSign> = {
      'r1': {
        heartRate: 72, systolic: 138, diastolic: 85, oxygen: 96,
        temperature: 36.5, respiratory: 18, steps: 1240, sleepHours: 5.2, measuredAt: '10:24'
      },
      'r2': {
        heartRate: 78, systolic: 125, diastolic: 80, oxygen: 97,
        temperature: 36.4, respiratory: 17, steps: 2100, sleepHours: 6.8, measuredAt: '09:46'
      },
      'r3': {
        heartRate: 70, systolic: 142, diastolic: 88, oxygen: 95,
        temperature: 36.6, respiratory: 19, steps: 380, sleepHours: 4.5, measuredAt: '09:12'
      },
      'r4': {
        heartRate: 68, systolic: 118, diastolic: 76, oxygen: 98,
        temperature: 36.3, respiratory: 16, steps: 3200, sleepHours: 7.2, measuredAt: '08:30'
      },
      'r5': {
        heartRate: 75, systolic: 122, diastolic: 78, oxygen: 98,
        temperature: 36.4, respiratory: 17, steps: 2800, sleepHours: 7.0, measuredAt: '08:15'
      }
    };
    return map[resident.id] ?? {
      heartRate: 0, systolic: 0, diastolic: 0, oxygen: 0,
      temperature: 0, respiratory: 0, steps: 0, sleepHours: 0, measuredAt: '--'
    };
  }

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

  private selectedResident(): ResidentData {
    const resident: ResidentData | undefined =
      this.allResidents().find((item: ResidentData) => item.id === this.selectedResidentId);
    return resident ?? this.allResidents()[0];
  }

  private filteredResidents(): ResidentData[] {
    const activeFilter: ResidentFilter = this.activeResidentFilter();
    return this.allResidents().filter((item: ResidentData) =>
      activeFilter === 'all' || item.level === activeFilter);
  }

  private activeResidentFilter(): ResidentFilter {
    if (this.residentFilterIndex === 1) {
      return 'warning';
    }
    if (this.residentFilterIndex === 2) {
      return 'danger';
    }
    return 'all';
  }

  private tabOptions(): ResidentTabOption[] {
    return [
      { value: 'overview', label: '概览' },
      { value: 'vitals', label: '体征趋势' },
      { value: 'care', label: '护理记录' },
      { value: 'devices', label: '设备' }
    ];
  }

  private statusText(level: StatusLevel): string {
    if (level === 'danger') {
      return '危险';
    }
    if (level === 'warning') {
      return '关注';
    }
    return '稳定';
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

  private statusBackground(level: StatusLevel): ResourceColor {
    if (level === 'danger') {
      return $r('app.color.status_danger_bg');
    }
    if (level === 'warning') {
      return $r('app.color.status_warning_bg');
    }
    return $r('app.color.status_normal_bg');
  }

  private heartRateLevel(vital: VitalSign): StatusLevel {
    if (vital.heartRate < 50 || vital.heartRate > 110) {
      return 'danger';
    }
    if (vital.heartRate < 60 || vital.heartRate > 100) {
      return 'warning';
    }
    return 'normal';
  }

  private bloodPressureLevel(vital: VitalSign): StatusLevel {
    if (vital.systolic >= 140 || vital.diastolic >= 90) {
      return 'danger';
    }
    if (vital.systolic >= 130 || vital.diastolic >= 80) {
      return 'warning';
    }
    return 'normal';
  }

  private oxygenLevel(vital: VitalSign): StatusLevel {
    if (vital.oxygen < 95) {
      return 'danger';
    }
    if (vital.oxygen < 97) {
      return 'warning';
    }
    return 'normal';
  }

  private medicationLevel(progress: MedicationProgress): StatusLevel {
    return progress.total > 0 && progress.done >= progress.total ? 'normal' : 'warning';
  }

  private metricStateText(level: StatusLevel, warningText: string): string {
    return level === 'normal' ? '正常' : warningText;
  }

  private residentRowBackground(residentId: string): ResourceColor {
    if (this.selectedResidentId === residentId) {
      return $r('sys.color.comp_background_secondary');
    }
    if (this.hoveredResidentId === residentId) {
      return $r('sys.color.interactive_hover');
    }
    return Color.Transparent;
  }

  private trendRows(resident: ResidentData): VitalTrendRow[] {
    const vital: VitalSign = this.residentVitalSign(resident);
    return [
      { time: '06:00', heartRate: vital.heartRate - 4, systolic: vital.systolic - 6, diastolic: vital.diastolic - 3 },
      { time: '08:00', heartRate: vital.heartRate + 1, systolic: vital.systolic - 3, diastolic: vital.diastolic - 1 },
      { time: '10:00', heartRate: vital.heartRate - 2, systolic: vital.systolic + 2, diastolic: vital.diastolic + 1 },
      { time: '12:00', heartRate: vital.heartRate + 5, systolic: vital.systolic + 4, diastolic: vital.diastolic + 2 },
      { time: '14:00', heartRate: vital.heartRate + 2, systolic: vital.systolic - 1, diastolic: vital.diastolic },
      { time: '当前', heartRate: vital.heartRate, systolic: vital.systolic, diastolic: vital.diastolic }
    ];
  }

  private careRecords(resident: ResidentData): CareRecordRow[] {
    return [
      { time: '10:30', project: '情绪关怀', operator: '刘婷', result: `${resident.status}，已持续跟进`, level: resident.level },
      { time: '10:24', project: '体征测量', operator: '王倩', result: '体征数据已同步', level: 'normal' },
      { time: '09:00', project: '晨间巡房', operator: '王倩', result: '环境与安全检查完成', level: 'normal' },
      { time: '08:00', project: '早餐协助', operator: '刘婷', result: '进食约八成', level: 'normal' },
      { time: '07:30', project: '起床护理', operator: '刘婷', result: '洗漱与更衣完成', level: 'normal' }
    ];
  }

  private riskRows(resident: ResidentData): RiskRow[] {
    if (resident.id === 'r1') {
      return [
        { label: '跌倒风险', value: '高风险', level: 'danger' },
        { label: '压疮风险', value: '需关注', level: 'warning' },
        { label: '走失风险', value: '低风险', level: 'normal' }
      ];
    }
    if (resident.id === 'r2' || resident.id === 'r3') {
      return [
        { label: '跌倒风险', value: '需关注', level: 'warning' },
        { label: '压疮风险', value: '低风险', level: 'normal' },
        { label: '走失风险', value: '低风险', level: 'normal' }
      ];
    }
    return [
      { label: '跌倒风险', value: '低风险', level: 'normal' },
      { label: '压疮风险', value: '低风险', level: 'normal' },
      { label: '走失风险', value: '低风险', level: 'normal' }
    ];
  }

  private residentDevices(resident: ResidentData): RoomDeviceData[] {
    const devices: RoomDeviceData[] = [
      { id: 'd1', name: '智能床垫', type: '睡眠体征', room: resident.room, status: '数据异常', level: 'warning', battery: 78, lastUpdate: '10:24' },
      { id: 'd2', name: '毫米波雷达', type: '离床跌倒', room: resident.room, status: '离线', level: 'danger', battery: 0, lastUpdate: '14:20' },
      { id: 'd3', name: '紧急呼叫器', type: '主动求助', room: resident.room, status: '在线', level: 'normal', battery: 45, lastUpdate: '09:50' },
      { id: 'd4', name: '智能床垫', type: '睡眠体征', room: resident.room, status: '在线', level: 'normal', battery: 90, lastUpdate: '09:40' },
      { id: 'd5', name: '房间雷达', type: '活动监测', room: resident.room, status: '在线', level: 'normal', battery: 86, lastUpdate: '10:23' },
      { id: 'd6', name: '随身定位卡', type: '位置安全', room: resident.room, status: '在线', level: 'normal', battery: 62, lastUpdate: '10:22' },
      { id: 'd7', name: '健康手环', type: '生命体征', room: resident.room, status: '在线', level: 'normal', battery: 71, lastUpdate: '08:30' },
      { id: 'd8', name: '血糖仪', type: '血糖监测', room: resident.room, status: '在线', level: 'normal', battery: 84, lastUpdate: '08:15' }
    ];
    return devices.filter((item: RoomDeviceData) => resident.deviceIds.includes(item.id));
  }

  build() {
    Row() {
      this.masterPane()

      Column()
        .width(1)
        .height('100%')
        .backgroundColor($r('sys.color.comp_divider'))

      this.detailPane()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private masterPane() {
    Column({ space: 0 }) {
      Column() {
        this.filterBar()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      List({ space: 0 }) {
        if (this.filteredResidents().length === 0) {
          ListItem() {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(24)
                .fontColor([$r('sys.color.font_tertiary')])
              Text('未找到符合条件的长者')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
          }
        } else {
          Repeat(this.filteredResidents())
            .each((repeatItem: RepeatItem<ResidentData>) => {
              ListItem() {
                Column({ space: 0 }) {
                  this.residentListRow(repeatItem.item)
                  if (repeatItem.index !== this.filteredResidents().length - 1) {
                    Divider()
                      .strokeWidth(0.5)
                      .color($r('sys.color.comp_divider'))
                      .margin({ left: 68, right: 12 })
                  }
                }
                .width('100%')
              }
            })
            .key((item: ResidentData) => item.id)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ left: 12, right: 12, bottom: 14 })
      .padding({ top: 4, bottom: 4 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(14)
      .clip(true)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width(360)
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private filterBar() {
    WideSlidingCapsule({
      items: this.residentFilterItems,
      selectedIndex: this.residentFilterIndex,
      itemWidth: (360 - 32 - 6 - 8) / 3,
      onSelect: (index: number) => {
        this.residentFilterIndex = index;
      }
    })
  }

  @Builder
  private residentListRow(resident: ResidentData) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        Text(resident.avatarText ?? resident.name.slice(0, 1))
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(20)

        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(resident.name)
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(this.statusText(resident.level))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(`${resident.room} · ${resident.bed} · ${resident.status}`)
            .width('100%')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 8vp)')
    .height(72)
    .margin({ left: 4, right: 4 })
    .backgroundColor(this.residentRowBackground(resident.id))
    .borderRadius(10)
    .hoverEffect(HoverEffect.None)
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({ margin: LengthMetrics.vp(2), strokeWidth: LengthMetrics.vp(2) })
    .onHover((isHover: boolean) => {
      this.hoveredResidentId = isHover ? resident.id : '';
    })
    .onClick(() => {
      this.selectedResidentId = resident.id;
      this.selectedTab = 'overview';
    })
  }

  @Builder
  private detailPane() {
    Column({ space: 0 }) {
      Scroll() {
        Column({ space: 16 }) {
          this.residentProfileSurface(this.selectedResident())

          if (this.selectedTab === 'overview') {
            this.healthOverviewCard(this.selectedResident())
            this.overviewContent(this.selectedResident())
          } else if (this.selectedTab === 'vitals') {
            this.vitalTrendContent(this.selectedResident())
          } else if (this.selectedTab === 'care') {
            this.careRecordContent(this.selectedResident())
          } else {
            this.deviceContent(this.selectedResident())
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 1120 })
        .padding({ left: 24, right: 24, top: 20, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private residentProfileSurface(resident: ResidentData) {
    Column({ space: 0 }) {
      Row({ space: 18 }) {
        Text(resident.avatarText ?? resident.name.slice(0, 1))
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_blue'))
          .width(56)
          .height(56)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(29,99,237,0.10)')
          .borderRadius(28)

        Column({ space: 7 }) {
          Row({ space: 10 }) {
            Text(resident.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.statusText(resident.level))
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.statusColor(resident.level))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.statusBackground(resident.level))
              .borderRadius(5)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(`${resident.age}岁 · ${resident.gender === 'male' ? '男' : '女'} · ${resident.status}`)
            .width('100%')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 12 }) {
          this.profileMetaItem('房间床位', `${resident.room} · ${resident.bed}`)
          Divider()
            .vertical(true)
            .height(34)
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.profileMetaItem('护理等级', resident.careLevel)
          Divider()
            .vertical(true)
            .height(34)
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.profileMetaItem('责任护工', '刘婷')
        }
        .width('43%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 20, right: 20 })

      this.detailTabBar()
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private profileMetaItem(label: string, value: string) {
    Column({ space: 5 }) {
      Text(label)
        .width('100%')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(value)
        .width('100%')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private detailTabBar() {
    Row({ space: 0 }) {
      Repeat(this.tabOptions())
        .each((repeatItem: RepeatItem<ResidentTabOption>) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Column({ space: 8 }) {
              Text(repeatItem.item.label)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(this.selectedTab === repeatItem.item.value ?
                  FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.selectedTab === repeatItem.item.value ?
                  $r('app.color.brand_blue') : $r('sys.color.font_secondary'))

              Divider()
                .width(28)
                .strokeWidth(this.selectedTab === repeatItem.item.value ? 2 : 0)
                .color(this.selectedTab === repeatItem.item.value ?
                  $r('app.color.brand_blue') : Color.Transparent)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }
            .width(112)
            .height(54)
            .backgroundColor(Color.Transparent)
            .borderRadius(8)
            .focusBox({ margin: LengthMetrics.vp(2), strokeWidth: LengthMetrics.vp(2) })
            .onClick(() => {
              this.selectedTab = repeatItem.item.value;
            })
        })
        .key((item: ResidentTabOption) => item.value)
    }
    .width('100%')
    .height(54)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private healthOverviewCard(resident: ResidentData) {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 3 }) {
          Text('健康概览')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('核心体征与今日照护进度')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 12 }) {
          if (resident.allergies.length > 0) {
            Row({ space: 5 }) {
              SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
                .fontSize(13)
                .fontColor([$r('app.color.status_danger')])
              Text(`${resident.allergies.join('、')}过敏`)
                .fontSize($r('sys.float.Caption_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.status_danger'))
            }
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.status_danger_bg'))
            .borderRadius(12)
          }

          Text(`最近测量 ${this.residentVitalSign(resident).measuredAt}`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Row({ space: 0 }) {
        this.primaryVitalMetric(
          '血压',
          `${this.residentVitalSign(resident).systolic}/${this.residentVitalSign(resident).diastolic}`,
          'mmHg',
          this.metricStateText(this.bloodPressureLevel(this.residentVitalSign(resident)), '偏高'),
          this.bloodPressureLevel(this.residentVitalSign(resident)),
          1.35
        )
        Divider()
          .vertical(true)
          .height(58)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.primaryVitalMetric(
          '心率',
          `${this.residentVitalSign(resident).heartRate}`,
          'bpm',
          this.metricStateText(this.heartRateLevel(this.residentVitalSign(resident)), '需关注'),
          this.heartRateLevel(this.residentVitalSign(resident)),
          1
        )
        Divider()
          .vertical(true)
          .height(58)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.primaryVitalMetric(
          '血氧',
          `${this.residentVitalSign(resident).oxygen}`,
          '%',
          this.metricStateText(this.oxygenLevel(this.residentVitalSign(resident)), '需关注'),
          this.oxygenLevel(this.residentVitalSign(resident)),
          1
        )
        Divider()
          .vertical(true)
          .height(58)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.primaryVitalMetric(
          '今日用药',
          `${this.residentMedicationProgress(resident).done}/${this.residentMedicationProgress(resident).total}`,
          '次',
          this.residentMedicationProgress(resident).done >= this.residentMedicationProgress(resident).total ?
            '已完成' :
            `待完成 ${this.residentMedicationProgress(resident).total -
              this.residentMedicationProgress(resident).done} 次`,
          this.medicationLevel(this.residentMedicationProgress(resident)),
          1
        )
      }
      .width('100%')
      .height(94)
      .padding({ left: 10, right: 10 })
      .alignItems(VerticalAlign.Center)

      Row({ space: 0 }) {
        this.secondaryVitalMetric('体温', `${this.residentVitalSign(resident).temperature}`, '℃')
        Divider()
          .vertical(true)
          .height(36)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.secondaryVitalMetric('呼吸', `${this.residentVitalSign(resident).respiratory}`, '次/分')
        Divider()
          .vertical(true)
          .height(36)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.secondaryVitalMetric('今日步数', `${this.residentVitalSign(resident).steps}`, '步')
        Divider()
          .vertical(true)
          .height(36)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.secondaryVitalMetric('昨夜睡眠', `${this.residentVitalSign(resident).sleepHours}`, '小时')
      }
      .width('calc(100% - 40vp)')
      .height(66)
      .margin({ left: 20, right: 20, bottom: 18 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(10)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private primaryVitalMetric(
    label: string,
    value: string,
    unit: string,
    state: string,
    level: StatusLevel,
    weight: number
  ) {
    Column({ space: 7 }) {
      Text(label)
        .width('100%')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 4 }) {
        Text(value)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(unit)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row({ space: 6 }) {
        Circle({ width: 6, height: 6 })
          .fill(this.statusColor(level))
        Text(state)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.statusColor(level))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(weight)
    .padding({ left: 14, right: 14 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private secondaryVitalMetric(label: string, value: string, unit: string) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 4 }) {
        Text(value)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(unit)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private overviewContent(resident: ResidentData) {
    Row({ space: 16 }) {
      Column({ space: 16 }) {
        this.carePlanCard(resident)
        this.basicInfoCard(resident)
      }
      .layoutWeight(1)

      Column({ space: 16 }) {
        this.riskCard(resident)
        this.medicationCard(resident)
        this.contactCard(resident)
      }
      .width(320)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private carePlanCard(resident: ResidentData) {
    Column({ space: 0 }) {
      this.cardTitle('今日护理', '4 项 · 已完成 2 项')
      this.carePlanRow('14:00', '翻身叩背', '待执行', 'warning', false)
      this.carePlanRow('12:00', '协助服药', '进行中', 'warning', false)
      this.carePlanRow('10:30', '情绪关怀', '已完成', resident.level, false)
      this.carePlanRow('09:00', '晨间巡房', '已完成', 'normal', true)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private carePlanRow(time: string, project: string, state: string, level: StatusLevel, isLast: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(time)
          .width(48)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
        Text(project)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(state)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.statusColor(level))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.statusBackground(level))
          .borderRadius(5)
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      }
    }
    .width('100%')
  }

  @Builder
  private basicInfoCard(resident: ResidentData) {
    Column({ space: 0 }) {
      this.cardTitle('基础信息', '')
      this.descriptionRow('入住日期', resident.admissionDate, false)
      this.descriptionRow('护理等级', resident.careLevel, false)
      this.descriptionRow('主要诊断', resident.diagnosis.join(' · '), false)
      this.descriptionRow('房间床位', `${resident.room} ${resident.bed}`, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private riskCard(resident: ResidentData) {
    Column({ space: 0 }) {
      this.cardTitle('风险评估', '本月已评估')
      Repeat(this.riskRows(resident))
        .each((repeatItem: RepeatItem<RiskRow>) => {
          Row() {
            Text(repeatItem.item.label)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
              .layoutWeight(1)
            Text(repeatItem.item.value)
              .fontSize($r('sys.float.Body_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.statusColor(repeatItem.item.level))
          }
          .width('100%')
          .height(38)
          .alignItems(VerticalAlign.Center)
        })
        .key((item: RiskRow) => item.label)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private medicationCard(resident: ResidentData) {
    Column({ space: 10 }) {
      this.cardTitle('今日用药', '按医嘱执行')
      Row() {
        Column({ space: 4 }) {
          Text(`${this.residentMedicationProgress(resident).done}/${this.residentMedicationProgress(resident).total}`)
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_blue'))
          Text('已完成次数')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text(this.residentMedicationProgress(resident).done ===
            this.residentMedicationProgress(resident).total ? '全部完成' : '下次 14:00')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.residentMedicationProgress(resident).done ===
              this.residentMedicationProgress(resident).total ?
              $r('app.color.status_normal') : $r('app.color.status_warning'))
          Text('口服 · 请核对医嘱')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private contactCard(resident: ResidentData) {
    Column({ space: 8 }) {
      this.cardTitle('紧急联系人', '')
      Text(resident.emergencyContact)
        .width('100%')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(resident.emergencyPhone)
        .width('100%')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private vitalTrendContent(resident: ResidentData) {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        this.cardTitle('今日心率趋势', '单位 bpm')
        Row({ space: 12 }) {
          Repeat(this.trendRows(resident))
            .each((repeatItem: RepeatItem<VitalTrendRow>) => {
              Column({ space: 7 }) {
                Text(`${repeatItem.item.heartRate}`)
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_secondary'))
                Column()
                  .width(18)
                  .height(42 + (repeatItem.item.heartRate - 60))
                  .backgroundColor(repeatItem.item.time === '当前' ?
                    $r('app.color.brand_blue') : 'rgba(29,99,237,0.28)')
                  .borderRadius(4)
                Text(repeatItem.item.time)
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .layoutWeight(1)
              .height(130)
              .justifyContent(FlexAlign.End)
              .alignItems(HorizontalAlign.Center)
            })
            .key((item: VitalTrendRow) => item.time)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 4, bottom: 18 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })

      Column({ space: 0 }) {
        this.cardTitle('测量记录', '最近 6 次')
        Repeat(this.trendRows(resident))
          .each((repeatItem: RepeatItem<VitalTrendRow>) => {
            Row() {
              Text(repeatItem.item.time)
                .width(90)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
              Text(`心率 ${repeatItem.item.heartRate} bpm`)
                .layoutWeight(1)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
              Text(`血压 ${repeatItem.item.systolic}/${repeatItem.item.diastolic}`)
                .fontSize($r('sys.float.Body_M'))
                .fontColor(repeatItem.item.systolic >= 140 ?
                  $r('app.color.status_danger') : $r('sys.color.font_primary'))
            }
            .width('100%')
            .height(48)
            .alignItems(VerticalAlign.Center)
            .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
          })
          .key((item: VitalTrendRow) => item.time)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 4, bottom: 10 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    }
    .width('100%')
  }

  @Builder
  private careRecordContent(resident: ResidentData) {
    Column({ space: 0 }) {
      this.cardTitle('今日护理记录', `${this.careRecords(resident).length} 条记录`)
      Repeat(this.careRecords(resident))
        .each((repeatItem: RepeatItem<CareRecordRow>) => {
          Row({ space: 14 }) {
            Text(repeatItem.item.time)
              .width(54)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_tertiary'))

            Circle({ width: 8, height: 8 })
              .fill(this.statusColor(repeatItem.item.level))

            Column({ space: 4 }) {
              Row({ space: 8 }) {
                Text(repeatItem.item.project)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(repeatItem.item.operator)
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_tertiary'))
              }
              Text(repeatItem.item.result)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .height(66)
          .alignItems(VerticalAlign.Center)
          .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
        })
        .key((item: CareRecordRow) => `${item.time}_${item.project}`)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 4, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private deviceContent(resident: ResidentData) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('房间设备')
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`${resident.room} · 共 ${this.residentDevices(resident).length} 台`)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.residentDevices(resident).some((item: RoomDeviceData) => item.level === 'danger') ?
          '存在离线设备' : '设备运行正常')
          .fontSize($r('sys.float.Body_S'))
          .fontColor(this.residentDevices(resident).some((item: RoomDeviceData) => item.level === 'danger') ?
            $r('app.color.status_danger') : $r('app.color.status_normal'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Grid() {
        Repeat(this.residentDevices(resident))
          .each((repeatItem: RepeatItem<RoomDeviceData>) => {
            GridItem() {
              Column({ space: 12 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(repeatItem.item.name)
                      .fontSize($r('sys.float.Body_L'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Text(repeatItem.item.type)
                      .fontSize($r('sys.float.Body_S'))
                      .fontColor($r('sys.color.font_secondary'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(repeatItem.item.status)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor(this.statusColor(repeatItem.item.level))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor(this.statusBackground(repeatItem.item.level))
                    .borderRadius(5)
                }
                .width('100%')

                Row() {
                  Text(`电量 ${repeatItem.item.battery ?? 0}%`)
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('sys.color.font_secondary'))
                    .layoutWeight(1)
                  Text(`更新 ${repeatItem.item.lastUpdate}`)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('sys.color.font_tertiary'))
                }
                .width('100%')
              }
              .width('100%')
              .height('100%')
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(12)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })
              .justifyContent(FlexAlign.Center)
            }
          })
          .key((item: RoomDeviceData) => item.id)
      }
      .width('100%')
      .columnsTemplate('1fr 1fr')
      .columnsGap(14)
      .rowsGap(14)
      .height(Math.ceil(this.residentDevices(resident).length / 2) * 132 +
        Math.max(0, Math.ceil(this.residentDevices(resident).length / 2) - 1) * 14)
    }
    .width('100%')
  }

  @Builder
  private cardTitle(title: string, description: string) {
    Row() {
      Text(title)
        .fontSize($r('sys.float.Subtitle_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      if (description !== '') {
        Text(description)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private descriptionRow(label: string, value: string, isLast: boolean) {
    Column({ space: 0 }) {
      Row({ space: 16 }) {
        Text(label)
          .width(76)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
        Text(value)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      }
    }
    .width('100%')
  }
}
