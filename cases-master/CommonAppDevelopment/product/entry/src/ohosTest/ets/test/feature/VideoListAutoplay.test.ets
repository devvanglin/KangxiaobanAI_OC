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
import { emitter } from '@kit.BasicServicesKit';

const CASE: string = 'VideoListAutoplay'; // 案例名称
const CASE_NANE: string = '滑动视频自动播放'; // 案例中文名称

/**
 * 【滑动视频自动播放】自动化测试用例
 * 1. 进入案例检查页面是否正常
 * 2. 视频加载完成后判断列表中间视频是否自动播放
 * 3. 列表滑动判断列表中间视频是否自动播放
 * 4. 退出案例
 */
export default function videoListAutoplayTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NANE);
  let driver = Driver.create();
  let videoListAutoplay_centerIndex: number = 0;
  let videoListAutoplay_index: number = 0;
  let videoListAutoplay_isPlaying: boolean = false;
  emitter.on({
    eventId: 1, priority: 0
  }, (data: emitter.EventData) => {
    videoListAutoplay_centerIndex = data.data?.videoListAutoplay_centerIndex;
    videoListAutoplay_index = data.data?.videoListAutoplay_index;
    videoListAutoplay_isPlaying=data.data?.videoListAutoplay_isPlaying;
  })

  /**
   * 进入首页判断布局
   */
  it('首页页面检查', 0, async (done: Function) => {
    // 给定时间使得视频列表加载完成
    await driver.delayMs(20000);
    // 断言检查页面相关组件是否都存在
    await driver.assertComponentExist(ON.id('customSearch'));
    await driver.assertComponentExist(ON.id('lazyForEachListPage'));
    await driver.delayMs(500);
    done();
  })

  /**
   * 视频加载完成后判断列表中间视频是否自动播放
   */
  it('检查中间视频播放', 0, async (done: Function) => {
    expect(videoListAutoplay_centerIndex === videoListAutoplay_index).assertEqual(true); // 判断视频是否是列表中间视频
    expect(videoListAutoplay_isPlaying).assertEqual(true); // 判断视频是否开始播放
    await driver.delayMs(1000);
    done();
  })

  /**
   * 列表滑动判断列表中间视频是否自动播放
   */
  it('滑动列表中间视频播放', 0, async (done: Function) => {
    // 开始的滑动的起始点为(500,2500),结束点为(500,500)，指的是从页面最左边500的地方开始向上滑动。2000指的是滑动速率。
    await driver.swipe(500, 2500, 500, 500, 2000);
    expect(videoListAutoplay_centerIndex === videoListAutoplay_index).assertEqual(true); // 判断视频是否是列表中间视频
    expect(videoListAutoplay_isPlaying).assertEqual(true); // 判断视频是否开始播放
    await driver.delayMs(2500);
    done();
  })

  /**
   * 列表滑动判断列表中间视频是否自动播放
   */
  it('向上滑动列表中间视频播放', 0, async (done: Function) => {
    // 开始的滑动的起始点为(500,500),结束点为(500,2500)，指的是从页面最左边500的地方开始向上滑动。2000指的是滑动速率。
    await driver.swipe(500, 500, 500, 2500, 2000);
    expect(videoListAutoplay_centerIndex === videoListAutoplay_index).assertEqual(true); // 判断视频是否是列表中间视频
    expect(videoListAutoplay_isPlaying).assertEqual(true); // 判断视频是否开始播放
    await driver.delayMs(2500);
    done();
  })

  /**
   * 退出案例
   */
  exit(CASE_NANE)

}


