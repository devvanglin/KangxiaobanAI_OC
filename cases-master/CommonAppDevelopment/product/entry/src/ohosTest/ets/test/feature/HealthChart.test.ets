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
import { Driver, MatchPattern, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import exit from '../common/Exit.test';

const CASE: string = 'HealthChart'; // 案例名称
const TAG: string = '[HealthChart_Test]';
const DELAY_MS: number = 1000; // 指定1000ms的延迟

/**
 * 【MpChart运动健康】自动化测试用例
 * 主要功能：测试图表是否正确展示。
 * 执行步骤：
 * 1. 获取心率图表位置，点击心率图表。
 * 2. 获取步数图表位置，点击步数图表。
 */
export default function healthChartTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('MpChart运动健康');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 获取心率图表位置，点击心率图表。
   */
  it(CASE + '获取心率图表位置，点击心率图表。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('mpChartList'));
    let mpChartList = await driver.findComponent(ON.id('mpChartList'));
    let heartRateBtn = await mpChartList.scrollSearch(ON.id('heartRate'));
    let point = await heartRateBtn.getBoundsCenter();
    await driver.click(point.x, point.y);
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('心率：', MatchPattern.CONTAINS));
    done();
  })

  /**
   * 获取步数图表位置，点击步数图表。
   */
  it(CASE + '获取步数图表位置，点击步数图表。', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('mpChartList'));
    let mpChartList = await driver.findComponent(ON.id('mpChartList'));
    let heartRateBtn = await mpChartList.scrollSearch(ON.id('stepNumber'));
    let point = await heartRateBtn.getBoundsCenter();
    await driver.click(point.x, point.y);
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('步数：', MatchPattern.CONTAINS));
    done();
  })

  exit('MpChart运动健康');
}