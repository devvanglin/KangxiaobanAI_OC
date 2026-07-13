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
  Medication,
  MealRecord,
  MonitorSnapshot,
  MoodRecord,
  ResidentData,
  RoomDeviceData,
  RiskAssessment,
  StatusLevel,
  TaskState,
  VitalSign
} from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';

interface VitalTrendRow {
  time: string;
  heartRate: number;
  bp: string;
}

@ComponentV2
export struct ResidentDetailPage {
  @Param @Require resident: ResidentData;
  @Param @Require geometryId: string;
  @Event onClose: () => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

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
                // 状态概览
                this.statusOverviewCard()
                // 过敏警示（如有）
                if (this.resident.allergies.length > 0) {
                  this.allergyAlertCard()
                }
                // 生命体征网格
                this.vitalSignGrid()
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
              .padding({ left: 16, right: 16, top: 64, bottom: 16 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .backgroundColor($r('sys.color.background_secondary'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .hideBackButton(true)
      .titleBar({
        enableComponentSafeArea: false,
        style: this.titleBarStyle(),
        content: this.titleBarContent()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .padding({ top: this.globalInfoModel.statusBarHeight })
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
  }

  // ---------------- 状态概览（无姓名，标题栏已有） ----------------

  @Builder
  private statusOverviewCard() {
    Column({ space: 12 }) {
      Row() {
        Text(`${this.resident.age}岁 · ${this.genderText(this.resident.gender)} · ${this.resident.room} ${this.resident.bed}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.resident.careLevel)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(6)
          .margin({ right: 6 })

        Text(this.statusText(this.resident.level))
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.statusColor(this.resident.level))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.statusBg(this.resident.level))
          .borderRadius(6)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.resident.status)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.resident.diagnosis.length > 0) {
        Row({ space: 6 }) {
          ForEach(this.resident.diagnosis, (item: string, index: number) => {
            Text(item)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(6)
          }, (item: string, index: number) => index.toString())
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  // ---------------- 基础信息 ----------------

  @Builder
  private basicInfoCard() {
    Column({ space: 0 }) {
      this.sectionTitle('基础信息')
      this.descriptionRow('性别', this.genderText(this.resident.gender), false)
      this.descriptionRow('年龄', `${this.resident.age}岁`, false)
      this.descriptionRow('房间床号', `${this.resident.room} ${this.resident.bed}`, false)
      this.descriptionRow('护理等级', this.resident.careLevel, false)
      this.descriptionRow('入院日期', this.resident.admissionDate, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private emergencyContactCard() {
    Column({ space: 0 }) {
      this.sectionTitle('紧急联系')
      Column({ space: 0 }) {
        HdsListItemCard({
          textItem: {
            primaryText: { text: this.resident.emergencyContact },
            secondaryText: { text: this.resident.emergencyPhone }
          },
          suffixItem: new SuffixText({ text: '第一联系人' }),
          cardBorderRadius: 0,
          cardBackgroundColor: 'rgba(0,0,0,0)',
          cardHeight: 60,
          cardPrefixMargin: 0,
          cardSuffixMargin: 0
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private allergyAlertCard() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
          .fontSize(16)
          .fontColor([$r('app.color.status_danger')])
        Text('过敏警示')
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.status_danger'))
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(this.resident.allergies, (item: string, index: number) => {
          Text(item)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('app.color.status_danger'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.status_danger_bg'))
            .borderRadius(6)
        }, (item: string, index: number) => index.toString())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.alert_danger_bg'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('app.color.alert_danger_border') })
  }

  @Builder
  private riskAssessmentCard() {
    Column({ space: 0 }) {
      this.sectionTitle('风险评估')
      this.riskRow('跌倒风险', this.riskAssessment().fallRisk, false)
      this.riskRow('压疮风险', this.riskAssessment().pressureUlcerRisk, false)
      this.riskRow('走失风险', this.riskAssessment().wanderingRisk, false)
      this.descriptionRow('ADL 评分', `${this.riskAssessment().adlScore} 分`, false)
      this.descriptionRow('认知评分', `${this.riskAssessment().cognitiveScore} 分`, false)
      this.descriptionRow('下次复评', this.riskAssessment().nextReview, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('近期报警')
      Column({ space: 0 }) {
        Repeat(this.alertEvents())
          .each((repeatItem: RepeatItem<AlertEvent>) => {
            this.alertEventRow(repeatItem.item, repeatItem.index === this.alertEvents().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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

  // ---------------- 监测 Tab ----------------

  @Builder
  private vitalSignGrid() {
    Column({ space: 8 }) {
      this.sectionTitle('实时生命体征')
      Grid() {
        GridItem() {
          this.vitalGridItem('心率', `${this.vitalSign().heartRate}`, 'bpm', this.heartRateLevel())
        }
        GridItem() {
          this.vitalGridItem('血压', `${this.vitalSign().systolic}/${this.vitalSign().diastolic}`, 'mmHg', this.bpLevel())
        }
        GridItem() {
          this.vitalGridItem('血氧', `${this.vitalSign().oxygen}`, '%', this.oxygenLevel())
        }
        GridItem() {
          this.vitalGridItem('体温', `${this.vitalSign().temperature}`, '°C', 'normal')
        }
        GridItem() {
          this.vitalGridItem('呼吸', `${this.vitalSign().respiratory}`, '次/分', 'normal')
        }
        GridItem() {
          this.vitalGridItem('步数', `${this.vitalSign().steps}`, '步', 'normal')
        }
        GridItem() {
          this.vitalGridItem('睡眠', `${this.vitalSign().sleepHours}`, '小时', this.sleepLevel())
        }
        GridItem() {
          this.vitalGridItem('更新', this.vitalSign().measuredAt, '', 'normal')
        }
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .height(140)
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  private heartRateLevel(): StatusLevel {
    const hr: number = this.vitalSign().heartRate;
    if (hr > 100 || hr < 60) {
      return 'warning';
    }
    return 'normal';
  }

  private bpLevel(): StatusLevel {
    const s: number = this.vitalSign().systolic;
    if (s >= 140) {
      return 'danger';
    }
    if (s >= 130) {
      return 'warning';
    }
    return 'normal';
  }

  private oxygenLevel(): StatusLevel {
    if (this.vitalSign().oxygen < 95) {
      return 'danger';
    }
    return 'normal';
  }

  private sleepLevel(): StatusLevel {
    if (this.vitalSign().sleepHours < 5) {
      return 'warning';
    }
    return 'normal';
  }

  @Builder
  private vitalGridItem(label: string, value: string, unit: string, level: StatusLevel) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(level === 'normal' ? $r('sys.color.font_primary') : this.statusColor(level))
      if (unit !== '') {
        Text(unit)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(level === 'normal' ? $r('sys.color.comp_background_tertiary') : this.statusBg(level))
    .borderRadius(10)
  }

  @Builder
  private vitalTrendCard() {
    Column({ space: 0 }) {
      this.sectionTitle('体征趋势（近 6 次）')
      Column({ space: 0 }) {
        Repeat(this.vitalTrend())
          .each((repeatItem: RepeatItem<VitalTrendRow>) => {
            this.vitalTrendRow(repeatItem.item, repeatItem.index === this.vitalTrend().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('房间监控')
      Column({ space: 0 }) {
        Repeat(this.monitors())
          .each((repeatItem: RepeatItem<MonitorSnapshot>) => {
            this.monitorRow(repeatItem.item, repeatItem.index === this.monitors().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('IoT 设备')
      Column({ space: 0 }) {
        Repeat(this.residentDevices())
          .each((repeatItem: RepeatItem<RoomDeviceData>) => {
            this.deviceRow(repeatItem.item, repeatItem.index === this.residentDevices().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('情绪记录')
      Column({ space: 0 }) {
        Repeat(this.moodRecords())
          .each((repeatItem: RepeatItem<MoodRecord>) => {
            this.moodRow(repeatItem.item, repeatItem.index === this.moodRecords().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('今日足迹')
      Column({ space: 0 }) {
        Repeat(this.footprints())
          .each((repeatItem: RepeatItem<FootprintRecord>) => {
            this.footprintRow(repeatItem.item, repeatItem.index === this.footprints().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('用药管理')
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
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('今日护理任务')
      Column({ space: 0 }) {
        Repeat(this.careTasks())
          .each((repeatItem: RepeatItem<CareTaskItem>) => {
            this.careTaskRow(repeatItem.item, repeatItem.index === this.careTasks().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
      this.sectionTitle('今日膳食')
      Column({ space: 0 }) {
        Repeat(this.meals())
          .each((repeatItem: RepeatItem<MealRecord>) => {
            this.mealRow(repeatItem.item, repeatItem.index === this.meals().length - 1)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
  private sectionTitle(text: string) {
    Text(text)
      .fontSize($r('sys.float.Body_M'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .height(40)
  }

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
  private divider(isLast: boolean) {
    if (!isLast) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
    }
  }

  // ---------------- 数据方法 ----------------

  private vitalSign(): VitalSign {
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
    return map[this.resident.id] ?? {
      heartRate: 0, systolic: 0, diastolic: 0, oxygen: 0,
      temperature: 0, respiratory: 0, steps: 0, sleepHours: 0,
      measuredAt: '--'
    };
  }

  private vitalTrend(): VitalTrendRow[] {
    return [
      { time: '今天 10:24', heartRate: 72, bp: '138/85' },
      { time: '今天 06:00', heartRate: 68, bp: '132/82' },
      { time: '昨天 22:00', heartRate: 75, bp: '140/88' },
      { time: '昨天 18:00', heartRate: 80, bp: '136/84' },
      { time: '昨天 14:00', heartRate: 76, bp: '130/80' },
      { time: '昨天 10:00', heartRate: 74, bp: '128/78' }
    ];
  }

  private monitors(): MonitorSnapshot[] {
    return [
      { id: 'm1', name: '房间全景', room: this.resident.room, status: 'online', lastEvent: '10:20 人员活动', lastUpdate: '10:24' },
      { id: 'm2', name: '床头特写', room: this.resident.room, status: 'online', lastEvent: '07:30 起夜', lastUpdate: '10:24' }
    ];
  }

  private residentDevices(): RoomDeviceData[] {
    const all: RoomDeviceData[] = [
      { id: 'd1', name: '智能床垫', type: '睡眠体征', room: this.resident.room, status: '数据异常', level: 'warning', battery: 78, lastUpdate: '10:24' },
      { id: 'd2', name: '毫米波雷达', type: '离床跌倒', room: this.resident.room, status: '离线', level: 'danger', battery: 0, lastUpdate: '14:20' },
      { id: 'd3', name: '紧急呼叫器', type: '主动求助', room: this.resident.room, status: '在线', level: 'normal', battery: 45, lastUpdate: '09:50' },
      { id: 'd4', name: '智能床垫', type: '睡眠体征', room: this.resident.room, status: '在线', level: 'normal', battery: 90, lastUpdate: '09:40' },
      { id: 'd5', name: '毫米波雷达', type: '离床跌倒', room: this.resident.room, status: '在线', level: 'normal', battery: 92, lastUpdate: '10:20' },
      { id: 'd6', name: '紧急呼叫器', type: '主动求助', room: this.resident.room, status: '在线', level: 'normal', battery: 45, lastUpdate: '09:50' },
      { id: 'd7', name: '门磁传感器', type: '出入监测', room: this.resident.room, status: '在线', level: 'normal', battery: 88, lastUpdate: '08:30' },
      { id: 'd8', name: '温湿度计', type: '环境监测', room: this.resident.room, status: '在线', level: 'normal', battery: 76, lastUpdate: '10:00' }
    ];
    return all.filter((d: RoomDeviceData) => this.resident.deviceIds.includes(d.id));
  }

  private moodRecords(): MoodRecord[] {
    const base: MoodRecord[] = [
      { time: '10:24', mood: '低落', level: 'danger', note: 'AI 对话语调低沉，活动量下降 41%' },
      { time: '09:30', mood: '平静', level: 'normal', note: '早巡时能够简单应答' },
      { time: '昨天 20:10', mood: '焦虑', level: 'warning', note: '睡前反复询问家属何时来访' },
      { time: '昨天 15:00', mood: '愉快', level: 'normal', note: '参加书法角，主动展示作品' },
      { time: '昨天 10:00', mood: '平静', level: 'normal', note: '早餐后看报，状态稳定' }
    ];
    return base;
  }

  private footprints(): FootprintRecord[] {
    return [
      { time: '10:24', location: '3F-302 房间', activity: '卧床', duration: 180, level: 'warning' },
      { time: '08:30', location: '3F 餐厅', activity: '早餐', duration: 35, level: 'normal' },
      { time: '07:30', location: '3F 卫生间', activity: '洗漱', duration: 15, level: 'normal' },
      { time: '昨天 15:00', location: '2F 活动室', activity: '书法角', duration: 60, level: 'normal' },
      { time: '昨天 14:00', location: '3F 走廊', activity: '散步', duration: 20, level: 'normal' },
      { time: '昨天 12:00', location: '3F 餐厅', activity: '午餐', duration: 40, level: 'normal' }
    ];
  }

  private medications(): Medication[] {
    return [
      { id: 'med1', name: '硝苯地平控释片', dose: '30mg', frequency: '每日 1 次', route: '口服', nextTime: '今日 14:00', todayTotal: 1, todayDone: 0, level: 'warning' },
      { id: 'med2', name: '二甲双胍', dose: '500mg', frequency: '每日 3 次', route: '口服', nextTime: '今日 12:00', todayTotal: 3, todayDone: 2, level: 'normal' },
      { id: 'med3', name: '舍曲林', dose: '50mg', frequency: '每日 1 次', route: '口服', nextTime: '今日 20:00', todayTotal: 1, todayDone: 1, level: 'normal' }
    ];
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
    return [
      { id: 'ct1', time: '14:00', project: '翻身叩背', state: 'todo', assignee: '刘婷', note: '预防压疮' },
      { id: 'ct2', time: '12:00', project: '协助服药', state: 'doing', assignee: '王倩' },
      { id: 'ct3', time: '10:30', project: '情绪关怀', state: 'done', assignee: '刘婷', note: 'AI 预警触达' },
      { id: 'ct4', time: '09:00', project: '早巡', state: 'done', assignee: '王倩' },
      { id: 'ct5', time: '08:00', project: '早餐协助', state: 'done', assignee: '赵晨' }
    ];
  }

  private meals(): MealRecord[] {
    return [
      { type: 'breakfast', label: '早餐 · 糖尿病餐', state: 'done', note: '已用完' },
      { type: 'lunch', label: '午餐 · 低盐软食', state: 'doing', note: '进行中' },
      { type: 'dinner', label: '晚餐 · 糖尿病餐', state: 'todo' },
      { type: 'snack', label: '加餐 · 无糖酸奶', state: 'todo' }
    ];
  }

  private riskAssessment(): RiskAssessment {
    const map: Record<string, RiskAssessment> = {
      'r1': { fallRisk: 'danger', pressureUlcerRisk: 'warning', wanderingRisk: 'normal', adlScore: 65, cognitiveScore: 22, nextReview: '2026-09-15' },
      'r2': { fallRisk: 'warning', pressureUlcerRisk: 'normal', wanderingRisk: 'normal', adlScore: 75, cognitiveScore: 26, nextReview: '2026-09-20' },
      'r3': { fallRisk: 'danger', pressureUlcerRisk: 'warning', wanderingRisk: 'warning', adlScore: 55, cognitiveScore: 20, nextReview: '2026-09-01' },
      'r4': { fallRisk: 'normal', pressureUlcerRisk: 'normal', wanderingRisk: 'normal', adlScore: 85, cognitiveScore: 28, nextReview: '2026-12-01' },
      'r5': { fallRisk: 'normal', pressureUlcerRisk: 'normal', wanderingRisk: 'normal', adlScore: 88, cognitiveScore: 29, nextReview: '2026-12-01' }
    };
    return map[this.resident.id] ?? {
      fallRisk: 'normal', pressureUlcerRisk: 'normal', wanderingRisk: 'normal',
      adlScore: 0, cognitiveScore: 0, nextReview: '--'
    };
  }

  private alertEvents(): AlertEvent[] {
    return [
      { time: '今天 10:24', type: 'AI 情绪预警', level: 'danger', status: 'open', detail: '活动量下降 41%，语调低沉' },
      { time: '昨天 22:30', type: '离床报警', level: 'warning', status: 'resolved', handler: '王倩', detail: '夜间离床 8 分钟，已协助回床' },
      { time: '前天 14:00', type: '呼叫器', level: 'normal', status: 'resolved', handler: '刘婷', detail: '主动呼叫，已处理' }
    ];
  }
}
