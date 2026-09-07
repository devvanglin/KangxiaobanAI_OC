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
import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Bed, CareExecution, CareTask, Elder, HealthRecord, IotDevice, MedicationRecord, Room } from '../../network/Dto';

type ResidentFilter = 'all' | 'warning' | 'danger';
type ResidentDetailTab = 'overview' | 'vitals' | 'care' | 'devices' | 'behavior' | 'medications';

interface VitalTrendRow {
  time: string;
  heartRate: number;
  respiratory: number;
  systolic: number;
  diastolic: number;
  level: StatusLevel;
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

// Doctor-owned resident surface; keep its UI state independent from the caregiver workspace.
@ComponentV2
export struct WideDoctorResidentPage {
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Param compactWidth: boolean = false;
  @Param topBarHeight: number = 0;
  @Param @Require masterScroller: Scroller;
  @Param @Require detailScroller: Scroller;
  @Param naviIndicatorHeight: number = 0;
  @Param backRequestToken: number = 0;
  @Param requestedResidentId: string = '';
  @Param residentSelectionRequestToken: number = 0;
  @Event onLocalDetailVisibilityChange: (visible: boolean) => void = (_visible: boolean) => {};
  @Event onMasterScrollerActive: () => void = () => {};
  @Event onDetailScrollerActive: () => void = () => {};

  private pageTopInset(): number {
    return this.topBarHeight + (this.compactWidth ? 16 : 20);
  }

  private masterFilterHeight(): number {
    return 72;
  }

  private detailContentMaxWidth(): number {
    return this.compactWidth ? 960 : 1280;
  }

  private deviceCardHeight(): number {
    return this.compactWidth ? 148 : 132;
  }

  @Local residentFilterIndex: number = 0;
  private detailTabItems: WideSlidingCapsuleItem[] = [
    { title: '概览', index: 0 },
    { title: '体征趋势', index: 1 },
    { title: '护理记录', index: 2 },
    { title: '设备', index: 3 },
    { title: '行为', index: 4 },
    { title: '药物', index: 5 }
  ];
  @Param selectedResidentId: string = '';
  @Local selectedTab: ResidentDetailTab = 'overview';
  @Local hoveredResidentId: string = '';
  @Local compactDetailVisible: boolean = false;
  @Event onSelectResident: (id: string) => void = (_id: string) => {};

  @Monitor('backRequestToken')
  onBackRequestTokenChange(): void {
    if (this.compactWidth && this.compactDetailVisible) {
      this.showCompactList();
    }
  }

  @Monitor('compactWidth')
  onCompactWidthChange(): void {
    this.reportVisibleScrollerOwner();
  }

  @Monitor('residentSelectionRequestToken', 'requestedResidentId')
  onResidentSelectionRequestTokenChange(): void {
    const requestedId: string = this.requestedResidentId.trim();
    if (requestedId.length === 0) {
      if (this.compactWidth) {
        this.showCompactList();
      } else {
        this.resetDetailScrollPosition();
        this.compactDetailVisible = false;
      }
      return;
    }

    const requestedResident: ResidentData | undefined =
      this.allResidents().find((resident: ResidentData) => resident.id === requestedId);
    if (!requestedResident) {
      return;
    }

    this.onSelectResident(requestedResident.id);
    this.selectedTab = 'overview';
    if (this.compactWidth) {
      this.showCompactDetail();
    } else {
      this.resetDetailScrollPosition();
      this.compactDetailVisible = false;
      this.onLocalDetailVisibilityChange(false);
      this.onDetailScrollerActive();
    }
  }

  aboutToAppear(): void {
    this.businessStore.load();
    this.reportVisibleScrollerOwner();
  }

  private reportVisibleScrollerOwner(): void {
    if (this.compactWidth && !this.compactDetailVisible) {
      this.onMasterScrollerActive();
    } else {
      this.onDetailScrollerActive();
    }
  }

  private showCompactList(): void {
    this.resetDetailScrollPosition();
    this.compactDetailVisible = false;
    this.onLocalDetailVisibilityChange(false);
    this.onMasterScrollerActive();
  }

  private showCompactDetail(): void {
    this.resetDetailScrollPosition();
    this.compactDetailVisible = true;
    this.onLocalDetailVisibilityChange(true);
    this.onDetailScrollerActive();
  }

  private resetDetailScrollPosition(): void {
    try {
      this.detailScroller.scrollEdge(Edge.Top);
    } catch (_error) {
      // The compact detail scroller may not be attached on its first render.
    }
  }

  private allResidents(): ResidentData[] {
    return this.businessStore.elders.map((elder: Elder): ResidentData => {
      const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder.bed_id);
      const room: Room | undefined = bed ?
        this.businessStore.rooms.find((item: Room) => item.id === bed.room_id) : undefined;
      const contactName: string = elder.emergency_contacts && elder.emergency_contacts.length > 0 ?
        `${elder.emergency_contacts[0].name}（${elder.emergency_contacts[0].relation}）` : '未登记';
      const contactPhone: string = elder.emergency_contacts && elder.emergency_contacts.length > 0 ?
        elder.emergency_contacts[0].phone : '';
      const latest: HealthRecord | undefined = this.businessStore.healthRecords
        .filter((item: HealthRecord) => item.elder_id === elder.id)
        .sort((left: HealthRecord, right: HealthRecord): number =>
          right.record_time.localeCompare(left.record_time))[0];
      const healthLevel: StatusLevel = this.serverRiskLevel(latest?.risk_level);
      const hasOpenAlert: boolean = this.businessStore.alerts.some((item: Alert) =>
        item.elder_id === elder.id && item.status !== 'handled' && item.status !== 'closed');
      const level: StatusLevel = hasOpenAlert ? 'danger' : healthLevel;
      const status: string = hasOpenAlert ? '存在待处理告警' : latest === undefined ? '暂无体征记录' :
        (latest.risk_summary?.trim() || (healthLevel === 'normal' ? '服务器评估正常' : '服务器评估需关注'));
      const location: string = room ? `${room.floor}F-${room.room_no}` : '未分配房间';
      return {
        id: `${elder.id}`,
        name: elder.name,
        age: this.ageFromBirthDate(elder.birth_date),
        gender: elder.gender === 'F' ? 'female' : 'male',
        room: location,
        bed: bed ? `${bed.bed_no}床` : '未分配床位',
        level: level,
        status: status,
        emergencyContact: contactName,
        emergencyPhone: contactPhone,
        admissionDate: elder.created_at ?? '',
        careLevel: `${elder.care_level}级护理`,
        diagnosis: elder.remark ? elder.remark.split('；') : [],
        allergies: elder.allergies ?? [],
        deviceIds: this.businessStore.devices
          .filter((item: IotDevice) => item.elder_id === elder.id)
          .map((item: IotDevice): string => item.device_id),
        avatarText: elder.name.slice(0, 1)
      };
    });
  }

  private ageFromBirthDate(birthDate?: string): number {
    if (!birthDate || birthDate.length < 4) {
      return 0;
    }
    return new Date().getFullYear() - Number(birthDate.slice(0, 4));
  }

  private timeText(value: string): string {
    return value.length >= 16 ? value.slice(11, 16) : value;
  }

  private residentVitalSign(resident: ResidentData): VitalSign {
    const elderId: number = Number(resident.id);
    const records: HealthRecord[] = this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === elderId)
      .sort((left: HealthRecord, right: HealthRecord): number => right.record_time.localeCompare(left.record_time));
    if (records.length === 0) {
      return {
        heartRate: 0, systolic: 0, diastolic: 0, oxygen: 0,
        temperature: 0, respiratory: 0, steps: 0, sleepHours: 0, measuredAt: '--',
        riskLevel: 'normal', riskSummary: ''
      };
    }
    const latest: HealthRecord = records[0];
    return {
      heartRate: latest.heart_rate ?? 0,
      systolic: latest.systolic ?? 0,
      diastolic: latest.diastolic ?? 0,
      oxygen: latest.spo2 ?? 0,
      temperature: latest.temperature ?? 0,
      respiratory: latest.respiratory_rate ?? 0,
      steps: latest.steps ?? 0,
      sleepHours: latest.sleep_hours ?? 0,
      measuredAt: this.timeText(latest.record_time),
      riskLevel: this.serverRiskLevel(latest.risk_level),
      riskSummary: latest.risk_summary ?? ''
    };
  }

  private residentMedicationProgress(resident: ResidentData): MedicationProgress {
    const elderId: number = Number(resident.id);
    const records: MedicationRecord[] = this.businessStore.medications
      .filter((item: MedicationRecord) => item.elder_id === elderId);
    let done: number = 0;
    let total: number = 0;
    for (let index: number = 0; index < records.length; index++) {
      done += Math.max(0, records[index].today_done ?? 0);
      total += Math.max(0, records[index].today_total ?? 0);
    }
    return { done: done, total: total };
  }

  private hasHeartRate(resident: ResidentData): boolean {
    return this.residentVitalSign(resident).heartRate > 0;
  }

  private previousVitalValue(resident: ResidentData, pick: (item: HealthRecord) => number): number | undefined {
    const records: HealthRecord[] = this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === Number(resident.id))
      .sort((left: HealthRecord, right: HealthRecord): number => right.record_time.localeCompare(left.record_time));
    if (records.length < 2) {
      return undefined;
    }
    const value: number = pick(records[1]);
    return value > 0 ? value : undefined;
  }

  private metricTrendText(current: number, previous: number | undefined, digits: number,
    lowerIsBetter: boolean): string {
    if (current <= 0 || previous === undefined || previous <= 0) {
      return '暂无对比';
    }
    const factor: number = Math.pow(10, digits);
    const delta: number = Math.round((current - previous) * factor) / factor;
    if (delta === 0) {
      return '较昨日 持平';
    }
    return delta > 0 ? `较昨日 ↑ ${delta}` : `较昨日 ↓ ${Math.abs(delta)}`;
  }

  private metricTrendColor(current: number, previous: number | undefined, digits: number,
    lowerIsBetter: boolean): ResourceColor {
    if (current <= 0 || previous === undefined || previous <= 0) {
      return $r('sys.color.font_tertiary');
    }
    const factor: number = Math.pow(10, digits);
    const delta: number = Math.round((current - previous) * factor) / factor;
    if (delta === 0) {
      return $r('sys.color.font_tertiary');
    }
    const rising: boolean = delta > 0;
    const worse: boolean = lowerIsBetter ? rising : !rising;
    return worse ? $r('app.color.status_danger') : $r('app.color.status_normal');
  }

  private residentMedications(resident: ResidentData): MedicationRecord[] {
    return this.businessStore.medications
      .filter((item: MedicationRecord) => item.elder_id === Number(resident.id))
      .sort((left: MedicationRecord, right: MedicationRecord): number =>
        (left.plan_time ?? '').localeCompare(right.plan_time ?? ''));
  }

  private nextMedicationText(resident: ResidentData): string {
    const records: MedicationRecord[] = this.residentMedications(resident);
    if (records.length === 0) {
      return '暂无计划';
    }
    const pending: MedicationRecord | undefined = records.find((item: MedicationRecord): boolean =>
      item.status !== 'taken');
    if (pending === undefined) {
      return '全部完成';
    }
    return pending.plan_time ? `下次 ${this.timeText(pending.plan_time)}` : '待执行';
  }

  private residentCareTasks(resident: ResidentData): CareTask[] {
    return this.businessStore.tasks
      .filter((item: CareTask): boolean => item.elder_id === Number(resident.id))
      .sort((left: CareTask, right: CareTask): number =>
        (left.due_at ?? '').localeCompare(right.due_at ?? ''));
  }

  private responsibleCaregiver(resident: ResidentData): string {
    const task: CareTask | undefined = this.residentCareTasks(resident)
      .find((item: CareTask): boolean => (item.assignee ?? '').trim().length > 0);
    return task?.assignee ?? '未分配';
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

  private residentFilterItems(): WideSlidingCapsuleItem[] {
    const residents: ResidentData[] = this.allResidents();
    return [
      { title: `全部 ${residents.length}`, index: 0 },
      { title: `关注 ${residents.filter((item: ResidentData): boolean => item.level === 'warning').length}`, index: 1 },
      { title: `危险 ${residents.filter((item: ResidentData): boolean => item.level === 'danger').length}`, index: 2 }
    ];
  }

  private selectedDetailTabIndex(): number {
    if (this.selectedTab === 'vitals') {
      return 1;
    }
    if (this.selectedTab === 'care') {
      return 2;
    }
    if (this.selectedTab === 'devices') {
      return 3;
    }
    if (this.selectedTab === 'behavior') {
      return 4;
    }
    if (this.selectedTab === 'medications') {
      return 5;
    }
    return 0;
  }

  private selectDetailTab(index: number): void {
    if (index === 1) {
      this.selectedTab = 'vitals';
    } else if (index === 2) {
      this.selectedTab = 'care';
    } else if (index === 3) {
      this.selectedTab = 'devices';
    } else if (index === 4) {
      this.selectedTab = 'behavior';
    } else if (index === 5) {
      this.selectedTab = 'medications';
    } else {
      this.selectedTab = 'overview';
    }
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

  private serverRiskLevel(value?: string): StatusLevel {
    if (value === 'danger' || value === 'high' || value === 'critical') {
      return 'danger';
    }
    if (value === 'warning' || value === 'medium') {
      return 'warning';
    }
    return 'normal';
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
    return this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === Number(resident.id))
      .filter((item: HealthRecord): boolean => item.heart_rate !== undefined &&
        item.systolic !== undefined && item.diastolic !== undefined)
      .sort((left: HealthRecord, right: HealthRecord): number => left.record_time.localeCompare(right.record_time))
      .map((item: HealthRecord): VitalTrendRow => {
        return { time: this.timeText(item.record_time), heartRate: item.heart_rate ?? 0,
          respiratory: item.respiratory_rate ?? 0,
          systolic: item.systolic ?? 0, diastolic: item.diastolic ?? 0,
          level: this.serverRiskLevel(item.risk_level) };
      });
  }

  private ageText(resident: ResidentData): string {
    return resident.age > 0 ? `${resident.age}岁` : '年龄未登记';
  }

  private measuredAtText(resident: ResidentData): string {
    const measuredAt: string = this.residentVitalSign(resident).measuredAt;
    return measuredAt === '--' ? '暂无体征记录' : `${measuredAt} 更新`;
  }

  private careRecords(resident: ResidentData): CareRecordRow[] {
    const elderId: number = Number(resident.id);
    return this.businessStore.careExecutions
      .filter((execution: CareExecution): boolean => execution.elder_id === elderId)
      .slice()
      .sort((left: CareExecution, right: CareExecution): number =>
        right.executed_at.localeCompare(left.executed_at))
      .map((execution: CareExecution): CareRecordRow => {
        const task: CareTask | undefined = this.businessStore.tasks.find((item: CareTask): boolean =>
          item.elder_id === elderId && item.plan_item_id !== undefined &&
          item.plan_item_id === execution.plan_item_id);
        const abnormal: string = (execution.abnormal ?? '').trim();
        const resultText: string = (execution.result ?? '').trim();
        const statusText: string = abnormal.length > 0 || execution.status === 'abnormal' ? `异常：${abnormal || '需关注'}` :
          resultText.length > 0 ? resultText : execution.status === 'reviewed' ? '护理执行已复核' :
            execution.status === 'skipped' ? '护理项目已跳过' : '护理项目已完成';
        const level: StatusLevel = abnormal.length > 0 || execution.status === 'abnormal' ? 'danger' :
          execution.status === 'completed' || execution.status === 'reviewed' ? 'normal' : 'warning';
        return {
          time: execution.executed_at ? this.timeText(execution.executed_at) : '--',
          project: task?.title ?? `护理项目 #${execution.plan_item_id}`,
          operator: execution.executor || '服务器记录',
          result: statusText,
          level: level
        };
      });
  }

  private riskRows(resident: ResidentData): RiskRow[] {
    const alerts: Alert[] = this.businessStore.alerts.filter((item: Alert) =>
      item.elder_id === Number(resident.id) && item.status !== 'handled' && item.status !== 'closed');
    const rows: RiskRow[] = [];
    const latest: HealthRecord | undefined = this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === Number(resident.id))
      .sort((left: HealthRecord, right: HealthRecord): number =>
        right.record_time.localeCompare(left.record_time))[0];
    if (latest && (latest.risk_summary?.trim().length ?? 0) > 0) {
      rows.push({ label: '体征风险', value: latest.risk_summary ?? '',
        level: this.serverRiskLevel(latest.risk_level) });
    }
    for (let index: number = 0; index < alerts.length; index++) {
      const item: Alert = alerts[index];
      const level: StatusLevel = item.level === 'emergency' ? 'danger' : item.level === 'important' ? 'warning' : 'normal';
      rows.push({ label: item.type, value: item.content, level: level });
    }
    if (rows.length === 0) {
      rows.push({ label: '综合风险', value: latest ? '服务器未报告异常风险' : '暂无服务器风险记录', level: 'normal' });
    }
    return rows;
  }

  private residentDevices(resident: ResidentData): RoomDeviceData[] {
    return this.businessStore.devices
      .filter((item: IotDevice) => item.elder_id === Number(resident.id))
      .map((item: IotDevice): RoomDeviceData => {
        return { id: item.device_id, name: item.product, type: item.protocol, room: resident.room,
          status: item.online === 1 ? '在线' : '离线', level: item.online === 1 ? 'normal' : 'danger',
          battery: item.battery,
          lastUpdate: item.last_seen ? this.timeText(item.last_seen) : '--' };
      });
  }

  build() {
    if (this.compactWidth) {
      Row() {
        if (this.compactDetailVisible) {
          this.detailPane()
        } else {
          this.masterPane()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: 24 + this.naviIndicatorHeight })
      .backgroundColor($r('sys.color.background_secondary'))
      .justifyContent(FlexAlign.Center)
    } else {
      Row({ space: 20 }) {
        this.masterPane()
        this.detailPane()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 28, right: 28, bottom: 24 + this.naviIndicatorHeight })
      .backgroundColor($r('sys.color.background_secondary'))
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private masterPane() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row()
          .width('100%')
          .height(this.pageTopInset())

        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      }
      .width('100%')
      .height('100%')

      List({ scroller: this.masterScroller, space: 0 }) {
        ListItem() {
          Row()
            .width('100%')
            .height(this.pageTopInset() + this.masterFilterHeight())
        }

        if (this.filteredResidents().length === 0) {
          ListItem() {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(24)
                .fontColor([$r('sys.color.font_tertiary')])
              Text(this.businessStore.eldersLoaded ?
                (this.businessStore.error.length > 0 ? '长者数据加载失败' : '暂无长者数据') : '正在加载长者数据')
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
                }
                .width('100%')
              }
            })
            .key((item: ResidentData) => item.id)
        }

        ListItem() {
          Text(`共 ${this.filteredResidents().length} 位长者`)
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .padding({ top: 16, bottom: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 10 + this.naviIndicatorHeight })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScrollStart(() => {
        this.onMasterScrollerActive();
      })

      Column() {
        this.filterBar()
      }
      .width('100%')
      .height(this.masterFilterHeight())
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .margin({ top: this.pageTopInset() })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width(this.compactWidth ? '100%' : '29%')
    .constraintSize({
      minWidth: this.compactWidth ? 0 : 340,
      maxWidth: this.compactWidth ? '100%' : 420
    })
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private filterBar() {
      WideSlidingCapsule({
        items: this.residentFilterItems(),
      selectedIndex: this.residentFilterIndex,
      itemWidth: (360 - 32 - 6 - 8) / 3,
      fillWidth: true,
      onSelect: (index: number) => {
        this.residentFilterIndex = index;
      }
    })
  }

  @Builder
  private residentListRow(resident: ResidentData) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(40)
          .fontColor([$r('sys.color.icon_secondary')])

        Column() {
          Row({ space: 8 }) {
            Text(resident.name)
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(this.statusText(resident.level))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
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
    .height(64)
    .margin({ left: 4, right: 4, top: 4, bottom: 4 })
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
      this.onSelectResident(resident.id);
      this.selectedTab = 'overview';
      if (this.compactWidth) {
        this.showCompactDetail();
      } else {
        this.resetDetailScrollPosition();
        this.onDetailScrollerActive();
      }
    })
  }

  private selectedResident(): ResidentData | undefined {
    if (this.selectedResidentId.length === 0) {
      return undefined;
    }
    return this.allResidents().find(
      (resident: ResidentData): boolean => resident.id === this.selectedResidentId);
  }

  @Builder
  private detailPane() {
    if (this.allResidents().length === 0) {
      this.emptyResidentDetail()
    } else if (this.selectedResident() === undefined) {
      this.selectResidentHint()
    } else {
      this.residentDetailPane(this.selectedResidentOrFirst())
    }
  }

  private selectedResidentOrFirst(): ResidentData {
    const residents: ResidentData[] = this.allResidents();
    const selected: ResidentData | undefined = residents.find(
      (resident: ResidentData): boolean => resident.id === this.selectedResidentId);
    return selected ?? residents[0];
  }

  @Builder
  private selectResidentHint() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.person_2_fill'))
        .fontSize(44)
        .fontColor([$r('sys.color.font_tertiary')])
      Text('在左侧选择一位长者')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      Text('点击长者名字即可查看健康与护理情况')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private emptyResidentDetail() {
    Column({ space: 10 }) {
      if (this.businessStore.loading && !this.businessStore.eldersLoaded) {
        LoadingProgress()
          .width(36)
          .height(36)
        Text('正在加载长者数据')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      } else {
        Text(this.businessStore.error.length > 0 ? '长者数据加载失败' : '暂无长者数据')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private residentDetailPane(resident: ResidentData) {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll(this.detailScroller) {
        Column({ space: this.compactWidth ? 12 : 16 }) {
          this.residentProfileSurface(resident)

          if (this.selectedTab === 'overview') {
            this.healthOverviewCard(resident)
            this.overviewContent(resident)
          } else if (this.selectedTab === 'vitals') {
            this.vitalTrendContent(resident)
          } else if (this.selectedTab === 'care') {
            this.careRecordContent(resident)
          } else if (this.selectedTab === 'behavior') {
            this.behaviorContent(resident)
          } else if (this.selectedTab === 'medications') {
            this.medicationContent(resident)
          } else {
            this.deviceContent(resident)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: this.detailContentMaxWidth() })
        .padding({
          top: this.pageTopInset(),
          bottom: 8 + this.naviIndicatorHeight
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScrollStart(() => {
        this.onDetailScrollerActive();
      })
      .onAppear(() => {
        if (this.compactWidth && this.compactDetailVisible) {
          this.resetDetailScrollPosition();
        }
      })

    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private residentProfileSurface(resident: ResidentData) {
    Column({ space: 0 }) {
      if (this.compactWidth) {
        Column({ space: 14 }) {
          this.residentIdentityBlock(resident)
          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
          this.profileMetaStrip(resident)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 14 })
        .alignItems(HorizontalAlign.Start)
      } else {
        Row({ space: 24 }) {
          Column() {
            this.residentIdentityBlock(resident)
          }
          .layoutWeight(1)

          Column() {
            this.profileMetaStrip(resident)
          }
          .width('52%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 22, bottom: 20 })
        .alignItems(VerticalAlign.Center)
      }

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
  private residentIdentityBlock(resident: ResidentData) {
    Row({ space: 10 }) {
      Text(resident.name)
        .fontSize(this.compactWidth ? 20 : 22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.compactWidth) {
        Text(this.statusText(resident.level))
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(resident.level))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.statusBackground(resident.level))
          .borderRadius(5)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private profileMetaStrip(resident: ResidentData) {
    Row({ space: this.compactWidth ? 8 : 12 }) {
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
      this.profileMetaItem('责任护工', this.responsibleCaregiver(resident))
      if (!this.compactWidth) {
        Divider()
          .vertical(true)
          .height(34)
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        this.profileMetaItem('健康状态', this.statusText(resident.level), this.statusColor(resident.level))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private profileMetaItem(label: string, value: string, valueColor?: ResourceColor) {
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
        .fontColor(valueColor ?? $r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private detailTabBar() {
    Row() {
      WideSlidingCapsule({
        items: this.detailTabItems,
        selectedIndex: this.selectedDetailTabIndex(),
        itemWidth: this.compactWidth ? 88 : 104,
        fillWidth: this.compactWidth,
        onSelect: (index: number) => {
          this.selectDetailTab(index);
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private healthOverviewCard(resident: ResidentData) {
    Column({ space: this.compactWidth ? 12 : 14 }) {
      if (this.compactWidth) {
        Column({ space: 10 }) {
          Row() {
            Text('健康概览')
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text(this.measuredAtText(resident))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (resident.allergies.length > 0) {
            this.allergyBadge(resident)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Row() {
          Text('健康概览')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))

          Blank()

          Row({ space: 12 }) {
            if (resident.allergies.length > 0) {
              this.allergyBadge(resident)
            }
            Text(this.measuredAtText(resident))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      Row({ space: this.compactWidth ? 10 : 12 }) {
        this.respiratoryMetric(resident)
        this.heartRateMetric(resident)
        this.fallStatusMetric(resident)
        this.inBedMetric(resident)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(this.compactWidth ? 16 : 24)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private allergyBadge(resident: ResidentData) {
    Row({ space: 5 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
        .fontSize(13)
        .fontColor([$r('app.color.status_danger')])
      Text(`${resident.allergies.join('、')}过敏`)
        .fontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.status_danger'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 9, right: 9, top: 5, bottom: 5 })
    .backgroundColor($r('app.color.status_danger_bg'))
    .borderRadius(12)
  }

  @Builder
  private respiratoryMetric(resident: ResidentData) {
    if (this.residentVitalSign(resident).respiratory > 0) {
      this.overviewVitalCard('呼吸', this.residentVitalSign(resident).respiratory.toString(), '次/分',
        this.metricTrendText(this.residentVitalSign(resident).respiratory,
          this.previousVitalValue(resident, (item: HealthRecord): number => item.respiratory_rate ?? 0), 0, true),
        this.metricTrendColor(this.residentVitalSign(resident).respiratory,
          this.previousVitalValue(resident, (item: HealthRecord): number => item.respiratory_rate ?? 0), 0, true))
    } else {
      this.overviewVitalCard('呼吸', '--', '', '暂无数据', $r('sys.color.font_tertiary'))
    }
  }

  @Builder
  private heartRateMetric(resident: ResidentData) {
    if (this.hasHeartRate(resident)) {
      this.overviewVitalCard('心率', this.residentVitalSign(resident).heartRate.toString(), '次/分',
        this.metricTrendText(this.residentVitalSign(resident).heartRate,
          this.previousVitalValue(resident, (item: HealthRecord): number => item.heart_rate ?? 0), 0, true),
        this.metricTrendColor(this.residentVitalSign(resident).heartRate,
          this.previousVitalValue(resident, (item: HealthRecord): number => item.heart_rate ?? 0), 0, true))
    } else {
      this.overviewVitalCard('心率', '--', '', '暂无数据', $r('sys.color.font_tertiary'))
    }
  }

  /** 跌倒状态：存在未处理的服务器跌倒告警即视为跌倒，其余为正常。 */
  private hasOpenFallAlert(resident: ResidentData): boolean {
    return this.businessStore.alerts.some((item: Alert): boolean =>
      item.elder_id === Number(resident.id) && item.type === 'fall' &&
      item.status !== 'handled' && item.status !== 'closed');
  }

  /** 在床状态：与后端在住统计同口径（登记状态 status=2 视为在床）。 */
  private isInBed(resident: ResidentData): boolean {
    const elder: Elder | undefined = this.businessStore.elders.find(
      (item: Elder): boolean => item.id === Number(resident.id));
    return elder !== undefined && elder.status === 2;
  }

  @Builder
  private fallStatusMetric(resident: ResidentData) {
    if (this.hasOpenFallAlert(resident)) {
      this.overviewVitalCard('跌倒状态', '跌倒', '',
        '有未处理跌倒告警', $r('app.color.status_danger'))
    } else {
      this.overviewVitalCard('跌倒状态', '正常', '',
        this.residentVitalSign(resident).measuredAt === '--' ? '暂无监测数据' : '无跌倒告警',
        $r('app.color.status_normal'))
    }
  }

  @Builder
  private inBedMetric(resident: ResidentData) {
    if (this.isInBed(resident)) {
      this.overviewVitalCard('在床状态', '在床', '', '按在住登记', $r('app.color.status_normal'))
    } else {
      this.overviewVitalCard('在床状态', '离床', '', '未登记在住', $r('app.color.status_warning'))
    }
  }

  @Builder
  private overviewVitalCard(label: string, value: string, unit: string, trend: string,
    trendColor: ResourceColor) {
    Column({ space: this.compactWidth ? 5 : 7 }) {
      Row({ space: 4 }) {
        Text(value)
          .fontSize(this.compactWidth ? 20 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (unit.length > 0) {
          Text(unit)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ bottom: 2 })
        }
      }
      .alignItems(VerticalAlign.Bottom)

      Text(label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))

      Row({ space: 5 }) {
        Row()
          .width(5)
          .height(5)
          .borderRadius(2.5)
          .backgroundColor(trendColor)
        Text(trend)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(trendColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(this.compactWidth ? 88 : 104)
    .padding({ left: this.compactWidth ? 12 : 16, right: this.compactWidth ? 8 : 12 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private overviewContent(resident: ResidentData) {
    if (this.compactWidth) {
      Column({ space: 12 }) {
        this.primaryOverviewGroup(resident)
        this.secondaryOverviewGroup(resident)
      }
      .width('100%')
    } else {
      Row({ space: 16 }) {
        Column() {
          this.primaryOverviewGroup(resident)
        }
        .layoutWeight(3)

        Column() {
          this.secondaryOverviewGroup(resident)
        }
        .layoutWeight(2)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private primaryOverviewGroup(resident: ResidentData) {
    Column({ space: 0 }) {
      this.basicInfoCard(resident)
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 16, right: 16 })
      this.contactCard(resident)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private secondaryOverviewGroup(resident: ResidentData) {
    Column({ space: 0 }) {
      this.riskCard(resident)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
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
  }

  @Builder
  private riskCard(resident: ResidentData) {
    Column({ space: 0 }) {
      this.cardTitle('预警情况', '来自服务器告警记录')
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
      this.openAlertList(resident)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
  }

  /** 该长者的未处理服务器告警（与工作台「重点关注」同一过滤口径）。 */
  private openAlertsOf(resident: ResidentData): Alert[] {
    return this.businessStore.alerts
      .filter((item: Alert): boolean => item.elder_id?.toString() === resident.id &&
        item.status !== 'handled' && item.status !== 'closed')
      .sort((left: Alert, right: Alert): number => right.create_time.localeCompare(left.create_time));
  }

  @Builder
  private openAlertList(resident: ResidentData) {
    Column({ space: 0 }) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ top: 6, bottom: 6 })
      if (this.openAlertsOf(resident).length === 0) {
        Text('当前无未处理预警')
          .width('100%')
          .height(38)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      } else {
        ForEach(this.openAlertsOf(resident), (alert: Alert) => {
          Row({ space: 8 }) {
            Text(alert.level === 'emergency' ? '紧急' : alert.level === 'important' ? '重要' : '一般')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor(alert.level === 'emergency' ? $r('app.color.doctor_workspace_danger') :
                $r('app.color.doctor_workspace_warning'))
            Text(alert.content)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.timeText(alert.create_time))
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .height(38)
          .alignItems(VerticalAlign.Center)
        }, (alert: Alert) => `alert-${alert.id}`)
      }
    }
    .width('100%')
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

      Column({ space: 12 }) {
        this.cardTitle('今日呼吸趋势', '单位 次/分')
        Row({ space: 12 }) {
          Repeat(this.trendRows(resident))
            .each((repeatItem: RepeatItem<VitalTrendRow>) => {
              Column({ space: 7 }) {
                Text(repeatItem.item.respiratory > 0 ? `${repeatItem.item.respiratory}` : '--')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_secondary'))
                Column()
                  .width(18)
                  .height(repeatItem.item.respiratory > 0 ?
                    Math.max(24, 42 + (repeatItem.item.respiratory - 12) * 3) : 24)
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
        this.cardTitle('测量记录', `${this.trendRows(resident).length} 次`)
        Repeat(this.trendRows(resident))
          .each((repeatItem: RepeatItem<VitalTrendRow>) => {
            Row() {
              Text(repeatItem.item.time)
                .width(this.compactWidth ? 72 : 90)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
              Text(`心率 ${repeatItem.item.heartRate} bpm`)
                .layoutWeight(1)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
              Text(repeatItem.item.respiratory > 0 ? `呼吸 ${repeatItem.item.respiratory} 次/分` : '呼吸 --')
                .layoutWeight(1)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
              Text(`血压 ${repeatItem.item.systolic}/${repeatItem.item.diastolic}`)
                .fontSize($r('sys.float.Body_M'))
                .fontColor(repeatItem.item.level === 'normal' ?
                  $r('sys.color.font_primary') : this.statusColor(repeatItem.item.level))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
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

            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.statusColor(repeatItem.item.level))

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
          .constraintSize({ minHeight: 66 })
          .padding({ top: 8, bottom: 8 })
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
  private behaviorContent(resident: ResidentData) {
    Column({ space: 12 }) {
      this.cardTitle('摄像头行为', resident.room)
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(32).fontColor([$r('app.color.brand_blue')])
        Text('摄像头行为识别接入中').fontSize(16).fontWeight(FontWeight.Medium)
        Text('当前仅完成摄像头设备配置与在线状态展示，行为分析适配后将在这里显示事件。').fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      }.width('100%').padding(28).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(10).alignItems(HorizontalAlign.Center)
    }.width('100%')
  }

  private medicationStateText(status: string): string {
    if (status === 'taken') {
      return '已完成';
    }
    if (status === 'missed') {
      return '已错过';
    }
    return '待执行';
  }

  private medicationStateLevel(status: string): StatusLevel {
    if (status === 'taken') {
      return 'normal';
    }
    if (status === 'missed') {
      return 'danger';
    }
    return 'warning';
  }

  @Builder
  private medicationContent(resident: ResidentData) {
    Column({ space: 12 }) {
      Column({ space: 10 }) {
        this.cardTitle('今日用药进度', '按医嘱执行')
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

          Text(this.nextMedicationText(resident))
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.residentMedicationProgress(resident).done ===
              this.residentMedicationProgress(resident).total ?
              $r('app.color.status_normal') : $r('app.color.status_warning'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 4, bottom: 14 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })

      Column({ space: 0 }) {
        this.cardTitle('用药计划', `${this.residentMedications(resident).length} 条医嘱`)
        if (this.residentMedications(resident).length === 0) {
          Column({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.cross_case')).fontSize(30).fontColor([$r('app.color.brand_blue')])
            Text('暂无用药计划').fontSize(15).fontWeight(FontWeight.Medium)
            Text('服务器未下发该长者的用药医嘱，可在管理端「药物」模块维护目录。')
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(24)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .alignItems(HorizontalAlign.Center)
        } else {
          Repeat(this.residentMedications(resident))
            .each((repeatItem: RepeatItem<MedicationRecord>) => {
              Row({ space: 14 }) {
                Text(this.timeText(repeatItem.item.plan_time ?? ''))
                  .width(54)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_tertiary'))

                Row()
                  .width(8)
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor(this.statusColor(this.medicationStateLevel(repeatItem.item.status)))

                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text(repeatItem.item.medicine_name)
                      .fontSize($r('sys.float.Body_M'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(repeatItem.item.dosage)
                      .fontSize($r('sys.float.Caption_M'))
                      .fontColor($r('sys.color.font_secondary'))
                  }
                  Text([repeatItem.item.frequency, repeatItem.item.route]
                    .filter((value: string): boolean => value.length > 0).join(' · '))
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('sys.color.font_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(this.medicationStateText(repeatItem.item.status))
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor(this.statusColor(this.medicationStateLevel(repeatItem.item.status)))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor(this.statusBackground(this.medicationStateLevel(repeatItem.item.status)))
                  .borderRadius(5)
                  .maxLines(1)
              }
              .width('100%')
              .constraintSize({ minHeight: 66 })
              .padding({ top: 8, bottom: 8 })
              .alignItems(VerticalAlign.Center)
              .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
            })
            .key((item: MedicationRecord) => `${item.id}_${item.status}`)
        }
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
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(repeatItem.item.type)
                      .fontSize($r('sys.float.Body_S'))
                      .fontColor($r('sys.color.font_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(repeatItem.item.status)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor(this.statusColor(repeatItem.item.level))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor(this.statusBackground(repeatItem.item.level))
                    .borderRadius(5)
                    .maxLines(1)
                }
                .width('100%')

                Row() {
                  Text(repeatItem.item.battery === undefined ? '电量未上报' :
                    `电量 ${repeatItem.item.battery}%`)
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
              .padding(this.compactWidth ? 14 : 16)
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
      .columnsGap(this.compactWidth ? 12 : 14)
      .rowsGap(this.compactWidth ? 12 : 14)
      .scrollBar(BarState.Off)
      .height(Math.ceil(this.residentDevices(resident).length / 2) * this.deviceCardHeight() +
        Math.max(0, Math.ceil(this.residentDevices(resident).length / 2) - 1) *
          (this.compactWidth ? 12 : 14))
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
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
      .constraintSize({ minHeight: 44 })
      .padding({ top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      }
    }
    .width('100%')
  }
}
