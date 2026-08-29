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

import { AppStorageV2 } from '@kit.ArkUI';
import {
  HdsListItemCard,
  HdsNavDestination,
  hdsMaterial,
  ScrollEffectType,
  SuffixText,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import {
  AlertEvent,
  CareTaskItem,
  FootprintRecord,
  MedicationProgress,
  Medication,
  MealRecord,
  MealType,
  MonitorSnapshot,
  MoodRecord,
  ResidentData,
  RoomDeviceData,
  StatusLevel,
  TaskState,
  VitalSign
} from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';
import { BusinessStore } from '../network/BusinessStore';
import { Alert, Assessment, CareTask, DiningOrder, HealthRecord, IotDevice, MedicationRecord } from '../network/Dto';
import {
  RESIDENT_SUMMARY_DETAIL_HEIGHT,
  RESIDENT_SUMMARY_DETAIL_NO_ALLERGY_HEIGHT,
  ResidentSummaryCard
} from '../component/ResidentSummaryCard';

interface VitalTrendRow {
  time: string;
  heartRate: number;
  bp: string;
}

const ALL_RESIDENT_DETAIL_SECTIONS_EXPANDED: number = 0x7FF;
const RESIDENT_DETAIL_EXPANSION_STORE_KEY: string = 'kanxiaoban_resident_detail_expansion_store';

@ObservedV2
class ResidentDetailExpansionStore {
  @Trace expandedMask: number = ALL_RESIDENT_DETAIL_SECTIONS_EXPANDED;
}

@ComponentV2
export struct ResidentDetailPage {
  @Param @Require resident: ResidentData;
  @Param @Require vitalSignData: VitalSign;
  @Param @Require medicationProgress: MedicationProgress;
  @Param @Require geometryId: string;
  @Event onClose: () => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local expansionStore: ResidentDetailExpansionStore =
    AppStorageV2.connect(ResidentDetailExpansionStore, RESIDENT_DETAIL_EXPANSION_STORE_KEY,
      () => new ResidentDetailExpansionStore()) ?? new ResidentDetailExpansionStore();
  @Local businessStore: BusinessStore = BusinessStore.getShared();

  aboutToAppear(): void {
    this.businessStore.load();
  }

  private get expandedMask(): number {
    return this.expansionStore.expandedMask;
  }

  private set expandedMask(value: number) {
    this.expansionStore.expandedMask = value;
  }

  @Styles
  private sectionCardStyle() {
    .width('100%')
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .clip(true)
  }

  @Styles
  private sectionHeaderNormalStyle() {
    .backgroundColor(Color.Transparent)
  }

  @Styles
  private sectionHeaderPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
  }

  private sectionCardBottomPadding(sectionBit: number): number {
    return (this.expandedMask & (1 << sectionBit)) !== 0 ? 12 : 4;
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

  private taskStateText(state: TaskState): string {
    if (state === 'todo') {
      return '待执行';
    }
    if (state === 'doing') {
      return '进行中';
    }
    return '已完成';
  }

  private taskStateLevel(state: TaskState): StatusLevel {
    if (state === 'todo') {
      return 'danger';
    }
    if (state === 'doing') {
      return 'warning';
    }
    return 'normal';
  }

  private genderText(gender: string): string {
    return gender === 'male' ? '男' : '女';
  }

  private titleBarStyle(): TitleBarStyleOptions {
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

  private titleBarContent(): TitleBarContentOptions {
    return {
      title: { mainTitle: this.resident.name },
      menu: {
        value: [{
          content: {
            icon: $r('sys.symbol.xmark'),
            isEnabled: true,
            action: () => {
              this.onClose();
            }
          }
        }]
      }
    };
  }

  build() {
    Column() {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.End }) {
          Scroll() {
            Row() {
              Column({ space: 12 }) {
                Column() {
                  ResidentSummaryCard({
                    resident: this.resident,
                    vitalSign: this.vitalSignData,
                    medicationProgress: this.medicationProgress,
                    mode: 'detail'
                  })
                }
                .width('100%')
                .height(this.resident.allergies.length > 0 ?
                  RESIDENT_SUMMARY_DETAIL_HEIGHT : RESIDENT_SUMMARY_DETAIL_NO_ALLERGY_HEIGHT)
                // 体征趋势
                this.vitalTrendCard()
                // 房间监控
                this.monitorEntryCard()
                // 用药管理
                this.medicationCard()
                // 今日护理任务
                this.careTaskCard()
                // 今日膳食
                this.mealCard()
                // 今日足迹
                this.footprintCard()
                // 情绪记录
                this.moodCard()
                // IoT 设备
                this.deviceCard()
                // 风险评估
                this.riskAssessmentCard()
                // 基础信息
                this.basicInfoCard()
                // 近期报警
                this.alertHistoryCard()
              }
              .width('100%')
              .constraintSize({ maxWidth: 960 })
              .padding({
                left: 16,
                right: 16,
                top: this.globalInfoModel.statusBarHeight + 64,
                bottom: 16 + this.globalInfoModel.naviIndicatorHeight
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
      }
      .backgroundColor($r('sys.color.background_secondary'))
      .ignoreLayoutSafeArea(
        [LayoutSafeAreaType.SYSTEM],
        [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
      )
      .hideBackButton(true)
      .titleBar({
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false,
        style: this.titleBarStyle(),
        content: this.titleBarContent()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }

  // ---------------- 基础信息 ----------------

  @Builder
  private basicInfoCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('基础信息')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 9)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`基础信息，${(this.expandedMask & (1 << 9)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 9);
      })
      if ((this.expandedMask & (1 << 9)) !== 0) {
        Column({ space: 0 }) {
          this.descriptionRow('性别', this.genderText(this.resident.gender), false)
          this.descriptionRow('年龄', this.resident.age > 0 ? `${this.resident.age}岁` : '未登记', false)
          this.descriptionRow('房间床号', `${this.resident.room} ${this.resident.bed}`, false)
          this.descriptionRow('护理等级', this.resident.careLevel, false)
          this.descriptionRow('入院日期', this.resident.admissionDate, true)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(9) })
  }

  @Builder
  private riskAssessmentCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('风险评估')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 8)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`风险评估，${(this.expandedMask & (1 << 8)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 8);
      })
      if ((this.expandedMask & (1 << 8)) !== 0) {
        Column({ space: 0 }) {
          if (this.hasAssessment()) {
            this.descriptionRow('评估类型', this.latestAssessmentType(), false)
            this.riskRow('风险等级', this.latestAssessmentLevel(), false)
            this.descriptionRow('评分', this.latestAssessmentScore(), false)
            this.descriptionRow('评估时间', this.latestAssessmentTime(), false)
            this.descriptionRow('评估说明', this.latestAssessmentNotes(), true)
          } else {
            this.sectionEmptyState('暂无服务器风险评估')
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(8) })
  }

  @Builder
  private riskRow(label: string, level: StatusLevel, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: label }
        },
        suffixItem: new SuffixText({ text: this.statusText(level) }),
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

  @Builder
  private alertHistoryCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('近期报警')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 10)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`近期报警，${(this.expandedMask & (1 << 10)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 10);
      })
      if ((this.expandedMask & (1 << 10)) !== 0) {
        Column({ space: 0 }) {
          Repeat(this.alertEvents())
            .each((repeatItem: RepeatItem<AlertEvent>) => {
              this.alertEventRow(repeatItem.item, repeatItem.index === this.alertEvents().length - 1)
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(10) })
  }

  @Builder
  private alertEventRow(item: AlertEvent, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: `${item.type} · ${item.time}` },
          secondaryText: { text: item.detail }
        },
        suffixItem: new SuffixText({
          text: item.status === 'open' ? '未处理' : (item.handler ?? '已处理')
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 60,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  @Builder
  private vitalTrendCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('体征趋势（近 6 次）')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 0)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`体征趋势，${(this.expandedMask & (1 << 0)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 0);
      })
      if ((this.expandedMask & (1 << 0)) !== 0) {
        Column({ space: 0 }) {
          Repeat(this.vitalTrend())
            .each((repeatItem: RepeatItem<VitalTrendRow>) => {
              this.vitalTrendRow(repeatItem.item, repeatItem.index === this.vitalTrend().length - 1)
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(0) })
  }

  @Builder
  private vitalTrendRow(item: VitalTrendRow, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: item.time },
          secondaryText: { text: `心率 ${item.heartRate} bpm · 血压 ${item.bp}` }
        },
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 52,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  @Builder
  private monitorEntryCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('房间监控')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 1)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`房间监控，${(this.expandedMask & (1 << 1)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 1);
      })
      if ((this.expandedMask & (1 << 1)) !== 0) {
        Column({ space: 0 }) {
          if (this.monitors().length === 0) {
            this.sectionEmptyState('房间监控接口尚未开放')
          } else {
            Repeat(this.monitors())
              .each((repeatItem: RepeatItem<MonitorSnapshot>) => {
                this.monitorRow(repeatItem.item, repeatItem.index === this.monitors().length - 1)
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(1) })
  }

  @Builder
  private monitorRow(item: MonitorSnapshot, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: item.name },
          secondaryText: { text: `${item.room} · ${item.lastEvent}` }
        },
        suffixItem: new SuffixText({
          text: item.status === 'online' ? '在线' : '离线'
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

  // ---------------- IoT 设备 ----------------

  @Builder
  private deviceCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('IoT 设备')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 7)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`IoT 设备，${(this.expandedMask & (1 << 7)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 7);
      })
      if ((this.expandedMask & (1 << 7)) !== 0) {
        Column({ space: 0 }) {
          Repeat(this.residentDevices())
            .each((repeatItem: RepeatItem<RoomDeviceData>) => {
              this.deviceRow(repeatItem.item, repeatItem.index === this.residentDevices().length - 1)
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(7) })
  }

  @Builder
  private deviceRow(item: RoomDeviceData, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: item.name },
          secondaryText: { text: `${item.type} · ${item.room}` }
        },
        suffixItem: new SuffixText({
          text: `${item.status}${item.battery !== undefined ? ' · ' + item.battery + '%' : ''}`
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

  // ---------------- 情绪记录 ----------------

  @Builder
  private moodCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('情绪记录')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 6)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`情绪记录，${(this.expandedMask & (1 << 6)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 6);
      })
      if ((this.expandedMask & (1 << 6)) !== 0) {
        Column({ space: 0 }) {
          if (this.moodRecords().length === 0) {
            this.sectionEmptyState('情绪记录接口尚未开放')
          } else {
            Repeat(this.moodRecords())
              .each((repeatItem: RepeatItem<MoodRecord>) => {
                this.moodRow(repeatItem.item, repeatItem.index === this.moodRecords().length - 1)
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(6) })
  }

  @Builder
  private moodRow(item: MoodRecord, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: `${item.mood} · ${item.time}` },
          secondaryText: { text: item.note }
        },
        suffixItem: new SuffixText({ text: this.statusText(item.level) }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 60,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  // ---------------- 今日足迹 ----------------

  @Builder
  private footprintCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('今日足迹')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 5)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`今日足迹，${(this.expandedMask & (1 << 5)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 5);
      })
      if ((this.expandedMask & (1 << 5)) !== 0) {
        Column({ space: 0 }) {
          if (this.footprints().length === 0) {
            this.sectionEmptyState('活动足迹接口尚未开放')
          } else {
            Repeat(this.footprints())
              .each((repeatItem: RepeatItem<FootprintRecord>) => {
                this.footprintRow(repeatItem.item, repeatItem.index === this.footprints().length - 1)
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(5) })
  }

  @Builder
  private footprintRow(item: FootprintRecord, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: `${item.time} · ${item.location}` },
          secondaryText: { text: `${item.activity} · ${item.duration} 分钟` }
        },
        suffixItem: new SuffixText({ text: this.statusText(item.level) }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 60,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  // ---------------- 用药管理 ----------------

  @Builder
  private medicationCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('用药管理')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 2)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`用药管理，${(this.expandedMask & (1 << 2)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 2);
      })
      if ((this.expandedMask & (1 << 2)) !== 0) {
        Column({ space: 0 }) {
          this.descriptionRow('下次服药', this.nextMedicationTime(), false)
          this.descriptionRow('今日进度', `${this.medicationDoneCount()}/${this.medicationTotalCount()} 次`, false)
          Column({ space: 0 }) {
            Repeat(this.medications())
              .each((repeatItem: RepeatItem<Medication>) => {
                this.medicationRow(repeatItem.item, repeatItem.index === this.medications().length - 1)
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(2) })
  }

  @Builder
  private medicationRow(item: Medication, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: `${item.name} · ${item.dose}` },
          secondaryText: { text: `${item.frequency} · ${item.route} · 下次 ${item.nextTime}` }
        },
        suffixItem: new SuffixText({
          text: `${item.todayDone}/${item.todayTotal}`
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 60,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  @Builder
  private careTaskCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('今日护理任务')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 3)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`今日护理任务，${(this.expandedMask & (1 << 3)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 3);
      })
      if ((this.expandedMask & (1 << 3)) !== 0) {
        Column({ space: 0 }) {
          Repeat(this.careTasks())
            .each((repeatItem: RepeatItem<CareTaskItem>) => {
              this.careTaskRow(repeatItem.item, repeatItem.index === this.careTasks().length - 1)
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(3) })
  }

  @Builder
  private careTaskRow(item: CareTaskItem, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: `${item.time} · ${item.project}` },
          secondaryText: { text: item.note ? `${item.assignee} · ${item.note}` : item.assignee }
        },
        suffixItem: new SuffixText({ text: this.taskStateText(item.state) }),
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
  private mealCard() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          Text('今日膳食')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_tertiary')])
            .rotate({ angle: (this.expandedMask & (1 << 4)) !== 0 ? 180 : 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })
      .backgroundColor(Color.Transparent)
      .borderRadius(12)
      .clip(true)
      .stateStyles({
        normal: this.sectionHeaderNormalStyle,
        pressed: this.sectionHeaderPressedStyle
      })
      .accessibilityText(`今日膳食，${(this.expandedMask & (1 << 4)) !== 0 ? '已展开，点击收起' : '已收起，点击展开'}`)
      .onClick(() => {
        this.expandedMask = this.expandedMask ^ (1 << 4);
      })
      if ((this.expandedMask & (1 << 4)) !== 0) {
        Column({ space: 0 }) {
          if (this.meals().length === 0) {
            this.sectionEmptyState('暂无膳食记录')
          } else {
            Repeat(this.meals())
              .each((repeatItem: RepeatItem<MealRecord>) => {
                this.mealRow(repeatItem.item, repeatItem.index === this.meals().length - 1)
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.FastOutSlowIn }))
      }
    }
    .sectionCardStyle()
    .padding({ left: 4, right: 4, top: 4, bottom: this.sectionCardBottomPadding(4) })
  }

  @Builder
  private mealRow(item: MealRecord, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: item.label },
          secondaryText: { text: item.note ?? '' }
        },
        suffixItem: new SuffixText({ text: this.taskStateText(item.state) }),
        cardBorderRadius: 0,
        cardBackgroundColor: 'rgba(0,0,0,0)',
        cardHeight: 48,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0
      })
      this.divider(isLast)
    }
    .width('100%')
  }

  // ---------------- 公共 Builder ----------------

  @Builder
  private descriptionRow(label: string, value: string, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: label }
        },
        suffixItem: new SuffixText({ text: value }),
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

  @Builder
  private sectionEmptyState(message: string) {
    Text(message)
      .width('100%')
      .padding({ top: 18, bottom: 18 })
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_tertiary'))
      .textAlign(TextAlign.Center)
  }

  @Builder
  private divider(isLast: boolean) {
    if (!isLast) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
    }
  }

  // ---------------- 数据方法 ----------------

  private vitalSign(): VitalSign {
    return this.vitalSignData;
  }

  private vitalTrend(): VitalTrendRow[] {
    return this.businessStore.healthRecords.filter((item: HealthRecord) => item.elder_id === Number(this.resident.id))
      .map((item: HealthRecord): VitalTrendRow => ({ time: item.record_time.slice(0, 16), heartRate: item.heart_rate ?? 0,
        bp: `${item.systolic ?? 0}/${item.diastolic ?? 0}` }));
  }

  private monitors(): MonitorSnapshot[] {
    return [];
  }

  private residentDevices(): RoomDeviceData[] {
    return this.businessStore.devices.filter((item: IotDevice) => item.elder_id === Number(this.resident.id))
      .map((item: IotDevice): RoomDeviceData => ({ id: item.device_id, name: item.product, type: item.protocol,
        room: this.resident.room, status: item.online === 1 ? '在线' : '离线', level: item.online === 1 ? 'normal' : 'danger',
        battery: item.battery, lastUpdate: item.last_seen ? item.last_seen.slice(11, 16) : '--' }));
  }

  private moodRecords(): MoodRecord[] {
    return [];
  }

  private footprints(): FootprintRecord[] {
    return [];
  }

  private medications(): Medication[] {
    return this.businessStore.medications.filter((item: MedicationRecord) => item.elder_id === Number(this.resident.id))
      .map((item: MedicationRecord): Medication => {
        const todayTotal: number = Math.max(0, item.today_total ?? 0);
        const todayDone: number = Math.max(0, item.today_done ?? 0);
        return { id: `${item.id}`, name: item.medicine_name, dose: item.dosage,
          frequency: item.frequency ?? '', route: item.route ?? '',
          nextTime: item.plan_time ? item.plan_time.slice(11, 16) : '--',
          todayTotal: todayTotal, todayDone: todayDone,
          level: todayTotal > 0 && todayDone < todayTotal ? 'warning' : 'normal' };
      });
  }

  private nextMedicationTime(): string {
    const meds: Medication[] = this.medications();
    return meds.length > 0 ? meds[0].nextTime : '无';
  }

  private medicationDoneCount(): number {
    return this.medications().reduce((sum: number, m: Medication) => sum + m.todayDone, 0);
  }

  private medicationTotalCount(): number {
    return this.medications().reduce((sum: number, m: Medication) => sum + m.todayTotal, 0);
  }

  private careTasks(): CareTaskItem[] {
    return this.businessStore.tasks.filter((item: CareTask) => item.elder_id === Number(this.resident.id))
      .map((item: CareTask): CareTaskItem => ({ id: `${item.id}`, time: item.due_at ? item.due_at.slice(11, 16) : '--',
        project: item.title, state: item.status === 'done' ? 'done' : item.status === 'doing' ? 'doing' : 'todo',
        assignee: item.assignee ?? '', note: item.remark ?? '' }));
  }

  private meals(): MealRecord[] {
    return this.businessStore.diningOrders.filter((item: DiningOrder) => item.elder_id === Number(this.resident.id))
      .map((item: DiningOrder): MealRecord => ({
        type: this.mealType(item.meal_time),
        label: `${this.mealLabel(item.meal_time)} · ${item.items}`,
        state: item.status === 'served' || item.status === 'completed' ? 'done' :
          item.status === 'preparing' ? 'doing' : 'todo',
        note: item.status
      }));
  }

  private mealType(value: string): MealType {
    if (value === 'breakfast' || value === 'lunch' || value === 'dinner' || value === 'snack') {
      return value;
    }
    return 'snack';
  }

  private mealLabel(value: string): string {
    if (value === 'breakfast') return '早餐';
    if (value === 'lunch') return '午餐';
    if (value === 'dinner') return '晚餐';
    return '加餐';
  }

  private latestAssessment(): Assessment | undefined {
    return this.businessStore.assessments
      .filter((item: Assessment) => item.elder_id === Number(this.resident.id))
      .sort((left: Assessment, right: Assessment): number =>
        right.assessed_at.localeCompare(left.assessed_at))[0];
  }

  private hasAssessment(): boolean {
    return this.latestAssessment() !== undefined;
  }

  private latestAssessmentType(): string {
    return this.latestAssessment()?.assessment_type ?? '--';
  }

  private latestAssessmentLevel(): StatusLevel {
    const level: string = this.latestAssessment()?.risk_level ?? '';
    if (level === 'high' || level === 'danger') return 'danger';
    if (level === 'medium' || level === 'warning') return 'warning';
    return 'normal';
  }

  private latestAssessmentScore(): string {
    const score: number | undefined = this.latestAssessment()?.score;
    return score === undefined ? '未记录' : `${score} 分`;
  }

  private latestAssessmentTime(): string {
    const value: string = this.latestAssessment()?.assessed_at ?? '';
    return value.length > 0 ? value.slice(0, 16) : '--';
  }

  private latestAssessmentNotes(): string {
    return this.latestAssessment()?.notes || '未记录';
  }

  private alertEvents(): AlertEvent[] {
    return this.businessStore.alerts.filter((item: Alert) => item.elder_id === Number(this.resident.id))
      .map((item: Alert): AlertEvent => ({ time: item.create_time.slice(0, 16), type: item.type,
        level: item.level === 'emergency' ? 'danger' : item.level === 'important' ? 'warning' : 'normal',
        status: item.status === 'new' ? 'open' : 'resolved', handler: item.handled_by, detail: item.content }));
  }
}
