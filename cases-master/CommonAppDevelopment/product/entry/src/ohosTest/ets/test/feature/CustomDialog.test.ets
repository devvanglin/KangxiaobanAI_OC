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

const CASE_NAME: string = '全局弹窗封装案例'; // 案例名称

/**
 * 【全局弹窗封装案例】自动化测试用例
 */
export default function customDialogTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、进入案例时‘领取红包’弹窗能出现，点击右上角‘x’能关闭弹窗
   * 2、点击‘发红包’按钮，能出现‘领取红包弹窗’，点击右上角‘x’能关闭弹窗
   */
  it(CASE_NAME + '_subwindow', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('领取红包'));
    let closeButton: Component = await driver.findComponent(ON.id('close_button'));
    await closeButton.click();
    await driver.delayMs(200);
    let text = await driver.findComponent(ON.text('领取红包'));
    expect(text).assertNull();

    let openButton: Component = await driver.findComponent(ON.text('发红包'));
    await openButton.click();
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.text('领取红包'));
    closeButton = await driver.findComponent(ON.id('close_button'));
    await closeButton.click();
    await driver.delayMs(200);

    done();
  })

  /**
   * 1、点击提现按钮，能出现‘请先绑定储蓄卡再提现’的弹窗，点击‘去绑定’会有‘仅演示’的提示，点击‘取消’能关闭弹窗
   */
  it(CASE_NAME + '_dialog', 0, async (done: Function) => {
    let openButton: Component = await driver.findComponent(ON.text('提现'));
    await openButton.click();
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.text('请先绑定储蓄卡再提现'));
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('仅演示，可自行实现业务功能'); // 通过弹出'仅演示，可自行实现业务功能'提示来验证
    };
    observer.once('toastShow', callback);
    let bindButton: Component = await driver.findComponent(ON.text('去绑定'));
    await bindButton.click();
    await driver.delayMs(1000);

    let cancelButton: Component = await driver.findComponent(ON.text('取消'));
    await cancelButton.click();
    await driver.delayMs(500);
    let tip = await driver.findComponent(ON.text('请先绑定储蓄卡再提现'));
    expect(tip).assertNull();

    done();
  })

  exit(CASE_NAME);
}
