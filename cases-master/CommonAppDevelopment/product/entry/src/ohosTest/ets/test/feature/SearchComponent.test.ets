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

const CASE_NAME: string = '搜索功能实现案例'; // 案例名称

/**
 * 【搜索功能实现案例】自动化测试用例
 */
export default function searchComponentTest() {
  let driver = Driver.create();

  /**
   * 1、点击主页搜索框
   * 2、输入案例名称，点击搜索
   * 3、点击搜索结果
   * 4、返回
   */
  it(CASE_NAME + 'common_search', 0, async (done: Function) => {
    let search: Component = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(500);
    search = await driver.findComponent(ON.type('Search'));
    await search.inputText('短视频切换');
    await driver.delayMs(1000);
    let button: Component = await driver.findComponent(ON.text('搜索'));
    await button.click();
    await driver.delayMs(1000);
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    await driver.delayMs(1000);
    let case1: Component = await driver.findComponent(ON.id('case_name'));
    let case1Name: string = await case1.getText();
    expect(case1Name).assertEqual('短视频切换');

    await driver.pressBack();
    await driver.delayMs(200);

    done();
  })

  /**
   * 1、点击主页搜索框
   * 2、点击分类区域
   * 3、输入案例名称，点击搜索
   * 4、点击搜索结果
   * 5、返回
   */
  it(CASE_NAME + '_classify_search', 0, async (done: Function) => {
    let search: Component = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(500);
    let items: Component[] = await driver.findComponents(ON.type('GridItem'));
    await items[0].click();
    await driver.delayMs(200);
    search = await driver.findComponent(ON.type('Search'));
    await search.inputText('弹窗');
    await driver.delayMs(500);
    let button: Component = await driver.findComponent(ON.text('搜索'));
    await button.click();
    await driver.delayMs(1000);
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    await driver.delayMs(1000);
    let case1: Component = await driver.findComponent(ON.id('case_name'));
    let case1Name: string = await case1.getText();
    expect(case1Name.indexOf('弹窗') !== -1).assertTrue();

    await driver.pressBack();
    await driver.delayMs(200);

    done();
  })

  /**
   * 1、点击主页搜索框
   * 2、点击搜索历史的一项
   * 3、返回
   * 4、点击删除历史搜索图标
   * 5、返回
   */
  it(CASE_NAME + '_search_history', 0, async (done: Function) => {
    let search: Component = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(500);
    let history: Component = await driver.findComponent(ON.text('短视频切换'));
    await history.click();
    await driver.delayMs(500);
    let case1: Component = await driver.findComponent(ON.id('case_name'));
    let case1Name: string = await case1.getText();
    expect(case1Name).assertEqual('短视频切换');

    await driver.pressBack();
    await driver.delayMs(200);

    search = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(500);
    let deleteButton: Component = await driver.findComponent(ON.id('delete_history'));
    await deleteButton.click();
    await driver.delayMs(500);
    let confirm: Component = await driver.findComponent(ON.text('确认'));
    await confirm.click();
    await driver.delayMs(200);
    history = await driver.findComponent(ON.text('短视频切换'));
    expect(history).assertNull();

    await driver.pressBack();
    await driver.delayMs(200);

    done();
  })

  /**
   * 1、点击主页搜索框
   * 2、输入‘案例’
   * 3、滑动搜索结果列表
   * 4、点击结果列表项跳转
   * 5、返回
   */
  it(CASE_NAME + '_search_result_list', 0, async (done: Function) => {
    let search: Component = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(500);
    search = await driver.findComponent(ON.type('Search'));
    await search.inputText('案例');
    await driver.delayMs(1000);
    let button: Component = await driver.findComponent(ON.text('搜索'));
    await button.click();
    await driver.delayMs(1000);
    let list: Component = await driver.findComponent(ON.id('search_result_list'));
    await list.scrollToBottom(2000);
    await driver.delayMs(3000);
    let item: Component = await driver.findComponent(ON.text('4.MpChart图表实现案例'));
    await item.click();
    await driver.delayMs(500);
    let case1: Component = await driver.findComponent(ON.id('case_name'));
    let case1Name: string = await case1.getText();
    expect(case1Name).assertEqual('MpChart图表实现案例');

    await driver.pressBack();
    await driver.delayMs(200);

    done();
  })
}
