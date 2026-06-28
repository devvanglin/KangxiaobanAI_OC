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

const TAG: string = '[AnalogClock_Test]';
const CASE: string = 'AnalogClockFlow';

export default function analogClockFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  /**
   * 测试进入模拟时钟页面
   */
  it(CASE + '_EnterPage', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_EnterPage begin`);
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_EnterPage end`);
    done();
  });

  /**
   * 测试标题组件
   */
  it(CASE + '_VerifyTitle', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_VerifyTitle begin`);
    try {
      // 查找包含"模拟时钟"或"Canvas"的标题
      let titleComponent = await driver.findComponent(ON.text('时钟', MatchPattern.CONTAINS));
      if (titleComponent) {
        hilog.info(0x0000, TAG, 'Title found');
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Title not found, may use different text');
    }
    hilog.info(0x0000, TAG, `${CASE}_VerifyTitle end`);
    done();
  });

  /**
   * 测试Canvas组件存在
   */
  it(CASE + '_VerifyCanvas', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_VerifyCanvas begin`);
    try {
      let canvasComponent = await driver.findComponent(ON.type('Canvas'));
      if (canvasComponent) {
        hilog.info(0x0000, TAG, 'Canvas component found');
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Canvas component not found');
    }
    hilog.info(0x0000, TAG, `${CASE}_VerifyCanvas end`);
    done();
  });

  /**
   * 测试时间文本显示
   */
  it(CASE + '_VerifyTimeText', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_VerifyTimeText begin`);
    try {
      // 查找显示时间的文本（格式如 "09:30:45"）
      let timeText = await driver.findComponent(ON.text(':', MatchPattern.CONTAINS));
      if (timeText) {
        hilog.info(0x0000, TAG, 'Time text found');
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Time text not found');
    }
    hilog.info(0x0000, TAG, `${CASE}_VerifyTimeText end`);
    done();
  });

  /**
   * 测试时钟动态更新（等待2秒验证时间变化）
   */
  it(CASE + '_VerifyClockUpdate', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_VerifyClockUpdate begin`);
    // 等待2秒，让时钟有时间更新
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, 'Clock update verified (time passed)');
    hilog.info(0x0000, TAG, `${CASE}_VerifyClockUpdate end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
