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
import { it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import exit from './common/Exit';

const TAG: string = '[CustomScan_Test]';
const CASE: string = 'CustomScanFlow';

export default function customScanFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_EnterScanPage', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_EnterScanPage begin`);
    // 验证进入扫码页面
    await driver.delayMs(2000);

    // 处理相机权限弹窗
    try {
      let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
      if (btnPermission) {
        await btnPermission.click();
        await driver.delayMs(1000);
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Permission already granted');
    }

    // 验证相机流组件存在
    await driver.assertComponentExist(ON.id('camera_component'));
    hilog.info(0x0000, TAG, `${CASE}_EnterScanPage end`);
    done();
  });

  it(CASE + '_ScanLineAppears', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ScanLineAppears begin`);
    // 验证扫描线动画出现
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('scan_line'));
    hilog.info(0x0000, TAG, `${CASE}_ScanLineAppears end`);
    done();
  });

  it(CASE + '_ControlButtonsExist', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ControlButtonsExist begin`);
    // 验证控制按钮存在
    await driver.assertComponentExist(ON.id('btn_flashlight'));
    await driver.assertComponentExist(ON.id('btn_gallery'));
    hilog.info(0x0000, TAG, `${CASE}_ControlButtonsExist end`);
    done();
  });

  it(CASE + '_ContinuousScan', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ContinuousScan begin`);
    // 测试连续扫码功能
    // 这里需要使用真实二维码进行测试
    await driver.delayMs(3000);
    hilog.info(0x0000, TAG, `${CASE}_ContinuousScan end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
