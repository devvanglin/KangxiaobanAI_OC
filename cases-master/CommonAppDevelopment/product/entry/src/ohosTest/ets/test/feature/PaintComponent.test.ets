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

const CASE: string = 'PaintComponent'; // 案例名称
const CASE_NAME: string = '使用绘制组件实现自定义进度动画';

/**
 * 【使用绘制组件实现自定义进度动画】自动化测试用例
 */
export default function paintComponentTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 点击充电按钮，进度会持续增长，直到100%时绿色填充满整个圆形，当到达20%以上变成蓝色，到达80%以上变成绿色
   */
  it(CASE + "_charge", 0, async (done: Function) => {
    // 点击充电按钮
    let charge = await driver.findComponent(ON.text('充电'));
    await charge.click();
    // 特殊场景，需要等进度变化完成
    await driver.delayMs(21000);

    // 断言：进度已经100%
    await driver.assertComponentExist(ON.text('100%'));

    done();
  })

  /**
   * 点击耗电按钮，进度会持续下降，直到0%时恢复1中的初始效果，当到达80%以下变成蓝色，到达20%以下变成红色
   */
  it(CASE + "_consumer", 0, async (done: Function) => {
    // 点击耗电按钮
    let consumer = await driver.findComponent(ON.text('耗电'));
    await consumer.click();
    // 特殊场景，需要等进度变化完成
    await driver.delayMs(21000);


    // 断言：进度已经0%
    await driver.assertComponentExist(ON.text('0%'));
    done();
  })

  exit(CASE_NAME);
}