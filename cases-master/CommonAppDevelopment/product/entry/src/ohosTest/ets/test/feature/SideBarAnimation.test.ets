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
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'SideBarAnimation'; // 案例名称
const CASE_NAME: string = 'SideBarContainer侧边栏淡入淡出动效实现案例'; // 案例中文名称

/**
 * 【SideBarContainer侧边栏淡入淡出动效实现案例】自动化测试用例
 * 1. 搜索进入【SideBarContainer侧边栏淡入淡出动效实现案例】
 * 2. 点击右侧三角按钮
 * 3. 再次点击右侧三角按钮
 */
export default function sideBarAnimationTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 点击右侧三角按钮,侧边栏淡入，三角按钮转向右边。
   */
  it(CASE + '_点击右侧三角按钮', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击右侧三角按钮
    await driver.assertComponentExist(ON.id('ohos_ic_public_arrow_left_id').enabled(true)); // 断言左箭头按钮是否存在且可点击
    const arrowLeft = await driver.findComponent(ON.id('ohos_ic_public_arrow_left_id'));
    await arrowLeft.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('side_bar_view_id')); // 断言侧边栏出现
    await driver.assertComponentExist(ON.id('ohos_ic_public_arrow_right_id').enabled(true)); // 断言箭头按钮转向右边

    done();
  })

  /**
   * 再次点击右侧三角按钮,侧边栏恢复，三角按钮转向左边。
   */
  it(CASE + '_再次点击右侧三角按钮', 0, async (done: Function) => {
    let driver = Driver.create();

    // 再次点击右侧三角按钮
    await driver.assertComponentExist(ON.id('ohos_ic_public_arrow_right_id').enabled(true)); // 断言右箭头按钮是否存在且可点击
    const arrowRight = await driver.findComponent(ON.id('ohos_ic_public_arrow_right_id'));
    await arrowRight.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('ohos_ic_public_arrow_left_id').enabled(true)); // 断言箭头按钮转向左边

    done();
  })

  // 退出案例
  exit(CASE_NAME);
}