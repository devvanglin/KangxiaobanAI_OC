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
  ChipGroup,
  ChipGroupItemOptions,
  ChipGroupSpaceOptions,
  ChipItemStyle,
  ChipSize
} from '@kit.ArkUI';
import {
  HdsListItemCard,
  SuffixText
} from '@kit.UIDesignKit';
import {
  HealthRecord,
  MoodRecord,
  ResidentData,
  RoomDeviceData,
  StatusLevel
} from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';

@ComponentV2
export struct ResidentDetailPage {
  @Param @Require resident: ResidentData;
  @Event onClose: () => void = () => {};
  @Local residentTabIndex: number = 0;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

  private static readonly SEGMENT_STYLE: ChipItemStyle = {
    size: ChipSize.NORMAL,
    backgroundColor: 'rgba(0,0,0,0)',
    fontColor: $r('sys.color.font_secondary'),
    selectedBackgroundColor: $r('sys.color.comp_background_primary'),
    selectedFontColor: $r('sys.color.font_primary')
  };

  private static readonly SEGMENT_SPACE: ChipGroupSpaceOptions = {
    itemSpace: 0,
    startSpace: 0
  };

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 12;
  }

  private residentTabs(): ChipGroupItemOptions[] {
    return [
      { label: { text: '概要' }, allowClose: false },
      { label: { text: '健康' }, allowClose: false },
      { label: { text: '情绪' }, allowClose: false },
      { label: { text: '设备' }, allowClose: false }
    ];
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

  @Builder
  private iconCircleButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([$r('sys.color.font_primary')])
    }
    .width(36)
    .height(36)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .onClick(onClick)
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        ChipGroup({
          items: this.residentTabs(),
          itemStyle: ResidentDetailPage.SEGMENT_STYLE,
          multiple: false,
          selectedIndexes: [this.residentTabIndex],
          chipGroupSpace: ResidentDetailPage.SEGMENT_SPACE,
          chipGroupPadding: { top: 4, bottom: 4 },
          onChange: (indexes: number[]) => {
            if (indexes.length > 0) {
              this.residentTabIndex = indexes[0];
            }
          }
        })

        this.iconCircleButton($r('sys.symbol.xmark'), () => {
          this.onClose();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor($r('sys.color.comp_background_primary'))

      Column({ space: 4 }) {
        Text('长者档案')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
        Text(this.resident.name)
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 20, bottom: 12 })

      this.residentDetailContent()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding() })
    .backgroundColor($r('sys.color.background_secondary'))
    .clip(true)
    .geometryTransition(this.resident.id)
    .transition(TransitionEffect.OPACITY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private residentDetailContent() {
    Scroll() {
      Column({ space: 0 }) {
        if (this.residentTabIndex === 0) {
          this.residentBasicInfo()
        } else if (this.residentTabIndex === 1) {
          this.residentHealthTimeline()
        } else if (this.residentTabIndex === 2) {
          this.residentMoodList()
        } else {
          this.residentDeviceTable(this.residentDevices())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private residentBasicInfo() {
    Column({ space: 0 }) {
      Text('基础信息')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .height(40)
      this.descriptionRow('紧急联系人', this.resident.emergencyContact, false)
      this.descriptionRow('联系电话', this.resident.emergencyPhone, false)
      this.descriptionRow('入院日期', this.resident.admissionDate, true)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
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
    Column({ space: 0 }) {
      HdsListItemCard({
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
      this.divider(isLast)
    }
    .width('100%')
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
    Column({ space: 0 }) {
      HdsListItemCard({
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
      this.divider(isLast)
    }
    .width('100%')
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
    Column({ space: 0 }) {
      HdsListItemCard({
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
        cardHeight: 52,
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

  private residentHealthRecords(): HealthRecord[] {
    const records: HealthRecord[] = [
      { time: '2025-06-30 08:30', type: '早巡', operator: '刘婷', content: '血压 138/85，心率 72，精神状态平稳' },
      { time: '2025-06-29 20:15', type: '夜间巡房', operator: '王倩', content: '起夜 2 次，入睡潜伏期 35 分钟' },
      { time: '2025-06-29 14:00', type: '用药', operator: '系统', content: '降压药已按时服用，无异常反应' },
      { time: '2025-06-28 09:10', type: '医生查房', operator: '张医生', content: '调整降糖方案，建议增加午后血糖监测' }
    ];
    return records;
  }

  private residentMoodRecords(): MoodRecord[] {
    const records: MoodRecord[] = [
      { time: '10:24', mood: '低落', level: 'danger', note: 'AI 对话语调低沉，活动量下降 41%' },
      { time: '09:30', mood: '平静', level: 'normal', note: '早巡时能够简单应答' },
      { time: '昨天 20:10', mood: '焦虑', level: 'warning', note: '睡前反复询问家属何时来访' },
      { time: '昨天 15:00', mood: '愉快', level: 'normal', note: '参加书法角，主动展示作品' }
    ];
    return records;
  }

  private residentDevices(): RoomDeviceData[] {
    const devices: RoomDeviceData[] = [
      { id: 'd1', name: '智能床垫', type: '睡眠体征', room: this.resident.room, status: '数据异常', level: 'warning', battery: 78, lastUpdate: '10:24' },
      { id: 'd5', name: '毫米波雷达', type: '离床跌倒', room: this.resident.room, status: '在线', level: 'normal', battery: 92, lastUpdate: '10:20' },
      { id: 'd6', name: '紧急呼叫器', type: '主动求助', room: this.resident.room, status: '在线', level: 'normal', battery: 45, lastUpdate: '09:50' }
    ];
    return devices.filter((d: RoomDeviceData) => this.resident.deviceIds.includes(d.id));
  }
}
