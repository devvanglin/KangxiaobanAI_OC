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
import { Driver, MatchPattern, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'TextExpand'; // 案例名称
const TAG: string = '[TextExpand_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【文字展开收起案例】自动化测试用例
 * 主要功能：测试文字展开收起是否正确展示。
 * 执行步骤：
 * 1. 点击文字是否展开收起。
 * 2. 点击图标是否展开收起。
 */
export default function textExpandTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('文字展开收起案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 点击文字是否展开收起。
   */
  it(CASE + '点击文字是否展开收起。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('展开', MatchPattern.CONTAINS));
    await driver.assertComponentExist(ON.id('textClick00'));
    let textClick = await driver.findComponent(ON.id('textClick00'));
    await textClick.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('收起', MatchPattern.CONTAINS));
    done();
  })

  /**
   * 点击图标是否展开收起。
   */
  it(CASE + '点击文字是否展开收起。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('热门'));
    let tabClick = await driver.findComponent(ON.text('热门'));
    await tabClick.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('textClick10'));
    let textClick = await driver.findComponent(ON.id('textClick10'));
    await textClick.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('textClick10'));
    done();
  })

  exit('文字展开收起案例');
}