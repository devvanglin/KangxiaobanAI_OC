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
const CASE: string = 'PlayModeFlow';

export default function playModeFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_SwitchPlayMode', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SwitchPlayMode begin`);
    // 测试播放模式切换功能
    await driver.delayMs(1000);

    // 点击播放模式按钮多次，测试不同模式切换
    let btnPlayMode = await driver.findComponent(ON.id('btn_play_mode'));
    for (let i = 0; i < 4; i++) {
      await btnPlayMode.click();
      await driver.delayMs(500);
    }
    hilog.info(0x0000, TAG, `${CASE}_SwitchPlayMode end`);
    done();
  });

  it(CASE + '_LoopModeSingle', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_LoopModeSingle begin`);
    // 测试单曲循环模式
    let btnPlayMode = await driver.findComponent(ON.id('btn_play_mode'));
    await btnPlayMode.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_LoopModeSingle end`);
    done();
  });

  it(CASE + '_LoopModeList', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_LoopModeList begin`);
    // 测试列表循环模式
    let btnPlayMode = await driver.findComponent(ON.id('btn_play_mode'));
    await btnPlayMode.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_LoopModeList end`);
    done();
  });

  it(CASE + '_LoopModeShuffle', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_LoopModeShuffle begin`);
    // 测试随机播放模式
    let btnPlayMode = await driver.findComponent(ON.id('btn_play_mode'));
    await btnPlayMode.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_LoopModeShuffle end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
