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
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';
import { Want } from '@kit.AbilityKit';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

const CASE: string = 'shareimagepage'; // 案例名称
const CASE_NAME: string = '图片分享案例';

/**
 * 【图片分享案例】自动化测试用例
 * 需要使用真机测试
 * 1.发送文字消息
 * 2.分享图片到case
 */
export default function shareImagePageTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('图片分享案例');
  const driver = Driver.create();
  const delegator: AbilityDelegatorRegistry.AbilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();


/*  *//**
   * 执行步骤：
   * 1.底部输入框输入"这是发送的消息"点击发送按钮
   * 2.通过判断输入框中没有文字,且列表中有发送的消息来验证
   **//*
  it(CASE + '发送文字消息', 0, async (done: Function) => {
    const textInput = await driver.findComponent(ON.type('TextInput'));
    await textInput.inputText('这是发送的消息');
    const send = await driver.findComponent(ON.text('发送'));
    await send.click();
    await driver.delayMs(200);
    const textIn = await driver.findComponent(ON.type('TextInput'));
    expect(await textIn.getText()).assertEqual('');
    await driver.assertComponentExist(ON.text('这是发送的消息')) // 通过判断输入框中没有文字,且列表中有发送的消息来验证
    done();
  })*/

  /**
   * 执行步骤：
   * 1.拉起相机，拍摄一张照片。点击分享按钮，选择case应用
   * 2.通过案例内是否出现图片来判断
   **/
  it(CASE + '分享图片', 0, async (done: Function) => {
    const want: Want = {
      bundleName: 'com.huawei.hmos.camera',
      abilityName: 'com.huawei.hmos.camera.MainAbility'
    };
    delegator.startAbility(want, (err) => {
      logger.info(CASE, 'StartAbility get err ' + JSON.stringify(err));
      expect(err).assertNull();
    });
    await driver.delayMs(1000);
    if (await driver.findComponent(ON.text('夜景增强'))) {
      const night = await driver.findComponent(ON.text('夜景增强'));
      await night.click();
      await driver.delayMs(300);
    }
    await driver.click(630, 2317); // 点击拍照
    await driver.delayMs(1000);
    await driver.click(200, 2317); // 刚刚拍摄的图片
    await driver.delayMs(2000);
    await driver.click(630, 1300); // 调出分享按钮
    await driver.delayMs(300);
    await driver.click(110, 2539); // 分享按钮
    await driver.delayMs(1000);
    const app = await driver.findComponent(ON.text('我的开发案例'));
    await app.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.id('shared_image')); // 通过案例内是否出现图片来判断
    await driver.delayMs(500);
    done();
  })

  // 退出案例
  exit(CASE_NAME);


}