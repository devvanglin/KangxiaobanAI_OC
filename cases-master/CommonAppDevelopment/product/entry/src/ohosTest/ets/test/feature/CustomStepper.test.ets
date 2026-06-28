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
import { Driver, ON, Component, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '自定义Stepper'; // 案例名称

/**
 * 【自定义Stepper】自动化测试用例
 */
export default function customStepperTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、查看‘用户须知’页面，点击‘下一页’按钮
   * 2、查看‘申请人员类别’页面，任意选择一项后，点击‘下一页’按钮
   * 3、查看‘在线填表’页面，输入姓名和年龄后，点击’提交‘按钮
   */
  it(CASE_NAME + '_next_page', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('用户须知'));
    let scroll: Component = await driver.findComponent(ON.type('Scroll'));
    await scroll.scrollToBottom(2000);
    await driver.delayMs(500);
    let nextPage: Component = await driver.findComponent(ON.text('下一页'));
    await nextPage.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('申请人员类别'));
    // 断言：不选择直接点击下一页会出现提示“数据填写不完整”
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('数据填写不完整'); // 通过弹出'数据填写不完整'提示来验证
    };
    observer.once('toastShow', callback);
    nextPage = await driver.findComponent(ON.text('下一页'));
    await nextPage.click();

    let choose: Component = await driver.findComponent(ON.text('符合特殊条件'));
    await choose.click();
    await driver.delayMs(1000);
    await nextPage.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('在线填表'));
    let commit: Component = await driver.findComponent(ON.text('提交'));
    await commit.click();
    // 断言：不填写直接提交，会提示数据填写不完整
    let callback1 = (UIElementInfo1: UIElementInfo) => {
      expect(UIElementInfo1.text).assertEqual('数据填写不完整'); // 通过弹出'数据填写不完整'提示来验证
    };
    observer.once('toastShow', callback1);
    let name: Component = await driver.findComponent(ON.type('TextInput').isAfter(ON.text('姓名')));
    await name.inputText('张三');
    await driver.delayMs(1000);
    let age: Component = await driver.findComponent(ON.type('TextInput').isAfter(ON.text('年龄')));
    await age.inputText('25');
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(1000);
    commit = await driver.findComponent(ON.text('提交'));
    await commit.click();
    // 断言：填写后提交，会提示“数据已提交”
    let callback2 = (UIElementInfo2: UIElementInfo) => {
      expect(UIElementInfo2.text).assertEqual('数据已提交');
    };
    observer.once('toastShow', callback2);

    done();
  })

  /**
   * 1、在‘在线填表’页面，点击‘上一页’按钮
   * 2、‘申请人员类别’页面，点击‘上一页’按钮
   */
  it(CASE_NAME + '_last_page', 0, async (done: Function) => {
    let lastPage: Component = await driver.findComponent(ON.text('上一页'));
    await lastPage.click();
    await driver.delayMs(1000);
    let radios: Component[] = await driver.findComponents(ON.id('option'));
    expect(radios.length).assertEqual(4);
    expect(await radios[3].isChecked()).assertTrue();
    lastPage = await driver.findComponent(ON.text('上一页'));
    await lastPage.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('用户须知'));

    done();
  })

  exit(CASE_NAME);
}
