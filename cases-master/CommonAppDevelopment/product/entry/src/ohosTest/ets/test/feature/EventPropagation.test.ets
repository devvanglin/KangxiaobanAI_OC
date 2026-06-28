/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

const CASE_NAME: string = '阻塞事件冒泡'; // 案例名称

/**
 * 【阻塞事件冒泡】自动化测试用例
 */
export default function eventPropagationTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、打开阻塞事件冒泡开关
   * 2、分别点击‘点击事件例子’和‘触摸事件例子’的按钮
   */
  it(CASE_NAME + '_open_clog', 0, async (done: Function) => {
    let clickButton: Component = await driver.findComponent(ON.text('disable的子组件').within(ON.id('click_event')));
    for (let i = 0; i < 3; i++) {
      await clickButton.click();
      await driver.delayMs(200);
    }
    let result: Component = await driver.findComponent(ON.id('click_parent_result'))
    expect(await result.getText()).assertEqual('0');

    let touchButton: Component = await driver.findComponent(ON.text('子组件').within(ON.id('touch_event')));
    for (let i = 0; i < 3; i++) {
      await touchButton.click();
      await driver.delayMs(200);
    }
    let parentResult: Component = await driver.findComponent(ON.id('touch_parent_result'));
    expect(await parentResult.getText()).assertEqual('0');
    let childResult: Component = await driver.findComponent(ON.id('touch_child_result'));
    expect(await childResult.getText()).assertEqual('3');

    done();
  })

  /**
   * 1、关闭阻塞事件冒泡开关
   * 2、分别点击‘点击事件例子’和‘触摸事件例子’的按钮
   */
  it(CASE_NAME + '_close_clog', 0, async (done: Function) => {
    let switchButton: Component = await driver.findComponent(ON.type('Toggle').isAfter(ON.text('阻塞事件冒泡')));
    await switchButton.click();
    await driver.delayMs(200);

    let clickButton: Component = await driver.findComponent(ON.text('disable的子组件').within(ON.id('click_event')));
    for (let i = 0; i < 3; i++) {
      await clickButton.click();
      await driver.delayMs(200);
    }
    let result: Component = await driver.findComponent(ON.id('click_parent_result'))
    expect(await result.getText()).assertEqual('3');

    let touchButton: Component = await driver.findComponent(ON.text('子组件').within(ON.id('touch_event')));
    for (let i = 0; i < 3; i++) {
      await touchButton.click();
      await driver.delayMs(200);
    }
    let parentResult: Component = await driver.findComponent(ON.id('touch_parent_result'));
    expect(await parentResult.getText()).assertEqual('3');
    let childResult: Component = await driver.findComponent(ON.id('touch_child_result'));
    expect(await childResult.getText()).assertEqual('6');

    done();
  })

  exit(CASE_NAME);
}
