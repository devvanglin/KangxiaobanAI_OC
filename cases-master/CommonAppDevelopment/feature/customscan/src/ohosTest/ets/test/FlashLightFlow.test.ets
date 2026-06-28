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

import { Driver, ON, MatchPattern } from '@ohos.UiTest';
import { it } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import exit from './common/Exit';

const TAG: string = '[CustomScan_Test]';
const CASE: string = 'FlashLightFlow';

export default function flashLightFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_OpenFlashLight', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_OpenFlashLight begin`);
    // 处理权限
    await driver.delayMs(2000);
    try {
      let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
      if (btnPermission) {
        await btnPermission.click();
        await driver.delayMs(1000);
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Permission already granted');
    }

    // 点击闪光灯按钮打开闪光灯
    let btnFlashLight = await driver.findComponent(ON.id('btn_flashlight'));
    await btnFlashLight.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_OpenFlashLight end`);
    done();
  });

  it(CASE + '_CloseFlashLight', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_CloseFlashLight begin`);
    // 再次点击闪光灯按钮关闭闪光灯
    let btnFlashLight = await driver.findComponent(ON.id('btn_flashlight'));
    await btnFlashLight.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_CloseFlashLight end`);
    done();
  });

  it(CASE + '_ToggleFlashLight', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ToggleFlashLight begin`);
    // 测试多次切换闪光灯状态
    let btnFlashLight = await driver.findComponent(ON.id('btn_flashlight'));
    await btnFlashLight.click();
    await driver.delayMs(500);
    await btnFlashLight.click();
    await driver.delayMs(500);
    await btnFlashLight.click();
    await driver.delayMs(500);
    await btnFlashLight.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_ToggleFlashLight end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
