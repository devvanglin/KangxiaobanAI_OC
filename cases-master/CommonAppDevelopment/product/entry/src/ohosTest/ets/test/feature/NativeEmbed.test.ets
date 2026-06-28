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

const CASE: string = 'NativeEmbed'; // 案例名称
const TAG: string = '[NativeEmbed_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【ArkWeb同层渲染】自动化测试用例
 * 主要功能：显示线程调用。
 * 执行步骤：
 * 1. 进入页面即可看到同层渲染效果。
 */
export default function nativeEmbedTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('ArkWeb同层渲染');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 进入页面即可看到同层渲染效果。
   */
  it(CASE + '进入页面即可看到同层渲染效果。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('充电宝'));
    await driver.findComponent(ON.text('充电宝'));
    done();
  })

  exit('ArkWeb同层渲染');
}