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
import { HomeSearchState } from '../model/HomeSearchState';

@ComponentV2
export struct SearchPage {
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local homeSearchState: HomeSearchState =
    AppStorageV2.connect(HomeSearchState, StorageKey.HOME_SEARCH_STATE) ?? new HomeSearchState();

  build() {
    HdsNavDestination() {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])

          Search({ placeholder: '搜索姓名、房间或设备', value: this.searchText })
            .width('100%')
            .height(40)
            .placeholderColor($r('sys.color.font_secondary'))
            .backgroundColor('rgba(0,0,0,0)')
            .textFont({ size: $r('sys.float.Body_L'), weight: FontWeight.Regular })
            .searchIcon({ src: $r('sys.media.ohos_ic_public_search_filled') })
            .defaultFocus(true)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.searchText = value;
            })

          SymbolGlyph($r('sys.symbol.mic'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width('100%')
        .height(48)
        .padding({ left: 14, right: 14 })
        .backgroundColor('rgba(255,255,255,0.72)')
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius(12)
        .border({
          width: 0.5,
          color: 'rgba(255,255,255,0.4)'
        })
        .sharedTransition('homeSearchBar', {
          duration: 350,
          curve: Curve.EaseInOut
        })

        List() {
          ListItem() {
            Column() {
              Text('搜索历史')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
                .width('100%')
                .padding({ top: 16, bottom: 8 })

              Row({ space: 8 }) {
                Text('肖爷爷')
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor($r('sys.color.comp_background_primary'))
                  .borderRadius(8)
                  .onClick(() => {
                    this.searchText = '肖爷爷';
                  })

                Text('3F-302')
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor($r('sys.color.comp_background_primary'))
                  .borderRadius(8)
                  .onClick(() => {
                    this.searchText = '3F-302';
                  })

                Text('智能床垫')
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor($r('sys.color.comp_background_primary'))
                  .borderRadius(8)
                  .onClick(() => {
                    this.searchText = '智能床垫';
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 12 })
      .backgroundColor($r('sys.color.background_secondary'))
    }
    .hideBackButton(false)
    .titleBar({
      content: {
        title: {
          mainTitle: ''
        },
        backIcon: {
          action: () => {
            this.pathStack.pop();
          }
        }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
