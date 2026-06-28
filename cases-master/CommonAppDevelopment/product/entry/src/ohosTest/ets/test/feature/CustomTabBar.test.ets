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

const CASE_NAME: string = '自定义TabBar页签案例'; // 案例名称

/**
 * 【自定义TabBar页签案例】自动化测试用例
 */
export default function customTabBarTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、依次点击下方tabBar按钮‘首页’，‘新闻’，‘视频’，‘朋友圈’，‘我的’
   */
  it(CASE_NAME + '_click_button', 0, async (done: Function) => {
    let indexButton: Component = await driver.findComponent(ON.id('tab_button_0'));
    let newsButton: Component = await driver.findComponent(ON.id('tab_button_1'));
    let videoButton: Component = await driver.findComponent(ON.id('tab_button_2'));
    let friendsButton: Component = await driver.findComponent(ON.id('tab_button_3'));
    let myButton: Component = await driver.findComponent(ON.id('tab_button_4'));
    const indexButtonTop: number = (await indexButton.getBounds()).top;
    const newsButtonTop: number = (await newsButton.getBounds()).top;
    const videoButtonTop: number = (await videoButton.getBounds()).top;
    const friendsButtonTop: number = (await friendsButton.getBounds()).top;
    const myButtonTop: number = (await myButton.getBounds()).top;

    await newsButton.click();
    await driver.delayMs(500);
    indexButton = await driver.findComponent(ON.id('tab_button_0'));
    expect(indexButtonTop).assertLess((await indexButton.getBounds()).top);
    newsButton = await driver.findComponent(ON.id('tab_button_1'));
    expect(newsButtonTop).assertLarger((await newsButton.getBounds()).top);

    await videoButton.click();
    await driver.delayMs(500);
    videoButton = await driver.findComponent(ON.id('tab_button_2'));
    expect(videoButtonTop).assertEqual((await videoButton.getBounds()).top);

    await friendsButton.click();
    await driver.delayMs(500);
    friendsButton = await driver.findComponent(ON.id('tab_button_3'));
    expect(friendsButtonTop).assertLarger((await friendsButton.getBounds()).top);

    await myButton.click();
    await driver.delayMs(500);
    myButton = await driver.findComponent(ON.id('tab_button_4'));
    expect(myButtonTop).assertLarger((await myButton.getBounds()).top);

    done();
  })

  exit(CASE_NAME);
}
