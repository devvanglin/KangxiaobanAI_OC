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
import { Driver, ON, Component } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = 'HEIF软解码器案例'; // 案例名称

/**
 * 【HEIF软解码器案例】自动化测试用例
 */
export default function decodeHEIFImageTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、正常加载所有HEIF网络图片
   */
  it(CASE_NAME + '_show_HEIF_image', 0, async (done: Function) => {
    // 加载时间较长
    await driver.delayMs(10000);
    let items: Component[] = await driver.findComponents(ON.type('FlowItem'));
    expect(items.length).assertEqual(6);
    await driver.assertComponentExist(ON.id('image1.heic'));
    await driver.assertComponentExist(ON.id('image2.heic'));
    await driver.assertComponentExist(ON.id('image3.heic'));
    await driver.assertComponentExist(ON.id('image4.heic'));
    // 向上滑动
    await driver.swipe(200, 1500, 200, 100, 2200); // 向上滑动
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.id('image5.heic'));
    await driver.assertComponentExist(ON.id('image6.heic'));


    done();
  })

  exit(CASE_NAME);
}
