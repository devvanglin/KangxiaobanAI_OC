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
const CASE: string = 'MusicPlayerFlow';

export default function musicPlayerFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_EnterMusicPlayerPage', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_EnterMusicPlayerPage begin`);
    // 验证进入音乐播放器页面
    await driver.delayMs(2000);

    // 验证音乐播放器组件存在
    await driver.assertComponentExist(ON.id('music_player_info_comp'));
    hilog.info(0x0000, TAG, `${CASE}_EnterMusicPlayerPage end`);
    done();
  });

  it(CASE + '_ControlButtonsExist', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ControlButtonsExist begin`);
    // 验证控制按钮存在
    await driver.assertComponentExist(ON.id('btn_play_mode'));
    await driver.assertComponentExist(ON.id('btn_play_previous'));
    await driver.assertComponentExist(ON.id('btn_play_pause'));
    await driver.assertComponentExist(ON.id('btn_play_next'));
    hilog.info(0x0000, TAG, `${CASE}_ControlButtonsExist end`);
    done();
  });

  it(CASE + '_PlayMusic', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_PlayMusic begin`);
    // 测试播放音乐功能
    let btnPlay = await driver.findComponent(ON.id('btn_play_pause'));
    await btnPlay.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_PlayMusic end`);
    done();
  });

  it(CASE + '_PauseMusic', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_PauseMusic begin`);
    // 测试暂停音乐功能
    let btnPause = await driver.findComponent(ON.id('btn_play_pause'));
    await btnPause.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_PauseMusic end`);
    done();
  });

  it(CASE + '_NextMusic', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_NextMusic begin`);
    // 测试下一首功能
    let btnNext = await driver.findComponent(ON.id('btn_play_next'));
    await btnNext.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_NextMusic end`);
    done();
  });

  it(CASE + '_PreviousMusic', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_PreviousMusic begin`);
    // 测试上一首功能
    let btnPrevious = await driver.findComponent(ON.id('btn_play_previous'));
    await btnPrevious.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_PreviousMusic end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
