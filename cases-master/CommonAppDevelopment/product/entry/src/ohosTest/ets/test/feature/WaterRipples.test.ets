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

const CASE: string = 'WaterRipples'; // 案例名称
const CASE_NAME: string = '听歌识曲水波纹特效案例'; // 案例中文名称

/**
 * 【听歌识曲水波纹特效案例】自动化测试用例
 * 1. 搜索进入【听歌识曲水波纹特效案例】
 * 2. 点击按钮，出现动画
 * 3. 再次点击，动画消失
 */
export default function waterRipplesTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 开始水波纹动效
   */
  it(CASE_NAME + '_Start_WaterRipples', 0, async (done: Function) => {
    let driver = Driver.create();

    // 水波纹动效按钮是否可点击
    await driver.assertComponentExist(ON.type('Button').id('ripplesButton').enabled(true)); // 断言按钮是否存在且可点击
    const ripplesButton = await driver.findComponent(ON.type('Button').id('ripplesButton'));
    await ripplesButton.click();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 停止水波纹动画
   */
  it(CASE_NAME + '_End_WaterRipples', 0, async (done: Function) => {
    let driver = Driver.create();

    // 水波纹动效按钮是否可点击
    await driver.assertComponentExist(ON.type('Button').id('ripplesButton').enabled(true)); // 断言按钮是否存在且可点击
    const ripplesButton = await driver.findComponent(ON.type('Button').id('ripplesButton'));
    await ripplesButton.click();
    await driver.delayMs(1000);

    done();
  })

  // 退出案例
  exit(CASE_NAME);
}