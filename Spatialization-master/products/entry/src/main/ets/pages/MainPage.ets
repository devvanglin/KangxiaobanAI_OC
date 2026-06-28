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
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { DetailParam, SampleData, SAMPLE_LIST } from '../model/SampleModel';
import { BreakpointType } from '../util/BreakpointSystem';

@Entry
@ComponentV2
struct MainPage {
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  private pathStack: NavPathStack = new NavPathStack();
  private scrollerForScroll: Scroller = new Scroller();
  private sampleList = SAMPLE_LIST.slice(2, 5);
  private menus: HdsNavigationMenuContentOptions = {
    value: [{
      content: {
        label: 'menu1',
        icon: $r('sys.symbol.service_management'),
      }
    }],
  };

  @Builder
  headerBuilder() {
    RelativeContainer() {
      Image($r('app.media.ic_banner_icon'))
        .height(56)
        .alignRules({
          center: { anchor: '__container__', align: VerticalAlign.Center },
          middle: { anchor: '__container__', align: HorizontalAlign.Center },
        })
        .margin({ bottom: $r('sys.float.padding_level4') })
      Column() {
        Text($r('app.string.banner_title'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({overflow: TextOverflow.Ellipsis})
        Text($r('app.string.banner_desc'))
          .fontSize($r('sys.float.Subtitle_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({overflow: TextOverflow.Ellipsis})
          .margin({ top: $r('sys.float.padding_level2') })
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({
        left: new BreakpointType({
          sm: $r('sys.float.padding_level8'),
          md: $r('sys.float.padding_level12'),
          lg: $r('sys.float.padding_level16')
        }).getValue(this.globalInfoModel.widthBreakpoint),
        right: new BreakpointType({
          sm: $r('sys.float.padding_level8'),
          md: $r('sys.float.padding_level12'),
          lg: $r('sys.float.padding_level16'),
        }).getValue(this.globalInfoModel.widthBreakpoint),
        bottom: $r('sys.float.padding_level12')
      })
      .alignRules({
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
      })
    }
    .backgroundImage($r('app.media.ic_banner_bg'))
    .backgroundImageSize(ImageSize.FILL)
    .width('100%')
    .height(276)
  }

  @Builder
  footerBuilder() {
    Column()
      .height(this.globalInfoModel.naviIndicatorHeight);
  }

  build() {
    HdsNavigation(this.pathStack) {
      List({ scroller: this.scrollerForScroll }) {
        ListItemGroup({ header: this.headerBuilder })
        ListItemGroup({ space: 2, footer: this.footerBuilder }) {
          Repeat(this.sampleList)
            .each((repeatItem: RepeatItem<SampleData>) => {
              ListItem() {
                Row({ space: 12 }) {
                  Image($r(`app.media.ic_sample_${repeatItem.item.id}`))
                    .height(88)
                    .borderRadius($r('sys.float.corner_radius_level4'))
                    .width(66)
                  Column() {
                    Text($r('app.string.cases', repeatItem.index + 1, repeatItem.item.title))
                      .fontSize($r('sys.float.Subtitle_M'))
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                      .maxLines(2)
                      .textOverflow({overflow: TextOverflow.Ellipsis})
                    Text(repeatItem.item.desc)
                      .margin({ top: $r('sys.float.padding_level3') })
                      .fontSize($r('sys.float.Body_M'))
                      .fontColor($r('sys.color.font_secondary'))
                      .maxLines(2)
                      .textOverflow({overflow: TextOverflow.Ellipsis})
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize($r('sys.float.Title_M'))
                    .fontColor([$r('sys.color.font_fourth')])
                }
                .onClick(() => {
                  this.pathStack.pushPath({
                    name: 'DetailView',
                    param: {
                      currentIndex: repeatItem.index,
                    } as DetailParam,
                  });
                })
                .height(120)
              }
            })
        }
        .padding({
          left: new BreakpointType({
            sm: $r('sys.float.padding_level8'),
            md: $r('sys.float.padding_level12'),
            lg: $r('sys.float.padding_level16')
          }).getValue(this.globalInfoModel.widthBreakpoint),
          right: new BreakpointType({
            sm: $r('sys.float.padding_level8'),
            md: $r('sys.float.padding_level12'),
            lg: $r('sys.float.padding_level16')
          }).getValue(this.globalInfoModel.widthBreakpoint)
        })
        .divider({
          strokeWidth: '1px',
          startMargin: 82,
          endMargin: 12,
          color: $r('sys.color.comp_divider')
        })
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.None)
      .lanes(new BreakpointType({
        sm: 1,
        md: 2,
        lg: 2
      }).getValue(this.globalInfoModel.widthBreakpoint), new BreakpointType({
        sm: $r('sys.float.padding_level0'),
        md: $r('sys.float.padding_level12'),
        lg: $r('sys.float.padding_level16')
      }).getValue(this.globalInfoModel.widthBreakpoint))
      .align(Alignment.Top)
      .clipContent(ContentClipMode.SAFE_AREA)
      .height('100%')

    }
    .mode(NavigationMode.Stack)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      },
    })
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}