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

import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  PrefixCustomBuilder,
  SuffixButton
} from '@kit.UIDesignKit';
import { BreakpointType } from '../util/BreakpointSystem';

export interface HealthListCardData {
  title: string;
  subTitle?: string;
  rows: HealthListCardRow[];
}

export interface HealthListCardRow {
  id: string;
  name: string;
  age: number;
  room: string;
  bed: string;
  iconSymbol: Resource;
  iconBg: ResourceColor;
}

@ComponentV2
export struct HealthListCard {
  @Param @Require cardData: HealthListCardData;
  @Param @Require widthBreakpoint: WidthBreakpoint;
  @Event onItemClick: (id: string) => void = () => {};

  private bottomPadding(): number {
    return new BreakpointType<number>({
      sm: 4,
      md: 8,
      lg: 8
    }).getValue(this.widthBreakpoint);
  }

  @Builder
  private IconBuilder(symbol: Resource, bgColor: ResourceColor) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(symbol)
        .fontSize($r('sys.float.Title_M'))
        .fontColor([$r('sys.color.font_on_primary')])
        .symbolEffect(new SymbolGlyphModifier(symbol))
    }
    .width(40)
    .height(40)
    .backgroundColor(bgColor)
    .borderRadius($r('sys.float.corner_radius_level5'))
  }

  build() {
    Column({ space: 0 }) {
      Column() {
        if (this.cardData.subTitle) {
          Text(this.cardData.subTitle)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .fontWeight(FontWeight.Regular)
            .margin({
              left: $r('sys.float.padding_level8'),
              bottom: $r('sys.float.padding_level2')
            })
            .maxLines(1)
            .ellipsisMode(EllipsisMode.END)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Text(this.cardData.title)
          .fontSize($r('sys.float.Title_M'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
          .margin({
            left: $r('sys.float.padding_level8'),
            bottom: $r('sys.float.padding_level4')
          })
          .maxLines(1)
          .ellipsisMode(EllipsisMode.END)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .height(56)
      .width('100%')

      List({ space: 0 }) {
        Repeat(this.cardData.rows)
          .each((repeatItem: RepeatItem<HealthListCardRow>) => {
            ListItem() {
              HdsListItemCard({
                prefixItem: new PrefixCustomBuilder(() => {
                  this.IconBuilder(repeatItem.item.iconSymbol, repeatItem.item.iconBg);
                }),
                textItem: {
                  primaryText: { text: repeatItem.item.name },
                  secondaryText: {
                    text: `${repeatItem.item.age}岁 · ${repeatItem.item.room} · ${repeatItem.item.bed}`
                  }
                },
                suffixItem: new SuffixButton({
                  text: '查看',
                  textColor: $r('sys.color.interactive_active')
                }),
                cardBorderRadius: 0,
                cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
                cardHeight: 68,
                cardPrefixMargin: $r('sys.float.padding_level0'),
                cardSuffixMargin: $r('sys.float.padding_level2'),
                onClick: () => {
                  this.onItemClick(repeatItem.item.id);
                }
              })
            }
          })
          .key((row: HealthListCardRow) => row.id)
      }
      .divider({
        strokeWidth: '1px',
        color: $r('sys.color.comp_background_tertiary'),
        startMargin: 56,
        endMargin: 16
      })
      .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.PARENT_FIRST })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      .height(this.cardData.rows.length * 68)
    }
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({
      width: 0,
      color: $r('sys.color.comp_background_list_card'),
      radius: $r('sys.float.corner_radius_level8')
    })
    .clickEffect({ level: ClickEffectLevel.MIDDLE })
    .alignItems(HorizontalAlign.Start)
    .clip(true)
    .padding({
      top: $r('sys.float.padding_level8'),
      bottom: this.bottomPadding()
    })
    .width('100%')
  }
}
