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

const CASE_NAME: string = '分享二维码按钮案例'; // 案例中文名称

/**
 * 【分享二维码按钮案例】自动化测试用例
 * 1. 确认是否有华为分享标志
 */
export default function shareButtonTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn("听歌识曲水波纹特效案例")

  let driver = Driver.create();

  /**
   * 关联用例: 拉起系统分享弹窗。
   * 执行步骤:
   * 1. 确认是否有华为分享标志
   */
  it(CASE_NAME + "_拉起系统分享弹窗", 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('源码网页'));
    let entryDrawerIcon = await driver.findComponent(ON.text('源码网页'));
    await entryDrawerIcon.click(); // 点击发短信按钮
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.id('share_button'));
    let shareButton = await driver.findComponent(ON.id("share_button"));
    await shareButton.click(); // 点击发短信按钮
    await driver.delayMs(2000);

    await driver.assertComponentExist(ON.text('华为分享'));

    done();
  })

  it(CASE_NAME + "_关闭弹窗", 0, async (done: Function) => {
    await driver.pressBack();
    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);
    
    done();
  })
  // 退出案例
  exit(CASE_NAME);
}
