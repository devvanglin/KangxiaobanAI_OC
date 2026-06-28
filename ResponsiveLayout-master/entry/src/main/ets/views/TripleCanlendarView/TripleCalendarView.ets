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

import { ItemRestriction, SegmentButtonTextItem, SegmentButton, SegmentButtonOptions } from '@kit.ArkUI';
import { CalendarView } from './CalendarView';
import { CalendarItem } from './model/CalendarItem';
import { TripScheduleView } from './TripSchedule';
import { CommonConstants } from '../../constants/CommonConstants';
import { CalendarSideBarView } from './CalendarSideBarView';
import { WindowInfo } from '../../utils/WindowUtil';
import { deviceInfo } from '@kit.BasicServicesKit';

@Component
export struct TripleCalendarNavView {
  @ObjectLink @Watch('widthBpChange') mainWindowInfo: WindowInfo;
  @State isShowingSidebar: boolean = (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ||
    this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) ? true : false;
  @StorageLink('monthStatus') monthStatus: boolean = (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) ? false : true;
  @StorageLink('navMode') navMode: NavigationMode = NavigationMode.Split;
  @StorageLink('selectedItem') selectedItem: CalendarItem = new CalendarItem('', '', false);
  @State singleSelectCapsuleOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: $r('app.string.year') }, { text: $r('app.string.month') },
      { text: $r('app.string.week') }, { text: $r('app.string.day') }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
    backgroundColor: $r('app.color.window_background'),
    selectedBackgroundColor: $r('app.color.start_window_background')
  });
  @State singleSelectCapsuleSelectedIndexes: number[] = [1];
  pageInfos: NavPathStack = new NavPathStack();
  pathStack: NavPathStack = new NavPathStack();

  widthBpChange(): void {
    if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG ||
      this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) {
      this.isShowingSidebar = true;
    } else {
      this.isShowingSidebar = false;
    }
  }

  @Builder
  pageMap(name: string, param: CalendarItem) {
    if (param.isTrip) {
      NavDestination() {
        Column() {
          Text(CommonConstants.TRIP_SCHEDULE_VIEW[0])
            .fontSize($r('app.float.font_size_title'))
            .fontWeight(FontWeight.Bold)
            .width(CommonConstants.FULL_PERCENT)
          Text(CommonConstants.TRIP_SCHEDULE_VIEW[1] + CommonConstants.TRIP_SCHEDULE_VIEW[2] + param.lunarDate)
            .fontSize($r('app.float.font_size_common'))
            .fontColor($r('app.color.font_color_gray'))
            .width(CommonConstants.FULL_PERCENT)
            .fontWeight(FontWeight.Regular)

          TripScheduleView({
            mainWindowInfo: this.mainWindowInfo,
          })
        }
        .width(CommonConstants.FULL_PERCENT)
      }
      .width(CommonConstants.FULL_PERCENT)
      .padding({
        left: CommonConstants.COMMON_MARGIN,
        right: CommonConstants.COMMON_MARGIN
      })
      .backgroundColor($r('app.color.window_background'))
      .hideTitleBar(true)
    } else {
      NavDestination()
        .hideTitleBar(true)
    }
  }

  aboutToAppear(): void {
    this.navMode = NavigationMode.Stack;
  }

  build() {
    SideBarContainer((this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) ? SideBarContainerType.Embed :
      SideBarContainerType.Overlay) {
      CalendarSideBarView()

      Stack() {
        if (this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_LG) {
          Column()
            .height(CommonConstants.FULL_PERCENT)
            .width(CommonConstants.FULL_PERCENT)
            .backgroundColor($r('app.color.sidebar_stack'))
            .zIndex(1)
            .visibility(this.isShowingSidebar ? Visibility.Visible : Visibility.Hidden)
        }

        Column() {
          // [Start btn_change_navigation]
          Row() {
            // [StartExclude btn_change_navigation]
            Image($r('app.media.ic_public_back'))
              .width(40)
              .height(40)
              .margin({ right: 20 })
              .onClick(() => {
                this.pageInfos.pop();
              })
            Text(CommonConstants.TRIP_SCHEDULE_VIEW[3])
              .fontSize($r('app.float.symbol_font_size'))
              .lineHeight($r('app.float.line_height_or_top'))
              .fontWeight(FontWeight.Bold)
            Blank()
            // [EndExclude btn_change_navigation]

            if (this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_SM) {
              Column() {
                // [StartExclude btn_change_navigation]
                SegmentButton({
                  options: this.singleSelectCapsuleOptions,
                  selectedIndexes: $singleSelectCapsuleSelectedIndexes
                })
                // [EndExclude btn_change_navigation]
              }
              // [StartExclude btn_change_navigation]
              .width($r('app.float.navigation_width'))
              .height($r('app.float.image_size'))
              .padding({ top: $r('app.float.notes_c_margin') })

              Blank()

              Column() {
                SymbolGlyph($r('sys.symbol.thumbnails'))
                  .fontSize($r('app.float.symbol_font_size'))
                  .margin($r('app.float.margin_common'))
              }
              .width($r('app.float.image_size'))
              .height($r('app.float.image_size'))
              .borderRadius($r('app.float.border_radius_common'))
              .backgroundColor(deviceInfo.deviceType === '2in1' ? '' : $r('app.color.background_gray'))
              .margin({ right: $r('app.float.margin_common') })
              // [EndExclude btn_change_navigation]
              .onClick(() => {
                if (this.navMode === NavigationMode.Split) {
                  this.navMode = NavigationMode.Stack;
                } else if (this.navMode === NavigationMode.Stack && this.selectedItem.isTrip) {
                  this.navMode = NavigationMode.Split;
                }
              })
            }
            // [StartExclude btn_change_navigation]
            Column() {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize($r('app.float.symbol_font_size'))
                .margin($r('app.float.margin_common'))
            }
            .width($r('app.float.image_size'))
            .height($r('app.float.image_size'))
            .borderRadius($r('app.float.border_radius_common'))
            .backgroundColor(deviceInfo.deviceType === '2in1' ? '' : $r('app.color.background_gray'))
            .margin({ right: $r('app.float.margin_common') })

            Column() {
              SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
                .fontSize($r('app.float.symbol_font_size'))
                .margin($r('app.float.margin_common'))
            }
            .width($r('app.float.image_size'))
            .height($r('app.float.image_size'))
            .borderRadius($r('app.float.border_radius_common'))
            .backgroundColor(deviceInfo.deviceType === '2in1' ? '' : $r('app.color.background_gray'))
          }
          .height($r('app.float.image_size'))
          .width(CommonConstants.FULL_PERCENT)
          .padding({
            left: (deviceInfo.deviceType === '2in1' || this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_LG) ? $r('app.float.margin_row_top') :
              (this.monthStatus ? $r('app.float.margin_row_top') : CommonConstants.COMMON_MARGIN),
            right: deviceInfo.deviceType === '2in1' ? $r('app.float.margin_right') : CommonConstants.COMMON_MARGIN
          })
          .margin({
            top: deviceInfo.deviceType === '2in1' ? CommonConstants.COMMON_MARGIN : $r('app.float.margin_common'),
            bottom: CommonConstants.COMMON_MARGIN
          })

          if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM) {
            Row() {
              Column() {
                SegmentButton({
                  options: this.singleSelectCapsuleOptions,
                  selectedIndexes: $singleSelectCapsuleSelectedIndexes
                })
              }
              .width(CommonConstants.FULL_PERCENT)
              .padding({
                left: CommonConstants.COMMON_MARGIN,
                right: CommonConstants.COMMON_MARGIN
              })
              .height($r('app.float.segment_button_height'))
            }
            .width(CommonConstants.FULL_PERCENT)
            .height($r('app.float.image_size'))
          }
          // [EndExclude btn_change_navigation]
          // [Start navigation_calendar_view]
          Navigation(this.pathStack) {
            CalendarView({
              mainWindowInfo: this.mainWindowInfo,
              pathStack: this.pathStack,
            })
          }
          .navDestination(this.pageMap)
          .mode(this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM ? NavigationMode.Stack : this.navMode)
          // [StartExclude btn_change_navigation]
          // [StartExclude navigation_calendar_view]
          .backgroundColor($r('app.color.window_background'))
          .layoutWeight(1)
          .width(CommonConstants.FULL_PERCENT)
          .navBarWidthRange([$r('app.float.nav_bar_width_range'), $r('app.string.eighty_percent')])
          .navBarWidth((this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_LG || this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_XL) ?
            this.mainWindowInfo.windowSize.width - CommonConstants.SIDEBAR_WIDTH - CommonConstants.NOTES_SIDEBAR_WIDTH :
            this.mainWindowInfo.windowSize.width - CommonConstants.CALENDAR_CONTENT_WIDTH)
          .hideTitleBar(true)
          // [EndExclude navigation_calendar_view]
          // [EndExclude btn_change_navigation]
          .onNavigationModeChange((mode: NavigationMode) => {
            if (this.mainWindowInfo.widthBp === WidthBreakpoint.WIDTH_SM || mode === NavigationMode.Stack) {
              this.pathStack.clear();
            } else if (mode === NavigationMode.Split) {
              this.pathStack.pushPath({ name: this.selectedItem.date, param: this.selectedItem }, false);
            }
          })

          // [End btn_change_navigation]
        }
        .height(CommonConstants.FULL_PERCENT)
        .backgroundColor($r('app.color.window_background'))
        .padding({
          top: deviceInfo.deviceType === '2in1' ? CommonConstants.COMMON_ZERO : $r('app.float.navigation_margin_top')
        })
      }
      .height(CommonConstants.FULL_PERCENT)
      .backgroundColor($r('app.color.window_background'))
    }
    .height(CommonConstants.FULL_PERCENT)
    .width(CommonConstants.FULL_PERCENT)
    .showSideBar(this.isShowingSidebar)
    .sideBarWidth(CommonConstants.SIDEBAR_WIDTH)
    .controlButton({
      icons: {
        hidden: deviceInfo.deviceType === '2in1' ? $r('app.media.close_sidebar') :
          $r('app.media.close_sidebar_bg'),
        shown: deviceInfo.deviceType === '2in1' ? $r('app.media.open_sidebar_calendar') :
          $r('app.media.open_sidebar_bg'),
        switching: this.isShowingSidebar ?
          ('2in1' ? $r('app.media.open_sidebar_calendar') : $r('app.media.open_sidebar_bg')) :
          ('2in1' ? $r('app.media.close_sidebar') : $r('app.media.close_sidebar_bg'))
      },
      top: deviceInfo.deviceType === '2in1' ? CommonConstants.COMMON_MARGIN :
        CommonConstants.CONTROL_BUTTON_TOP,
      left: (deviceInfo.deviceType === '2in1' && this.isShowingSidebar) ?
        CommonConstants.CONTROL_BUTTON_LEFT : CommonConstants.COMMON_MARGIN,
      width: CommonConstants.CONTROL_BUTTON,
      height: CommonConstants.CONTROL_BUTTON
    })
    .onChange((value: boolean) => {
      this.isShowingSidebar = value;
      this.monthStatus = !value;
    })
    .backgroundColor($r('app.color.window_background'))
  }

}