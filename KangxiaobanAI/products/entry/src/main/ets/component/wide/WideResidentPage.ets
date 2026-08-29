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
import { Alert, Bed, CareTask, Elder, HealthRecord, IotDevice, MedicationRecord, Room } from '../../network/Dto';

type ResidentFilter = 'all' | 'warning' | 'danger';
type ResidentDetailTab = 'overview' | 'vitals' | 'care' | 'devices';

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
  private residentFilterItems: WideSlidingCapsuleItem[] = [
    { title: '全部 5', index: 0 },
    { title: '关注 2', index: 1 },
    { title: '危险 1', index: 2 }
  ];
  private detailTabItems: WideSlidingCapsuleItem[] = [
    { title: '概览', index: 0 },
    { title: '体征趋势', index: 1 },
    { title: '护理记录', index: 2 },
    { title: '设备', index: 3 }
  ];
  @Local selectedResidentId: string = 'r1';
  @Local selectedTab: ResidentDetailTab = 'overview';
  @Local hoveredResidentId: string = '';
  @Local compactDetailVisible: boolean = false;

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

    this.selectedResidentId = requestedResident.id;
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
      const abnormal: boolean = this.businessStore.healthRecords.some((item: HealthRecord) =>
        item.elder_id === elder.id && item.is_abnormal);
      const hasOpenAlert: boolean = this.businessStore.alerts.some((item) =>
        item.elder_id === elder.id && item.status !== 'handled' && item.status !== 'closed');
      const level: StatusLevel = hasOpenAlert ? 'danger' : abnormal ? 'warning' : 'normal';
      const location: string = room ? `${room.floor}F-${room.room_no}` : '未分配房间';
      return {
        id: `${elder.id}`,
        name: elder.name,
        age: this.ageFromBirthDate(elder.birth_date),
        gender: elder.gender === 'F' ? 'female' : 'male',
        room: location,
        bed: bed ? `${bed.bed_no}床` : '未分配床位',
        level: level,
        status: hasOpenAlert ? '存在待处理告警' : abnormal ? '体征需要关注' : '状态稳定',
        emergencyContact: contactName,
        emergencyPhone: contactPhone,
        admissionDate: elder.created_at ?? '',
        careLevel: `${elder.care_level}级护理`,
        diagnosis: elder.remark ? elder.remark.split('；') : [],
        allergies: [],
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
        temperature: 0, respiratory: 0, steps: 0, sleepHours: 0, measuredAt: '--'
      };
    }
    const latest: HealthRecord = records[0];
    return {
      heartRate: latest.heart_rate ?? 0,
      systolic: latest.systolic ?? 0,
      diastolic: latest.diastolic ?? 0,
      oxygen: latest.spo2 ?? 0,
      temperature: latest.temperature ?? 0,
      respiratory: 0,
      steps: 0,
      sleepHours: 0,
      measuredAt: this.timeText(latest.record_time)
    };
  }

  private residentMedicationProgress(resident: ResidentData): MedicationProgress {
    const elderId: number = Number(resident.id);
    const records: MedicationRecord[] = this.businessStore.medications
      .filter((item: MedicationRecord) => item.elder_id === elderId);
    return {
      done: records.filter((item: MedicationRecord) => item.status === 'taken').length,
      total: records.length
    };
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
    return 0;
  }

  private selectDetailTab(index: number): void {
    if (index === 1) {
      this.selectedTab = 'vitals';
    } else if (index === 2) {
      this.selectedTab = 'care';
    } else if (index === 3) {
      this.selectedTab = 'devices';
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
    return this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === Number(resident.id))
      .sort((left: HealthRecord, right: HealthRecord): number => left.record_time.localeCompare(right.record_time))
      .map((item: HealthRecord): VitalTrendRow => {
        return { time: this.timeText(item.record_time), heartRate: item.heart_rate ?? 0,
          systolic: item.systolic ?? 0, diastolic: item.diastolic ?? 0 };
      });
  }

  private careRecords(resident: ResidentData): CareRecordRow[] {
    return this.businessStore.tasks
      .filter((item: CareTask) => item.elder_id === Number(resident.id))
      .map((item: CareTask): CareRecordRow => {
        return { time: item.due_at ? this.timeText(item.due_at) : '--', project: item.title,
          operator: item.assignee ?? '', result: item.remark ?? item.status,
          level: item.status === 'done' ? 'normal' : 'warning' };
      });
  }

  private riskRows(resident: ResidentData): RiskRow[] {
    const alerts: Alert[] = this.businessStore.alerts.filter((item: Alert) =>
      item.elder_id === Number(resident.id));
    if (alerts.length === 0) {
      return [{ label: '综合风险', value: '暂无未处理风险', level: 'normal' }];
    }
    return alerts.map((item: Alert): RiskRow => {
      const level: StatusLevel = item.level === 'emergency' ? 'danger' : item.level === 'important' ? 'warning' : 'normal';
      return { label: item.type, value: item.content, level: level };
    });
  }

  private residentDevices(resident: ResidentData): RoomDeviceData[] {
    return this.businessStore.devices
      .filter((item: IotDevice) => item.elder_id === Number(resident.id))
      .map((item: IotDevice): RoomDeviceData => {
        return { id: item.device_id, name: item.product, type: item.protocol, room: resident.room,
          status: item.online === 1 ? '在线' : '离线', level: item.online === 1 ? 'normal' : 'danger',
          battery: 0, lastUpdate: item.last_seen ? this.timeText(item.last_seen) : '--' };
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
      .padding({ left: 16, right: 16, bottom: 16 })
      .backgroundColor($r('sys.color.background_secondary'))
      .justifyContent(FlexAlign.Center)
    } else {
      Row({ space: 20 }) {
        this.masterPane()
        this.detailPane()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
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
      items: this.residentFilterItems,
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
      if (this.compactWidth) {
        this.showCompactDetail();
      } else {
        this.resetDetailScrollPosition();
        this.onDetailScrollerActive();
      }
    })
  }

  @Builder
  private detailPane() {
    if (this.selectedResidentId === 'r2') {
      this.residentDetailPane(this.allResidents()[1])
    } else if (this.selectedResidentId === 'r3') {
      this.residentDetailPane(this.allResidents()[2])
    } else if (this.selectedResidentId === 'r4') {
      this.residentDetailPane(this.allResidents()[3])
    } else if (this.selectedResidentId === 'r5') {
      this.residentDetailPane(this.allResidents()[4])
    } else {
      this.residentDetailPane(this.allResidents()[0])
    }
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
          .width('42%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 16 })
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
    Row({ space: this.compactWidth ? 14 : 18 }) {
      Text(resident.avatarText ?? resident.name.slice(0, 1))
        .fontSize(this.compactWidth ? $r('sys.float.Title_M') : $r('sys.float.Title_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_blue'))
        .width(this.compactWidth ? 52 : 56)
        .height(this.compactWidth ? 52 : 56)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(29,99,237,0.10)')
        .borderRadius(this.compactWidth ? 26 : 28)

      Column({ space: 7 }) {
        Row({ space: 10 }) {
          Text(resident.name)
            .fontSize(this.compactWidth ? 20 : 22)
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
          .maxLines(this.compactWidth ? 2 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
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
      this.profileMetaItem('责任护工', '刘婷')
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
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
            Text(`${this.residentVitalSign(resident).measuredAt} 更新`)
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
            Text(`${this.residentVitalSign(resident).measuredAt} 更新`)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      Column({ space: 0 }) {
        if (this.compactWidth) {
          Row({ space: 0 }) {
            this.bloodPressureMetric(resident)
            Divider()
              .vertical(true)
              .height(54)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.heartRateMetric(resident)
          }
          .width('100%')
          .height(84)
          .alignItems(VerticalAlign.Center)

          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))

          Row({ space: 0 }) {
            this.oxygenMetric(resident)
            Divider()
              .vertical(true)
              .height(54)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.medicationMetric(resident)
          }
          .width('100%')
          .height(84)
          .alignItems(VerticalAlign.Center)
        } else {
          Row({ space: 0 }) {
            this.bloodPressureMetric(resident)
            Divider()
              .vertical(true)
              .height(52)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.heartRateMetric(resident)
            Divider()
              .vertical(true)
              .height(52)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.oxygenMetric(resident)
            Divider()
              .vertical(true)
              .height(52)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.medicationMetric(resident)
          }
          .width('100%')
          .height(82)
          .alignItems(VerticalAlign.Center)
        }

        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))

        if (this.compactWidth) {
          Row({ space: 0 }) {
            this.secondaryVitalMetric('体温', `${this.residentVitalSign(resident).temperature}`, '℃')
            Divider()
              .vertical(true)
              .height(32)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.secondaryVitalMetric('呼吸', `${this.residentVitalSign(resident).respiratory}`, '次/分')
          }
          .width('100%')
          .height(54)
          .alignItems(VerticalAlign.Center)

          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))

          Row({ space: 0 }) {
            this.secondaryVitalMetric('今日步数', `${this.residentVitalSign(resident).steps}`, '步')
            Divider()
              .vertical(true)
              .height(32)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.secondaryVitalMetric('昨夜睡眠', `${this.residentVitalSign(resident).sleepHours}`, '小时')
          }
          .width('100%')
          .height(54)
          .alignItems(VerticalAlign.Center)
        } else {
          Row({ space: 0 }) {
            this.secondaryVitalMetric('体温', `${this.residentVitalSign(resident).temperature}`, '℃')
            Divider()
              .vertical(true)
              .height(32)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.secondaryVitalMetric('呼吸', `${this.residentVitalSign(resident).respiratory}`, '次/分')
            Divider()
              .vertical(true)
              .height(32)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.secondaryVitalMetric('今日步数', `${this.residentVitalSign(resident).steps}`, '步')
            Divider()
              .vertical(true)
              .height(32)
              .strokeWidth(0.5)
              .color($r('sys.color.comp_divider'))
            this.secondaryVitalMetric('昨夜睡眠', `${this.residentVitalSign(resident).sleepHours}`, '小时')
          }
          .width('100%')
          .height(56)
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
    .padding(this.compactWidth ? 16 : 20)
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
  private bloodPressureMetric(resident: ResidentData) {
    this.primaryVitalMetric(
      '血压',
      `${this.residentVitalSign(resident).systolic}/${this.residentVitalSign(resident).diastolic}`,
      'mmHg',
      this.metricStateText(this.bloodPressureLevel(this.residentVitalSign(resident)), '偏高'),
      this.bloodPressureLevel(this.residentVitalSign(resident))
    )
  }

  @Builder
  private heartRateMetric(resident: ResidentData) {
    this.primaryVitalMetric(
      '心率',
      `${this.residentVitalSign(resident).heartRate}`,
      'bpm',
      this.metricStateText(this.heartRateLevel(this.residentVitalSign(resident)), '需关注'),
      this.heartRateLevel(this.residentVitalSign(resident))
    )
  }

  @Builder
  private oxygenMetric(resident: ResidentData) {
    this.primaryVitalMetric(
      '血氧',
      `${this.residentVitalSign(resident).oxygen}`,
      '%',
      this.metricStateText(this.oxygenLevel(this.residentVitalSign(resident)), '需关注'),
      this.oxygenLevel(this.residentVitalSign(resident))
    )
  }

  @Builder
  private medicationMetric(resident: ResidentData) {
    this.primaryVitalMetric(
      '今日用药',
      `${this.residentMedicationProgress(resident).done}/${this.residentMedicationProgress(resident).total}`,
      '次',
      this.residentMedicationProgress(resident).done >= this.residentMedicationProgress(resident).total ?
        '已完成' :
        `待完成 ${this.residentMedicationProgress(resident).total -
          this.residentMedicationProgress(resident).done} 次`,
      this.medicationLevel(this.residentMedicationProgress(resident))
    )
  }

  @Builder
  private primaryVitalMetric(
    label: string,
    value: string,
    unit: string,
    state: string,
    level: StatusLevel
  ) {
    Column({ space: 5 }) {
      Text(label)
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 4 }) {
        Text(value)
          .fontSize(this.compactWidth ? 20 : 22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(unit)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Bottom)

      Row({ space: 6 }) {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.statusColor(level))
        Text(state)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.statusColor(level))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height('100%')
    .padding({ left: this.compactWidth ? 8 : 14, right: this.compactWidth ? 8 : 14 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private secondaryVitalMetric(label: string, value: string, unit: string) {
    Column({ space: 5 }) {
      Text(label)
        .width('100%')
        .textAlign(TextAlign.Center)
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
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .height('100%')
    .padding({ left: this.compactWidth ? 6 : 10, right: this.compactWidth ? 6 : 10 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
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
      this.carePlanCard(resident)
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 16, right: 16 })
      this.basicInfoCard(resident)
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
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 16, right: 16 })
      this.medicationCard(resident)
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

      Column({ space: 0 }) {
        this.cardTitle('测量记录', '最近 6 次')
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
              Text(`血压 ${repeatItem.item.systolic}/${repeatItem.item.diastolic}`)
                .fontSize($r('sys.float.Body_M'))
                .fontColor(repeatItem.item.systolic >= 140 ?
                  $r('app.color.status_danger') : $r('sys.color.font_primary'))
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
