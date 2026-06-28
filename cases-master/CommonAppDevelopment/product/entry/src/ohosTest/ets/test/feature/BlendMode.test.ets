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

const CASE_NAME: string = '图片混合案例'; // 案例名称

/**
 * 【图片混合案例】自动化测试用例
 */
export default  function blendModeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、分表点击挂件列表的挂件
   */
  it(CASE_NAME + '_click_pendant', 0, async (done: Function) => {
    // 断言：最开始是默认无挂件
    await driver.assertComponentExist(ON.id('pendant_0'));
    let pendant1: Component = await driver.findComponent(ON.id('pendant_1'));
    //断言：目前不存在pendant_1
    expect(pendant1).assertNull();
    let pendant1Button: Component = await driver.findComponent(ON.text('挂件1'));
    await pendant1Button.click();
    await driver.delayMs(500);
    //断言：目前存在pendant_1
    await driver.assertComponentExist(ON.id('pendant_1'));

    let pendant2Button: Component = await driver.findComponent(ON.text('挂件2'));
    await pendant2Button.click();
    await driver.delayMs(500);
    //断言：目前存在pendant_2
    await driver.assertComponentExist(ON.id('pendant_2'));

    let pendant3Button: Component = await driver.findComponent(ON.text('挂件3'));
    await pendant3Button.click();
    await driver.delayMs(500);
    //断言：目前存在pendant_3
    await driver.assertComponentExist(ON.id('pendant_3'));

    let pendant4Button: Component = await driver.findComponent(ON.text('挂件4'));
    await pendant4Button.click();
    await driver.delayMs(500);
    //断言：目前存在pendant_4
    await driver.assertComponentExist(ON.id('pendant_4'));

    let pendant5Button: Component = await driver.findComponent(ON.text('挂件5'));
    await pendant5Button.click();
    await driver.delayMs(500);
    //断言：目前存在pendant_5
    await driver.assertComponentExist(ON.id('pendant_5'));


    done();
  })

  /**
   * 2、点击默认挂件
   */
  it(CASE_NAME + '_click_default', 0, async (done: Function) => {
    let pendant0Button: Component = await driver.findComponent(ON.text('挂件0'));
    await pendant0Button.click();
    await driver.delayMs(200);
    //断言：目前存在pendant_0
    await driver.assertComponentExist(ON.id('pendant_0'));

    done();
  })

  exit(CASE_NAME);
}
