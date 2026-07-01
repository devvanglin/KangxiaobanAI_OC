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

import { HdsListItemCard, SuffixText } from '@kit.UIDesignKit';
import { AppStorageV2 } from '@kit.ArkUI';
import {
  ChipGroup,
  ChipGroupItemOptions,
  ChipGroupSpaceOptions,
  ChipItemStyle,
  ChipSize
} from '@kit.ArkUI';
import { HealthRowData, StatusLevel } from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';

@ComponentV2
export struct HealthExpandPage {
  @Event onClose: () => void = () => {};
  @Local healthTabIndex: number = 0;
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

  private healthTabs(): ChipGroupItemOptions[] {
    return [
      { label: { text: '全部' }, allowClose: false },
      { label: { text: '风险' }, allowClose: false },
      { label: { text: '正常' }, allowClose: false }
    ];
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
          items: this.healthTabs(),
          itemStyle: HealthExpandPage.SEGMENT_STYLE,
          multiple: false,
          selectedIndexes: [this.healthTabIndex],
          chipGroupSpace: HealthExpandPage.SEGMENT_SPACE,
          chipGroupPadding: { top: 4, bottom: 4 },
          onChange: (indexes: number[]) => {
            if (indexes.length > 0) {
              this.healthTabIndex = indexes[0];
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
        Text('健康状态')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
        Text('今日长者健康')
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 20, bottom: 12 })

      Column({ space: 0 }) {
        this.healthExpandList()
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .clip(true)
      .padding({ left: 13, right: 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding(), left: 16, right: 16, bottom: 36 })
    .backgroundColor($r('sys.color.background_secondary'))
    .clip(true)
    .geometryTransition('healthCard')
    .transition(TransitionEffect.OPACITY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private healthExpandList() {
    List({ space: 0 }) {
      Repeat(this.healthRows().filter((item: HealthRowData) => {
        if (this.healthTabIndex === 1) {
          return item.level !== 'normal';
        }
        if (this.healthTabIndex === 2) {
          return item.level === 'normal';
        }
        return true;
      }))
        .each((repeatItem: RepeatItem<HealthRowData>) => {
          ListItem() {
            HdsListItemCard({
              textItem: {
                primaryText: { text: repeatItem.item.name },
                secondaryText: {
                  text: `${repeatItem.item.age}岁 · ${repeatItem.item.room} · ${repeatItem.item.bed} · 情绪${repeatItem.item.mood} · ${repeatItem.item.lastUpdate}`
                }
              },
              suffixItem: new SuffixText({
                text: repeatItem.item.status
              }),
              cardBorderRadius: 0,
              cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
              cardHeight: 68,
              cardPrefixMargin: -5,
              cardSuffixMargin: -14,
              hoverBorderRadius: 0
            })
          }
          .clip(false)
        })
        .key((item: HealthRowData) => item.id)
    }
    .width('100%')
    .height('100%')
    .divider({
      strokeWidth: 0.5,
      color: $r('sys.color.comp_divider'),
      startMargin: 0,
      endMargin: 0
    })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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
}
