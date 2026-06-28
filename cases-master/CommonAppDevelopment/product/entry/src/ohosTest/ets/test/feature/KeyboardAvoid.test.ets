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
import { Driver, ON } from '@kit.TestKit';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';


const CASE: string = 'KeyboardAvoid'; // 案例名称

/**
 * 【组件随软键盘弹出避让案例】自动化测试用例
 * 1. 进入案例时，TextInput获焦，弹出系统键盘，点击空白地方键盘收起；
 * 2. 点击输入框触发TextInput获焦，弹出系统键盘；
 * 3. 点击“弹出键盘”按钮触发TextInput获焦，弹出系统键盘；
 * 4. 在上抬避让模式下， 键盘抬起时组件上抬，键盘收起后让组件恢复；
 * 5. 在缩小避让模式下，键盘抬起时组件上抬并缩小，键盘收起后让组件恢复；
 */
export default function keyboardAvoidTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('组件随软键盘弹出避让案例');
  let driver = Driver.create();

  /**
   * 关联用例: 访问案例，软键盘自动拉起，上抬避让页面组件实现上抬避让
   * 执行步骤:
   * 1. 滑动页面，查看上抬避让效果
   * 2. 通过判断键盘是否拉起和是否展示全部数据(共12条)进行验证
   */
  it(CASE + '上抬避让模式', 0, async (done: Function) => {
    let KeyboardAvoidTextInput = await driver.findComponent(ON.type('TextInput'));
    let KeyboardAvoidLiftUpComponents = await driver.findComponent(ON.id('KeyboardAvoidLiftUpComponents'));
    let isFocused = await KeyboardAvoidTextInput.isFocused();
    if (isFocused) {
      await KeyboardAvoidLiftUpComponents.scrollToBottom(4000);
      await driver.assertComponentExist(ON.text('第十二条数据'));
    } else {
      expect(isFocused).assertEqual(true);
    }
    done();
  })

  /**
   * 关联用例: 点击页面空白位置，软键盘收起，点击输入框，软键盘拉起
   * 执行步骤:
   * 1. 点击页面空白位置，收起软键盘
   * 2. 点击'弹出键盘'按钮，拉起软键盘
   * 3. 通过判断键盘高度是否从拉起状态变化为收起状态再变化为拉起状态进行验证
   */
  it(CASE + '键盘收起与拉起', 0, async (done: Function) => {
    let KeyboardAvoidBlank = await driver.findComponent(ON.id('KeyboardAvoidBlank'));
    let KeyboardAvoidButtonPopUpKeyboard = await driver.findComponent(ON.id('KeyboardAvoidButtonPopUpKeyboard'));
    let KeyboardAvoidTextInput = await driver.findComponent(ON.type('TextInput'));

    let beforeIsFocused = await KeyboardAvoidTextInput.isFocused();
    await KeyboardAvoidBlank.click();
    await driver.delayMs(2000);
    let middleIsFocused = await KeyboardAvoidTextInput.isFocused();
    await KeyboardAvoidButtonPopUpKeyboard.click();
    await driver.delayMs(2000);
    let finalIsFocused = await KeyboardAvoidTextInput.isFocused();
    const finalCheck = beforeIsFocused && !middleIsFocused && finalIsFocused;
    expect(finalCheck).assertEqual(true);
    done();
  })

  /**
   * 关联用例: 点击“缩小避让”按钮，页面切换，点击输入框拉起软键盘，实现组件上抬避让让同时实现缩小
   * 执行步骤:
   * 1. 点击'缩小避让'按钮，切换页面至grid
   * 2. 点击'弹出键盘'按钮，拉起软键盘
   * 3. 滑动页面，查看上抬避让效果
   * 4. 通过判断键盘是否拉起和是否展示全部数据(共12条)进行验证
   */
  it(CASE + '缩小避让模式', 0, async (done: Function) => {
    let KeyboardAvoidButtonScaling = await driver.findComponent(ON.id('KeyboardAvoidButtonScaling'));
    let KeyboardAvoidButtonPopUpKeyboard = await driver.findComponent(ON.id('KeyboardAvoidButtonPopUpKeyboard'));
    let KeyboardAvoidTextInput = await driver.findComponent(ON.type('TextInput'));
    await KeyboardAvoidButtonScaling.click();
    await KeyboardAvoidButtonPopUpKeyboard.click();
    let isFocused = await KeyboardAvoidTextInput.isFocused();
    if (isFocused) {
      await driver.fling({
        x: 100, y: 800
      }, {
        x: 100, y: 50
      }, 5, 600);
      await driver.assertComponentExist(ON.text('第十二条数据'));

    } else {
      expect(isFocused).assertEqual(true);
    }
    // 退出输入法
    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  exit('组件随软键盘弹出避让案例');
}