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

import { expect, it } from '@ohos/hypium';
import { Driver, ON, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'FaceAndFingerPrintLocking'; // 案例名称
const TAG: string = '[FaceAndFingerPrintLocking_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【人脸指纹解锁案例】自动化测试用例
 * 主要功能：测试人脸指纹解锁。
 * 执行步骤：
 * 1. 打开指纹解锁界面。
 * 2. 打开人脸解锁界面。
 */
export default function faceAndFingerPrintLockingTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('人脸指纹解锁案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 打开指纹解锁界面。
   */
  it(CASE + '打开指纹解锁界面。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('fingerToggle'));
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('请先设置当前解锁方式');
    };
    observer.once('toastShow', callback);
    let textClick = await driver.findComponent(ON.id('fingerToggle'));
    await textClick.click();
    await driver.delayMs(DELAY_MS);

    done();
  })

  /**
   * 打开人脸解锁界面。
   */
  it(CASE + '打开人脸解锁界面。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('faceToggle'));
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('请先设置当前解锁方式');
    };
    observer.once('toastShow', callback);
    let textClick = await driver.findComponent(ON.id('faceToggle'));
    await textClick.click();
    await driver.delayMs(DELAY_MS);

    done();
  })

  exit('人脸指纹解锁案例');
}