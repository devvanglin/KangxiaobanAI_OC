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

const CASE: string = 'TransitionAnimation'; // 案例名称
const TAG: string = '[TransitionAnimation_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【页面转场一镜到底动画】自动化测试用例
 * 主要功能：一镜到底转场。
 * 执行步骤：
 * 1. 点击首页卡片跳转到详情页，再点击进入路由页面按钮，进入新的路由页面。
 */
export default function transitionAnimationTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('页面转场一镜到底动画');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 点击首页卡片跳转到详情页，再点击进入路由页面按钮，进入新的路由页面。
   */
  it(CASE + '点击首页卡片跳转到详情页，再点击进入路由页面按钮，进入新的路由页面。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('云海日出星空', MatchPattern.CONTAINS));
    let button1 = await driver.findComponent(ON.text('云海日出星空', MatchPattern.CONTAINS));
    await button1.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('父页面', MatchPattern.CONTAINS).type('Button'));
    let button2 = await driver.findComponent(ON.text('父页面', MatchPattern.CONTAINS).type('Button'));
    await button2.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('这是子页面'));
    await driver.findComponent(ON.text('这是子页面'));
    await driver.pressBack();
    await driver.delayMs(DELAY_MS);
    await driver.pressBack();
    await driver.delayMs(DELAY_MS)
    await driver.assertComponentExist(ON.text('云海日出星空', MatchPattern.CONTAINS));
    await driver.findComponent(ON.text('云海日出星空', MatchPattern.CONTAINS));;

    done();
  })

  exit('页面转场一镜到底动画');
}