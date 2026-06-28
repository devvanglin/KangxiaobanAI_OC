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

const CASE: string = 'StatusBarAnimation'; // 案例名称
const CASE_NAME: string = '状态栏动画实现案例'; // 案例中文名称

/**
 * 【状态栏动画实现案例】自动化测试用例
 * 1. 向上滑动案例，状态栏展开动画
 * 2. 点击回顶部按钮，页面回到顶部位置，同时状态栏收起动画
 */
export default function statusBarAnimationTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 状态栏动画实现案例只能断言页面滑动后状态栏按钮是否正常显示和隐藏（状态栏动画需手工用例进行测试）
   */
  it(CASE, 0, async (done: Function) => {
    let driver = Driver.create();
    // 向上滑动
    await driver.assertComponentExist(ON.id('statusbar_animation_main_list')); // 断言数据列表是否存在
    await driver.swipe(200, 800, 200, 100, 1000);
    await driver.delayMs(1000);
    const isScroll = await (await driver.findComponent(ON.id('statusbar_animation_main_list'))).isScrollable();
    expect(isScroll).assertEqual(true); // 断言数据列表可滚动

    // 点击回顶部按钮
    await driver.assertComponentExist(ON.text('回顶部').enabled(true)); // 断言回顶部按钮是否存在且可点击
    const scrollTop = await driver.findComponent(ON.text('回顶部'));
    await scrollTop.click();
    await driver.delayMs(1000);

    done();
  })
  //退出案例
  exit(CASE_NAME);
}