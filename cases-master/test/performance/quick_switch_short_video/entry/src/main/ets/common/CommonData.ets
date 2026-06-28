/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

/**
 * Player component status.
 */
export enum AVPlayerState {
  IDLE = 'idle',
  INITIALIZED = 'initialized',
  PREPARED = 'prepared',
  PLAYING = 'playing',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  STOPPED = 'stopped',
  RELEASED = 'released',
  ERROR = 'error',
}

/**
 * Common constants for all features.
 */
export class CommConstants {
  /**
   * Track Thickness size min
   */
  static readonly TRACK_SIZE_MIN: number = 4;
  /**
   * Track Thickness borderRadius
   */
  static readonly TRACK_BORDER_RADIUS: number = 2;
  /**
   * Track Thickness size max
   */
  static readonly TRACK_SIZE_MAX: number = 6;
  /**
   * Timer interval number
   */
  static readonly TIMER_INTERVAL: number = 100;
  /**
   * Video play icon width
   */
  static readonly IMAGE_PLAY_WIDTH: string = '56vp';
  /**
   * Video play icon height
   */
  static readonly IMAGE_PLAY_HEIGHT: string = '56vp';
  /**
   * The surface width
   */
  static readonly SURFACE_WIDTH: number = 1920;
  /**
   * The surface height
   */
  static readonly SURFACE_HEIGHT: number = 1080;
  /**
   * Text front size
   */
  static readonly TEXT_FRONT_SIZE: string = '20vp';
  /**
   * Text margin size
   */
  static readonly TEXT_MARGIN_LEFT: string = '2vp';
  /**
   * Text left width
   */
  static readonly TEXT_LEFT_WIDTH: string = '45%';
  /**
   * Text mid width
   */
  static readonly TEXT_MID_WIDTH: string = '10%';
  /**
   * Time text all width
   */
  static readonly TEXT_TIME_ALL_WIDTH: string = '100%';
  /**
   * Blank text height
   */
  static readonly TEXT_BLANK_HEIGHT: string = '25%';
  /**
   * Slider step
   */
  static readonly SLIDER_STEP: number = 0.1;
  /**
   * Slider min
   */
  static readonly SLIDER_MIN: number = 0;
  /**
   * Slider width
   */
  static readonly SLIDER_WIDTH: string = '100%';
  /**
   * Slider height
   */
  static readonly SLIDER_HEIGHT: string = '20';
  /**
   * Slider index
   */
  static readonly SLIDER_INDEX: number = 3;
  /**
   * Slider opacity
   */
  static readonly SLIDER_OPACITY: number = 0.5;
  /**
   * Slider padding
   */
  static readonly SLIDER_PADDING: string = '2vp';
  /**
   * Flex offset x
   */
  static readonly FLEX_OFFSET_X: number = 0;
  /**
   * Flex offset y
   */
  static readonly FLEX_OFFSET_Y: number = 350;
  /**
   * Flex width
   */
  static readonly FLEX_WIDTH: string = '100%';
  /**
   * Flex height
   */
  static readonly FLEX_HEIGHT: string = '20%';
  /**
   * Flex index
   */
  static readonly FLEX_INDEX: number = 2;
  /**
   * Flex frame index
   */
  static readonly FLEX_FRAME_INDEX: number = 3;
  /**
   * Play image index
   */
  static readonly PLAY_IMAGE_INDEX: number = 2;
  /**
   * Column index
   */
  static readonly COLUMN_INDEX: number = 1;
  /**
   * Width percent full
   */
  static readonly WIDTH_FULL_PERCENT: string = '100%';
  /**
   * Height percent full
   */
  static readonly HEIGHT_FULL_PERCENT: string = '100%';
  /**
   * Height percent full
   */
  static readonly CACHED_COUNT: number = 3;
  /**
   * Seek hour unit
   */
  static readonly HOUR_UNIT: number = 60;
  /**
   * Second to Millisecond
   */
  static readonly SECOND_TO_MS: number = 1000;
  /**
   * Time const number
   */
  static readonly TIME_CONST_TEN: number = 10;
  /**
   * CurIndex default number
   */
  static readonly CURINDEX_DEFAULT_NUM: number = -1;
  /**
   * Divider height number
   */
  static readonly DIVIDER_HEIGHT: number = 14;
  /**
   * Divider width number
   */
  static readonly DIVIDER_WIDTH: number = 2;
  /**
   * Divider opacity
   */
  static readonly DIVIDER_OPACITY: number = 0.5;
  /**
   * Divider margin
   */
  static readonly DIVIDER_MARGIN: number = 8;
  /**
   * Divider x
   */
  static readonly DIVIDER_X: number = 0;
  /**
   * Divider y
   */
  static readonly DIVIDER_y: number = 0;
  /**
   * Divider z
   */
  static readonly DIVIDER_Z: number = 1;
  /**
   * Divider center x
   */
  static readonly DIVIDER_CENTER_X: string = '50%';
  /**
   * Divider center y
   */
  static readonly DIVIDER_CENTER_Y: string = '50%';
  /**
   * Divider angle
   */
  static readonly DIVIDER_ANGLE: number = 30;
  /**
   * Blank 600
   */
  static readonly BLANK_LEN_600: number = 600;
  /**
   * Blank 50
   */
  static readonly BLANK_LEN_50: number = 50;
  /**
   * Duration time
   */
  static readonly DURATION_TIME: number = 300;
}