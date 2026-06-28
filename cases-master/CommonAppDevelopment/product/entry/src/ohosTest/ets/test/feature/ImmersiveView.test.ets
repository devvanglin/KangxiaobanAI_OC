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
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'ImmersiveView'; // 案例名称
const CASE_NAME: string = '沉浸式适配案例';

/**
 * 【沉浸式适配案例】自动化测试用例
 */
export default function immersiveViewTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 点击首页banner，进入web页展示Web沉浸式
   */
  it(CASE + "_web_immersive", 0, async (done: Function) => {
    // 点击首页banner
    let banner = await driver.findComponent(ON.id('banner'));
    await banner.click();
    await driver.delayMs(200);

    // 断言：需存在type为‘Web’的组件
    await driver.assertComponentExist(ON.type('Web'));
    // 滑动到底部
    let scrollerInWeb = await driver.findComponent(ON.type('Web'));
    await scrollerInWeb.scrollToBottom(40000);
    await driver.delayMs(500);

    // 返回首页
    await driver.pressBack();
    await driver.delayMs(200);

    // 断言：需存在text为‘新品首发’的组件
    await driver.assertComponentExist(ON.text('新品首发'));

    done();
  })

  /**
   * 滑动商品列表，展示滚动场景沉浸式
   */
  it(CASE + "_list_immersive", 0, async (done: Function) => {
    // 滑动到底部
    let scrollerInGoods = await driver.findComponent(ON.type('Scroll'));
    await scrollerInGoods.scrollToBottom(40000);
    await driver.delayMs(500);

    // 断言：需存在text为‘折叠屏’的组件
    await driver.assertComponentExist(ON.text('折叠屏'));

    done();
  })

  /**
   * 点击商品列表项，展示普通布局沉浸式
   */
  it(CASE + "_common_immersive", 0, async (done: Function) => {
    // 点击商品列表项
    let goodsItem = await driver.findComponent(ON.text('充电宝'));
    await goodsItem.click();
    await driver.delayMs(200);
    // 断言：需存在text为‘加入购物车’的组件
    await driver.assertComponentExist(ON.text('加入购物车'));

    done();
  })

  /**
   * 点击商品评论字样，弹出评论弹窗展示底部弹窗沉浸式
   */
  it(CASE + "_bottom_dialog_immersive", 0, async (done: Function) => {
    // 点击商品评论字样
    let commentButton = await driver.findComponent(ON.text('商品评论'));
    await commentButton.click();
    await driver.delayMs(200);
    // 断言：需存在id为’close_button‘的组件
    await driver.assertComponentExist(ON.id('close_button'));
    // 滑动到底部
    let scrollerInComment = await driver.findComponent(ON.type('List'));
    await scrollerInComment.scrollToBottom(40000);
    await driver.delayMs(500);
    // 断言：需存在text为‘买家10’的组件
    await driver.assertComponentExist(ON.text('买家10'));
    // 关闭弹窗
    let closeButton = await driver.findComponent(ON.id('close_button'));
    await closeButton.click();
    await driver.delayMs(200);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  exit(CASE_NAME);
}