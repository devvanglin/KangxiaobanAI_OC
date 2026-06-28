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
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'PullToRefreshNews'; // 案例名称
const CASE_NAME: string = '下拉刷新与上滑加载案例'; // 案例中文名称
const TAG: string = '[pulltorefreshnews_Test]';

/**
 * 【下拉刷新与上滑加载案例】自动化测试用例
 * 1. 上滑列表，实现加载更多列表数据。
 * 2. 数据全部加载完毕后，继续上拉提示已经到底了。
 * 3. 下拉列表，实现整个列表数据刷新。
 */
export default function pullToRefreshNewsTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、上滑列表。
   * 2、通过验证滑动后列表是否增加新列表项判断列表加载成功。
   **/
  it(CASE + '上滑列表', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Page_Scroll_Up begin`);
    await driver.assertComponentExist(ON.id('pageList'));
    const pageList: Component = await driver.findComponent(ON.id('pageList'));
    // 加载第二页
    await pageList.scrollToBottom(2000);
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.text('入春来，百花香'));
    // 加载第三页
    await pageList.scrollToBottom(2000);
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.text('入春来，百花香'));
    // 加载第四页
    await pageList.scrollToBottom(2000);
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.text('入春来，百花香'));
    // 上滑到底后不再加载
    await pageList.scrollToBottom(2000);
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.text('《将进酒 君不见》'));
    done();
  })

  /**
   * 执行步骤：
   * 1、下拉列表。
   * 2、通过验证下拉后列表是否刷新判断列表刷新成功。
   **/
  it(CASE + '下拉列表', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Page_Scroll_Down begin`);
    await driver.assertComponentExist(ON.id('pageList'));
    const pageList: Component = await driver.findComponent(ON.id('pageList'));
    // 下拉到列表顶部，更新数据
    await pageList.scrollToTop(2000);
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.text('好物推荐'));
    done();
  })

  // 退出案例页面
  exit(CASE_NAME);
}