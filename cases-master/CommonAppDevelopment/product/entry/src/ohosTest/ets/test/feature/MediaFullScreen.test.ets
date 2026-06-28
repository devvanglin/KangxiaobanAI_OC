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

import { expect, it } from '@ohos/hypium';
import { DisplayRotation, Driver, MatchPattern, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'MediaFullScreen'; // 案例名称
const TAG: string = '[MediaFullScreen_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【视频全屏切换案例】自动化测试用例
 * 主要功能：测试视频是否正常横屏播放。
 * 执行步骤：
 * 1. 点击图片打开视频。
 * 2. 视频正常播放，窗口为横屏状态。
 * 3. 视频正常缩小，窗口恢复原本状态。
 */
export default function mediaFullScreenTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('视频全屏切换案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 点击图片打开视频。
   */
  it(CASE + '点击图片打开视频。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('mediaPic1'));
    let videoPic = await driver.findComponent(ON.id('mediaPic1'));
    await videoPic.click();
    await driver.delayMs(5000);
    await driver.assertComponentExist(ON.text('media_full_screen_video', MatchPattern.CONTAINS));
    done();
  })

  /**
   * 视频正常播放，窗口为横屏状态。
   */
  it(CASE + '视频正常播放，窗口为横屏状态。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('playingIcon'));
    let rotation = await driver.getDisplayRotation();
    console.info('rotation=', rotation);
    expect(rotation == DisplayRotation.ROTATION_90 || rotation == DisplayRotation.ROTATION_270).assertTrue();
    done();
  })

  /**
   * 视频正常缩小，窗口恢复原本状态。
   */
  it(CASE + '视频正常缩小，窗口恢复原本状态。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('collapseVideoButton'));
    let videoPic = await driver.findComponent(ON.id('collapseVideoButton'));
    await videoPic.click();
    await driver.delayMs(3000);
    let rotation = await driver.getDisplayRotation();
    expect(rotation == DisplayRotation.ROTATION_0).assertTrue();
    done();
  })

  exit('视频全屏切换案例');
}