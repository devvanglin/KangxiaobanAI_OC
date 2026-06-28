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
import { Driver, ON, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'SideSlipIntercept'; // 案例名称
const TAG: string = '[SideSlipIntercept_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【侧滑返回事件拦截】自动化测试用例
 * 主要功能：返回拦截。
 * 执行步骤：
 * 1. 退出时点保存是否保存。
 * 2. 退出时不点保存是否保存。
 */
export default function sideSlipInterceptTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('侧滑返回事件拦截');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 退出时点保存是否保存。
   */
  it(CASE + '退出时点保存是否保存。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('sideSlipInterceptTextArea'));
    let textArea = await driver.findComponent(ON.id('sideSlipInterceptTextArea'));
    await textArea.inputText('AAAAABBBBB');
    await driver.pressBack();
    await driver.delayMs(DELAY_MS);
    await driver.pressBack();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('保存'));
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('保存成功');
    };
    observer.once('toastShow', callback);
    let confirmBtn = await driver.findComponent(ON.text('保存'));
    await confirmBtn.click();
    await driver.delayMs(2000);

    let search = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(1000);
    let textInput = await driver.findComponent(ON.type('Search'));
    await textInput.inputText('侧滑返回事件拦截');
    await driver.delayMs(1000);
    let searchButton = await driver.findComponent(ON.text('搜索'));
    await searchButton.click();
    await driver.delayMs(2000);
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    await driver.delayMs(1000)

    await driver.assertComponentExist(ON.id('sideSlipInterceptTextArea'));
    let newTextArea = await driver.findComponent(ON.id('sideSlipInterceptTextArea'));
    let newText = await newTextArea.getText();
    expect(newText).assertEqual('AAAAABBBBB');
    done();
  })

  /**
   * 退出时不点保存是否保存。
   */
  it(CASE + '退出时不点保存是否保存。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('sideSlipInterceptTextArea'));
    let textArea = await driver.findComponent(ON.id('sideSlipInterceptTextArea'));
    await textArea.inputText('CCCCCDDDDD');
    await driver.pressBack();
    await driver.delayMs(DELAY_MS);
    await driver.pressBack();
    await driver.delayMs(DELAY_MS)
    await driver.assertComponentExist(ON.text('不保存'));
    let confirmBtn = await driver.findComponent(ON.text('不保存'));
    await confirmBtn.click();
    await driver.delayMs(2000);
    let search = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(1000);
    let textInput = await driver.findComponent(ON.type('Search'));
    await textInput.inputText('侧滑返回事件拦截');
    await driver.delayMs(1000);
    let searchButton = await driver.findComponent(ON.text('搜索'));
    await searchButton.click();
    await driver.delayMs(2000);
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    await driver.delayMs(1000)
    await driver.assertComponentExist(ON.id('sideSlipInterceptTextArea'));
    let newTextArea = await driver.findComponent(ON.id('sideSlipInterceptTextArea'));
    let newText = await newTextArea.getText();
    expect(newText).assertEqual('AAAAABBBBB');
    done();
  })

  exit('NAPI封装ArkTS接口');
}