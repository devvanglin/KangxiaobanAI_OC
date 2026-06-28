/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { WidthBreakpointType } from '../../utils/WidthBreakpointType';
import { CommonConstants } from '../../constants/CommonConstants';
import { DetailConstants } from '../../constants/ProductDetailConstants';
import { WindowInfo } from '../../utils/WindowUtil';
import { ProductUtilView } from './productView/ProductUtilView';
import { ProductPrice } from './productView/ProductPrice';
import { ProductDiscount } from './productView/ProductDiscount';
import { ProductConfig, UserComments } from './productView/ProductConfig';

@Component
export struct ProductPage {
  @ObjectLink mainWindowInfo: WindowInfo;
  @State currentSwiperIndex: number = 0;
  @Link isNavFullScreen: boolean;
  pathStack: NavPathStack = new NavPathStack();

  @Builder
  PictureIndicator(text: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Normal)
      .margin({ right: 2 })
  }

  build() {
    NavDestination(){
      Row() {
        if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM ||
          this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD) {
          Column() {
            Row() {
              Image($r('app.media.ic_public_back'))
                .height(30)
                .width(30)
                .margin({
                  right: 16
                })
                .onClick(() => {
                  this.isNavFullScreen = false;
                  this.pathStack.pop();
                })
              Text($r('app.string.shopping_title'))
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .margin({ bottom: 12 })
            Scroll() {
              Column() {
                ProductPicture({
                  mainWindowInfo: this.mainWindowInfo,
                  isNavFullScreen: this.isNavFullScreen,
                  pathStack: this.pathStack,
                })
                ProductInfo({
                  mainWindowInfo: this.mainWindowInfo,
                  isNavFullScreen: this.isNavFullScreen,
                  pathStack: this.pathStack,
                })
              }
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            ProductUtilView({ mainWindowInfo: this.mainWindowInfo })
          }
          .height('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.products_info'))
          .alignItems(HorizontalAlign.Center)
          .padding({
            top: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.topRect.height) + 12,
            bottom: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.bottomRect.height),
            left: 16,
            right: 16
          })
        } else {
          Column() {
            Row() {
              Image($r('app.media.ic_public_back'))
                .height(30)
                .width(30)
                .margin({
                  left: 16,
                  right: 16,
                })
                .onClick(() => {
                  this.isNavFullScreen = false;
                  this.pathStack.pop();
                })
              Text($r('app.string.shopping_title'))
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .margin({ bottom: 12 })
            Column(){
              ProductPicture({
                mainWindowInfo: this.mainWindowInfo,
                isNavFullScreen: this.isNavFullScreen,
                pathStack: this.pathStack,
              })
            }
          }
          .padding({
            top: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.topRect.height) + 12,
            bottom: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.bottomRect.height),
          })
          .height('100%')
          .layoutWeight(1)
        }
        if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) {
          Column(){
            Scroll() {
              Column() {
                ProductInfo({
                  mainWindowInfo: this.mainWindowInfo,
                  isNavFullScreen: this.isNavFullScreen,
                  pathStack: this.pathStack,
                })
              }
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            ProductUtilView({ mainWindowInfo: this.mainWindowInfo })
          }
          .padding({
            top: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.topRect.height) + 12,
            bottom: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.bottomRect.height),
            left: 16,
            right: 16
          })
          .backgroundColor($r('app.color.products_info'))
          .height('100%')
          .layoutWeight(1)
        }
      }
    }
    .hideTitleBar(true)
    .onBackPressed(()=>{
      this.isNavFullScreen = false;
      this.pathStack.pop();
      return true;
    })
  }
}

@Component
export struct ProductPicture {
  @ObjectLink mainWindowInfo: WindowInfo;
  @State currentSwiperIndex: number = 0;
  @State isNavFullScreen: boolean = false;
  pathStack: NavPathStack = new NavPathStack();
  private context: Context = this.getUIContext().getHostContext()!

  @Builder
  PictureIndicator(text: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Normal)
      .margin({ right: 2 })
  }

  build() {
    Column() {
      Column() {
        Swiper() {
          ForEach(DetailConstants.PRODUCT_DETAIL_RESOURCES, (item: Resource) => {
            Image(item)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          }, (item: Resource, index: number) => index + JSON.stringify(item))
        }
        .align(Alignment.Start)
        .indicator(false)
        .displayCount(1)
        .nextMargin(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD ? 175 :
          0)
        .prevMargin(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD ? 175 :
          0)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentSwiperIndex = index;
        })
      }
      .height(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM ? 200 :
        (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD) ? '50%' : '70%')

      Row() {
        Column() {
          Text(JSON.stringify(this.currentSwiperIndex + 1) + DetailConstants.PICTURE_INDICATOR(this.context)[0])
            .fontSize($r('app.float.picture_number_font'))
            .fontWeight(FontWeight.Normal)
            .fontColor(Color.White)
        }
        .width(36)
        .height(16)
        .backgroundColor($r('app.color.swiper_indicator_background'))
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
      }
      .width(CommonConstants.FULL_PERCENT)
      .justifyContent(FlexAlign.End)
      .padding({ right: new WidthBreakpointType(16, 24, 32, 32).getValue(this.mainWindowInfo.widthBp) })

      Row() {
        this.PictureIndicator(DetailConstants.PICTURE_INDICATOR(this.context)[1])
        Image($r('app.media.arrow_right'))
          .width(6)
          .height(12)
          .margin({ right: 12 })
        this.PictureIndicator(DetailConstants.PICTURE_INDICATOR(this.context)[2])
        Image($r('app.media.arrow_right'))
          .width(6)
          .height(12)
      }
      .padding({
        left: 12,
        right: 8
      })
      .backgroundColor($r('app.color.products_compare'))
      .width(112)
      .height(24)
      .borderRadius(12)
      .margin({ top: 10, bottom: 10 })

      Row() {
        List({ space: new WidthBreakpointType(DetailConstants.PICTURE_LIST_SPACES[0], DetailConstants.PICTURE_LIST_SPACES[1],
          DetailConstants.PICTURE_LIST_SPACES[2], DetailConstants.PICTURE_LIST_SPACES[2]).getValue(this.mainWindowInfo.widthBp) }) {
          ForEach(DetailConstants.PRODUCT_SMALL_RESOURCES, (item: Resource, index: number) => {
            ListItem() {
              Image(item)
                .width(48)
                .height(48)
                .borderRadius(8)
                .borderWidth(index === this.currentSwiperIndex ? 1 : 0)
            }
          }, (item: Resource, index: number) => JSON.stringify(item) + index)
        }
        .scrollBar(BarState.Off)
        .listDirection(Axis.Horizontal)
        .margin({
          top: 12,
          bottom: 12
        })
      }
      .justifyContent(FlexAlign.Center)
      .height(72)
      .width(CommonConstants.FULL_PERCENT)
    }
    .backgroundColor(Color.White)
  }
}

@Component
export struct ProductInfo {
  @ObjectLink mainWindowInfo: WindowInfo;
  pathStack: NavPathStack = new NavPathStack();
  @Link isNavFullScreen: boolean;

  build() {
    Column() {
      ProductPrice({ mainWindowInfo: this.mainWindowInfo })
      ProductDiscount({ mainWindowInfo: this.mainWindowInfo })
      UserComments({ mainWindowInfo: this.mainWindowInfo, pathStack: this.pathStack, isNavFullScreen: this.isNavFullScreen })
      ProductConfig({ mainWindowInfo: this.mainWindowInfo })
    }
    .backgroundColor($r('app.color.products_info'))
    .width(CommonConstants.FULL_PERCENT)
    .padding({
      bottom: 12
    })
  }
}



