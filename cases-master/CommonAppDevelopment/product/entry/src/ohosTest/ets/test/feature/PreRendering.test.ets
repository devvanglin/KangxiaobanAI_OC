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

const CASE_NAME: string = '使用预渲染实现Web页面顺开效果实践'; // 案例名称

/**
 * 【使用预渲染实现Web页面顺开效果实践】自动化测试用例
 */
export default function preRenderingTest() {
  let driver = Driver.create();

  searchCaseClickIn('骨架屏实现案例');

  /**
   * 1、访问任意案例，点击‘源码网页’按钮
   */
  it(CASE_NAME + '_open_web', 0, async (done: Function) => {
    let button: Component = await driver.findComponent(ON.text('源码网页'));
    await button.click();
    await driver.delayMs(500);

    await driver.assertComponentExist(ON.type('SheetPage'));
    await driver.assertComponentExist(ON.type('Web'));

    done();
  })

  /**
   * 1、弹窗弹出后，侧滑返回
   */
  it(CASE_NAME + '_side_slip', 0, async (done: Function) => {
    await driver.pressBack();
    await driver.delayMs(500);
    let sheetPage = await driver.findComponent(ON.type('SheetPage'));
    expect(sheetPage).assertNull();

    await driver.pressBack();
    await driver.delayMs(200);
    done();
  })

  exit('骨架屏实现案例')
}
