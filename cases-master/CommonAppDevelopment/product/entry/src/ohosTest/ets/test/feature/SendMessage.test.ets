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

import { Driver, ON } from '@ohos.UiTest';
import { expect, it } from '@ohos/hypium';
import { inputMethod } from '@kit.IMEKit';
import { logger } from 'utils';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import Want from '@ohos.app.ability.Want';

const TAG: string = '[SendMessage_Test]';
const delegator: AbilityDelegatorRegistry.AbilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();

/**
 * 【发短信案例】自动化测试用例
 * 主要功能：
 * 1. 拉起系统短信能力，案例需在真机上使用，点击发送短信后，拉起系统短信界面并回填发件人和发送内容。
 * 执行步骤：
 * 1. 断言存在发送短信按钮，并点击。
 * 2. 拉起系统短信。
 * 3. 断言成功回填收件人电话和短信内容。
 */
export default function sendMessageTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('发短信案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1. 断言存在发送短信按钮，并点击。
   * 2. 拉起系统短信。
   * 3. 断言成功回填收件人电话和短信内容。
   **/
  it('验证发短信功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在发送短信按钮
    await driver.assertComponentExist(ON.id('sendMessage'));
    let sendMessage = await driver.findComponent(ON.id('sendMessage'));
    await sendMessage.click(); // 点击发短信按钮
    await driver.delayMs(2000);
    // 拉起系统短信能力
    let want: Want = {
      bundleName: 'com.ohos.mms',
      abilityName: 'com.ohos.mms.MainAbility',
    };
    delegator.startAbility(want, (err) => {
      logger.info(TAG, 'StartAbility get err ' + JSON.stringify(err));
      expect(err).assertNull();
    })
    await driver.assertComponentExist(ON.text('103981630163222')); // 断言成功拉起系统短信，并回填信息内容
    await driver.assertComponentExist(ON.text('2618')); // 断言成功拉起系统短信，并回填收件人信息
    await driver.delayMs(500);
    // 收起键盘
    let inputMethodController = inputMethod.getController();
    inputMethodController.stopInputSession();
    await driver.delayMs(1000);
    await driver.pressBack();// 首次退出系统短信详情页，返回短信列表
    await driver.delayMs(1000);
    await driver.pressBack();// 返回上级页面，即回到发短信案例
    await driver.delayMs(1000);

    done();
  })

  exit('发短信案例'); // 返回上级页面，即回到瀑布流首页
}
