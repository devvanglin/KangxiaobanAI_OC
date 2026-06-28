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

const CASE: string = 'fontdynamicregistration'; // 案例名称
const CASE_NAME: string = '动态注册字体案例'; // 案例中文名称

/**
 * 【动态注册字体案例】自动化测试用例
 * 1. 搜索进入【动态注册字体案例】，点击思源宋体按钮，切换字体
 */
export default function fontDynamicRegistrationTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 点击思源宋体按钮，切换字体
   * 通过 来判断字体是否切换
   */
  it(CASE + '切换字体', 0, async (done: Function) => {
    await driver.delayMs(300);
    const currentFont = await driver.findComponent(ON.id('text_font'));
    const currentText = await currentFont.getText();
    await expect(currentText).assertEqual('当前字体: HarmonyOS Sans');
    const changeFont = await driver.findComponent(ON.id('change_font'));
    await changeFont.click();
    await driver.delayMs(15000); // 等待字体下载时间 15s
    await expect(await currentFont.getText()).assertEqual('当前字体: 思源宋体');
    done();
  })

  // 退出案例
  exit(CASE_NAME);
}