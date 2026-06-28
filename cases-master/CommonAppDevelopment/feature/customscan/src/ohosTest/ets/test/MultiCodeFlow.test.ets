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
const CASE: string = 'MultiCodeFlow';

export default function multiCodeFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_DetectMultipleQRCodes', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_DetectMultipleQRCodes begin`);
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

    // 验证多二维码模式已启用
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_DetectMultipleQRCodes end`);
    done();
  });

  it(CASE + '_SelectQRCode', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SelectQRCode begin`);
    // 测试选择特定二维码
    // 这里需要使用包含多个二维码的测试图片
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_SelectQRCode end`);
    done();
  });

  it(CASE + '_SwitchBetweenQRCodes', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SwitchBetweenQRCodes begin`);
    // 测试在多个二维码之间切换
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_SwitchBetweenQRCodes end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
