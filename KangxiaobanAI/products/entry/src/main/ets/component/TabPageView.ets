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
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig, TabPageListItem, TabPageSection, TabPageStat } from '../model/TabPageModel';

@ComponentV2
export struct TabPageView {
  @Param @Require currentTabIndex: number;
  @Param @Require pageKey: PageKeyEnum;
  @Param @Require config: TabPageConfig;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

  @Builder
  private sectionHeader(title: ResourceStr, description: ResourceStr) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize($r('sys.float.Subtitle_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(description)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private statCard(stat: TabPageStat) {
    Column({ space: 6 }) {
      Text(stat.label)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text(stat.value)
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(stat.note)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level4'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .layoutWeight(1)
  }

  @Builder
  private listItem(item: TabPageListItem, isLast: boolean = false) {
    Row() {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(item.subtitle)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(item.tag)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_primary'))
        .padding({
          left: $r('sys.float.padding_level3'),
          right: $r('sys.float.padding_level3'),
          top: 4,
          bottom: 4
        })
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius($r('sys.float.corner_radius_level8'))
    }
    .alignItems(VerticalAlign.Center)
    .padding({
      top: $r('sys.float.padding_level4'),
      bottom: $r('sys.float.padding_level4')
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: $r('sys.color.comp_divider')
    })
  }

  @Builder
  private sectionCard(section: TabPageSection) {
    Column({ space: $r('sys.float.padding_level2') }) {
      this.sectionHeader(section.title, section.description)
      Column() {
        Repeat(section.items)
          .each((repeatItem: RepeatItem<TabPageListItem>) => {
            this.listItem(repeatItem.item, repeatItem.index === section.items.length - 1)
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  build() {
    List({
      scroller: PAGE_SCROLLER_MAP.get(this.pageKey)?.[this.currentTabIndex],
      space: 16
    }) {
      ListItem() {
        Column({ space: $r('sys.float.padding_level3') }) {
          Row() {
            Text(this.config.subtitle)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

            SymbolGlyph(this.config.heroSymbol)
              .fontSize($r('sys.float.Title_M'))
              .fontColor([$r('sys.color.icon_primary')])
          }
          .alignItems(VerticalAlign.Top)

          Row() {
            Text(this.config.heroValue)
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text(this.config.heroNote)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .padding($r('sys.float.padding_level4'))
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius($r('sys.float.corner_radius_level16'))
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        top: this.globalInfoModel.statusBarHeight + 96
      })

      ListItem() {
        Row({ space: $r('sys.float.padding_level4') }) {
          Repeat(this.config.stats)
            .each((repeatItem: RepeatItem<TabPageStat>) => {
              this.statCard(repeatItem.item)
            })
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8')
      })

      ListItem() {
        this.sectionCard(this.config.primarySection)
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8')
      })

      ListItem() {
        this.sectionCard(this.config.secondarySection)
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        bottom: 120
      })
    }
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
