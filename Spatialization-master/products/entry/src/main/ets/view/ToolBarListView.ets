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
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { SampleData } from '../model/SampleModel';

@ComponentV2
struct ToolBarListView {
  private pathStack?: NavPathStack;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local currentSample?: SampleData;
  toolbarList: string[] = ['备忘录-仅图标', '玩机技巧-图标+文字', '阅读-纵向工具栏']

  build() {
    HdsNavDestination() {
      GridRow({
        columns: { sm: 4, md: 8, lg: 12 },
        gutter: {
          x: {
            sm: $r('sys.float.padding_level8'),
            md: $r('sys.float.padding_level12'),
            lg: $r('sys.float.padding_level24'),
          },
        },
      }) {
        GridCol({
          span: { sm: 4, md: 4, lg: 4, },
          offset: { sm: 0, md: 2, lg: 4, },
        }) {
          Scroll() {
            Column({ space: 16 }) {
              ForEach(this.toolbarList, (item: string, index: number) => {
                Column() {
                  Image($r(`app.media.ic_toolbar_${index + 1}`))
                    .borderRadius($r('sys.float.corner_radius_level10'))
                    .width('100%')
                  Button(item)
                    .fontColor($r('sys.color.font_primary'))
                    .margin({ top: -76 })
                    .backgroundColor(Color.Transparent)
                    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
                    .height(76)
                    .width('100%')
                    .borderRadius($r('sys.float.corner_radius_level10'))
                }
              }, (item: string)=> item);
            }
            .padding({
              top: this.globalInfoModel.statusBarHeight + 56,
              bottom: this.globalInfoModel.naviIndicatorHeight,
            })
          }
          .scrollBar(BarState.Off)
        }
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
        })
      }

    }
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      content: {
        title: {
          mainTitle: this.currentSample?.title ?? '',
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    })
    .onReady((cxt: NavDestinationContext) => {
      const param: SampleData = cxt.pathInfo.param as SampleData;
      this.pathStack = cxt.pathStack;
      this.currentSample = param;
    })
  }
}

@Builder
export function ToolBarListViewBuilder() {
  ToolBarListView()
}