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

import { it } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'VariableWatch'; // 案例名称
const CASE_NAME: string = '多层嵌套类对象监听'; // 案例中文名称
const TAG: string = '[variablewatch_Test]';

/**
 * 【多层嵌套类对象监听】自动化测试用例
 * 1. 进入页面图片价格组件。
 * 2. 点击刷新商品按钮。
 * 3. 验证商品是否刷新
 */

export default function variableWatchTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、验证图片价格组件是否存在。
   * 2、点击点击刷新商品按钮。
   * 3、验证商品是否刷新。
   */
  it(CASE + '验证图片刷新', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}variableWatch begin`);
    await driver.assertComponentExist(ON.text('价格1'));
    await driver.assertComponentExist(ON.text('刷新商品和价格（仅演示）'));
    const refreshButton: Component = await driver.findComponent(ON.text('刷新商品和价格（仅演示）'));
    await refreshButton.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('价格5'));
    done();
  })

  exit(CASE_NAME);
}