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
import { Driver, ON, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'modalwindow'; // 案例名称
const TAG: string = '[modalwindow_Test]';

/**
 * 【Next全屏登录页面案例】自动化测试用例
 * 1、本机一键登录效果。
 * 2、手机号验证码登录效果。
 */
export default function modalWindowTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('全屏登录页面');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 启动【全屏登录页面案例】
   * 点击'点击跳转到全屏登录页'
   * 不选中'请先阅读并同意协议'
   * 点击手机号码一键登录
   * 通过弹窗提示'请先阅读并同意协议'来验证
   **/
  it(CASE + '本机一键登录效果+不同意协议', 0, async (done: Function) => {
    const btn = await driver.findComponent(ON.text('点击跳转到全屏登录页'));
    await btn.click();
    await driver.delayMs(500);
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('请先阅读并同意协议');
    };
    observer.once('toastShow', callback);
    const login = await driver.findComponent(ON.text('手机号码一键登录'));
    await login.click();
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 执行步骤：
   * 启动【全屏登录页面案例】
   * 点击'点击跳转到全屏登录页'
   * 选中'请先阅读并同意协议'
   * 点击手机号码一键登录
   * 通过弹窗提示'登录成功'来验证
   **/
  it(CASE + '本机一键登录效果+同意协议', 0, async (done: Function) => {
    const btn = await driver.findComponent(ON.text('点击跳转到全屏登录页'));
    await btn.click();
    await driver.delayMs(1000);
    const agreement = await driver.findComponent(ON.id('default_agreement'));
    await agreement.click();
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('登录成功');
    };
    observer.once('toastShow', callback);
    const login = await driver.findComponent(ON.text('手机号码一键登录'));
    await login.click();
    await driver.delayMs(1000);
    const back = await driver.findComponent(ON.id('login_back'));
    await back.click();
    await driver.delayMs(1000);
    done();
  })

  /**
   * 执行步骤：
   * 启动【全屏登录页面案例】
   * 点击'点击跳转到全屏登录页'
   * 点击'其他登录方式'
   * 在输入框中输入11位手机号
   * 不选中'请先阅读并同意协议'
   * 点击发送验证码
   * 通过弹窗提示'请先阅读并同意服务协议及个人信息处理规则'来验证
   **/
  it(CASE + '手机号验证码登录效果+不同意协议', 0, async (done: Function) => {
    const btn = await driver.findComponent(ON.text('点击跳转到全屏登录页'));
    await btn.click();
    await driver.delayMs(500);
    const other = await driver.findComponent(ON.text('其他登录方式'));
    await other.click();
    await driver.delayMs(1000);
    const textInput = await driver.findComponent(ON.type('TextInput'));
    await textInput.inputText('12345678900');
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('请先阅读并同意服务协议及个人信息处理规则');
    };
    observer.once('toastShow', callback);
    const login = await driver.findComponent(ON.text('发送短信验证码'));
    await login.click();
    await driver.delayMs(1000);

    done();
  })

  /**
   * 执行步骤：
   * 启动【全屏登录页面案例】
   * 点击'点击跳转到全屏登录页'
   * 点击'其他登录方式'
   * 在输入框中输入11位手机号
   * 选中'请先阅读并同意协议'
   * 点击发送验证码
   * 通过发送按钮文字发生变化来验证
   **/
  it(CASE + '手机号验证码登录效果+同意协议', 0, async (done: Function) => {
    const agreement = await driver.findComponent(ON.id('other_agreement'));
    await agreement.click();
    const login = await driver.findComponent(ON.id('send_button_id'));
    await login.click();
    await driver.delayMs(1000);
    const send = await driver.findComponent(ON.id('send_button_id'));
    expect(await send.getText() !== '发送短信验证码').assertEqual(true) // 通过弹窗提示'请先阅读并同意服务协议及个人信息处理规则'来验证
    const back = await driver.findComponent(ON.id('login_back'));
    await back.click();
    await driver.delayMs(1000);
    const backSec = await driver.findComponent(ON.id('login_back'));
    await backSec.click();
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  // 退出案例
  exit('全屏登录页面');
}