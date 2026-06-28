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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { Driver, ON } from '@ohos.UiTest';
import Want from '@ohos.app.ability.Want';
import { logger } from 'utils';
import assembleTestCase from './AssembleTestCase.test';
import simplifyTestCase from './SimplifyTestCase.test';

const BUNDLE: string = 'Cases';
const TAG: string = '[Cases_Test]';
const delegator: AbilityDelegatorRegistry.AbilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
const bundleName: string = AbilityDelegatorRegistry.getArguments().bundleName;

export default function mainAbilityTest() {
  describe('ActsAbilityTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    /**
     * 打开应用
     */
    it(BUNDLE + '_startAbility', 0, async (done: Function) => {
      await startApp();
      done();
    });
    // 自定义组装测试用例
    assembleTestCase()

    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    })
  })

  // 全量自动化测试用例（只验证应用是否可以正常进入和退出）
  describe('CommonActsAbilityTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    /**
     * 打开应用
     */
    it(BUNDLE + '_startAbility', 0, async (done: Function) => {
      await startApp();
      done();
    });
    // 全量自动化测试用例（只验证应用是否可以正常进入和退出）
    simplifyTestCase();

    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    })
  })
}

async function startApp() {

  logger.info(TAG, BUNDLE + '_startAbility start')
  let want: Want = {
    bundleName: bundleName,
    abilityName: 'EntryAbility'
  };
  delegator.startAbility(want, (err) => {
    logger.info(TAG, 'StartAbility get err ' + JSON.stringify(err));
    expect(err).assertNull();
  })
  logger.info(TAG, BUNDLE + '_startAbility end');
  let driver: Driver = Driver.create();
  await driver.delayMs(3000);
  await driver.assertComponentExist(ON.text('同意并继续').type('Button'));
  let agreeButton = await driver.findComponent(ON.text('同意并继续').type('Button'));
  await agreeButton.click();

  // 等待开机广告结束
  await driver.delayMs(6000);

  try {
    // 判断是否有小艺弹框
    await driver.assertComponentExist(ON.type('Search'))
    const search = await driver.findComponent(ON.type('Search'))
    await search.click();
    await driver.delayMs(2000);

    await driver.assertComponentExist(ON.text('同意'));
    const xYAgreeButton = await driver.findComponent(ON.text('同意'));
    await xYAgreeButton.click();
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.text('下一步'));
    const xYNextButton = await driver.findComponent(ON.text('下一步'));
    await xYNextButton.click();
    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);

  } catch (error) {
    logger.error(TAG, error.message);
  }
}