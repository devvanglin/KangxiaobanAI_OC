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
import { Driver, ON, Component, Rect, Point } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = 'tabContent内容可以在tabBar上显示并响应滑动事件案例'; // 案例名称

/**
 * 【tabContent内容可以在tabBar上显示并响应滑动事件案例】自动化测试用例
 */
export default function tabContentOverFlowTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、滑动进度按钮
   */
  it(CASE_NAME + '_drag_process_button', 0, async (done: Function) => {
    let videoImageStart: Component = await driver.findComponent(ON.id('image'));
    await videoImageStart.click(); // 播放视频
    await driver.delayMs(2000);
    let videoImagePause: Component = await driver.findComponent(ON.id('video'));
    await videoImagePause.click(); // 暂停视频

    let process: Component = await driver.findComponent(ON.id('text2'));
    let process1Width: number = getComponentWidth(await process.getBounds());
    let processButton: Component = await driver.findComponent(ON.id('text3'));
    let processButtonPoint: Point = await processButton.getBoundsCenter();
    // let y: number = (await processButton.getBounds()).bottom;
    await driver.drag(processButtonPoint.x, processButtonPoint.y, processButtonPoint.x + 400, processButtonPoint.y,
      2000);
    await driver.delayMs(1000);
    let process2 = await driver.findComponent(ON.id('text2'));
    let process2Width: number = getComponentWidth(await process2.getBounds());
    // 断言：向右滑动后的进度条比滑动前的要宽
    expect(process2Width).assertLarger(process1Width);

    processButton = await driver.findComponent(ON.id('text3'));
    processButtonPoint = await processButton.getBoundsCenter();
    await driver.drag(processButtonPoint.x, processButtonPoint.y, processButtonPoint.x - 200, processButtonPoint.y,
      2000);
    await driver.delayMs(1000);
    process = await driver.findComponent(ON.id('text2'));
    let process3Width: number = getComponentWidth(await process.getBounds());
    // 断言：向左滑动后的进度条比滑动前的要窄
    expect(process3Width).assertLess(process2Width);

    done();
  })

  /**
   * 2、滑动进度下方区域
   */
  it(CASE_NAME + '_drag_below_area', 0, async (done: Function) => {
    let process: Component = await driver.findComponent(ON.id('text2'));
    let process1Width: number = getComponentWidth(await process.getBounds());
    let videoText: Component = await driver.findComponent(ON.text('视频'));
    let videoTextPoint: Point = await videoText.getBoundsCenter();
    await driver.drag(videoTextPoint.x, videoTextPoint.y, videoTextPoint.x + 400, videoTextPoint.y, 2000);
    await driver.delayMs(500);
    process = await driver.findComponent(ON.id('text2'));
    let process2Width: number = getComponentWidth(await process.getBounds());
    // 断言：向右滑动后的进度条比滑动前的要宽
    expect(process2Width).assertLarger(process1Width);

    await driver.drag(videoTextPoint.x, videoTextPoint.y, videoTextPoint.x - 200, videoTextPoint.y, 2000);
    await driver.delayMs(500);
    process = await driver.findComponent(ON.id('text2'));
    let process3Width: number = getComponentWidth(await process.getBounds());
    // 断言：向左滑动后的进度条比滑动前的要窄
    expect(process3Width).assertLess(process2Width);

    done();
  })

  exit(CASE_NAME);
}

function getComponentWidth(rect: Rect): number {
  return rect.right - rect.left;
}
