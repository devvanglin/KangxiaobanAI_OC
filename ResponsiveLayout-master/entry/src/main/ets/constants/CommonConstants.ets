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

import { CalendarItem } from '../views/TripleCanlendarView/model/CalendarItem';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TripData } from '../views/TripleCanlendarView/model/TripData';

const uiContext: UIContext | undefined = AppStorage.get('uiContext');
const context = uiContext?.getHostContext() as common.UIAbilityContext;

/**
 * Common constants for all features.
 */
export class CommonConstants {
  /**
   * start time.
   */
  static readonly START_TIME: number = -1;
  /**
   * The week message on calendar page.
   */
  static readonly WEEK_MESSAGE: Array<string> = (() => {
    try {
      return context.resourceManager.getStringArrayValueSync($r('app.strarray.week_message').id);
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'CommonConstants', `Failed to get week message. Code: ${err.code}, message: ${err.message}`);
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
  })();
  /**
   * grid column template.
   */
  static readonly GRID_COLUMN_TEMPLATE: string = '1fr 1fr 1fr 1fr 1fr 1fr 1fr';
  /**
   * grid row template.
   */
  static readonly GRID_ROW_TEMPLATE: string = '1fr 1fr 1fr 1fr 1fr';
  /**
   * The calendar message.
   */
  static readonly CALENDAR_TIME_MESSAGE : Array<CalendarItem | string> = (() => {
    try {
      const stringArray = context.resourceManager.getStringArrayValueSync($r('app.strarray.september').id);
      const tripIndices = [11, 15, 24]
      const nextMonthIndices = [30, 31, 32, 33, 34]
      const calendarItems = stringArray.map((value, index) => {
        const id = (index + 1).toString();
        const isNextMonth = nextMonthIndices.includes(index);
        const isTrip = tripIndices.includes(index);
        if (isTrip) {
          return new CalendarItem(id, value, isNextMonth, true);
        } else {
          return new CalendarItem(id, value, isNextMonth)
        }
      });
      return calendarItems
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'CommonConstants', `Failed to get week message. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  })();

  /**
   * The full percentage of component.
   */
  static readonly FULL_PERCENT: string = '100%';
  /**
   * Control button.
   */
  static readonly CONTROL_BUTTON: number = 40;
  /**
   * Calendar sideBar width.
   */
  static readonly SIDEBAR_WIDTH: number = 240;
  /**
   * Notes sideBar width.
   */
  static readonly NOTES_SIDEBAR_WIDTH: number = 304;
  /**
   * Calendar content width.
   */
  static readonly CALENDAR_CONTENT_WIDTH: number = 346;
  /**
   * Control button left.
   */
  static readonly CONTROL_BUTTON_LEFT: number = 256;
  /**
   * Control button top.
   */
  static readonly CONTROL_BUTTON_TOP: number = 44;
  /**
   * Common margin.
   */
  static readonly COMMON_MARGIN: number = 16;
  /**
   * Common zero.
   */
  static readonly COMMON_ZERO: number = 0;
  /**
   * Common one.
   */
  static readonly COMMON_ONE: number = 1;
  /**
   * Common five.
   */
  static readonly COMMON_FIVE: number = 5;
  /**
   * Common six.
   */
  static readonly COMMON_SIX: number = 6;
  /**
   * Common seven.
   */
  static readonly COMMON_SEVEN: number = 7;
  /**
   * The trip schedule.
   */
  static readonly TRIP_SCHEDULE: Array<TripData> = (() => {
    try {
      return [
        new TripData('08:00', '09:00', context.resourceManager.getStringSync($r('app.string.trip_schedule1').id),
          true),
        new TripData('08:00', '09:20', context.resourceManager.getStringSync($r('app.string.trip_schedule2').id),
          true, 'F1A3-F78G'),
        new TripData('11:00', '11:20', context.resourceManager.getStringSync($r('app.string.trip_schedule3').id),
          false, 'A3F4-2501'),
        new TripData('11:30', '12:00', context.resourceManager.getStringSync($r('app.string.trip_schedule4').id),
          false, 'A3F4-2501'),
        new TripData('14:00', '15:20', context.resourceManager.getStringSync($r('app.string.trip_schedule5').id),
          false, 'A5F4-2506')
      ];
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'CommonConstants', `Failed to get trip schedule. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  })();

  /**
   * Trip schedule view.
   */
  static readonly TRIP_SCHEDULE_VIEW: Array<string> =(() => {
    try {
      return context.resourceManager.getStringArrayValueSync($r('app.strarray.trip_schedule_view').id);
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'CommonConstants', `Failed to get trip schedule. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  })();
  /**
   * Calendar side bar view text list.
   */
  static readonly CALENDAR_SIDE_BAR_TEXT: Array<string> = (() => {
    try {
      return context.resourceManager.getStringArrayValueSync($r('app.strarray.calendar_side_bar_text').id);
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'CommonConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  })();
  /**
   * Common font weight 500.
   */
  static readonly FONT_WEIGHT_500: number = 500;
  /**
   * Common font weight 400.
   */
  static readonly FONT_WEIGHT_400: number = 400;
  /**
   * Trip list.
   */
  static readonly TRIP_LIST: Array<number> = [1, 2];
  /**
   * Text opacity.
   */
  static readonly TEXT_OPACITY: number[] = [1, 0.4, 0.6, 0.05];

  /**
   * Two.
   */
  static readonly TWO: number = 2;

  /**
   * Four.
   */
  static readonly FOUR: number = 4;

  /**
   * Five.
   */
  static readonly FIVE: number = 5;

  /**
   * Constant for screen dpi.
   */
  static readonly SCREEN_DPI_CONSTANT: number = 160;

  /**
   * Device types.
   */
  static readonly DEVICE_TYPES: string[] = ['2in1', 'tablet'];

  /**
   * Tab bar height for sm and md.
   */
  static readonly TAB_BAR_HEIGHT: number = 56;

  /**
   * Bottom rect height.
   */
  static readonly BOTTOM_RECT_HEIGHT: number = 24;

  /**
   * Bind sheet page type list.
   */
  static readonly BIND_SHEET_PAGE_TYPES: string[] = ['ShopBag', 'PayCard', 'ProductDetail', 'detailPayCard'];

}