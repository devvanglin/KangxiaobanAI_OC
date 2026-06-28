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

const CASE: string = 'addressexchange'; // 案例名称
const TAG: string = '[addressexchange_Test]';

/**
 * 【地址交换动画案例】自动化测试用例
 * 点击案例中间飞机图片，实现左右两侧文字转换动效
 */
export default function addressExchangeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('地址交换动画');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、点击案例中间交换图片
   * 2、通过进行验证左右两边文字是否转化位置来验证
   **/
  it(CASE + '点击交换图片', 0, async (done: Function) => {
    const beijing: Component = await driver.findComponent(ON.type('Text').text('北京'));
    const leftBound = (await beijing.getBoundsCenter()).x;
    const shanghai: Component = await driver.findComponent(ON.type('Text').text('上海'));
    const rightBound = (await shanghai.getBoundsCenter()).x;
    expect(leftBound < rightBound).assertEqual(true);
    logger.info(TAG, `${CASE}change begin`);
    const changeImage = await driver.findComponent(ON.id('translate_image'));
    await changeImage.click();
    await driver.delayMs(1000);
    logger.info(TAG, `${CASE}change end`);
    const changeShanghai: Component = await driver.findComponent(ON.type('Text').text('上海'));
    const changeBeijing: Component = await driver.findComponent(ON.type('Text').text('北京'));
    const changeLeftBound = (await changeShanghai.getBoundsCenter()).x;
    const changeRightBound = (await changeBeijing.getBoundsCenter()).x;
    expect(changeLeftBound < changeRightBound).assertEqual(true);
    done();
  })

  // 退出案例
  exit('地址交换动画案例');

}