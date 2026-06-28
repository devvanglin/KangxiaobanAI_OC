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

const CASE_NAME: string = '列表项交换案例';

/**
 * 【列表项交换案例】自动化测试用例
 */
export default function listExchangeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 长按列表项，将选中的列表项插入对应位置
   */
  it(CASE_NAME + '_drag_move', 0, async (done: Function) => {
    let item0 = await driver.findComponent(ON.id('list_exchange_0'));
    let item2 = await driver.findComponent(ON.id('list_exchange_2'));
    let item0Text: string = (await item0.getText()).toString();
    await item0.dragTo(item2);
    await driver.delayMs(200);
    let item2After = await driver.findComponent(ON.id('list_exchange_2'));
    let item2AfterText: string = (await item2After.getText()).toString();
    // 断言： 切换后的第三项就是切换前的第一项
    expect(item0Text).assertEqual(item2AfterText);
    await driver.delayMs(200);

    done();
  })

  /**
   * 列表项向右滑动，点击删除按钮
   */
  it(CASE_NAME + '_delete', 0, async (done: Function) => {
    let itemsBefore = await driver.findComponents(ON.type('ListItem'));
    let item0 = await driver.findComponent(ON.id('list_exchange_0'));
    let point = await item0.getBoundsCenter();
    console.log("point: " + JSON.stringify(point));
    await driver.swipe(point.x + 200, point.y, point.x - 200, point.y, 2000);
    await driver.delayMs(1000);
    let deleteButton = await driver.findComponent(ON.id('delete_button'));
    await deleteButton.click();
    await driver.delayMs(500);
    let itemsAfter = await driver.findComponents(ON.type('ListItem'));
    // 断言：删除后的列表项数比删除前少一个
    expect(itemsBefore.length).assertEqual(itemsAfter.length + 1);

    done();
  })

  exit(CASE_NAME);
}