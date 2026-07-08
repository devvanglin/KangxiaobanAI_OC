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

export class TabsBarModel {
  private static pageTabBarStyleMap: Map<PageKeyEnum, BottomTabBarStyle[]> = new Map();

  public static getTabBarByPage(pageKey: PageKeyEnum): BottomTabBarStyle[] {
    const tabBarStyleList: BottomTabBarStyle[] = [];
    if (!TabsBarModel.pageTabBarStyleMap.has(pageKey)) {
      const tabBarList = PAGE_BAR_MAP.get(pageKey);
      if (tabBarList) {
        tabBarList.forEach((item: BarItem) => {
          const tabBarStyle = new BottomTabBarStyle({
            normal: new SymbolGlyphModifier(item.normalSymbolResource)
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
              .fontColor([item.normalColor]),
            selected: new SymbolGlyphModifier(item.selectedSymbolResource)
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
              .fontColor([item.selectedColor])
          }, item.label)
            .labelStyle({
              unselectedColor: item.normalColor,
              selectedColor: item.selectedColor,
            });
          tabBarStyleList.push(tabBarStyle);
        });
      }
      TabsBarModel.pageTabBarStyleMap.set(pageKey, tabBarStyleList);
    }
    return TabsBarModel.pageTabBarStyleMap.get(pageKey) ?? [];
  }
}

export enum PageKeyEnum {
  ADAPTIVE_TAB = 'AdaptiveTabView',
}

const PAGE_BAR_MAP: Map<PageKeyEnum, BarItem[]> = new Map([
  [PageKeyEnum.ADAPTIVE_TAB, [
    {
      label: '',
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.house_fill'),
      selectedColor: $r('app.color.brand_blue'),
      selectedSymbolResource: $r('sys.symbol.house_fill'),
    } as BarItem,
    {
      label: '',
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.person_2_fill'),
      selectedColor: $r('app.color.brand_blue'),
      selectedSymbolResource: $r('sys.symbol.person_2_fill'),
    },
    {
      label: '',
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.square_and_pencil_fill'),
      selectedColor: $r('app.color.brand_blue'),
      selectedSymbolResource: $r('sys.symbol.square_and_pencil_fill'),
    },
    {
      label: '',
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
      selectedColor: $r('app.color.brand_blue'),
      selectedSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
    },
  ]],
]);

export const PAGE_SCROLLER_MAP: Map<PageKeyEnum, Scroller[]> = new Map([
  [PageKeyEnum.ADAPTIVE_TAB, new Array(4).fill(null).map(() => new Scroller())],
]);

interface BarItem {
  normalSymbolResource: Resource,
  selectedSymbolResource: Resource,
  label: ResourceStr,
  normalColor: ResourceColor;
  selectedColor: ResourceColor;
}
