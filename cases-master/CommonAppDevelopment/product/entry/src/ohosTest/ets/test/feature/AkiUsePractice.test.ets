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
import { logger } from 'utils';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'AkiUsePractice'; // 案例名称
const TAG: string = '[AkiUsePractice_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟

/**
 * 【使用AKI轻松实现跨语言调用】自动化测试用例
 * 主要功能：使用AKI编写C++跨线程调用JS函数场景。通过调用C++全局函数，创建子线程来调用JS函数，实现对变量value的
 * 加10操作，为开发者使用AKI提供参考。
 * 执行步骤：
 * 1.点击两次"AKI跨线程调用JS函数"按钮，每次点击，显示数值加10。
 */
export default function akiUsePracticeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('使用AKI轻松实现跨语言调用');
  let val: number = 0;
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);
  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    val = data.data?.val;
  })

  /**
   * 点击两次"AKI跨线程调用JS函数"按钮，每次点击，显示数值加10
   */
  it(CASE + '点击AKI跨线程调用JS函数按钮', 0, async (done: Function) => {
    let akiBtn = await driver.findComponent(ON.id('aki'));
    await akiBtn.click();
    await driver.delayMs(DELAY_MS);
    await akiBtn.click();
    await driver.delayMs(DELAY_MS);
    // 断言点击两次按钮后的值是否为20
    expect(val).assertEqual(20);
    logger.info(TAG, `${CASE} end`);
    done();
  })

  exit('使用AKI轻松实现跨语言调用');
}