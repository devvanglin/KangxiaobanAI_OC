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

import { AppStorageV2, CommonModifier } from '@kit.ArkUI';
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { DetailParam, SampleData, SAMPLE_LIST } from '../model/SampleModel';
import { BreakpointType } from '../util/BreakpointSystem';
import { CustomImmersiveStyle, MaterialUtil } from '../util/MaterialUtil';

@ComponentV2
struct DetailView {
  private pathStack?: NavPathStack;
  private sampleList = SAMPLE_LIST.slice(2, 5);
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local currentIndex: number = 0;
  @Local currentSample: SampleData = this.sampleList[this.currentIndex];

  @Computed
  get cardPadding(): Length {
    return new BreakpointType<Length>({
      sm: $r('sys.float.padding_level8'),
      md: $r('sys.float.padding_level12'),
      lg: $r('sys.float.padding_level16')
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Swiper() {
          Repeat(this.sampleList)
            .each((repeatItem: RepeatItem<SampleData>) => {
              Column() {
                Column() {
                  Text(repeatItem.item.title)
                    .fontSize($r('sys.float.Subtitle_L'))
                    .fontColor($r('sys.color.font_secondary'))
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: $r('sys.float.padding_level16') })
                    .maxLines(1)
                    .textOverflow({overflow: TextOverflow.Ellipsis})
                  Image(repeatItem.item.detailImg)
                    .objectFit(ImageFit.Contain)
                    .borderRadius(12)
                    .layoutWeight(1)
                }
                .padding({
                  top: this.cardPadding,
                  left: this.cardPadding,
                  right: this.cardPadding,
                  bottom: repeatItem.item.isFullImg ? 0 : this.cardPadding,
                })
                .width('100%')
                .clip(true)
                .borderRadius(24)
                .backgroundColor($r('sys.color.comp_background_primary'))
              }
              .padding({
                top: 72,
                bottom: 198 + this.globalInfoModel.naviIndicatorHeight,
              })
            })
        }
        .itemSpace(12)
        .index(this.currentIndex)
        .onChange((index: number) => {
          this.currentSample = this.sampleList[index];
          this.currentIndex = index;
        })
        .width('100%')
        .height('100%')
        .displayCount(1)
        .vertical(false)
        .prevMargin(new BreakpointType<Length>({
          sm: $r('sys.float.padding_level12'),
          md: this.globalInfoModel.heightBreakpoint === HeightBreakpoint.HEIGHT_LG ? $r('sys.float.padding_level12') :
            this.globalInfoModel.deviceWidth / 7,
          lg: this.globalInfoModel.deviceWidth / 5
        }).getValue(this.globalInfoModel.widthBreakpoint))
        .nextMargin(new BreakpointType<Length>({
          sm: $r('sys.float.padding_level12'),
          md: this.globalInfoModel.heightBreakpoint === HeightBreakpoint.HEIGHT_LG ? $r('sys.float.padding_level12') :
            this.globalInfoModel.deviceWidth / 7,
          lg: this.globalInfoModel.deviceWidth / 5
        }).getValue(this.globalInfoModel.widthBreakpoint))

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
            span: { sm: 4, md: this.globalInfoModel.heightBreakpoint === HeightBreakpoint.HEIGHT_LG ? 8 : 6, lg: 8, },
            offset: { sm: 0, md: this.globalInfoModel.heightBreakpoint === HeightBreakpoint.HEIGHT_LG ? 0 : 1, lg: 2, },
          }) {
            Column() {
              Column() {
                Text(this.currentSample.title)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontColor($r('sys.color.font_primary'))
                  .fontWeight(FontWeight.Bold)
                  .maxLines(2)
                  .textOverflow({overflow: TextOverflow.Ellipsis})
                Text(this.currentSample.desc)
                  .margin({ top: $r('sys.float.padding_level2') })
                  .fontSize($r('sys.float.Subtitle_S'))
                  .fontColor($r('sys.color.font_secondary'))
                  .maxLines(2)
                  .textOverflow({overflow: TextOverflow.Ellipsis})
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              // [Start immersive_button]
              Row({ space: 16 }) {
                Button($r('app.string.reading'))
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .height(40)
                  .layoutWeight(1)
                  .attributeModifier(MaterialUtil.getMaterialModifier({
                    modifier: new CommonModifier(),
                    style: CustomImmersiveStyle.ULTRA_THIN,
                    backgroundColor: $r('sys.color.comp_background_tertiary'),
                    materialColor: $r('sys.color.comp_background_tertiary')
                  }))
                Button($r('app.string.experience'))
                  // [StartExclude immersive_button]
                  .onClick(() => {
                    if (this.currentSample.routerName) {
                      this.pathStack?.pushPath({
                        name: this.currentSample.routerName,
                        param: this.currentSample,
                      })
                    }
                  })
                  // [EndExclude immersive_button]
                  .buttonStyle(ButtonStyleMode.EMPHASIZED)
                  .height(40)
                  .layoutWeight(1)
                  .attributeModifier(MaterialUtil.getMaterialModifier({
                    modifier: new CommonModifier(),
                    style: CustomImmersiveStyle.ULTRA_THIN,
                    backgroundColor: $r('sys.color.background_emphasize'),
                    materialColor: $r('sys.color.background_emphasize')
                  }))
              }
              // [End immersive_button]
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius($r('sys.float.corner_radius_level8'))
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
            .padding($r('sys.float.padding_level8'))
            .height(164)
          }
          .padding({
            left: $r('sys.float.padding_level8'),
            right: $r('sys.float.padding_level8'),
            bottom: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
              $r('sys.float.padding_level8')
          })
        }
      }
    }
    .onReady((cxt: NavDestinationContext) => {
      const param: DetailParam = cxt.pathInfo.param as DetailParam;
      this.pathStack = cxt.pathStack;
      this.currentIndex = param.currentIndex;
      this.currentSample = this.sampleList[this.currentIndex];
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      content: {
        title: {
          mainTitle: this.currentSample.title,
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
      enableComponentSafeArea: false,
    })
  }
}

@Builder
export function DetailViewBuilder() {
  DetailView()
}