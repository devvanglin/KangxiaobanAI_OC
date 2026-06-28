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
import exit from '../common/Exit.test';

const CASE: string = 'VotingComponent'; // 案例名称
const CASE_NAME: string = '投票动效实现案例';

/**
 * 【投票动效实现案例】自动化测试用例
 */
export default function votingComponentTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  /**
   * 点击早起选项，选择早起占28%，选择晚期占72%，下方提示文字也会改成以选择的选项，且显示总参与投票人数
   */
  it(CASE + '_choose_early', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击早起按钮
    let early = await driver.findComponent(ON.text('早起'));
    await early.click();
    await driver.delayMs(200);

    // 断言：已选择"早起"
    await driver.assertComponentExist(ON.text('已选择"早起"'));

    // 退出页面
    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  /**
   * 点击晚起按钮，选择早起占22%，选择晚期占78%，下方提示文字也会改成以选择的选项，且显示总参与投票人数
   */
  it(CASE + '_choose_wake_up_late', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击晚起按钮
    let wakeUpLate = await driver.findComponent(ON.text('晚起'));
    await wakeUpLate.click();
    await driver.delayMs(200);

    // 断言：已选择"晚起"
    await driver.assertComponentExist(ON.text('已选择"晚起"'));

    done();
  })

  exit(CASE_NAME);
}