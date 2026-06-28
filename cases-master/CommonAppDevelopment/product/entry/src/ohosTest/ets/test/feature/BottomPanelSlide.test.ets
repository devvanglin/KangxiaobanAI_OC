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
import { Component, Driver, ON } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'bottompanelslide'; // 案例名称
const TAG: string = '[bottompanelslide_Test]';

/**
 * 【底部面板嵌套列表滑动案例】自动化测试用例
 * 1. 滑动页面中的列表
 * 2. 点击"展开"后，滑动 panel中列表
 */
export default function bottomPanelSlideTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('底部面板嵌套列表滑动案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、滑动页面中的列表
   * 2、通过进行验证页面中列表是否可以滑动来验证
   **/
  it(CASE + '滑动页面中的列表', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Page_Scroll begin`);
    await driver.swipe(200, 700, 200, 200, 1000);
    await driver.delayMs(500);
    logger.info(TAG, `${CASE}_Page_Scroll`);
    await driver.assertComponentExist(ON.id('page_list'));
    const isScroll = await (await driver.findComponent(ON.id('page_list'))).isScrollable();
    expect(isScroll).assertEqual(true);
    done()
  })


  /**
   * 执行步骤：
   * 1、点击底部"展开"文字
   * 2、上滑展开的 panel中的列表
   * 3、panel完全展开时手指上滑
   * 4、panel完全展开且列表位于初始位置时，手指下滑
   * 5、通过判断 panel和'展开'的文字 组件是否存在来验证
   **/
  it(CASE + '滑动panel的列表', 0, async (done: Function) => {
    const screen = await driver.getDisplaySize();
    // 点击"展开"后，滑动 panel中列表
    const scrollTop = await driver.findComponent(ON.text('展开'));
    await scrollTop.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('bottom_panel_list'));

    const panel: Component = await driver.findComponent(ON.id('bottom_panel_column'));
    const beforeHeight = (await panel.getBounds()).top;
    await driver.swipe(200, screen.y - 100, 200, screen.y - 900);
    await driver.delayMs(500);
    const halfToFullHeight = (await panel.getBounds()).top;
    logger.info(TAG, `${CASE}_Panel_Scroll FULL`);
    const isFull = beforeHeight > halfToFullHeight ? true : false;
    expect(isFull).assertEqual(true); // 通过断言判 panel高度是否变高来验证

    const panelList = await driver.findComponent(ON.id('bottom_panel_list'));
    await panelList.scrollToBottom(40000)
    logger.info(TAG, `${CASE}_Panel_Scroll FULL scroll`);
    await driver.delayMs(500);
    await panelList.scrollToTop(40000);
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.id('bottom_panel_list'));


    await driver.swipe(200, 500, 200, 1000);
    await driver.delayMs(500);
    const fullToHalfHeight = (await panel.getBounds()).top;
    const isHalf = fullToHalfHeight >= halfToFullHeight ? true : false;
    logger.info(TAG, `${CASE}_Panel_Scroll half`);
    expect(isHalf).assertEqual(true); // 通过断言判 panel高度是否变高来验证

    await driver.swipe(200, screen.y - 700, 200, screen.y - 100);
    await driver.delayMs(100);
    await driver.assertComponentExist(ON.text('展开'));
    logger.info(TAG, `${CASE}_Panel_Scroll hide`);
    done()
  })

  exit('底部面板嵌套列表滑动案例');
}