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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class DetailConstants {
  /**
   * Product detail resources.
   */
  static readonly PRODUCT_DETAIL_RESOURCES: Resource[] = [$r('app.media.product_detail_1'),
    $r('app.media.product_detail_2'), $r('app.media.product_detail_2'), $r('app.media.product_detail_2'),
    $r('app.media.product_detail_3')];

  /**
   * Product small resources.
   */
  static readonly PRODUCT_SMALL_RESOURCES: Resource[] = [$r('app.media.product_small_1'),
    $r('app.media.product_small_2'), $r('app.media.product_small_2'), $r('app.media.product_small_2'),
    $r('app.media.product_small_3')];

  /**
   * Gradient color list.
   */
  static readonly GRADIENT_COLORS: string[] = ['#FF6354', '#CF0A2C', '#FAE8E0', '#FFC9C9'];

  /**
   * Product color selection.
   */
  static readonly PRODUCT_COLOR_SELECTION: Resource[] = [$r('app.media.product_small_1'),
    $r('app.media.product_small_2'), $r('app.media.product_small_3')];

  /**
   * Recommended config products.
   */
  static readonly RECOMMENDED_CONFIG_PRODUCTS: Resource[] = [$r('app.media.recommended_config_1'),
    $r('app.media.recommended_config_2'), $r('app.media.recommended_config_3'), $r('app.media.recommended_config_4')];

  /**
   * Button names.
   */
  static readonly BUTTON_NAMES = ((context: Context): string[] => {
    try {
      return [
        context.resourceManager.getStringSync($r('app.string.add_cart').id),
        context.resourceManager.getStringSync($r('app.string.buy').id)
      ];
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'DetailConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  });

  /**
   * Product config list.
   */
  static readonly PRODUCT_CONFIG_NAMES = ((context: Context): string[] => {
    try {
      return [
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES1').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES2').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES3').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES4').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES5').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES6').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES7').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_CONFIG_NAMES8').id)
      ];
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'DetailConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  });

  /**
   * User comment list.
   */
  static readonly USER_COMMENT_NAMES = ((context: Context): string[] => {
    try {
      return [
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES1').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES2').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES3').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES4').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES5').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES6').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES7').id),
        context.resourceManager.getStringSync($r('app.string.USER_COMMENT_NAMES8').id),
      ];
    }catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'DetailConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  });

  /**
   * List space.
   */
  static readonly PRODUCT_CONFIG_LIST_SPACE: number = 12;

  /**
   * Picture number.
   */
  static readonly PICTURE_INDICATOR = ((context: Context): string[] => {
    try {
      return ['/5', '3D',
        context.resourceManager.getStringSync($r('app.string.compare').id)]

    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'DetailConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  });
  /**
   * Picture list space list.
   */
  static readonly PICTURE_LIST_SPACES: string[] = ['8vp', '12vp', '16vp'];

  /**
   * Product discount name list.
   */
  static readonly PRODUCT_DISCOUNT_NAMES = ((context: Context): string[] => {
    try {
      return [
        context.resourceManager.getStringSync($r('app.string.PRODUCT_DISCOUNT_NAMES1').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_DISCOUNT_NAMES2').id),
        'Mate X5:',
        context.resourceManager.getStringSync($r('app.string.PRODUCT_DISCOUNT_NAMES3').id)];
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'DetailConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  });
  /**
   * Product price name list.
   */
  static readonly PRODUCT_PRICE_NAMES = ((context: Context): string[] => {
    try {
      return ['￥', '12999', '￥13999',
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES1').id),
        '07', ':', '14', ':', '50',
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES2').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES3').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES4').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES5').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES6').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES7').id),
        context.resourceManager.getStringSync($r('app.string.PRODUCT_PRICE_NAMES8').id)];
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(0x0000, 'DetailConstants', `Failed to get string. Code: ${err.code}, message: ${err.message}`);
      return [];
    }
  });

}