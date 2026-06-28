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

const CASE_NAME: string = 'H5页面资源离线缓存案例'; // 案例名称

/**
 * 【H5页面资源离线缓存案例】自动化测试用例
 */
export default function h5CacheTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、加载网页
   */
  it(CASE_NAME + '_load_web', 0, async (done: Function) => {
    let web: Component = await driver.findComponent(ON.type('Web'));
    expect(web).assertNull();
    let loadButton: Component = await driver.findComponent(ON.text('加载网页'));
    await loadButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.type('Web'));

    await driver.pressBack();

    done();
  })

  exit(CASE_NAME);
}
