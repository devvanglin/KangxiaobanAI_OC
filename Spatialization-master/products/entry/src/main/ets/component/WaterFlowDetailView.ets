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

import { AppStorageV2, ComponentContent, LengthMetrics } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
// [Start immersive_view]
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleMode,
  HideMode,
  ScrollEffectType,
  TextStyleMode,
} from '@kit.UIDesignKit';
// [StartExclude immersive_view]
import { StorageKey } from '../common/CommonConstants';
import { MaterialLevelItem, materialLevelMenu } from '../component/MaterialLevelMenu';
import { WaterFlowView } from '../component/WaterFlowView';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import Logger from '../util/Logger';
import { MaterialUtil } from '../util/MaterialUtil';

const TAG: string = '[ImmersiveLightView]';

@ComponentV2
export struct WaterFlowDetailView {
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local customMaterialLevel: MaterialLevelItem =
    AppStorageV2.connect(MaterialLevelItem, StorageKey.MATERIAL_LEVEL, () => new MaterialLevelItem()) ??
      new MaterialLevelItem();
  @Param @Require currentIndex: number;
  @Event handleTabBarAnimation?: (yOffset: number) => void;
  @Event handleBackBtnAction: () => void
  scroller: Scroller = PAGE_SCROLLER_MAP.get(PageKeyEnum.IMMERSIVE_LIGHT)?.[this.currentIndex] ?? new Scroller();
  // [Start immersive_menu]
  private menuId: string = 'MaterialLevelMenu' + this.currentIndex;
  private menus: HdsNavigationMenuContentOptions = {
    value: [
      {
        content: {
          label: $r('app.string.level'),
          icon: $r('sys.symbol.house_fill'),
          type: TextStyleMode.NORMAL,
          componentId: this.menuId,
          action: () => {
            try {
              const uiContext = this.getUIContext();
              const promptAction = this.getUIContext().getPromptAction();
              const contentNode = new ComponentContent(uiContext, wrapBuilder(materialLevelMenu))
              promptAction.openMenu(contentNode, { id: this.menuId }, MaterialUtil.getMaterialOptions<MenuOptions>(
                { mask: false, backgroundBlurStyle: BlurStyle.COMPONENT_THICK }) as MenuOptions)
                .catch((error: BusinessError) => {
                  Logger.error(TAG, `Show menu failed. cause code: ${error.code}, msg: ${error.message}`);
                });
            } catch (error) {
              Logger.error(TAG, `Show menu failed. cause msg: ${error.message}`);
            }
          }
        }
      }
    ],
  };
  // [End immersive_menu]

  build() {
    // [Start immersive_union]
    // [EndExclude immersive_view]
    HdsNavigation() {
      // [StartExclude immersive_view]
      // [Start immersive_tabs]
      // [StartExclude immersive_union]
      WaterFlowView({
        currentTabIndex: this.currentIndex,
        pageKey: PageKeyEnum.IMMERSIVE_LIGHT,
        handleTabBarAnimation: (yOffset: number) => {
          this.handleTabBarAnimation?.(yOffset);
        }
      })
      // [EndExclude immersive_union]
      // [End immersive_tabs]
      // [EndExclude immersive_view]
    }
    // [StartExclude immersive_union]
    // [StartExclude immersive_view]
    .mode(NavigationMode.Stack)
    // [Start immersive_scroll]
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideStatusBar: true,
      mode: HideMode.SCROLL_UP_TO,
    })
    // [EndExclude immersive_view]
    // [StartExclude immersive_scroll]
    // [EndExclude immersive_union]
    .titleBar({
      // [StartExclude immersive_union]
      // [StartExclude immersive_view]
      content: {
        title: {
          mainTitle: $r('app.string.sample_3_title'),
        },
        backIcon: {
          action: ()=>{
            this.handleBackBtnAction();
          }
        },
        menu: this.menus,
      },
      // [EndExclude immersive_union]
      // [EndExclude immersive_view]
      style: {
        // [StartExclude immersive_union]
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          // [StartExclude immersive_view]
          blurEffectiveEndOffset: LengthMetrics.vp(this.globalInfoModel.statusBarHeight + 56)
          // [EndExclude immersive_view]
        },
        // [EndExclude immersive_union]
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.customMaterialLevel.level,
        },
      },
      // [StartExclude immersive_union]
      // [StartExclude immersive_view]
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      // [EndExclude immersive_view]
      // [EndExclude immersive_union]
    })
    // [StartExclude immersive_union]
    // [EndExclude immersive_scroll]
    // [StartExclude immersive_view]
    .bindToScrollable([this.scroller])
    // [End immersive_scroll]
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // [EndExclude immersive_union]
    // [End immersive_union]
  }
}
// [EndExclude immersive_view]
// [Start immersive_view]