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
    const tabBarStyleList: BottomTabBarStyle[] = []
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
        })
      }
      TabsBarModel.pageTabBarStyleMap.set(pageKey, tabBarStyleList);
    }
    return TabsBarModel.pageTabBarStyleMap.get(pageKey) ?? [];
  }
}

export enum PageKeyEnum {
  ADAPTIVE_TAB = 'AdaptiveTabView',
  IMMERSIVE_LIGHT = 'ImmersiveLightView',
  SMART_REACH = 'SmartReachView',
}

const PAGE_BAR_MAP: Map<PageKeyEnum, BarItem[]> = new Map([
  [PageKeyEnum.IMMERSIVE_LIGHT, [
    {
      label: $r('app.string.tab_explore'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.house_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.house_fill'),
    } as BarItem,
    {
      label: $r('app.string.tab_app'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.bag_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.bag_fill'),
    },
    {
      label: $r('app.string.tab_service'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.meta_service'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.meta_service'),
    },
    {
      label: $r('app.string.tab_game'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.game_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.game_fill'),
    },
    {
      label: $r('app.string.tab_mine'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
    },
  ]],
  [PageKeyEnum.ADAPTIVE_TAB, [
    {
      label: $r('app.string.tab_home'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.house_fill'),
      selectedColor: '#FF1949',
      selectedSymbolResource: $r('sys.symbol.house_fill'),
    },
    {
      label: $r('app.string.tab_music'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.music_square_stack_fill'),
      selectedColor: '#FF1949',
      selectedSymbolResource: $r('sys.symbol.music_square_stack_fill'),
    },
    {
      label: $r('app.string.tab_cafe'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.meta_service'),
      selectedColor: '#FF1949',
      selectedSymbolResource: $r('sys.symbol.meta_service'),
    },
    {
      label: $r('app.string.tab_mine'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
      selectedColor: '#FF1949',
      selectedSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
    },
  ]],
  [PageKeyEnum.SMART_REACH, [
    {
      label: $r('app.string.tab_home'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.house_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.house_fill'),
    },
    {
      label: $r('app.string.tab_video'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.play_hexagon_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.play_hexagon_fill'),
    },
    {
      label: $r('app.string.tab_shopping'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.bag_fill_1'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.bag_fill_1'),
    },
    {
      label: $r('app.string.tab_mine'),
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
      selectedColor: $r('sys.color.icon_emphasize'),
      selectedSymbolResource: $r('sys.symbol.person_crop_circle_fill'),
    },
  ]],
]);

export const PAGE_SCROLLER_MAP: Map<PageKeyEnum, Scroller[]> = new Map([
  [PageKeyEnum.IMMERSIVE_LIGHT, new Array(5).fill(null).map(() => new Scroller())],
  [PageKeyEnum.ADAPTIVE_TAB, new Array(4).fill(null).map(() => new Scroller())],
  [PageKeyEnum.SMART_REACH, new Array(4).fill(null).map(() => new Scroller())],
]);

interface BarItem {
  normalSymbolResource: Resource,
  selectedSymbolResource: Resource,
  label: ResourceStr,
  normalColor: ResourceColor;
  selectedColor: ResourceColor;
}