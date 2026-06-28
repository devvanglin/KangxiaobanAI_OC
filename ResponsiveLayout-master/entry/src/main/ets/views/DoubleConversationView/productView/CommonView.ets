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

@Component
export struct ProductsConfigText {
  public configText: string = '';

  build() {
    Text(this.configText)
      .fontSize($r('app.float.products_config_font'))
      .lineHeight($r('app.float.products_config_line'))
      .fontWeight(FontWeight.Normal)
  }
}

@Component
export struct RightArrow {
  build() {
    Image($r('app.media.arrow_right'))
      .width($r('app.float.right_arrow_width'))
      .height($r('app.float.right_arrow_height'))
  }
}

@Component
export struct ConfigTipIcon {
  build() {
    Image($r('app.media.ic_public_todo'))
      .width($r('app.float.config_tip_icon_size'))
      .height($r('app.float.config_tip_icon_size'))
      .borderRadius(5)
      .opacity(CommonConstants.TEXT_OPACITY[1])
      .margin({ right: $r('app.float.config_tip_icon_margin') })
  }
}

@Component
export struct ConfigTipText {
  public tipText: string = '';

  build() {
    Text(this.tipText)
      .opacity(CommonConstants.TEXT_OPACITY[2])
      .fontSize($r('app.float.config_tip_text_font'))
      .fontWeight(FontWeight.Normal)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}

@Component
export struct UtilIcon {
  @ObjectLink mainWindowInfo: WindowInfo;
  public iconImg: Resource = $r('app.media.tab_home');

  build() {
    Row() {
      Image(this.iconImg)
        .width(24)
        .height(24)
    }
    .justifyContent(FlexAlign.Center)
    .width(new WidthBreakpointType($r('app.float.util_icon_width_sm'), $r('app.float.util_icon_width_md'),
        $r('app.float.util_icon_width_lg'), $r('app.float.util_icon_width_lg')).getValue(this.mainWindowInfo.widthBp))
    .height(CommonConstants.TAB_BAR_HEIGHT)
  }
}


@Component
export struct CommentsTitle {
  private context: Context = this.getUIContext().getHostContext()!

  build() {
    Text(DetailConstants.USER_COMMENT_NAMES(this.context)[0])
      .fontSize($r('app.float.user_comments_title_font'))
      .lineHeight($r('app.float.user_comments_title_line'))
      .fontWeight(CommonConstants.FONT_WEIGHT_500)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}

@Component
export struct UserCommentInfo {
  private context: Context = this.getUIContext().getHostContext()!

  build() {
    Row() {
      Image($r('app.media.user_profile'))
        .width(36)
        .height(36)
        .margin({ right: $r('app.float.comments_profile_margin') })
      Column() {
        Text(DetailConstants.USER_COMMENT_NAMES(this.context)[4])
          .fontSize($r('app.float.comments_user_font'))
          .lineHeight($r('app.float.comments_user_line'))
          .fontWeight(FontWeight.Normal)
        Rating({ rating: CommonConstants.FIVE, indicator: false })
          .stars(CommonConstants.FIVE)
          .stepSize(1)
          .height($r('app.float.rating_height'))
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .height(CommonConstants.FULL_PERCENT)
    }
    .height($r('app.float.comments_user_row_height'))
    .margin({
      top: $r('app.float.comments_tag_margin'),
      bottom: $r('app.float.comments_user_row_margin')
    })
  }
}

@Component
export struct CommentsContent {
  private context: Context = this.getUIContext().getHostContext()!

  build() {
    Text(DetailConstants.USER_COMMENT_NAMES(this.context)[5])
      .fontSize($r('app.float.comment_text_font'))
      .fontWeight(FontWeight.Normal)
      .lineHeight($r('app.float.comment_text_line'))
  }
}
