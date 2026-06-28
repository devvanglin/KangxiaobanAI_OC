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

const CASE_NAME: string = '配置ImageKnife请求头实现防盗链功能'; // 案例中文名称
// 默认图片Referer
const DEFAULT_REFER: string = 'https://gitee.com/';

/**
 * 【配置ImageKnife请求头实现防盗链功能】自动化测试用例
 * 1. 点击请求按钮
 * 2. 点击重置按钮
 * 3. 修改referer中的网址
 * 4. 点击请求
 */
export default function imageTheftTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 点击请求按钮
   */
  it(CASE_NAME + '_Request', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.type('Button').text('请求').enabled(true)); // 断言按钮是否存在
    const button = await driver.findComponent(ON.type('Button').text('请求'));
    await button.click();
    await driver.delayMs(5000);

    done();
  })

  /**
   * 点击重置按钮
   */
  it(CASE_NAME + '_Reset', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.type('Button').text('重置').enabled(true)); // 断言按钮是否存在
    const button = await driver.findComponent(ON.type('Button').text('重置'));
    await button.click();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 点击时钟按钮，回到刚才记录的位置
   */
  it(CASE_NAME + '_Modify_Referer', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.type('TextArea').text(DEFAULT_REFER));  // 断言是否存在referer输入框
    const textArea = await driver.findComponent(ON.type('TextArea').text(DEFAULT_REFER));
    await textArea.inputText("https://imnotgitee.com/") // 输入其他网站
    await driver.delayMs(1000);

    done();
  })

  /**
   * 再次点击请求按钮
   */
  it(CASE_NAME + '_Request_Again', 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.assertComponentExist(ON.type('Button').text('请求').enabled(true)); // 断言按钮是否存在
    const button = await driver.findComponent(ON.type('Button').text('请求'));
    await button.click();
    await driver.delayMs(5000);

    done();
  })

  // 退出案例
  exit(CASE_NAME);
}