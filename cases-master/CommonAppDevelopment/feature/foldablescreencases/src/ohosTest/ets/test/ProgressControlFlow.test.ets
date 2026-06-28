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

import { Driver, ON } from '@ohos.UiTest';
import { it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import exit from './common/Exit';

const TAG: string = '[FoldableScreen_Test]';
const CASE: string = 'ProgressControlFlow';

export default function progressControlFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_SliderExist', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SliderExist begin`);
    // 验证进度条存在
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('music_progress_slider'));
    hilog.info(0x0000, TAG, `${CASE}_SliderExist end`);
    done();
  });

  it(CASE + '_TimeDisplay', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_TimeDisplay begin`);
    // 验证时间显示存在
    await driver.assertComponentExist(ON.id('current_time_text'));
    await driver.assertComponentExist(ON.id('total_time_text'));
    hilog.info(0x0000, TAG, `${CASE}_TimeDisplay end`);
    done();
  });

  it(CASE + '_ProgressDrag', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ProgressDrag begin`);
    // 测试进度拖动功能
    let slider = await driver.findComponent(ON.id('music_progress_slider'));
    await slider.dragTo(100, 0);
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_ProgressDrag end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
