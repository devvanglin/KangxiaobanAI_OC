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
import { Driver, ON, Component } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NANE: string = '多重筛选案例'; // 案例中文名称

/**
 * 【滑动视频自动播放】自动化测试用例
 * 1. 进入案例检查页面是否正常
 * 2. 筛选白天、次套餐数据，检查是否存在易鹏工业园区停车场
 * 3. 筛选完后的数据重置，检查是否存在易鹏工业园区停车场
 * 4. 退出案例
 */
export default function multipleScreeningTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NANE);
  let driver = Driver.create();

  /**
   * 进入首页判断布局
   */
  it('首页页面检查', 0, async (done: Function) => {
    // 给定时间使得列表加载完成
    await driver.delayMs(2000);
    // 断言检查页面相关组件是否都存在
    await driver.assertComponentExist(ON.id('customTabBar'));
    await driver.assertComponentExist(ON.id('customTitle'));
    await driver.assertComponentExist(ON.id('filterComponent'));
    await driver.assertComponentExist(ON.id('infoCard'));
    await driver.delayMs(500);
    done();
  })

  /**
   * 筛选白天、次套餐数据
   */
  it('筛选数据', 0, async (done: Function) => {
    let filter: Component = await driver.findComponent(ON.text('筛选类型'));
    await filter.click();
    await driver.delayMs(500);
    let filterTime: Component = await driver.findComponent(ON.text('白天'));
    await filterTime.click();
    await driver.delayMs(500);
    let filterType: Component = await driver.findComponent(ON.text('次套餐'));
    await filterType.click();
    await driver.delayMs(500);
    let filterConfirm: Component = await driver.findComponent(ON.text('确认'));
    await filterConfirm.click();
    await driver.delayMs(500);
    let listData: Component = await driver.findComponent(ON.text('易鹏工业园区停车场'));
    expect(listData).assertNull();
    await driver.delayMs(500);
    done();
  })

  /**
   * 重置数据
   */
  it('重置数据', 0, async (done: Function) => {
    let filter: Component = await driver.findComponent(ON.text('筛选类型'));
    await filter.click();
    await driver.delayMs(500);
    let filterReset: Component = await driver.findComponent(ON.text('重置'));
    await filterReset.click();
    await driver.delayMs(500);
    let filterConfirm: Component = await driver.findComponent(ON.text('确认'));
    await filterConfirm.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('易鹏工业园区停车场'));
    await driver.delayMs(500);
    done();
  })

  /**
   * 退出案例
   */
  exit(CASE_NANE)

}