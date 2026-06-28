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

const CASE_NAME: string = '长列表滑动到指定列表项动效实现案例'; // 案例中文名称

/**
 * 【长列表滑动到指定列表项动效实现案例】自动化测试用例
 * 1. 往下滑动列表
 * 2. 点击上箭头，回到顶部
 * 3. 点击时钟按钮，回到刚才记录的位置
 */
export default function listSlideToHistoryTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);
  // 设置初始不相等的数值
  let firstText = 'firstText';
  let secondText = 'secondText';

  /**
   * 往下滑动列表
   */
  it(CASE_NAME + '_Slide', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.id('slide_to_history_button')); // 断言数据列表是否存在
    await driver.swipe(200, 800, 200, 100, 20000); // 快速滑动
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.type("Text").id("list_slide_text")); // 断言数据是否存在文本
    const text = await driver.findComponent(ON.type("Text").id("list_slide_text"));
    firstText = await text.getText();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 点击上箭头，回到顶部
   */
  it(CASE_NAME + '_Return_Top', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.type('Button').id('slide_to_history_button').enabled(true)); // 断言按钮是否存在且可点击
    const button = await driver.findComponent(ON.type('Button').id('slide_to_history_button'));
    await button.click();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 点击时钟按钮，回到刚才记录的位置
   */
  it(CASE_NAME + '_To_History', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.type('Button').id('slide_to_history_button').enabled(true)); // 断言按钮是否存在且可点击
    const button = await driver.findComponent(ON.type('Button').id('slide_to_history_button'));
    await button.click();
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.type("Text").id("list_slide_text")); // 断言数据是否存在文本
    const text = await driver.findComponent(ON.type("Text").id("list_slide_text"));
    secondText = await text.getText()
    await driver.delayMs(1000);

    // 通过断言判断是否划到同样位置
    expect(firstText).assertEqual(secondText);
    done();
  })

  // 退出案例
  exit(CASE_NAME);
}