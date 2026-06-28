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
// [Start adaptive_tab]
import {
  HdsBarStyle,
  hdsMaterial,
  HdsNavDestination,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
} from '@kit.UIDesignKit';
// [StartExclude adaptive_tab]
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { WaterFlowView } from '../component/WaterFlowView';
import { SampleData } from '../model/SampleModel';
import { PAGE_SCROLLER_MAP, PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import Logger from '../util/Logger';

const TAG: string = '[AdaptiveTabView]';

@Builder
export function AdaptiveTabViewBuilder() {
  AdaptiveTabView()
}

@ComponentV2
struct AdaptiveTabView {
  private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.ADAPTIVE_TAB) ?? [];
  @Local currentSample?: SampleData;
  // [EndExclude adaptive_tab]
  private controller: HdsTabsController = new HdsTabsController();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local isMiniBar: boolean = true;

  @Builder
  miniBarBuilder() {
    Row() {
      // [StartExclude adaptive_tab]
      Column() {
        Image($r('app.media.banner_HMOS'))
          .width('100%')
          .height('100%')
          .borderRadius('50%')
      }
      .padding(this.isMiniBar ? 1 : $r('sys.float.padding_level3'))
      .width(56)
      .aspectRatio(1)
      .justifyContent(FlexAlign.Center)

      Column({ space: 6 }) {
        Text('Espresso')
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        Text('Sabrina Carpenter')
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
      }
      .padding({ left: $r('sys.float.padding_level1') })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
          .fontSize($r('sys.float.Title_M'))
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize($r('sys.float.Title_M'))
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize($r('sys.float.Title_M'))
      }
      .padding({
        left: $r('sys.float.padding_level4'),
        right: $r('sys.float.padding_level8')
      })
      // [EndExclude adaptive_tab]
    }
  }
  // [StartExclude adaptive_tab]
  build() {
    HdsNavDestination() {
      // [EndExclude adaptive_tab]
      HdsTabs({ controller: this.controller }) {
        // [StartExclude adaptive_tab]
        Repeat(this.tabsBar)
          .each((repeatItem: RepeatItem<BottomTabBarStyle>) => {
            TabContent() {
              WaterFlowView({ currentTabIndex: repeatItem.index, pageKey: PageKeyEnum.ADAPTIVE_TAB })
            }
            .tabBar(repeatItem.item)
          })
        // [EndExclude adaptive_tab]
      }
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
          $r('sys.float.padding_level8'),
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        miniBar: {
          miniBarBuilder: () => this.miniBarBuilder(),
          onBarStyleChange: (miniBarStyle: HdsBarStyle) => {
            this.isMiniBar = miniBarStyle === HdsBarStyle.COLLAPSE
          }
        }
      })
      // [StartExclude adaptive_tab]
    }
    .onReady((cxt: NavDestinationContext) => {
      const param: SampleData = cxt.pathInfo.param as SampleData;
      this.currentSample = param;
    })
    .onAttach(() => {
      try {
        this.controller.preloadItems([0, 1, 2, 3]);
      } catch (error) {
        Logger.error(TAG, `OnAttach preloadItems failed`);
      }
    })
    .titleBar({
      content: {
        title: {
          mainTitle: this.currentSample?.title ?? '',
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    })
    .bindToScrollable(PAGE_SCROLLER_MAP.get(PageKeyEnum.ADAPTIVE_TAB) ?? [])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
// [EndExclude adaptive_tab]
// [End adaptive_tab]