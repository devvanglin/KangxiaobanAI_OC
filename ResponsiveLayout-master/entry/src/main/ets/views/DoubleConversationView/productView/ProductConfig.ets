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
import { CommentsContent, CommentsTitle, ConfigTipIcon, ConfigTipText, ProductsConfigText,
  RightArrow, UserCommentInfo } from './CommonView';
import { WindowInfo } from '../../../utils/WindowUtil';
import { WidthBreakpointType } from '../../../utils/WidthBreakpointType';

@Component
export struct ProductConfig {
  @ObjectLink mainWindowInfo: WindowInfo;
  private context: Context = this.getUIContext().getHostContext()!

  build() {
    Column() {
      Column() {
        Row() {
          ProductsConfigText({ configText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[0] })
            .margin({ right: $r('app.float.products_config_margin_12') })
          Column() {
            Row() {
              ProductsConfigText({ configText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[1] })
              Blank()
              RightArrow()
            }
            .width(CommonConstants.FULL_PERCENT)
            .margin({ bottom: $r('app.float.products_config_margin_8') })

            List({ space: DetailConstants.PRODUCT_CONFIG_LIST_SPACE }) {
              ForEach(DetailConstants.PRODUCT_COLOR_SELECTION, (item: Resource) => {
                ListItem() {
                  Image(item)
                    .width(36)
                    .height(36)
                }
              }, (item: Resource, index: number) => JSON.stringify(item) + index)
            }
            .listDirection(Axis.Horizontal)
            .width(CommonConstants.FULL_PERCENT)
            .margin({ bottom: $r('app.float.products_config_margin_8') })

            Divider()
              .width(CommonConstants.FULL_PERCENT)
              .strokeWidth(1)
              .color($r('app.color.divider_color'))
          }
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: $r('app.float.products_config_margin_12') })

        Row() {
          Column() {
            ProductsConfigText({ configText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[2] })
            ProductsConfigText({ configText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[3] })
          }
          .width($r('app.float.config_text_col_width'))
          .height($r('app.float.config_text_col_height'))
          .margin({ right: $r('app.float.products_config_margin_12') })

          Column() {
            Row() {
              List({ space: DetailConstants.PRODUCT_CONFIG_LIST_SPACE }) {
                ForEach(DetailConstants.RECOMMENDED_CONFIG_PRODUCTS, (item: Resource) => {
                  ListItem() {
                    Image(item)
                      .width(36)
                      .height(36)
                  }
                }, (item: Resource, index: number) => JSON.stringify(item) + index)
              }
              .scrollBar(BarState.Off)
              .listDirection(Axis.Horizontal)
              .layoutWeight(1)
              .margin({ bottom: $r('app.float.products_config_margin_8') })

              RightArrow()
            }
            .width(CommonConstants.FULL_PERCENT)

            Divider()
              .width(CommonConstants.FULL_PERCENT)
              .strokeWidth(1)
              .color($r('app.color.divider_color'))
          }
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: $r('app.float.products_config_margin_12') })

        Row() {
          ProductsConfigText({ configText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[4] })
            .margin({ right: $r('app.float.products_config_margin_12') })
          ProductsConfigText({ configText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[5] })
          Blank()
          RightArrow()
        }
        .width(CommonConstants.FULL_PERCENT)
        .margin({ bottom: $r('app.float.products_config_margin_12') })
      }
      .width(CommonConstants.FULL_PERCENT)
      .padding({
        left: $r('app.float.products_padding_sm'),
        right: $r('app.float.products_padding_sm')
      })

      Scroll() {
        Row() {
          ConfigTipIcon()
          ConfigTipText({ tipText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[6] })
            .margin({ right: $r('app.float.products_config_margin_12') })
          ConfigTipIcon()
          ConfigTipText({ tipText: DetailConstants.PRODUCT_CONFIG_NAMES(this.context)[7] })
            .layoutWeight(1)
        }
        .height(CommonConstants.FULL_PERCENT)
        .width(CommonConstants.FULL_PERCENT)
      }
      .align(Alignment.Start)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Horizontal)
      .width(CommonConstants.FULL_PERCENT)
      .backgroundColor($r('app.color.config_tip_background'))
      .height($r('app.float.config_tip_row_height'))
      .padding({
        left: $r('app.float.products_padding_sm'),
        right: $r('app.float.products_padding_sm')
      })
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(Color.White)
    .width(CommonConstants.FULL_PERCENT)
    .borderRadius(16)
    .padding({ top: $r('app.float.products_config_margin_12') })
  }
}

@Component
export struct UserComments {
  @ObjectLink mainWindowInfo: WindowInfo;
  pathStack: NavPathStack = new NavPathStack();
  private context: Context = this.getUIContext().getHostContext()!
  @Link isNavFullScreen: boolean;

  build() {
    Column() {
      Row() {
        CommentsTitle()
          .layoutWeight(1)
        Blank()
        Text(DetailConstants.USER_COMMENT_NAMES(this.context)[6])
          .fontSize($r('app.float.all_comments_font'))
          .lineHeight($r('app.float.all_comments_line'))
          .fontWeight(FontWeight.Normal)
          .opacity(CommonConstants.TEXT_OPACITY[2])
          .margin({ right: $r('app.float.all_comments_margin') })
          .visibility(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? Visibility.Visible :
            Visibility.None)
        RightArrow()
          .displayPriority(1)
          .visibility(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ? Visibility.Visible :
            Visibility.None)
      }
      .height($r('app.float.user_comments_title_line'))
      .width(CommonConstants.FULL_PERCENT)
      .margin({ bottom: $r('app.float.comments_title_margin') })

      Scroll() {
        Row() {
          CommentsTag({ tagText: DetailConstants.USER_COMMENT_NAMES(this.context)[1] })
          CommentsTag({ tagText: DetailConstants.USER_COMMENT_NAMES(this.context)[2] })
          CommentsTag({ tagText: DetailConstants.USER_COMMENT_NAMES(this.context)[3] })
        }
      }
      .align(Alignment.Start)
      .width(CommonConstants.FULL_PERCENT)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      Column() {
        UserCommentInfo()
        CommentsContent()
      }
      .alignItems(HorizontalAlign.Start)
    }
    .backgroundColor(Color.White)
    .alignItems(HorizontalAlign.Start)
    .width(CommonConstants.FULL_PERCENT)
    .borderRadius(16)
    .padding($r('app.float.products_config_margin_12'))
    .margin({ bottom: new WidthBreakpointType($r('app.float.products_padding_sm'), $r('app.float.products_padding_md'),
      $r('app.float.products_padding_lg'), $r('app.float.products_padding_lg')).getValue(this.mainWindowInfo.widthBp) })

  }
}

@Component
struct CommentsTag {
  public tagText: string = '';

  build() {
    Row() {
      Text(this.tagText)
        .fontSize($r('app.float.tag_font'))
        .fontWeight(FontWeight.Normal)
    }
    .margin({ right: $r('app.float.tag_margin') })
    .padding({
      left: $r('app.float.tag_padding'),
      right: $r('app.float.tag_padding')
    })
    .borderRadius(16)
    .height($r('app.float.tag_row_height'))
    .backgroundColor($r('app.color.user_comments_tag_background'))
  }
}