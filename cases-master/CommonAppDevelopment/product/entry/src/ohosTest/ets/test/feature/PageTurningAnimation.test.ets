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
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'PageTurningAnimation'; // 案例名称
const TAG: string = '[PageTurningAnimation_Test]';
const DELAY_MS: number = 1000;

/**
 * 【翻页动效案例】自动化测试用例
 * 主要功能：通过ArkUI提供的显示动画接口animateTo实现翻页的效果。
 * 执行步骤：
 * 1.进入案例页面，查看页面显示是否正常。（翻页动画效果需手工用例进行测试）
 */
export default function akiUsePracticeTest() {
  searchCaseClickIn('翻页动效案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 进入案例页面，查看页面显示是否正常
   */
  it(CASE + '进入案例页面，查看页面显示是否正常', 0, async (done: Function) => {
    // 断言检查页面相关组件是否都存在
    await driver.assertComponentExist(ON.id('bookPageA'));
    await driver.assertComponentExist(ON.id('bookPageB'));
    await driver.assertComponentExist(ON.id('bookPageC'));
    await driver.assertComponentExist(ON.id('bookPageD'));
    logger.info(TAG, `${CASE} end`);
    done();
  })

  exit('翻页动效案例');
}