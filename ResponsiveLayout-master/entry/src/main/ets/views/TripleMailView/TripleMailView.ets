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
import { WindowInfo } from '../../utils/WindowUtil';
import { MailSideBar } from './MailSideBarView';
import { MailNavigation } from './MailNavView';

@Component
export struct TripleColumnMailView {
  @ObjectLink @Watch('widthBpChange') mainWindowInfo: WindowInfo;
  @State isShowingSidebar: boolean = this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ||
    this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL ? true : false;
  pageInfos: NavPathStack = new NavPathStack();
  pathStack: NavPathStack = new NavPathStack();
  @State isFold: boolean = false;
  @State sideBarWidth: number = 304;

  widthBpChange(): void {
    if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ||
      this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) {
      this.isShowingSidebar = true;
    } else {
      this.isShowingSidebar = false;
    }
  }

  // [Start set_show_side_bar_build]
  build() {
    GridRow() {
      GridCol({ span: { sm: 12, md: 12, lg: 12, xl: 12 } }) {
        SideBarContainer(new WidthBreakpointType(SideBarContainerType.Overlay, SideBarContainerType.Overlay,
          SideBarContainerType.Embed, SideBarContainerType.Embed).getValue(this.mainWindowInfo.widthBp)) {
          // Area A
          Column() {
            MailSideBar()
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('sys.color.gray_01'))

          // Area B+C
          Column() {
            Stack() {
              MailNavigation({
                mainWindowInfo: this.mainWindowInfo,
                pageInfos: this.pageInfos,
                pathStack: this.pathStack,
              })
                .margin({ top: 18 })
                .padding({ left: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.topRect.left) })
              // [StartExclude set_show_side_bar_build]
              if (this.isFold && this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_LG) {
                Column()
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#33000000')
              }
              // [EndExclude set_show_side_bar_build]
            }
          }
          .width('100%')
          .height('100%')
        }
        .showSideBar(this.isShowingSidebar)
        // [StartExclude set_show_side_bar_build]
        .sideBarWidth(this.sideBarWidth)
        .minSideBarWidth(240)
        .minContentWidth(this.mainWindowInfo.widthBp ===  WidthBreakpoint.WIDTH_SM ? 360 : 600)
        .controlButton({
          left: 24,
          top: this.getUIContext().px2vp(this.mainWindowInfo.AvoidSystem?.topRect.height) + 18,
          width: 24,
          height: 24
        })
        .onChange((value: boolean) => {
          this.isFold = value;
        })
        // [EndExclude set_show_side_bar_build]
      }
    }
    .width('100%')
    .height('100%')
  }
  // [End set_show_side_bar_build]
}