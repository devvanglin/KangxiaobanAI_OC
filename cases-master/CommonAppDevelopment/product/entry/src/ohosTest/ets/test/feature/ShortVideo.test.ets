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
import { Driver, ON, UiDirection } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '短视频切换';

/**
 * 【短视频切换】自动化测试用例
 */
export default function shortVideoTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 向下滑动视频，切换下一个视频
   */
  it(CASE_NAME + '_swipe_down', 0, async (done: Function) => {
    // 断言当前的视频为第一个视频
    await driver.assertComponentExist(ON.id("short_video_0"));
    // 向下滑动
    await driver.fling(UiDirection.DOWN, 4000);
    await driver.delayMs(200);
    // 断言当前的视频为第二个视频
    await driver.assertComponentExist(ON.id("short_video_1"));

    done();
  })

  /**
   * 向上滑动视频，切换上一个视频
   */
  it(CASE_NAME + '_swipe_up', 0, async (done: Function) => {
    // 向上滑动
    await driver.fling(UiDirection.UP, 4000);
    await driver.delayMs(200);
    // 断言当前的视频为第一个视频
    await driver.assertComponentExist(ON.id("short_video_0"));

    done();
  })

  /**
   * 1、点击视频暂停
   * 2、再次点击视频继续播放
   */
  it(CASE_NAME + '_click', 0, async (done: Function) => {
    let video = await driver.findComponent(ON.type('Video'));
    await video.click();
    await driver.delayMs(200);
    // 断言：暂停图标出现
    await driver.assertComponentExist(ON.id("pause_icon"));

    let video2 = await driver.findComponent(ON.type('Video'));
    await video2.click();
    await driver.delayMs(200);
    let pauseIcon = await driver.findComponent(ON.id("pause_icon"));
    // 断言：'暂停图标'按钮已不不存在
    expect(pauseIcon).assertNull();

    done();
  })

  exit(CASE_NAME);
}