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
import { DisplayRotation, Driver, MatchPattern, ON, UiDirection } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'VideoScreenDirectionSwitching'; // 案例名称
const TAG: string = '[VideoScreenDirectionSwitching_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【视频横竖屏切换及进度条热区拖动案例】自动化测试用例
 * 主要功能：测试视频是否正常横竖屏播放。
 * 执行步骤：
 * 1. 上下切换视频。
 * 2. 视频正常播放，窗口为竖屏状态。
 * 3. 点击全屏按钮，视频横屏。
 * 4. 点击返回按钮，视频返回竖屏。
 */
export default function videoScreenDirectionSwitchingTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('视频横竖屏切换及进度条热区拖动案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 上下切换视频。
   */
  it(CASE + '上下切换视频。', 0, async (done: Function) => {
    await driver.fling(UiDirection.DOWN, 10000);
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('金莲步', MatchPattern.CONTAINS));
    await driver.fling(UiDirection.UP, 10000);
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('伤心千古', MatchPattern.CONTAINS));
    done();
  })

  /**
   * 视频正常播放，窗口为竖屏状态。
   */
  it(CASE + '视频正常播放，窗口为竖屏状态。', 0, async (done: Function) => {
    let rotation = await driver.getDisplayRotation();
    expect(rotation == DisplayRotation.ROTATION_0).assertTrue();
    await driver.delayMs(3000);
    done();
  })

  /**
   * 点击全屏按钮，视频横屏。
   */
  it(CASE + '点击全屏按钮，视频横屏。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('fullScreenPlayButton'));
    let videoPic = await driver.findComponent(ON.id('fullScreenPlayButton'));
    await videoPic.click();
    await driver.delayMs(DELAY_MS);
    let rotation = await driver.getDisplayRotation();
    expect(rotation == DisplayRotation.ROTATION_270).assertTrue();
    done();
  })

  /**
   * 点击返回按钮，视频返回竖屏。
   */
  it(CASE + '点击返回按钮，视频返回竖屏。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('fullScreenBackButton'));
    let videoPic = await driver.findComponent(ON.id('fullScreenBackButton'));
    await videoPic.click();
    await driver.delayMs(DELAY_MS);
    let rotation = await driver.getDisplayRotation();
    expect(rotation == DisplayRotation.ROTATION_0).assertTrue();
    done();
  })

  exit('视频横竖屏切换及进度条热区拖动案例');

}