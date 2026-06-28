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
import { Driver, ON, Component } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'ComponentStack'; // 案例名称
const CASE_NAME: string = '滚动吸顶效果实现案例'; // 案例中文名称

/**
 * 【滚动吸顶效果实现案例】自动化测试用例
 * 1. 向上滑动列表，搜索框有吸顶效果且按钮功能区有动画效果
 * 2. 向下滑动列表，界面恢复
 */
export default function componentStackTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 滚动吸顶效果实现案例只能断言动效前后搜索框的高度变化（动效需手工用例进行测试）
   */
  it(CASE, 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.id('component_stack_search'));
    const searchBefore: Component = await driver.findComponent(ON.id('component_stack_search'));
    // 获取搜索框的高度
    const searchHeightBefore = (await searchBefore.getBounds()).bottom - (await searchBefore.getBounds()).top;
    // 断言搜索框的高度是否为起始值100vp
    expect(Math.round(px2vp(searchHeightBefore))).assertEqual(100);

    // 向上滑动
    const scrollBottom: Component = await driver.findComponent(ON.id('water_flow_id'));
    await scrollBottom.scrollToBottom();
    await driver.delayMs(1000);

    // 断言横向排版的图标快捷栏出现
    await driver.assertComponentExist(ON.id('horizontal_list'));

    await driver.assertComponentExist(ON.id('component_stack_search'));
    const searchAfter: Component = await driver.findComponent(ON.id('component_stack_search'));
    // 获取搜索框的高度
    const searchHeightAfter = (await searchAfter.getBounds()).bottom - (await searchAfter.getBounds()).top;
    // 断言搜索框的高度是否为滑动后值70
    expect(Math.round(px2vp(searchHeightAfter))).assertEqual(70);

    // 向下滑动
    const scrollTop: Component = await driver.findComponent(ON.id('water_flow_id'));
    await scrollTop.scrollToTop();
    await driver.delayMs(1000);

    // 搜索框恢复原有高度
    await driver.assertComponentExist(ON.id('component_stack_search'));
    const searchOrigin: Component = await driver.findComponent(ON.id('component_stack_search'));
    // 获取搜索框的高度
    const searchHeightOrigin = (await searchOrigin.getBounds()).bottom - (await searchOrigin.getBounds()).top;
    // 断言搜索框的高度是否为恢复起始值100
    expect(Math.round(px2vp(searchHeightOrigin))).assertEqual(100);

    done();
  })
  // 退出案例
  exit(CASE_NAME);
}