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
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

/**
 * 【多模态页面转场动效实现案例】自动化测试用例
 * 主要功能：
 * 登陆方式有两种，验证码登录和账号密码登录：
 * 1. 进入案例弹出半模态登录页面。
 * 2. 在半模态页面选中同意协议按钮，并点击验证码登录按钮，跳转至手机验证码登录页面。（点击后切换页面涉及动效，需手工用例测试动效效果）
 * 3. 通过点击手机验证码登陆页面中的"账号密码登录"，跳转至账号密码登陆页面。（点击后切换页面涉及动效，需手工用例测试动效效果）
 * 4. 通过点击账号密码登陆页面中的"手机验证码登陆"，跳转至手机验证码登陆页面。（点击后切换页面涉及动效，需手工用例测试动效效果）
 * 执行步骤：
 * 1. 进入案例，在弹出的半模态页面点击"同意协议"，点击"验证码登录"按钮，断言页面跳转至"手机验证码登录"页面。
 * 2. 点击手机验证码登录页面中的"账号密码登录"，断言页面跳转至"账号密码登录"页面。
 * 3. 点击账号密码登录页面中的"手机验证码登录"，断言页面跳转至"手机验证码登录"页面。
 */
export default function multiModalTransitionTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('多模态页面转场动效实现案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、进入案例，断言当前在半模态窗口。
   * 2、在弹出的半模态页面点击"同意协议"，点击"验证码登录"按钮。
   * 3、断言页面跳转至"手机验证码登录"页面。
   **/
  it('验证半模态页面跳转功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言当前在半模态窗口(半模态标题唯一且存在)
    await driver.assertComponentExist(ON.id('bindSheetExist'));
    let isCheckedComponent = await driver.findComponent(ON.id('isChecked'));
    await driver.delayMs(100);
    await isCheckedComponent.click(); // 同意协议
    await driver.delayMs(100);
    // 断言存在"验证码登录"按钮
    await driver.assertComponentExist(ON.id('verificationLogin'));
    let verificationLoginButton = await driver.findComponent(ON.id('verificationLogin'));
    // 点击"验证码登录"按钮
    await verificationLoginButton.click();
    await driver.delayMs(100);
    // 断言已跳转至"手机验证码登录页面"
    await driver.assertComponentExist(ON.id('phoneLoginPage'));
    done();
  })

  /**
   * 执行步骤：
   * 1、当前在”手机验证码登录“页面，点击"账号密码登录"，断言页面跳转至"账号密码登录"页面。
   **/
  it('验证手机验证码页面跳转至账号密码登录页', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在"账号密码登录"跳转页面关键字
    await driver.assertComponentExist(ON.id('switchAccountLogin'));
    let switchComponent = await driver.findComponent(ON.id('switchAccountLogin'));
    await switchComponent.click(); // 跳转至"账号密码登录"页面
    await driver.delayMs(100);
    // 断言已跳转至"账号密码登录"页
    await driver.assertComponentExist(ON.id('AccountLoginPage'));
    done();
  })

  /**
   * 执行步骤：
   * 1、当前在"账号密码登录"页面，点击"手机验证码登录"，断言页面跳转至"手机验证码登录"页面。
   **/
  it('验证账号密码登录页跳转至手机验证码页面', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在"手机验证码登录"跳转页面关键字。
    await driver.assertComponentExist(ON.id('switchPhoneNumberLogin'));
    let switchComponent = await driver.findComponent(ON.id('switchPhoneNumberLogin'));
    await switchComponent.click(); // 同意协议
    await driver.delayMs(100);
    // 断言已跳转至"手机验证码登录页面"
    await driver.assertComponentExist(ON.id('phoneLoginPage'));
    await driver.delayMs(1000);
    done();
  })

  exit('多模态页面转场动效实现案例');
}
