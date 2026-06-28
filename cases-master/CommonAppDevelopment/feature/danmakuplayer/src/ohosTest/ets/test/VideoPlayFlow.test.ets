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
const CASE: string = 'VideoPlayFlow';

export default function videoPlayFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_EnterPlayerPage', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_EnterPlayerPage begin`);
    // 验证进入视频播放页面
    await driver.delayMs(2000);

    // 处理权限弹窗（如果有）
    try {
      let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
      if (btnPermission) {
        await btnPermission.click();
        await driver.delayMs(1000);
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'No permission dialog');
    }

    // 验证视频播放器组件存在
    await driver.assertComponentExist(ON.id('video_player'));
    hilog.info(0x0000, TAG, `${CASE}_EnterPlayerPage end`);
    done();
  });

  it(CASE + '_PlayButtonExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_PlayButtonExists begin`);
    // 验证播放按钮存在
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('play_button'));
    hilog.info(0x0000, TAG, `${CASE}_PlayButtonExists end`);
    done();
  });

  it(CASE + '_ClickPlay', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ClickPlay begin`);
    // 点击播放按钮
    let btnPlay = await driver.findComponent(ON.id('play_button'));
    await btnPlay.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_ClickPlay end`);
    done();
  });

  it(CASE + '_ProgressSliderExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_ProgressSliderExists begin`);
    // 验证进度条存在
    await driver.assertComponentExist(ON.id('progress_slider'));
    hilog.info(0x0000, TAG, `${CASE}_ProgressSliderExists end`);
    done();
  });

  it(CASE + '_TimeDisplayExists', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_TimeDisplayExists begin`);
    // 验证时间显示存在
    await driver.assertComponentExist(ON.id('current_time'));
    await driver.assertComponentExist(ON.id('total_time'));
    hilog.info(0x0000, TAG, `${CASE}_TimeDisplayExists end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}