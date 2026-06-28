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

const CASE: string = 'SecondaryLinkage'; // 案例名称
const CASE_NAME: string = '列表二级联动'; // 案例中文名称

/**
 * 【列表二级联动】自动化测试用例
 * 1. 搜索进入【列表二级联动】
 * 2. 点击一级列表类型3
 * 3. 滑动二级列表到类别5
 */
export default function secondaryLinkageTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 点击一级列表类型3,二级列表滚动到类别3。
   */
  it(CASE + '_点击类别3', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击类别3
    await driver.assertComponentExist(ON.text('类别3').enabled(true)); // 断言按钮是否存在且可点击
    const type3 = await driver.findComponent(ON.text('类别3'));
    await type3.click();
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.id('type_3_selected')); // 断言type3存在且被选中
    await driver.assertComponentExist(ON.id('content_17')); // 断言二级列表滚动到类别3，且列表3最后一个子项存在

    done();
  })

  /**
   * 滑动二级列表到类别5,一级列表滚动到类别5
   */
  it(CASE + '_滑动二级列表到类别5', 0, async (done: Function) => {
    let driver = Driver.create();

    // 滑动二级列表到类别5
    const listContent = await driver.findComponent(ON.id('list_content'));
    await listContent.scrollSearch(ON.id('content_29')) // 滚动二级列表到类别5
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('type_5_selected')); // 断言type5存在且被选中

    done();
  })

  // 退出案例
  exit(CASE_NAME);
}