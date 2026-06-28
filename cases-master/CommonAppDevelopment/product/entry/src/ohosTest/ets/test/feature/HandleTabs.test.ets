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
import { Component, Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'handletabs'; // 案例名称
const TAG: string = '[handletabs_Test]';

/**
 * 【Tab组件实现增删tab案例】自动化测试用例
 * 1、增加tab页签。通过测试页面新增一个空白tab页签来验证。
 * 2、删除tab页签。通过测试被点击页签消失来验证。
 */
export default function handleTabsTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('Tab组件实现增删Tab标签');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、增加tab页签。通过测试页面新增一个空白tab页签来验证。
   **/
  it(CASE + '增加tab页签', 0, async (done: Function) => {
    const clickComponent: Component = await driver.findComponent(ON.id('tabs_filled'));
    await clickComponent.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.id('add_tabs')); // 通过判断是否出现底部灰色色块，来判断是否新增页签成功
    done();
  })

  /**
   * 执行步骤：
   * 1、删除tab页签。通过测试被点击页签消失来验证。
   **/
  it(CASE + '删除tab页签', 0, async (done: Function) => {
    const clickComponent: Component =
      await driver.findComponent(ON.id('tabs_cancel').isBefore(ON.id('tabs_filled')).isAfter(ON.id('tabs_cancel')));
    await clickComponent.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('本示例介绍使用了实现自定义增删Tab页签的功能。该场景多用于浏览器等场景。')); // 通过判断是否回到首页来验证被点击页签消失
    done();
  })


  // 退出案例
  exit('Tab组件实现增删tab案例');

}