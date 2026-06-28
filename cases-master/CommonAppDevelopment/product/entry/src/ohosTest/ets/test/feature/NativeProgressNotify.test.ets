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

/**
 * 【在Native侧实现进度通知功能】自动化测试用例
 */
export default function nativeProgressNotifyTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('在Native侧实现进度通知功能');

  const driver = Driver.create();
  it("验证开启下载后下载进度条有更新", 0, async (done: Function) => {
    // 下载按钮
    await driver.assertComponentExist(ON.id('btnProgressNotify'));
    const btnStartDownload = await driver.findComponent(ON.id('btnProgressNotify'));
    // 下载进度
    await driver.assertComponentExist(ON.id('txtProgress'));
    const txtProgress = await driver.findComponent(ON.id('txtProgress'));
    // 验证初始进度为0
    const startProgress: string = await txtProgress!.getText();
    expect(startProgress).assertEqual('当前下载进度：0%');
    // 执行下载
    await btnStartDownload.click();
    await driver.delayMs(12000);
    // 验证下载进度100%
    const endProgress: string = await txtProgress!.getText();
    expect(endProgress).assertEqual('当前下载进度：100%');

    done();
  })

  exit('在Native侧实现进度通知功能');
}