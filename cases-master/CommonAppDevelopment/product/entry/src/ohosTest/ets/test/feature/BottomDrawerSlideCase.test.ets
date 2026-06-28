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
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'bottomdrawerslidecase'; // 案例名称
const TAG: string = '[bottomdrawerslidecase_Test]';

/**
 * 【底部抽屉滑动效果案例】自动化测试用例
 * 1. 短距离向上滑动案例，底部呈现抽屉式滑动效果
 * 2. 长距离向上滑动案例，跟手滑动。且滑动到顶部显示出顶部标题。
 */
export default function bottomDrawerSlideCaseTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('底部抽屉滑动效果案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、短距离向上滑动
   * 2、通过scrollPart组件高度是否改变来验证
   **/
  it(CASE + '短距离滑动', 0, async (done: Function) => {
    const screen = await driver.getDisplaySize();
    const scrollPart: Component = await driver.findComponent(ON.id('scrollPart'));
    const beforeHeight = (await scrollPart.getBounds()).top;
    await driver.swipe(200, screen.y - 100, 200, screen.y - 200, 1000);
    await driver.delayMs(200);
    const afterHeight = (await scrollPart.getBounds()).top;
    const isIncreasing = beforeHeight > afterHeight ? true : false;
    expect(isIncreasing).assertEqual(true); // 通过断言判断底部抽屉的底部高度是否变高来验证
    done()
  })

  /**
   * 执行步骤：
   * 1、长距离向上滑动
   * 2、通过顶部标题栏是否出现来验证
   **/
  it(CASE + '长距离滑动', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Long_Scroll begin`);
    const screen = await driver.getDisplaySize();
    await driver.swipe(200, screen.y - 100, 200, 400, 1000);
    await driver.delayMs(500);
    logger.info(TAG, `${CASE}_Page_Scroll`);
    await driver.assertComponentExist(ON.id('statusHead')); // 判断是否出现'打车'标题栏
    done()
  })

  exit('底部抽屉滑动效果案例');
}