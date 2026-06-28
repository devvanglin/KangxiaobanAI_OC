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
import { Component, Driver, ON } from '@ohos.UiTest';
import { logger } from "utils";
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'swipercomponent'; // 案例名称
const CASE_NAME: string = '多层级轮播图案例';

/**
 * 【多层级轮播图案例】自动化测试用例
 * 1. 轮播图手动切换图片
 * 2. 轮播图自动切换图片
 * 3. 点击跳转到相应案例
 */
export default function swiperComponentTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('多层级轮播图方案');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、手动滑动图片
   * 2、通过判断图片下方的字来验证
   **/
  it(CASE + '轮播图手动切换图片', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('Lottie动画'));
    await driver.swipe(621, 667, 200, 667);
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.text('滚动吸顶效果实现案例'));
    await driver.delayMs(500);
    done();
  })

  /**
   * 执行步骤：
   * 1、自动轮播图片
   * 2、通过判断图片下方的字来验证
   **/
  it(CASE + '自动轮播图片', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('滚动吸顶效果实现案例'));
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('MpChart图表实现案例'));
    done();
  })

  /**
   * 执行步骤：
   * 点击跳转到相应案例
   **/
  it(CASE + '点击跳转到相应案例', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('MpChart图表实现案例'));
    await driver.click(621, 667);
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('左Y轴相关设置：'));
    done();
  })

  /**
   * 执行步骤：
   * 1、点击顶部导航栏返回
   * 2、通过判断是否出现搜索框组件来验证
   **/
  it(CASE + '返回首页', 0, async (done: Function) => {
    // 退出页面
    await driver.pressBack();
    await driver.delayMs(300);
    await driver.pressBack();
    await driver.delayMs(300);
    await driver.assertComponentExist(ON.id('searchCaseTitle'));
    done()
  })

}