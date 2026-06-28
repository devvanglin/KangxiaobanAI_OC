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
import { Driver, ON, Rect } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'SlideToHideAndDisplace'; // 案例名称
const CASE_NAME: string = '滑动页面信息隐藏与组件位移效果案例'; // 案例中文名称

/**
 * 【滑动页面信息隐藏与组件位移效果案例】自动化测试用例
 * 1. 搜索进入【滑动页面信息隐藏与组件位移效果案例】
 * 2. 上滑至顶部
 * 3. 下滑至底部
 */
export default function slideToHideAndDisplaceTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  let batmanOriginBounds: Rect; // 头像初始位置

  /**
   * 上滑至顶部，头像变小且蝙蝠侠、设置和客服位置出现在顶部。
   */
  it(CASE + '_上滑至顶部', 0, async (done: Function) => {
    let driver = Driver.create();

    // 头像初始位置
    await driver.assertComponentExist(ON.id('slidetohanddisplace_batman_id')); // 断言头像存在
    const batmanOrigin = await driver.findComponent(ON.id('slidetohanddisplace_batman_id'));
    batmanOriginBounds = await batmanOrigin.getBounds();

    // 上滑至顶部
    const scrollBar = await driver.findComponent(ON.type('Scroll'));
    await scrollBar.scrollToBottom();
    await driver.delayMs(1000);

    // 断言头像发生位置变化且尺寸缩小
    await driver.assertComponentExist(ON.id('slidetohanddisplace_batman_id')); // 断言头像存在
    const batman = await driver.findComponent(ON.id('slidetohanddisplace_batman_id'));
    const batmanBounds = await batman.getBounds();
    expect(batmanBounds.bottom - batmanBounds.top).assertLess(batmanOriginBounds.bottom - batmanOriginBounds.top); // 断言头像位置变化且尺寸缩小


    done();
  })

  /**
   * 下滑至底部,界面恢复。
   */
  it(CASE + '_下滑至底部', 0, async (done: Function) => {
    let driver = Driver.create();

    // 上滑至顶部
    const scrollBar = await driver.findComponent(ON.type('Scroll'));
    await scrollBar.scrollToTop();
    await driver.delayMs(1000);

    // 断言头像发生位置变化且尺寸缩小
    await driver.assertComponentExist(ON.id('slidetohanddisplace_batman_id')); // 断言头像存在
    const batman = await driver.findComponent(ON.id('slidetohanddisplace_batman_id'));
    const batmanBounds = await batman.getBounds();
    expect(batmanBounds.top).assertEqual(batmanOriginBounds.top); // 断言头像位置恢复
    expect(batmanBounds.left).assertEqual(batmanOriginBounds.left); // 断言头像位置恢复

    done();
  })

  // 退出案例
  exit(CASE_NAME);
}