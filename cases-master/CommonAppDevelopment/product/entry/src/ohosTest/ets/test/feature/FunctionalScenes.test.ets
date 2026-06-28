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
import { Driver, ON, Component, Point } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '主页瀑布流实现案例'; // 案例名称

/**
 * 【主页瀑布流实现案例】自动化测试用例
 */
export default function functionalScenesTest() {
  let driver = Driver.create();

  /**
   * 1、轮播图滑动和点击跳转
   */
  it(CASE_NAME + '_swipe_carousel', 0, async (done: Function) => {
    let text: Component = await driver.findComponent(ON.text('搜索指定内容'));
    if (text !== null) {
      await driver.pressBack();
      await driver.delayMs(1000);
    }
    let swiper: Component = await driver.findComponent(ON.id('MainSwiper'));
    let point: Point = await swiper.getBoundsCenter();
    let case1: Component = await driver.findComponent(ON.id('case_title'));
    let case1Name: string = await case1.getText();
    await swiper.click();
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(500);
    await driver.swipe(point.x + 400, point.y, point.x - 400, point.y, 4000);
    await driver.delayMs(500);
    let case2: Component = await driver.findComponent(ON.id('case_title'));
    let case2Name: string = await case2.getText();
    expect(case1Name !== case2Name).assertTrue();
    swiper = await driver.findComponent(ON.id('MainSwiper'));
    await swiper.click();
    await driver.delayMs(1000);
    await driver.delayMs(200);
    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 1、切换分栏
   */
  it(CASE_NAME + '_toggle_sections', 0, async (done: Function) => {
    let sections: Component[] = await driver.findComponents(ON.id('section'));
    let section1Text: string = await sections[1].getText();
    let section2Text: string = await sections[2].getText();
    let point: Point = await sections[0].getBoundsCenter();
    await sections[1].click();
    await driver.delayMs(1000);
    sections = await driver.findComponents(ON.id('section'));
    expect(section1Text).assertEqual(await sections[0].getText());
    await driver.swipe(800, point.y + 500, 400, point.y + 500, 4000);
    await driver.delayMs(1000);
    sections = await driver.findComponents(ON.id('section'));
    expect(section2Text).assertEqual(await sections[0].getText());

    done();
  })

  /**
   * 1、点击下拉菜单按钮
   */
  it(CASE_NAME + '_drop_down_menu', 0, async (done: Function) => {
    let menuButton: Component = await driver.findComponent(ON.id('menu_button'));
    await menuButton.click();
    await driver.delayMs(1000);
    let menuItems: Component[] = await driver.findComponents(ON.id('menu_item'));
    let menuItem3Text: string = await menuItems[2].getText();
    await menuItems[2].click();
    await driver.delayMs(1000);
    let sections: Component[] = await driver.findComponents(ON.id('section'));
    expect(menuItem3Text).assertEqual(await sections[0].getText());

    done();
  })

  /**
   * 1、滑动瀑布流，点击案例
   */
  it(CASE_NAME + 'slip_and_click', 0, async (done: Function) => {
    await driver.swipe(200, 2000, 200, 100, 1000);
    await driver.delayMs(2000);
    let cases: Component[] = await driver.findComponents(ON.type('FlowItem'));
    await cases[0].click();
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}
