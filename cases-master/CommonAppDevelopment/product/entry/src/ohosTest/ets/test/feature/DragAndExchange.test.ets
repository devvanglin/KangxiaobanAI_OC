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

const CASE: string = 'DragAndExchange'; // 案例名称
const TAG: string = '[DragAndExchange_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【Grid和List内拖拽交换子组件位置】自动化测试用例
 * 主要功能：位置互换。
 * 执行步骤：
 * 1. 拖拽Grid中子组件，到目标Grid子组件位置，进行两者位置互换。
 * 2. 拖拽List中子组件，到目标List子组件位置，进行两者位置互换。
 */
export default function dragAndExchangeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('Grid和List内拖拽交换子组件位置');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 拖拽Grid中子组件，到目标Grid子组件位置，进行两者位置互换。
   */
  it(CASE + '拖拽Grid中子组件，到目标Grid子组件位置，进行两者位置互换。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('App1'));
    let App1 = await driver.findComponent(ON.id('App1'));
    let point1 = await App1.getBoundsCenter();
    await driver.assertComponentExist(ON.id('App3'));
    let App3 = await driver.findComponent(ON.id('App3'));
    let point3 = await App3.getBoundsCenter();
    await App1.dragTo(App3);
    await driver.delayMs(DELAY_MS);
    let App12 = await driver.findComponent(ON.id('App1'));
    let point12 = await App12.getBoundsCenter();
    expect(point1.x !== point12.x).assertTrue();
    expect(point12.x === point3.x).assertTrue();
    done();
  })

  /**
   * 拖拽List中子组件，到目标List子组件位置，进行两者位置互换。
   */
  it(CASE + '拖拽List中子组件，到目标List子组件位置，进行两者位置互换。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('Item1'));
    let Item1 = await driver.findComponent(ON.id('Item1'));
    let point1 = await Item1.getBoundsCenter();
    await driver.assertComponentExist(ON.id('Item3'));
    let Item3 = await driver.findComponent(ON.id('Item3'));
    let point3 = await Item3.getBoundsCenter();
    await Item1.dragTo(Item3);
    await driver.delayMs(DELAY_MS);
    let Item12 = await driver.findComponent(ON.id('Item1'));
    let point12 = await Item12.getBoundsCenter();
    expect(point1.x !== point12.x).assertTrue();
    expect(point12.x === point3.x).assertTrue();
    done();
  })

  exit('Grid和List内拖拽交换子组件位置');
}