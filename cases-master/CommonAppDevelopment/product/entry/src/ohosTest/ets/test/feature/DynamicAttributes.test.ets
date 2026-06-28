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
import { Driver, MatchPattern, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'DynamicAttributes'; // 案例名称
const TAG: string = '[DynamicAttributes_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【跨文件样式复用和组件复用】自动化测试用例
 * 主要功能：组件复用。
 * 执行步骤：
 * 1. 点击购物车页面的list列表跳转商品详情页。
 */
export default function dynamicAttributesTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('跨文件样式复用和组件复用');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 点击购物车页面的list列表跳转商品详情页。
   */
  it(CASE + '点击购物车页面的list列表跳转商品详情页。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('商品 1', MatchPattern.CONTAINS));
    let button1 = await driver.findComponent(ON.text('商品 1', MatchPattern.CONTAINS));
    await button1.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('¥300'));
    await driver.findComponent(ON.text('¥300'));
    await driver.pressBack();
    await driver.delayMs(DELAY_MS)
    await driver.assertComponentExist(ON.text('商品 1', MatchPattern.CONTAINS));
    await driver.findComponent(ON.text('商品 1', MatchPattern.CONTAINS));;

    done();
  })

  exit('跨文件样式复用和组件复用');
}