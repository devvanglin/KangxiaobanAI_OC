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

const CASE: string = 'SwiperSmoothVariation'; // 案例名称
const CASE_NAME: string = 'Swiper高度可变化效果实现'; // 案例中文名称
const TAG: string = '[swipersmoothvariation_Test]';

/**
 * 【Swiper高度可变化效果实现】自动化测试用例
 * 1. 进入页面验证swiper组件。
 * 2. 滑动swiper组件，验证各页面滚动成功。
 */

export default function swiperSmoothVariationTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、验证swiper组件和首页text是否存在。
   * 2、分别滑动三次swiper组件，验证每页text组件是否存在。
   */
  it(CASE + '验证swiper组件滑动', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}SwiperSmoothVariation swiper begin`);
    await driver.assertComponentExist(ON.text('拼车'));
    await driver.swipe(900,500,0,500,800);
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('打车'));
    await driver.swipe(900,500,0,500,800);
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('赚钱'));
    await driver.swipe(900,500,0,500,800);
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('公交车'));
    done();
  })

  // 退出案例页面
  exit(CASE_NAME);
}
