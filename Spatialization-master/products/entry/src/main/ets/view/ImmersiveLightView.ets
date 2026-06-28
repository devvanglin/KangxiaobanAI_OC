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

import { AppStorageV2, ComponentContent } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
// [Start immersive_view]
import {
  HdsAnimationMode,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigationMenuContentOptions,
  HdsTabs,
  HdsTabsController,
  HideMode,
  TextStyleMode,
} from '@kit.UIDesignKit';
// [StartExclude immersive_view]
import { StorageKey } from '../common/CommonConstants';
import { MaterialLevelItem, materialLevelMenu } from '../component/MaterialLevelMenu';
import { WaterFlowDetailView } from '../component/WaterFlowDetailView';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { SampleData } from '../model/SampleModel';
import { PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import Logger from '../util/Logger';
import { MaterialUtil } from '../util/MaterialUtil';

const TAG: string = '[ImmersiveLightView]';

@Builder
export function ImmersiveLightViewBuilder() {
  ImmersiveLightView()
}

@ComponentV2
struct ImmersiveLightView {
  private controller: HdsTabsController = new HdsTabsController();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local customMaterialLevel: MaterialLevelItem =
    AppStorageV2.connect(MaterialLevelItem, StorageKey.MATERIAL_LEVEL, () => new MaterialLevelItem()) ??
      new MaterialLevelItem();
  @Local currentSample?: SampleData;
  pathStack?: NavPathStack;
  private isScrollUp: boolean = false;
  private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.IMMERSIVE_LIGHT) ?? [];
  // [Start immersive_menu]
  private menuId: string = 'MaterialLevelMenu';
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

  handleTabBarAnimation(yOffset: number): void {
    if (this.globalInfoModel.needDynamicHideBar) {
      if (yOffset > 0 && !this.isScrollUp) {
        this.isScrollUp = true;
        this.controller.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      } else if (yOffset < 0 && this.isScrollUp) {
        this.isScrollUp = false;
        this.controller.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      }
    }
  }

  build() {
    // [Start immersive_union]
    HdsNavDestination() {
      // [Start immersive_tabs]
      HdsTabs({ controller: this.controller }) {
        // [StartExclude immersive_tabs]
        Repeat(this.tabsBar)
          .each((repeatItem: RepeatItem<BottomTabBarStyle>) => {
            TabContent() {
              WaterFlowDetailView({
                currentIndex: repeatItem.index,
                handleTabBarAnimation: (yOffset: number) => {
                  this.handleTabBarAnimation(yOffset);
                },
                handleBackBtnAction: () => {
                  this.pathStack?.pop();
                }
              })
            }
            .tabBar(repeatItem.item)
          })
        // [EndExclude immersive_tabs]
      }
      // [StartExclude immersive_union]
      .scrollable(false)
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .onAttach(() => {
        try {
          this.controller.preloadItems([0, 1, 2, 3, 4]);
        } catch (error) {
          Logger.error(TAG, `OnAttach preloadItems failed`);
        }
      })
      // [EndExclude immersive_union]
      .barFloatingStyle({
        // [StartExclude immersive_union]
        barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
          $r('sys.float.padding_level8'),
        adaptToHandedness: true,
        // [EndExclude immersive_union]
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.customMaterialLevel.level,
        }
      })
      // [End immersive_tabs]
    }
    // [End immersive_union]
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideStatusBar: true,
      mode: HideMode.SCROLL_UP_TO,
    })
    .hideTitleBar(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onReady((cxt: NavDestinationContext) => {
      this.pathStack = cxt.pathStack;
      const param: SampleData = cxt.pathInfo.param as SampleData;
      this.currentSample = param;
    })
  }
}