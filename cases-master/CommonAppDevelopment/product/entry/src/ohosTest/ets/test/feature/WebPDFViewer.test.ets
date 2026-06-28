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

const CASE: string = 'WebPDFViewer'; // 案例名称
const CASE_NAME: string = 'Web组件预览PDF及office文件实现案例'; // 案例中文名称

/**
 * 【Web组件预览PDF及office文件实现案例】自动化测试用例
 * 1. 搜索进入【Web组件预览PDF及office文件实现案例】，默认为预览本地PDF文件
 * 2. 点击预览网络PDF文件按钮
 */
export default function webPDFViewerTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 预览本地PDF文件按钮
   */
  it(CASE + '_Location_PDF', 0, async (done: Function) => {
    let driver = Driver.create();

    // 预览本地PDF文件按钮是否可点击
    await driver.assertComponentExist(ON.text('预览本地PDF').enabled(true)); // 断言按钮是否存在且可点击
    const location = await driver.findComponent(ON.text('预览本地PDF'));
    await location.click();
    await driver.delayMs(2000);

    done();
  })

  /**
   * 点击预览网络PDF文件按钮
   */
  it(CASE + 'Remote_PDF', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击预览网络PDF文件按钮
    await driver.assertComponentExist(ON.text('预览网络PDF').enabled(true)); // 断言按钮是否存在且可点击
    const remote = await driver.findComponent(ON.text('预览网络PDF'));
    await remote.click();
    await driver.delayMs(2000);

    done();
  })

  /**
   * 点击预览网络Excel文件按钮
   */
  it(CASE + 'Remote_Excel', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击预览网络Excel文件按钮
    await driver.assertComponentExist(ON.text('预览网络Excel').enabled(true)); // 断言按钮是否存在且可点击
    const excel = await driver.findComponent(ON.text('预览网络Excel'));
    await excel.click();
    await driver.delayMs(2000);

    done();
  })

  /**
   * 点击预览网络PPT文件按钮
   */
  it(CASE + 'Remote_PPT', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击预览网络PPT文件按钮
    await driver.assertComponentExist(ON.text('预览网络PPT').enabled(true)); // 断言按钮是否存在且可点击
    const ppt = await driver.findComponent(ON.text('预览网络PPT'));
    await ppt.click();
    await driver.delayMs(2000);

    done();
  })
  // 退出案例
  exit(CASE_NAME);
}