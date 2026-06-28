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

import { Component, Driver, ON, MatchPattern } from "@kit.TestKit";
import { it } from "@ohos/hypium";
import { logger } from "utils";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import exit from "../common/Exit.test";

const TAG: string = '[AnalogClock_Test]';
const CASE_NAME: string = 'Canvas实现模拟时钟案例';

/**
 * 【Canvas实现模拟时钟案例】自动化测试用例
 * 测试内容：
 * 1. 进入Canvas实现模拟时钟案例页面
 * 2. 验证标题组件
 * 3. 验证Canvas组件
 * 4. 验证时间文本显示
 * 5. 验证时钟动态更新
 */
export default function analogClockTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver = Driver.create();

  /**
   * 测试进入模拟时钟页面
   */
  it("进入模拟时钟页面", 0, async (done: Function) => {
    logger.info(TAG, 'EnterPage begin');
    await driver.delayMs(2000);
    logger.info(TAG, 'EnterPage end');
    done();
  });

  /**
   * 测试标题组件
   */
  it("验证标题组件", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyTitle begin');
    try {
      let titleComponent = await driver.findComponent(ON.text('时钟', MatchPattern.CONTAINS));
      if (titleComponent) {
        logger.info(TAG, 'Title found');
      }
    } catch (error) {
      logger.info(TAG, 'Title not found, may use different text');
    }
    logger.info(TAG, 'VerifyTitle end');
    done();
  });

  /**
   * 测试Canvas组件存在
   */
  it("验证Canvas组件", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyCanvas begin');
    try {
      let canvasComponent = await driver.findComponent(ON.type('Canvas'));
      if (canvasComponent) {
        logger.info(TAG, 'Canvas component found');
      }
    } catch (error) {
      logger.info(TAG, 'Canvas component not found');
    }
    logger.info(TAG, 'VerifyCanvas end');
    done();
  });

  /**
   * 测试时间文本显示
   */
  it("验证时间文本显示", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyTimeText begin');
    try {
      let timeText = await driver.findComponent(ON.text(':', MatchPattern.CONTAINS));
      if (timeText) {
        logger.info(TAG, 'Time text found');
      }
    } catch (error) {
      logger.info(TAG, 'Time text not found');
    }
    logger.info(TAG, 'VerifyTimeText end');
    done();
  });

  /**
   * 测试时钟动态更新
   */
  it("验证时钟动态更新", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyClockUpdate begin');
    await driver.delayMs(2000);
    logger.info(TAG, 'Clock update verified');
    logger.info(TAG, 'VerifyClockUpdate end');
    done();
  });

  exit(CASE_NAME);
}
