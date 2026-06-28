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

const CASE: string = 'ImageGridLayout'; // 案例名称
const TAG: string = '[ImageGridLayout_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【图片九宫格封装案例用】自动化测试用例
 * 主要功能：自动布局。
 * 执行步骤：
 * 1. 图片按照个数进行相应的布局。
 */
export default function imageGridLayoutTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('图片九宫格封装案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 图片按照个数进行相应的布局。
   */
  it(CASE + '图片按照个数进行相应的布局。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('一张图片场景', MatchPattern.CONTAINS));
    await driver.assertComponentExist(ON.text('三张图片场景', MatchPattern.CONTAINS));
    done();
  })

  exit('图片九宫格封装案例用');
}