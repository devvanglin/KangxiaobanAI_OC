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
import { Driver, MatchPattern, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'EtsWrapper'; // 案例名称
const TAG: string = '[EtsWrapper_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【NAPI封装ArkTS接口】自动化测试用例
 * 主要功能：位置互换。
 * 执行步骤：
 * 1. 点击"JS线程调用"按钮拉起picker，单击直接选择单个文件。
 * 2. 点击"PThread线程调用"按钮拉起picker，单击直接选择单个文件。
 */
export default function etsWrapperTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('NAPI封装ArkTS接口');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 点击"JS线程调用"按钮拉起picker，单击直接选择单个文件。
   */
  it(CASE + '点击"JS线程调用"按钮拉起picker，单击直接选择单个文件。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('JS线程调用').type('Button'));
    let jsButton = await driver.findComponent(ON.text('JS线程调用').type('Button'));
    await jsButton.click();
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('浏览'));
    let lookButton = await driver.findComponent(ON.text('浏览'));
    await lookButton.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('我的手机'));
    let phoneButton = await driver.findComponent(ON.text('我的手机'));
    await phoneButton.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('Documents'));
    let documentsButton = await driver.findComponent(ON.text('Documents'));
    await documentsButton.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('欢迎使用', MatchPattern.CONTAINS));
    let pdfButton = await driver.findComponent(ON.text('欢迎使用', MatchPattern.CONTAINS));
    await pdfButton.click();
    await driver.delayMs(DELAY_MS);
    let finishButton = await driver.findComponent(ON.text('完成'));
    if (finishButton) {
      await finishButton.click();
      await driver.delayMs(DELAY_MS);
    }
    await driver.assertComponentExist(ON.text('file://', MatchPattern.CONTAINS));
    await driver.findComponent(ON.text('file://', MatchPattern.CONTAINS));
    done();
  })

  /**
   * 点击"JS线程调用"按钮拉起picker，单击直接选择单个文件。
   */
  it(CASE + '点击"PThread线程调用"按钮拉起picker，单击直接选择单个文件。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('PThread线程调用').type('Button'));
    let jsButton = await driver.findComponent(ON.text('PThread线程调用').type('Button'));
    await jsButton.click();
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('浏览'));
    let lookButton = await driver.findComponent(ON.text('浏览'));
    await lookButton.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('我的手机'));
    let phoneButton = await driver.findComponent(ON.text('我的手机'));
    await phoneButton.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('Documents'));
    let documentsButton = await driver.findComponent(ON.text('Documents'));
    await documentsButton.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('欢迎使用', MatchPattern.CONTAINS));
    let pdfButton = await driver.findComponent(ON.text('欢迎使用', MatchPattern.CONTAINS));
    await pdfButton.click();
    await driver.delayMs(DELAY_MS);
    let finishButton = await driver.findComponent(ON.text('完成'));
    if (finishButton) {
      await finishButton.click();
      await driver.delayMs(DELAY_MS);
    }
    await driver.assertComponentExist(ON.text('file://', MatchPattern.CONTAINS));
    await driver.findComponent(ON.text('file://', MatchPattern.CONTAINS));
    done();
  })

  exit('NAPI封装ArkTS接口');
}