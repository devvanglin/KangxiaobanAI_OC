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

const CASE: string = 'ImperativeView'; // 案例名称
const CASE_NAME: string = '使用ArkUI的FrameNode扩展实现动态布局类框架';

/**
 * 【使用ArkUI的FrameNode扩展实现动态布局类框架】自动化测试用例
 */
export default function imperativeViewTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 点击刷新按钮，相关影视图片变换，刷新按钮消失
   */
  it(CASE + "_refresh", 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('刷新'));
    // 点击刷新按钮
    let charge = await driver.findComponent(ON.text('刷新'));
    await charge.click();
    await driver.delayMs(200);

    let chargeNew = await driver.findComponent(ON.text('刷新'));
    // 断言：'刷新'按钮已不不存在
    expect(chargeNew).assertNull(null);

    done();
  })

  exit(CASE_NAME);
}