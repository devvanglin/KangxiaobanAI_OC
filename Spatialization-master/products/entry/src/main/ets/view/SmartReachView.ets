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


import { AppStorageV2, curves, LengthMetrics, promptAction } from '@kit.ArkUI';
import { motion } from '@kit.MultimodalAwarenessKit';
// [Start gesture_reach]
import {
  hdsMaterial,
  HdsNavDestination,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
} from '@kit.UIDesignKit';
// [StartExclude gesture_reach]
import { StorageKey } from '../common/CommonConstants';
import { WaterFlowView } from '../component/WaterFlowView';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { SampleData } from '../model/SampleModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP, TabsBarModel } from '../model/TabsBarModel';
import { BreakpointType } from '../util/BreakpointSystem';
import Logger from '../util/Logger';
import { MaterialUtil } from '../util/MaterialUtil';

const NEVER_ALERT_KEY: string = 'NEVER_ALERT';
const TAG: string = '[SmartReachView]';

@Builder
export function SmartReachViewBuilder() {
  SmartReachView()
}

@ComponentV2
struct SmartReachView {
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local currentSample?: SampleData;
  @Local floatingAlignRules: AlignRuleOption = {
    right: { anchor: '__container__', align: HorizontalAlign.End },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
  };
  private controller: HdsTabsController = new HdsTabsController();
  private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.SMART_REACH) ?? [];
  private dialogComponentId?: number;
  handleHoldingHandChange: Callback<motion.HoldingHandStatus> = (status: motion.HoldingHandStatus) => {
    // [StartExclude gesture_change]
    Logger.info(TAG, `handle on holdingHandChanged:::${status}`);
    // [Start gesture_animate]
    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 288, 30) }, () => {
      if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
        if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
          this.floatingAlignRules = {
            left: { anchor: '__container__', align: HorizontalAlign.Start },
            bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          };
        } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
          this.floatingAlignRules = {
            right: { anchor: '__container__', align: HorizontalAlign.End },
            bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          };
        }
      }
    });
    // [End gesture_animate]
    // [EndExclude gesture_change]
  }

  aboutToAppear(): void {
    this.showAlert();
    try {
      if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
        motion.on('holdingHandChanged', this.handleHoldingHandChange);
        Logger.info(TAG, `Succeed handle on holdingHandChanged`);
      } else {
        Logger.error(TAG, `Can not handle on holdingHandChanged`);
      }
    } catch (error) {
      Logger.error(TAG, `Failed on holdingHandChanged. cause${error.message}`);
    }
  }

  aboutToDisappear(): void {
    try {
      if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
        motion.off('holdingHandChanged', this.handleHoldingHandChange);
      } else {
        Logger.error(TAG, `Can not handle off holdingHandChanged`);
      }
    } catch (error) {
      Logger.error(TAG, `Failed off holdingHandChanged. cause${error.message}`);
    }
  }

  showAlert() {
    try {
      const smartPromptAction = this.getUIContext().getPromptAction();
      smartPromptAction.openCustomDialog(MaterialUtil.getMaterialOptions<promptAction.CustomDialogOptions>({
        builder: () => {
          this.alertBuilder();
        },
        autoCancel: false,
      }) as promptAction.CustomDialogOptions)
        .then((dialogId: number) => {
          this.dialogComponentId = dialogId;
        })
        .catch((error: BusinessError) => {
          Logger.error(TAG, `show alert failed. cause code: ${error.code}; msg: ${error.message}`);
        });
    } catch (error) {
      Logger.error(TAG, `show alert failed. cause code: ${error.code}; msg: ${error.message}`);
    }
  }

  closeAlert() {
    if (this.dialogComponentId) {
      try {
        this.getUIContext().getPromptAction().closeCustomDialog(this.dialogComponentId);
        this.dialogComponentId = undefined;
      } catch (error) {
        Logger.error(TAG, `close alert failed. cause code: ${error.code}; msg: ${error.message}`);
      }
    }
  }

  @Builder
  alertBuilder() {
    Column() {
      Row() {
        Text($r('app.string.alert_title'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(56)

      Column() {
        Text($r('app.string.alert_msg'))
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .margin({ top: $r('sys.float.padding_level1') })
      }
      .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

      Image($r('app.media.ic_smart_reach'))
        .width('70%')
      Column() {
        Text($r('app.string.alert_desc'))
          .fontSize($r('sys.float.Subtitle_S'))
          .fontColor($r('sys.color.font_tertiary'))

        Row({ space: 16 }) {
          Button($r('app.string.okay'))
            .onClick(() => {
              this.closeAlert();
            })
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .height(40)
            .width('50%')
        }
        .padding({
          top: $r('sys.float.padding_level4'),
        })
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        top: $r('sys.float.padding_level4'),
        right: $r('sys.float.padding_level8'),
        bottom: $r('sys.float.padding_level8'),
      })
    }
  }

  build() {
    HdsNavDestination() {
      RelativeContainer() {
        // [EndExclude gesture_reach]
        HdsTabs({ controller: this.controller }) {
          // [StartExclude gesture_reach]
          Repeat(this.tabsBar)
            .each((repeatItem: RepeatItem<BottomTabBarStyle>) => {
              TabContent() {
                WaterFlowView({
                  currentTabIndex: repeatItem.index,
                  pageKey: PageKeyEnum.SMART_REACH
                })
              }
              .tabBar(repeatItem.item)
            })
          // [EndExclude gesture_reach]
        }
        .onAttach(() => {
          try {
            this.controller.preloadItems([0, 1, 2, 3]);
          } catch (error) {
            Logger.error(TAG, `OnAttach preloadItems failed`);
          }
        })
        .barOverlap(true)
        .vertical(false)
        .barPosition(BarPosition.End)
        .barFloatingStyle({
          barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
            $r('sys.float.padding_level8'),
          adaptToHandedness: true,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })

        Row() {
          SymbolGlyph($r('sys.symbol.square_and_pencil_fill'))
            .fontColor([$r('sys.color.icon_on_primary')])
            .fontSize($r('sys.float.Title_M'))
        }
        .alignRules(this.floatingAlignRules)
        // [StartExclude gesture_animate]
        .margin({
          left: new BreakpointType({
            sm: $r('sys.float.padding_level8'),
            md: $r('sys.float.padding_level12'),
            lg: $r('sys.float.padding_level16')
          }).getValue(this.globalInfoModel.widthBreakpoint),
          right: new BreakpointType({
            sm: $r('sys.float.padding_level8'),
            md: $r('sys.float.padding_level12'),
            lg: $r('sys.float.padding_level16')
          }).getValue(this.globalInfoModel.widthBreakpoint),
          bottom: 100,
        })
        .backgroundColor($r('sys.color.background_emphasize'))
        .borderRadius('50%')
        .clip(true)
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width(56)
        .aspectRatio(1)
      }

      // [StartExclude gesture_reach]
    }
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
          blurEffectiveEndOffset: LengthMetrics.vp(64),
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
    })
    .bindToScrollable(PAGE_SCROLLER_MAP.get(PageKeyEnum.SMART_REACH) ?? [])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onReady((cxt: NavDestinationContext) => {
      const param: SampleData = cxt.pathInfo.param as SampleData;
      this.currentSample = param;
    })
  }
}

// [EndExclude gesture_reach]
// [End gesture_reach]