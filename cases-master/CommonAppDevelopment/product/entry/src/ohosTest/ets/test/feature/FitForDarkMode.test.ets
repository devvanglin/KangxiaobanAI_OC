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
import { logger } from 'utils';
import Want from '@ohos.app.ability.Want';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import exit from '../common/Exit.test';

const CASE: string = 'FitForDarkMode'; // 案例名称
const CASE_NAME: string = '深色模式案例'; // 案例中文名称
const TAG: string = '[FitForDarkMode_Test]';
const SETTING: string = 'SETTINGS'; // 案例名称
const delegator: AbilityDelegatorRegistry.AbilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
const bundleName: string = AbilityDelegatorRegistry.getArguments().bundleName;

/**
 * 【深色模式案例】自动化测试用例
 * 1. 搜索进入【深色模式案例】，当前默认一般为浅色模式
 * 2. 点击系统【设置】-【显示和亮度】-【深色模式】点击按钮切换颜色模式
 * 3. 再次搜索进入【深色模式案例】，颜色模式会发生改变
 */
export default function fitForDarkModeTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);
  // 退出案例
  exit(CASE_NAME);

  /**
   * 打开系统设置应用，点击【设置】-【显示和亮度】-【深色模式】点击按钮切换颜色模式
   */
  it(SETTING, 0, async (done: Function) => {
    let driver = Driver.create();

    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility'
    };
    delegator.startAbility(want, (err) => {
      logger.info(TAG, 'StartAbility get err ' + JSON.stringify(err));
      expect(err).assertNull();
    })
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.text('显示和亮度')); // 断言是否存在显示和亮度按钮
    const display = await driver.findComponent(ON.text('显示和亮度'));
    await display.click();
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.text('深色模式')); // 断言是否存在深色模式按钮
    const dark = await driver.findComponent(ON.text('深色模式'));
    await dark.click();
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.text('全天开启')); // 断言是否存在全天开启项
    const switchButton = await driver.findComponent(ON.isAfter(ON.text('全天开启')).type('Toggle'));
    await switchButton.click();
    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 重新打开【我的开发案例】应用，查看颜色模式是否发生变化
   */
  it(CASE + '_ModeChange', 0, async (done: Function) => {
    let driver = Driver.create();

    const caseWant: Want = {
      bundleName: bundleName,
      abilityName: 'EntryAbility'
    };
    delegator.startAbility(caseWant, (err) => {
      logger.info(TAG, 'StartAbility get err ' + JSON.stringify(err));
      expect(err).assertNull();
    })
    await driver.delayMs(1000);

    done();
  })

  // 搜索并进入
  searchCaseClickIn(CASE_NAME);
  // 退出案例
  exit(CASE_NAME);
}