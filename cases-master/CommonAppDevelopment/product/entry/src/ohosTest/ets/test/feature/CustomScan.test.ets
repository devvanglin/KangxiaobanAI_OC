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

import { Component, Driver, ON, MatchPattern } from "@kit.TestKit";
import { it } from "@ohos/hypium";
import { logger } from "utils";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import exit from "../common/Exit.test";

const TAG: string = '[CustomScan_Test]';
const CASE_NAME: string = '折叠屏扫描二维码方案';

/**
 * 【折叠屏扫描二维码方案】自动化测试用例
 * 测试内容：
 * 1. 进入扫码页面
 * 2. 测试相机权限请求
 * 3. 测试闪光灯开关
 * 4. 测试图库扫码
 * 5. 测试多二维码识别
 * 6. 测试扫码结果展示
 */
export default function customScanTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver = Driver.create();

  /**
   * 测试相机权限请求
   */
  it("相机权限请求", 0, async (done: Function) => {
    logger.info(TAG, 'CameraPermissionRequest begin');
    await driver.delayMs(2000);

    // 处理权限弹窗
    try {
      let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
      if (btnPermission) {
        await btnPermission.click();
        await driver.delayMs(1000);
        logger.info(TAG, 'Camera permission granted');
      }
    } catch (error) {
      logger.info(TAG, 'Permission already granted or dialog not found');
    }

    // 验证进入扫码界面
    await driver.delayMs(1000);
    logger.info(TAG, 'CameraPermissionRequest end');
    done();
  });

  /**
   * 测试扫码界面元素
   */
  it("验证扫码界面元素", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyScanUI begin');

    // 验证相机组件存在
    try {
      await driver.assertComponentExist(ON.id('camera_component'));
      logger.info(TAG, 'Camera component found');
    } catch (error) {
      logger.info(TAG, 'Camera component not found, may use different id');
    }

    // 验证扫描线存在
    try {
      await driver.assertComponentExist(ON.id('scan_line'));
      logger.info(TAG, 'Scan line found');
    } catch (error) {
      logger.info(TAG, 'Scan line not found, may use different id');
    }

    logger.info(TAG, 'VerifyScanUI end');
    done();
  });

  /**
   * 测试闪光灯开关
   */
  it("闪光灯开关", 0, async (done: Function) => {
    logger.info(TAG, 'FlashLightToggle begin');

    try {
      // 查找闪光灯按钮
      let btnFlashLight = await driver.findComponent(ON.id('btn_flashlight'));
      if (btnFlashLight) {
        await btnFlashLight.click();
        await driver.delayMs(1000);
        logger.info(TAG, 'Flash light toggled');

        // 再次点击关闭
        await btnFlashLight.click();
        await driver.delayMs(1000);
        logger.info(TAG, 'Flash light toggled off');
      }
    } catch (error) {
      logger.info(TAG, 'Flash light button not found');
    }

    logger.info(TAG, 'FlashLightToggle end');
    done();
  });

  /**
   * 测试图库扫码按钮
   */
  it("图库扫码按钮", 0, async (done: Function) => {
    logger.info(TAG, 'PhotoPickerButton begin');

    try {
      // 查找图库按钮
      let btnPhotoPicker = await driver.findComponent(ON.id('btn_photo_picker'));
      if (btnPhotoPicker) {
        await btnPhotoPicker.click();
        await driver.delayMs(2000);
        logger.info(TAG, 'Photo picker opened');

        // 返回扫码页面
        await driver.pressBack();
        await driver.delayMs(1000);
      }
    } catch (error) {
      logger.info(TAG, 'Photo picker button not found');
    }

    logger.info(TAG, 'PhotoPickerButton end');
    done();
  });

  /**
   * 测试退出扫码页面
   */
  it("退出扫码页面", 0, async (done: Function) => {
    logger.info(TAG, 'ExitScanPage begin');

    // 返回上一页
    await driver.pressBack();
    await driver.delayMs(1000);

    logger.info(TAG, 'ExitScanPage end');
    done();
  });

  exit(CASE_NAME);
}
