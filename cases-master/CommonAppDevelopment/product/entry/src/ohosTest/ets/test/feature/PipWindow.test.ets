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
import { Driver, ON } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'PipWindow'; // 案例名称
const TAG: string = '[PipWindow_Test]';
const NETWORK_DELAY_MS: number = 4000; // 当网络状态不好时，等待四秒延时
const DELAY_MS: number = 500; // 指定500ms的延迟
const CASE_NANE: string = '视频悬浮窗'; // 案例中文名称

/**
 * 【视频悬浮窗】自动化测试用例（注：目前测试框架暂不支持测试画中画相关功能，画中画部分需要手动测试）
 * 1. 点击暂停图标，视频暂停
 * 2. 点击播放图标，视频继续播放
 * 3. 双击视频播放区，视频暂停
 * 4. 双击视频播放区，视频继续播放
 * 5. 向上滑动视频播放区左半部分，调节视频亮度
 * 6. 向上滑动视频播放区右半部分，调节视频声音
 */
export default function pipWindowTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NANE);
  let driver = Driver.create();
  let pipWindow_isPlaying: boolean = false;
  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    pipWindow_isPlaying = data.data?.pipWindow_isPlaying;
  })

  /**
   * 点击图标视频暂停
   */
  it(CASE + 'PipWindow_ChangePlaying_001', 0, async (done: Function) => {
    // 当网络状态不好时，等待两秒延时
    await driver.delayMs(NETWORK_DELAY_MS);

    let isPlaying = await driver.findComponent(ON.id('isPlaying'));
    await isPlaying.click();
    await driver.delayMs(DELAY_MS);
    expect(pipWindow_isPlaying).assertEqual(false); // 判断点击图标后视频暂停
    done();
  })

  /**
   * 点击图标视频播放
   */
  it(CASE + 'PipWindow_ChangePlaying_002', 0, async (done: Function) => {
    let isPlaying = await driver.findComponent(ON.id('isPlaying'));
    await isPlaying.click();
    await driver.delayMs(DELAY_MS);
    expect(pipWindow_isPlaying).assertEqual(true); // 判断点击图标后视频播放
    done();
  })

  /**
   * 双击视频播放页面视频暂停
   */
  it(CASE + 'PipWindow_ChangePlaying_003', 0, async (done: Function) => {
    let XComponentView = await driver.findComponent(ON.id('XComponentView'));
    await XComponentView.doubleClick();
    await driver.delayMs(DELAY_MS);
    expect(pipWindow_isPlaying).assertEqual(false); // 判断双击视频播放页面视频暂停
    done();
  })

  /**
   * 双击视频播放页面视频播放
   */
  it(CASE + 'PipWindow_ChangePlaying_004', 0, async (done: Function) => {
    let XComponentView = await driver.findComponent(ON.id('XComponentView'));
    await XComponentView.doubleClick();
    await driver.delayMs(DELAY_MS);
    expect(pipWindow_isPlaying).assertEqual(true); // 判断双击视频播放页面视频播放
    done();
  })

  /**
   * 滑动视频播放页面改变视频亮度
   */
  it(CASE + 'PipWindow_Brightness_001', 0, async (done: Function) => {
    let XComponentView = await driver.findComponent(ON.id('XComponentView'));
    // XComponentView.getBounds();获取视频播放页面的边框信息
    let rect = await XComponentView.getBounds();
    logger.info(TAG, JSON.stringify(rect));
    // 开始的滑动的起始点为(rect.left + 100,rect.bottom - 200),结束点为(rect.left + 100,rect.bottom - 700)，指的是从距离视频播放页面最左边100vp的地方开始向上滑动500vp。1000指的是滑动速率。
    await driver.swipe(rect.left + 100, rect.bottom - 200, rect.left + 100, rect.bottom - 700, 1000);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 滑动视频播放页面改变视频声音
   */
  it(CASE + 'PipWindow_Sound_001', 0, async (done: Function) => {
    let XComponentView = await driver.findComponent(ON.id('XComponentView'));
    let rect = await XComponentView.getBounds();
    logger.info(TAG, JSON.stringify(rect));
    // 开始的滑动的起始点为rect.right - 100,rect.bottom - 200),结束点为(rect.right - 100,rect.bottom - 700)，指的是从距离视频播放页面最右边100vp的地方开始向上滑动500vp。1000指的是滑动速率。
    await driver.swipe(rect.right - 100, rect.bottom - 200, rect.right - 100, rect.bottom - 700, 1000);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 退出案例
   */
  exit(CASE_NANE)

}