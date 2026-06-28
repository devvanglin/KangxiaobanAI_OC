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

const CASE_NAME: string = '网格元素交换'; // 案例名称

/**
 * 【网格元素交换案例】自动化测试用例
 */
export default function gridExchangeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、进入案例后，页面正常显示
   */
  it(CASE_NAME + '_init', 0, async (done: Function) => {
    let isShow: boolean = false;
    let grid: Component = await driver.findComponent(ON.id('gridContainer'));
    let flexList: Component[] = await driver.findComponents(ON.id('flexContainer'));
    // grid容器和两个flex容器都可以找到，说明页面正常显示
    if (grid && flexList.length === 2) {
      isShow = true;
    }
    expect(isShow).assertEqual(true);

    done();
  })

  /**
   * 2、点击编辑按钮，长按拖动网格元素
   */
  it(CASE_NAME + '_drag_change', 0, async (done: Function) => {
    let editButton: Component = await driver.findComponent(ON.text('编辑'));
    await editButton.click();
    await driver.delayMs(200);
    let app3: Component = await driver.findComponent(ON.text('APP3'));
    let app8: Component = await driver.findComponent(ON.text('APP8'));
    let app3Point = await app3.getBoundsCenter();
    let app8Point = await app8.getBoundsCenter();
    console.log('app3after: ' + app3Point.y);
    // 断言：变换前APP3应在APP8的上面
    expect(app3Point.y).assertLess(app8Point.y);

    await app3.dragTo(app8);
    await driver.delayMs(200);
    let app3After: Component = await driver.findComponent(ON.text('APP3'));
    let app8After: Component = await driver.findComponent(ON.text('APP8'));
    let app3PointAfter = await app3After.getBoundsCenter();
    let app8PointAfter = await app8After.getBoundsCenter();

    // 断言：变换前APP3应与APP8在同一行
    expect(app3PointAfter.y).assertEqual(app8PointAfter.y);

    done();
  })

  /**
   * 3、点击-图标，从网格中删除元素
   */
  it(CASE_NAME + '_delete', 0, async (done: Function) => {
    let deleteButton: Component = await driver.findComponent(ON.id('delete_button').within(ON.id('APP3InHome')));
    await deleteButton.click();
    await driver.delayMs(1000);
    let app3: Component = await driver.findComponent(ON.id('APP3InHome'));
    // 断言：被删除的APP3不在网格内
    expect(app3).assertNull();

    done();
  })

  /**
   * 3、点击底部元素的+图标，往网格内加元素
   */
  it(CASE_NAME + '_add', 0, async (done: Function) => {
    let addButton: Component = await driver.findComponent(ON.id('add_button').within(ON.id('APP3')));
    await addButton.click();
    await driver.delayMs(200);
    let saveButton: Component = await driver.findComponent(ON.text('保存'));
    await saveButton.click();
    await driver.delayMs(200);
    // 断言：APP3已被添加入网格
    await driver.assertComponentExist(ON.id('APP3InHome'));

    done();
  })

  exit(CASE_NAME);
}
