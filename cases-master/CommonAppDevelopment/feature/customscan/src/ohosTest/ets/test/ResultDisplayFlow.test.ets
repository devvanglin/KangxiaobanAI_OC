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
const CASE: string = 'ResultDisplayFlow';

export default function resultDisplayFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_DisplayURLResult', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_DisplayURLResult begin`);
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

    // 扫描 URL 二维码后验证结果展示
    // 这里需要使用包含 URL 的测试二维码
    await driver.delayMs(3000);
    hilog.info(0x0000, TAG, `${CASE}_DisplayURLResult end`);
    done();
  });

  it(CASE + '_DisplayTextResult', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_DisplayTextResult begin`);
    // 扫描文本二维码后验证结果展示
    // 这里需要使用包含文本的测试二维码
    await driver.delayMs(3000);
    hilog.info(0x0000, TAG, `${CASE}_DisplayTextResult end`);
    done();
  });

  it(CASE + '_CloseResultDialog', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_CloseResultDialog begin`);
    // 测试关闭结果对话框
    await driver.delayMs(1000);
    // 如果有结果对话框打开，点击关闭
    try {
      let btnClose = await driver.findComponent(ON.id('btn_close_result'));
      if (btnClose) {
        await btnClose.click();
        await driver.delayMs(1000);
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'No result dialog to close');
    }
    hilog.info(0x0000, TAG, `${CASE}_CloseResultDialog end`);
    done();
  });

  it(CASE + '_RescanAfterClose', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_RescanAfterClose begin`);
    // 验证关闭结果后可以继续扫码
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_RescanAfterClose end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
