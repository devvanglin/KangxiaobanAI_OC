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
import { Driver, ON, UiDirection } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '多段混合数据展示'; // 案例名称

/**
 * 【多列不同数据展示】 自动化测试用例
 */
export default function multiColumnDisplayTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1. 进入案例后，页面正常显示
   */
  it(CASE_NAME + '_init', 0, async (done: Function) => {
    // 一组9个数据，首先展示的是五个数据
    const dataCount: number = 5;
    for (let i = 1; i <= dataCount; i++) {
      await driver.assertComponentExist(ON.id(i.toString()))
    }
    // 剩余四个数据在屏幕滑动后展示
    await driver.fling(UiDirection.DOWN, 1000);
    await driver.delayMs(1000);
    for (let i = 9; i > dataCount; i--) {
      await driver.assertComponentExist(ON.id(i.toString()))
    }
    await driver.delayMs(1000);
    done();
  })

  // 退出案例
  exit('多段混合数据展示');
}