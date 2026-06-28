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

import { Driver, ON, MatchPattern } from '@ohos.UiTest';
import { it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import exit from './common/Exit';

const TAG: string = '[DanmakuPlayer_Test]';
const CASE: string = 'ControlFlow';

export default function controlFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_ControlPanelExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ControlPanelExists begin`);
    // 验证控制面板存在
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.id('control_panel'));
    hilog.info(0x0000, TAG, `${CASE}_ControlPanelExists end`);
    done();
  });

  it(CASE + '_PauseButtonExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_PauseButtonExists begin`);
    // 验证暂停按钮存在
    await driver.assertComponentExist(ON.id('pause_button'));
    hilog.info(0x0000, TAG, `${CASE}_PauseButtonExists end`);
    done();
  });

  it(CASE + '_FullscreenButtonExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_FullscreenButtonExists begin`);
    // 验证全屏按钮存在
    await driver.assertComponentExist(ON.id('fullscreen_button'));
    hilog.info(0x0000, TAG, `${CASE}_FullscreenButtonExists end`);
    done();
  });

  it(CASE + '_VolumePanelExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_VolumePanelExists begin`);
    // 验证音量控制面板存在
    await driver.assertComponentExist(ON.id('volume_panel'));
    hilog.info(0x0000, TAG, `${CASE}_VolumePanelExists end`);
    done();
  });

  it(CASE + '_BrightnessControlExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_BrightnessControlExists begin`);
    // 验证亮度控制存在（通常在屏幕左侧滑动区域）
    await driver.assertComponentExist(ON.id('brightness_control'));
    hilog.info(0x0000, TAG, `${CASE}_BrightnessControlExists end`);
    done();
  });

  it(CASE + '_SeekProgressExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SeekProgressExists begin`);
    // 验证拖动进度UI存在
    await driver.assertComponentExist(ON.id('seek_progress'));
    hilog.info(0x0000, TAG, `${CASE}_SeekProgressExists end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}