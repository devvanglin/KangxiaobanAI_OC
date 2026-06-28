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
import { Driver, ON, Component } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '自定义TabBar页签凸起和凹陷案例'; // 案例名称

/**
 * 【自定义TabBar页签凸起和凹陷案例】自动化测试用例
 */
export default function customDrawTabBarTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、点击凸起tabBar中的页签
   */
  it(CASE_NAME + '_click_bulge', 0, async (done: Function) => {
    let ball: Component = await driver.findComponent(ON.id('ball').within(ON.id('bugle_tabBar')));
    let newsButton: Component = await driver.findComponent(ON.text('新闻').within(ON.id('bugle_tabBar')));
    let ballX: number = (await ball.getBoundsCenter()).x;
    let newsButtonX: number = (await newsButton.getBoundsCenter()).x
    // 断言：初始状态下，新闻tab没有凸起
    expect(ballX === newsButtonX).assertFalse();
    await newsButton.click();
    await driver.delayMs(3000);

    ball = await driver.findComponent(ON.id('ball').within(ON.id('bugle_tabBar')));
    ballX = (await ball.getBoundsCenter()).x;
    // 断言：新闻办tab凸起
    expect(ballX === newsButtonX).assertTrue();

    done();
  })

  /**
   * 2、点击凹陷tabBar中的页签
   */
  it(CASE_NAME + '_click_concavity', 0, async (done: Function) => {
    let ball: Component = await driver.findComponent(ON.id('ball').within(ON.id('concavity_tabBar')));
    let myButton: Component = await driver.findComponent(ON.text('我的').within(ON.id('concavity_tabBar')));
    let ballX: number = (await ball.getBoundsCenter()).x;
    let myButtonX: number = (await myButton.getBoundsCenter()).x
    // 断言：我的tab没有凹陷
    expect(ballX === myButtonX).assertFalse();
    await myButton.click();
    await driver.delayMs(1000);

    ball = await driver.findComponent(ON.id('ball').within(ON.id('concavity_tabBar')));
    ballX = (await ball.getBoundsCenter()).x;
    // 断言：我的tab凹陷
    expect(ballX === myButtonX).assertTrue();

    done();
  })

  exit(CASE_NAME);
}
