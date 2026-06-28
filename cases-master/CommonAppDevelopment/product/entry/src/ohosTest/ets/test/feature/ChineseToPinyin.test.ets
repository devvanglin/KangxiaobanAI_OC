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

import { it } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'ChineseToPinyin'; // 案例名称
const CASE_NAME: string = '汉字转拼音案例'; // 案例中文名称
const TAG: string = '[chinesetopinyin_Test]';

/**
 * 【汉字转拼音案例】自动化测试用例
 * 1. 进入页面查找中文名输入栏。
 * 2. 验证转换后的拼音栏是否正确。
 */
export default function chineseToPinyinTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、查找输入框。
   * 2、输入预设文字。
   * 3、验证拼音栏是否正确。
   **/
  it(CASE + '验证文字转拼音', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Word_Recognition begin`);
    await driver.assertComponentExist(ON.id('chineseInput'));
    const chineseInput: Component = await driver.findComponent(ON.id('chineseInput'));
    await chineseInput.clearText();
    await chineseInput.inputText('小刚');
    await driver.assertComponentExist(ON.text('XIAOGANG'));
    await driver.delayMs(500);
    await driver.pressBack();
    await driver.delayMs(1000);
    done();
  })

  // 退出案例页面
  exit(CASE_NAME);
}