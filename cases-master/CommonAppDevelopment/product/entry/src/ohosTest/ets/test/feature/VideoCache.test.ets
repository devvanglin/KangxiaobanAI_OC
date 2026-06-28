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
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '边缓存边播放案例';

/**
 * 【边缓存边播放案例】自动化测试用例
 */
export default function videoCacheTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 播放的时候，播放进度小于等于缓存的进度
   */
  it(CASE_NAME + '_cache', 0, async (done: Function) => {
    // 加载需要较长时间
    await driver.delayMs(5000);
    await driver.assertComponentExist(ON.id('videoSwitch'));
    let currentCachePercent: number | undefined = AppStorage.get<number>('currentCachePercent');
    expect(currentCachePercent).assertLarger(0);
    let currentPercent: number | undefined = AppStorage.get<number>('VideoCacheCurrentPercent');
    let flag = currentCachePercent !== undefined && currentPercent !== undefined && currentCachePercent >= currentPercent;
    expect(flag).assertTrue();

    done();
  })

  /**
   * 点击暂停按钮暂停
   */
  it(CASE_NAME + '_click_pause', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('videoSwitch'));
    let videoSwitch = await driver.findComponent(ON.id('videoSwitch'));
    await videoSwitch.click();
    await driver.delayMs(1000);
    let beforePercent: number | undefined = AppStorage.get<number>('VideoCacheCurrentPercent');
    await driver.delayMs(2000);
    let afterPercent: number | undefined = AppStorage.get<number>('VideoCacheCurrentPercent');
    // 断言视频暂停后，进度不变
    expect(beforePercent).assertEqual(afterPercent);

    done();
  })

  /**
   * 点击播放按钮播放
   */
  it(CASE_NAME + '_click_play', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('videoSwitch'));
    let videoSwitch = await driver.findComponent(ON.id('videoSwitch'));
    await videoSwitch.click();
    let beforePercent: number | undefined = AppStorage.get<number>('VideoCacheCurrentPercent');
    await driver.delayMs(2000);
    let afterPercent: number | undefined = AppStorage.get<number>('VideoCacheCurrentPercent');
    // 断言视频恢复播放后，进度变化
    expect(afterPercent).assertLarger(beforePercent);

    done();
  })

  exit(CASE_NAME);
}