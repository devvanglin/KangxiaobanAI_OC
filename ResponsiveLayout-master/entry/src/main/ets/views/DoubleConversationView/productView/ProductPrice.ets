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

import { CommonConstants } from '../../../constants/CommonConstants';
import { DetailConstants } from '../../../constants/ProductDetailConstants';
import { WindowInfo } from '../../../utils/WindowUtil';
import { WidthBreakpointType } from '../../../utils/WidthBreakpointType';
import { RightArrow } from './CommonView';

@Component
export struct ProductPrice {
  @ObjectLink mainWindowInfo: WindowInfo;
  private context: Context = this.getUIContext().getHostContext()!

  build() {
    Column() {
      Row() {
        Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[0])
          .fontSize($r('app.float.product_price_font_1'))
          .lineHeight($r('app.float.product_price_line_1'))
          .fontWeight(CommonConstants.FONT_WEIGHT_500)
          .fontColor(Color.White)
          .displayPriority(4)
        Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[1])
          .fontSize($r('app.float.product_price_font_2'))
          .lineHeight($r('app.float.product_price_line_2'))
          .fontWeight(CommonConstants.FONT_WEIGHT_500)
          .fontColor(Color.White)
          .displayPriority(4)
        Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[2])
          .decoration({
            type: TextDecorationType.LineThrough,
            color: Color.White
          })
          .opacity(CommonConstants.TEXT_OPACITY[2])
          .fontSize($r('app.float.product_price_font_3'))
          .fontWeight(CommonConstants.FONT_WEIGHT_500)
          .opacity(CommonConstants.TEXT_OPACITY[2])
          .fontColor(Color.White)
          .displayPriority(1)
        Blank()
          .displayPriority(2)
        Row() {
          this.TimeTip(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[3])
          this.TimeText(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[4])
          this.TimeTip(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[5])
          this.TimeText(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[6])
          this.TimeTip(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[7])
          this.TimeText(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[8])
        }
        .displayPriority(3)
      }
      .width(CommonConstants.FULL_PERCENT)
      .height($r('app.float.product_price_row_height'))
      .borderRadius(8)
      .padding({
        left: $r('app.float.product_price_padding_left_right'),
        right: $r('app.float.product_price_padding_left_right'),
        bottom: $r('app.float.product_price_padding_bottom')
      })
      .alignItems(VerticalAlign.Bottom)
      .linearGradient({
        direction: GradientDirection.Right,
        repeating: false,
        colors: [[DetailConstants.GRADIENT_COLORS[0], 0.0], [DetailConstants.GRADIENT_COLORS[1], 1.0]]
      })

      Row() {
        Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[9])
          .fontSize($r('app.float.product_price_font_3'))
          .fontWeight(FontWeight.Normal)
          .lineHeight($r('app.float.product_price_line_3'))
          .opacity(CommonConstants.TEXT_OPACITY[2])
        Blank()
        RightArrow()
      }
      .width(CommonConstants.FULL_PERCENT)
      .margin({
        top: $r('app.float.price_margin_top'),
        bottom: $r('app.float.price_margin_bottom')
      })

      Row() {
        this.ProductTag(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[10])
        this.ProductTag(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[11])
        this.ProductTag(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[12])
        Blank()
          .displayPriority(2)
        Row() {
          Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[13])
            .fontColor(Color.White)
            .fontSize($r('app.float.product_price_font_3'))
            .fontWeight(CommonConstants.FONT_WEIGHT_500)
        }
        .displayPriority(1)
        .width(this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_LG ? $r('app.float.price_tag_row_width') :
          $r('app.float.price_tag_row_width_lg'))
        .borderRadius(14)
        .height($r('app.float.price_tag_row_height'))
        .backgroundColor($r('app.color.products_info_background_2'))
        .justifyContent(FlexAlign.Center)
      }
      .width(CommonConstants.FULL_PERCENT)
      .margin({ bottom: $r('app.float.price_tag_row_margin') })

      Row() {
        Image($r('app.media.ic_public_gps'))
          .opacity(CommonConstants.TEXT_OPACITY[2])
          .width(12)
          .height(12)
          .margin({ right: $r('app.float.price_position_margin') })
        Column() {
          Row() {
            Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[14])
              .fontSize($r('app.float.product_price_font_3'))
              .fontWeight(FontWeight.Normal)
              .lineHeight($r('app.float.product_price_line_3'))
              .opacity(CommonConstants.TEXT_OPACITY[2])
            Blank()
            RightArrow()
          }
          .width(CommonConstants.FULL_PERCENT)

          Text(DetailConstants.PRODUCT_PRICE_NAMES(this.context)[15])
            .fontSize($r('app.float.product_price_font_3'))
            .lineHeight($r('app.float.product_price_line_3'))
            .margin({ top: $r('app.float.price_position_margin') })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .alignItems(VerticalAlign.Top)
      .width(CommonConstants.FULL_PERCENT)
      .height($r('app.float.price_position_row_height'))
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(Color.White)
    .width(CommonConstants.FULL_PERCENT)
    .borderRadius(16)
    .padding($r('app.float.price_col_padding'))
    .margin({
      top: this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_LG ? $r('app.float.price_col_margin_top') : 0,
      bottom: new WidthBreakpointType($r('app.float.price_col_margin_bottom_sm'), $r('app.float.price_col_margin_bottom_md'),
        $r('app.float.price_col_margin_bottom_lg'), $r('app.float.price_col_margin_bottom_lg')).getValue(this.mainWindowInfo.widthBp) })
  }

  @Builder
  TimeText(timeText: string) {
    Row() {
      Text(timeText)
        .fontSize($r('app.float.product_price_font_4'))
        .lineHeight($r('app.float.product_price_line_4'))
        .width($r('app.float.product_price_line_5'))
        .fontWeight(CommonConstants.FONT_WEIGHT_500)
        .fontColor(Color.White)
    }
    .padding({
      left: $r('app.float.time_text_padding'),
      right: $r('app.float.time_text_padding')
    })
    .height($r('app.float.time_text_height'))
    .width($r('app.float.time_text_width'))
    .borderRadius(2)
    .backgroundColor($r('app.color.time_tip_background'))
  }

  @Builder
  TimeTip(tipText: string) {
    Text(tipText)
      .fontSize($r('app.float.product_price_font_5'))
      .lineHeight($r('app.float.product_price_line_5'))
      .fontWeight(CommonConstants.FONT_WEIGHT_500)
      .fontColor(Color.White)
  }

  @Builder
  ProductTag(tagText: string) {
    Row() {
      Text(tagText)
        .fontSize($r('app.float.product_price_font_4'))
        .lineHeight($r('app.float.product_price_line_4'))
        .fontColor($r('app.color.service_font_color'))
        .fontWeight(FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .displayPriority(3)
    .height($r('app.float.product_tag_row_height'))
    .opacity(CommonConstants.TEXT_OPACITY[2])
    .borderRadius(4)
    .borderColor($r('app.color.price_tag_border_color'))
    .borderWidth($r('app.float.product_tag_row_border_width'))
    .padding({
      left: $r('app.float.product_tag_row_padding'),
      right: $r('app.float.product_tag_row_padding')
    })
    .margin({ right: $r('app.float.product_tag_row_margin') })
    .linearGradient({
      direction: GradientDirection.Right,
      repeating: false,
      colors: [[DetailConstants.GRADIENT_COLORS[2], 0.0], [DetailConstants.GRADIENT_COLORS[3], 1.0]]
    })
  }
}