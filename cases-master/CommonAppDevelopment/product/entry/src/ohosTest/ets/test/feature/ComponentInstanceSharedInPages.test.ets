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
import { Component, Driver, ON } from '@ohos.UiTest';
import { logger } from "utils";
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'componentinstancesharedinpages'; // 案例名称
const CASE_NAME: string = '页面间共享组件实例';

/**
 * 【页面间共享组件实例】自动化测试用例
 * 1. 拉起半模态弹窗
 * 2. 拉起活体检测页面
 * 3. 活体检测
 */
export default function componentInstanceSharedInPagesTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('页面间共享组件实例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1.拖动地图
   * 2.弹窗动画结束前，点击"打车"按钮
   * 3.通过切换到打车页面，弹窗动画还在继续来判断
   **/
  it(CASE + '页面间使用同一个组件实例', 0, async (done: Function) => {
    await driver.swipe(902, 894, 600, 894);
    const taxi = await driver.findComponent(ON.id('taxi_button'));
    await taxi.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.id('ThumbTackComponent'));
    await driver.pressBack();
    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  // 退出案例
  exit(CASE_NAME);


}