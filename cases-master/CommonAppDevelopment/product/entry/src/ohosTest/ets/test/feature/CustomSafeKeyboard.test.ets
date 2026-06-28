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

import { it, expect } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'CustomSafeKeyboard'; // 案例名称
const CASE_NAME: string = '自定义安全键盘案例'; // 案例中文名称
const TAG: string = '[customsafekeyboard_Test]';

/**
 * 【自定义安全键盘案例】自动化测试用例
 * 1. 进入页面拉起键盘。
 * 2. 验证键盘输入字母数字与特殊字符。
 * 3. 验证显示密码功能。
 */

export default function customSafeKeyboardTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME)
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1. 进入页面拉起键盘。
   * 2. 验证键盘输入字母数字与特殊字符。
   */
  it(CASE + '验证自定义安全键盘', 0, async (done: Function) => {
    logger.info(TAG, `${CASE} CustomSafeKeyboard input begin`);
    await driver.assertComponentExist(ON.id('textInput'));
    const textInput: Component = await driver.findComponent(ON.id('textInput'));
    await textInput.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('1'));
    const num1: Component = await driver.findComponent(ON.text('1'));
    await num1.click();
    await driver.assertComponentExist(ON.text('ABC'));
    const checkABC: Component = await driver.findComponent(ON.text('ABC'));
    await checkABC.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('a'));
    const wordA: Component = await driver.findComponent(ON.text('a'));
    await wordA.click();
    await driver.assertComponentExist(ON.text('#+='));
    const checkCharacter: Component = await driver.findComponent(ON.text('#+='));
    await checkCharacter.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('+'));
    const addButton: Component = await driver.findComponent(ON.text('+'));
    await addButton.click();
    await driver.delayMs(500);
    done();
  })

  /**
   * 执行步骤：
   * 1. 点击显示密码按钮。
   * 2. 验证文本框文字是否符合预期。
   */
  it(CASE + '验证显示密码', 0, async (done: Function) => {
    logger.info(TAG, `${CASE} CustomSafeKeyboard showText begin`);
    await driver.assertComponentExist(ON.id('textInput'));
    const textInput: Component = await driver.findComponent(ON.id('textInput'));
    await driver.assertComponentExist(ON.type('Image').within(ON.id('textInput')));
    const pmdButton: Component = await driver.findComponent(ON.type('Image').within(ON.id('textInput')));
    await pmdButton.click();
    await driver.delayMs(500);
    const textSpan: string = await textInput.getText();
    expect(textSpan.length === 3).assertEqual(true);
    await driver.assertComponentExist(ON.text('完成'));
    const backButton: Component = await driver.findComponent(ON.text('完成'));
    await backButton.click();
    await driver.delayMs(1000);
    done();
  })

  exit(CASE_NAME);
}