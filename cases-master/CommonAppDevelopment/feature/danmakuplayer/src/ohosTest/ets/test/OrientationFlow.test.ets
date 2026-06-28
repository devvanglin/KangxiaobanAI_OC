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
const CASE: string = 'OrientationFlow';

export default function orientationFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_InitialPortraitMode', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_InitialPortraitMode begin`);
    // 验证初始竖屏模式
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.id('video_player'));
    hilog.info(0x0000, TAG, `${CASE}_InitialPortraitMode end`);
    done();
  });

  it(CASE + '_ClickFullscreenButton', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ClickFullscreenButton begin`);
    // 点击全屏按钮
    let btnFullscreen = await driver.findComponent(ON.id('fullscreen_button'));
    await btnFullscreen.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_ClickFullscreenButton end`);
    done();
  });

  it(CASE + '_LandscapeMode', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_LandscapeMode begin`);
    // 验证横屏模式
    await driver.assertComponentExist(ON.id('video_player'));
    // 验证横屏时显示锁定按钮
    await driver.assertComponentExist(ON.id('lock_button'));
    hilog.info(0x0000, TAG, `${CASE}_LandscapeMode end`);
    done();
  });

  it(CASE + '_BackButtonExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_BackButtonExists begin`);
    // 验证横屏时返回按钮存在
    await driver.assertComponentExist(ON.id('back_button'));
    hilog.info(0x0000, TAG, `${CASE}_BackButtonExists end`);
    done();
  });

  it(CASE + '_ClickBackButton', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ClickBackButton begin`);
    // 点击返回按钮，退出横屏
    let btnBack = await driver.findComponent(ON.id('back_button'));
    await btnBack.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_ClickBackButton end`);
    done();
  });

  it(CASE + '_ReturnToPortrait', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ReturnToPortrait begin`);
    // 验证返回到竖屏模式
    await driver.assertComponentExist(ON.id('video_player'));
    hilog.info(0x0000, TAG, `${CASE}_ReturnToPortrait end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}