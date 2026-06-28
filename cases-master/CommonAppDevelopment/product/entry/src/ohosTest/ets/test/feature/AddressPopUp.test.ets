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

import { expect, it } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '页面间共享组件实例的案例'; // 案例名称

/**
 * 【页面间共享组件实例的案例】自动化测试用例
 */
export default function addressPopUpTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、初始存在大头针及弹窗
   * 2、拖拽过程中弹窗消失
   * 3、拖拽结束后弹窗恢复
   */
  it(CASE_NAME + '_drag_map', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('addressDescription'));
    await driver.drag(200, 600, 400, 800, 2000);
    let addressDescription = await driver.findComponent(ON.id('addressDescription'));
    expect(addressDescription).assertNull();
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.id('addressDescription'));

    done();
  })

  exit(CASE_NAME);
}
