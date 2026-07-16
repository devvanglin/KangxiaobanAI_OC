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

import {
  MedicationProgress,
  ResidentData,
  StatusLevel,
  VitalSign
} from '../model/DetailTypes';

export type ResidentSummaryMode = 'compact' | 'detail';

export interface ResidentSummaryCardOptions {
  resident: ResidentData;
  vitalSign: VitalSign;
  medicationProgress: MedicationProgress;
  mode: ResidentSummaryMode;
}

export const RESIDENT_SUMMARY_CARD_HEIGHT: number = 148;
export const RESIDENT_SUMMARY_DETAIL_HEIGHT: number = 256;
export const RESIDENT_SUMMARY_DETAIL_NO_ALLERGY_HEIGHT: number = 212;

function isDetailMode(options: ResidentSummaryCardOptions): boolean {
  return options.mode === 'detail';
}

function summaryCardHeight(options: ResidentSummaryCardOptions): number {
  if (!isDetailMode(options)) {
    return RESIDENT_SUMMARY_CARD_HEIGHT;
  }
  return options.resident.allergies.length > 0 ?
    RESIDENT_SUMMARY_DETAIL_HEIGHT : RESIDENT_SUMMARY_DETAIL_NO_ALLERGY_HEIGHT;
}

function genderText(resident: ResidentData): string {
  return resident.gender === 'male' ? '男' : '女';
}

function statusText(level: StatusLevel): string {
  if (level === 'danger') {
    return '危险';
  }
  if (level === 'warning') {
    return '关注';
  }
  return '稳定';
}

function statusColor(level: StatusLevel): ResourceColor {
  if (level === 'danger') {
    return $r('app.color.status_danger');
  }
  if (level === 'warning') {
    return $r('app.color.status_warning');
  }
  return $r('app.color.status_normal');
}

function statusBackground(level: StatusLevel): ResourceColor {
  if (level === 'danger') {
    return $r('app.color.status_danger_bg');
  }
  if (level === 'warning') {
    return $r('app.color.status_warning_bg');
  }
  return $r('app.color.status_normal_bg');
}

function heartRateLevel(vitalSign: VitalSign): StatusLevel {
  if (vitalSign.heartRate > 100 || vitalSign.heartRate < 60) {
    return 'warning';
  }
  return 'normal';
}

function bloodPressureLevel(vitalSign: VitalSign): StatusLevel {
  if (vitalSign.systolic >= 140) {
    return 'danger';
  }
  if (vitalSign.systolic >= 130) {
    return 'warning';
  }
  return 'normal';
}

function oxygenLevel(vitalSign: VitalSign): StatusLevel {
  return vitalSign.oxygen < 95 ? 'danger' : 'normal';
}

function sleepLevel(vitalSign: VitalSign): StatusLevel {
  return vitalSign.sleepHours < 5 ? 'warning' : 'normal';
}

function diagnosisText(resident: ResidentData): string {
  const visibleText: string = resident.diagnosis.slice(0, 2).join('·');
  const remainingCount: number = resident.diagnosis.length - 2;
  return remainingCount > 0 ? `${visibleText} +${remainingCount}` : visibleText;
}

@Builder
function residentIdentityRow(options: ResidentSummaryCardOptions) {
  Row() {
    if (!isDetailMode(options)) {
      Text(options.resident.name)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }

    Text(`${options.resident.age}岁·${genderText(options.resident)}`)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_secondary'))
      .margin({ left: isDetailMode(options) ? 0 : 8 })

    Text(`${options.resident.room} ${options.resident.bed}`)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_secondary'))
      .margin({ left: 8 })
      .layoutWeight(1)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })

    Text(statusText(options.resident.level))
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(statusColor(options.resident.level))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(statusBackground(options.resident.level))
      .borderRadius(6)
      .margin({ right: 6 })

    Text(options.vitalSign.measuredAt)
      .fontSize($r('sys.float.Caption_M'))
      .fontColor($r('sys.color.font_tertiary'))
  }
  .width('100%')
  .alignItems(VerticalAlign.Center)
}

@Builder
function residentConditionRow(options: ResidentSummaryCardOptions) {
  Row({ space: 8 }) {
    Text(options.resident.status)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)

    if (options.resident.diagnosis.length > 0) {
      Text(diagnosisText(options.resident))
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }
  .width('100%')
  .alignItems(VerticalAlign.Center)
}

@Builder
function residentMetricItem(label: string, value: string, unit: string, level: StatusLevel, compact: boolean) {
  Column({ space: 3 }) {
    Row({ space: 2 }) {
      Text(value)
        .fontSize(compact ? $r('sys.float.Subtitle_L') : $r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor(level === 'normal' ? $r('sys.color.font_primary') : statusColor(level))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
  .height('100%')
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
}

@Builder
function residentPrimaryMetrics(options: ResidentSummaryCardOptions) {
  Row() {
    residentMetricItem('心率', `${options.vitalSign.heartRate}`, 'bpm', heartRateLevel(options.vitalSign), true)
    residentMetricItem('血压', `${options.vitalSign.systolic}/${options.vitalSign.diastolic}`, '',
      bloodPressureLevel(options.vitalSign), true)
    residentMetricItem('步数', `${options.vitalSign.steps}`, '步', 'normal', true)
    residentMetricItem('用药', `${options.medicationProgress.done}/${options.medicationProgress.total}`, '次',
      'normal', true)
  }
  .width('100%')
  .height(50)
}

@Builder
function residentAllergyNotice(options: ResidentSummaryCardOptions) {
  Row({ space: 7 }) {
    SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
      .fontSize(15)
      .fontColor([$r('app.color.status_danger')])
    Text(`${options.resident.allergies.join('、')}过敏`)
      .fontSize($r('sys.float.Body_S'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.status_danger'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)
  }
  .width('100%')
  .padding({ left: 10, right: 10, top: 7, bottom: 7 })
  .backgroundColor($r('app.color.alert_danger_bg'))
  .borderRadius(10)
}

@Builder
function residentSecondaryMetrics(options: ResidentSummaryCardOptions) {
  Row() {
    residentMetricItem('血氧', `${options.vitalSign.oxygen}`, '%', oxygenLevel(options.vitalSign), false)
    residentMetricItem('体温', `${options.vitalSign.temperature}`, '℃', 'normal', false)
    residentMetricItem('呼吸', `${options.vitalSign.respiratory}`, '次/分', 'normal', false)
    residentMetricItem('睡眠', `${options.vitalSign.sleepHours}`, '小时', sleepLevel(options.vitalSign), false)
  }
  .width('100%')
  .height(48)
}

@Builder
export function ResidentSummaryCard(options: ResidentSummaryCardOptions) {
  Column({ space: 8 }) {
    Column({ space: 12 }) {
      residentIdentityRow(options)
      residentConditionRow(options)
      residentPrimaryMetrics(options)
    }
    .width('100%')

    if (isDetailMode(options)) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      if (options.resident.allergies.length > 0) {
        residentAllergyNotice(options)
      }

      residentSecondaryMetrics(options)
    }
  }
  .width('100%')
  .height(summaryCardHeight(options))
  .padding({ left: 14, right: 14, top: 14, bottom: 14 })
  .backgroundColor($r('sys.color.comp_background_primary'))
  .borderRadius(16)
  .border({ width: 0.5, color: $r('sys.color.comp_divider') })
}
