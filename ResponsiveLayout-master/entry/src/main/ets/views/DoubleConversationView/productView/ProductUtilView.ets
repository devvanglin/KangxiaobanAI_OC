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

import { deviceInfo } from '@kit.BasicServicesKit';
import { WidthBreakpointType } from '../../../utils/WidthBreakpointType';
import { CommonConstants } from '../../../constants/CommonConstants';
import { DetailConstants } from '../../../constants/ProductDetailConstants';
import { UtilIcon } from './CommonView';
import { WindowInfo } from '../../../utils/WindowUtil';

@Component
export struct ProductUtilView {
  @ObjectLink mainWindowInfo: WindowInfo;
  @State detailType: string = CommonConstants.BIND_SHEET_PAGE_TYPES[3];
  private context: Context = this.getUIContext().getHostContext()!

  build() {
    GridRow({
      columns: {
        sm: 4,
        md: 8,
        lg: 12,
        xl: 12,
      }
    }) {
      GridCol({
        span: {
          sm: 4,
          md: 8,
          lg: 12,
          xl: 12,
        }
      }) {
        Row() {
          UtilIcon({ mainWindowInfo: this.mainWindowInfo, iconImg: $r('app.media.tab_home') })
            .visibility((this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD) ?
              Visibility.None : Visibility.Visible)
            .displayPriority(3)
          UtilIcon({ mainWindowInfo: this.mainWindowInfo, iconImg: $r('app.media.ic_public_comments') })
            .visibility((this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD) ?
              Visibility.None : Visibility.Visible)
            .displayPriority(3)
          UtilIcon({ mainWindowInfo: this.mainWindowInfo, iconImg: $r('app.media.tab_shopping_bag') })
            .visibility((this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_MD) ?
              Visibility.None :  Visibility.Visible)
            .displayPriority(3)
          Blank()
            .displayPriority(1)
          Button(DetailConstants.BUTTON_NAMES(this.context)[0])
            .fontSize('16fp')
            .fontColor('#CF0A2C')
            .fontWeight(CommonConstants.FONT_WEIGHT_500)
            .layoutWeight(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM ? 1 : 1)
            .height(40)
            .borderRadius(20)
            .backgroundColor('#0D000000')
            .margin({ right: 12 })
            .displayPriority(1)
          // [Start dialog_btn]
          Button(DetailConstants.BUTTON_NAMES(this.context)[1])
            // [StartExclude dialog_btn]
            .fontSize('16fp')
            .fontColor(Color.White)
            .fontWeight(500)
            .layoutWeight(1)
            .height('40vp')
            .borderRadius(20)
            .backgroundColor('#CF0A2C')
            .displayPriority(1)
          // [End dialog_btn]
        }
        .backgroundColor($r('app.color.products_info'))
        .height(deviceInfo.deviceType === '2in1' ? CommonConstants.TAB_BAR_HEIGHT :
          CommonConstants.TAB_BAR_HEIGHT + CommonConstants.BOTTOM_RECT_HEIGHT)
        .width(CommonConstants.FULL_PERCENT)
        .padding({
          left: new WidthBreakpointType(16, 24, 32, 32).getValue(this.mainWindowInfo.widthBp),
          right: new WidthBreakpointType(16, 24, 32, 32).getValue(this.mainWindowInfo.widthBp),
        })
      }
    }
  }
}

export class NavParams {
  viewName: string = '';

  constructor(viewName: string) {
    this.viewName = viewName;
  }
}