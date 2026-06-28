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
const CASE: string = 'DanmakuFlow';

export default function danmakuFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_DanmakuViewExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_DanmakuViewExists begin`);
    // 验证弹幕视图存在
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.id('danmaku_view'));
    hilog.info(0x0000, TAG, `${CASE}_DanmakuViewExists end`);
    done();
  });

  it(CASE + '_DanmakuToggleExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_DanmakuToggleExists begin`);
    // 验证弹幕开关存在
    await driver.assertComponentExist(ON.id('danmaku_toggle'));
    hilog.info(0x0000, TAG, `${CASE}_DanmakuToggleExists end`);
    done();
  });

  it(CASE + '_SendDanmakuButtonExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SendDanmakuButtonExists begin`);
    // 验证发送弹幕按钮存在
    await driver.assertComponentExist(ON.id('send_danmaku'));
    hilog.info(0x0000, TAG, `${CASE}_SendDanmakuButtonExists end`);
    done();
  });

  it(CASE + '_ClickSendDanmaku', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ClickSendDanmaku begin`);
    // 点击发送弹幕按钮
    let btnSend = await driver.findComponent(ON.id('send_danmaku'));
    await btnSend.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_ClickSendDanmaku end`);
    done();
  });

  it(CASE + '_ToggleDanmaku', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ToggleDanmaku begin`);
    // 切换弹幕开关
    let toggleDanmaku = await driver.findComponent(ON.id('danmaku_toggle'));
    await toggleDanmaku.click();
    await driver.delayMs(1000);
    // 再次切换回来
    await toggleDanmaku.click();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_ToggleDanmaku end`);
    done();
  });

  it(CASE + '_DanmakuSettingsExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_DanmakuSettingsExists begin`);
    // 验证弹幕设置按钮存在
    await driver.assertComponentExist(ON.id('danmaku_settings'));
    hilog.info(0x0000, TAG, `${CASE}_DanmakuSettingsExists end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}