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
 * 【Navigation路由拦截案例】自动化测试用例
 * 主要功能：
 * 1. 首次进入案例此时为未登录状态，手机验证码登陆后跳转"我的页面"并记录登陆状态。
 * 2. 在已登录的状态，返回首页，再次点击案例，无需重复登录，可直接进入"我的页面"。
 * 3. 在"我的页面"退出登陆后，二次登录需重新验证登录。
 * 执行步骤：
 * 1. 进入案例，在弹出的半模态登陆页面里，勾选"阅读并同意协议"，点击按钮"手机号码一键登录"，跳转"我的页面"。
 * 2. 在"我的页面"点击返回上级页面按钮，返回上级页面，此时重新进入案例，可直接进入"我的页面"，不需要重复登录。
 * 3. 在进入"我的页面"状态，点击"退出登录"按钮，退出案例，重新点击进入案例，此时重新进入案例，需要重新登录。
 */
export default function navigationInterceptorTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('Navigation路由拦截案例');
  const driver = Driver.create();
  /**
   * 执行步骤：
   * 1、进入案例，断言当前在半模态窗口。
   * 2、在弹出的半模态页面点击"同意协议"，点击"手机号码一键登录"按钮。
   * 3、断言页面跳转至"我的页面"，点击返回上级页面按钮，回到主页瀑布流。
   **/
  it('验证路由拦截的半模态页面跳转功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言当前在半模态窗口(半模态标题唯一且存在)
    await driver.assertComponentExist(ON.id('bindSheetExist'));
    let isCheckedComponent = await driver.findComponent(ON.id('isChecked'));
    await driver.delayMs(100);
    await isCheckedComponent.click(); // 同意协议
    await driver.delayMs(100);
    // 断言存在"手机号码一键登录"按钮
    await driver.assertComponentExist(ON.id('phoneNumberLogin'));
    let verificationLoginButton = await driver.findComponent(ON.id('phoneNumberLogin'));
    // 点击"手机号码一键登录"按钮
    await verificationLoginButton.click();
    await driver.delayMs(500);
    // 断言已跳转至"我的页面"
    await driver.assertComponentExist(ON.id('homePage'));
    done();
  })
  exit('Navigation路由拦截案例'); // 返回上级页面，回到主页瀑布流。

  /**
   * 执行步骤：
   * 重新搜索进入案例，断言此时直接进入"我的页面"，不需要重复登录。
   **/
  it('验证路由拦截的记录登陆状态功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 重新搜索进入案例
    // 点击“搜索”框
    let search = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(1000);
    // 在搜索框输入需查找的案例名
    let textInput = await driver.findComponent(ON.type('Search'));
    await textInput.inputText('Navigation路由拦截案例');
    await driver.delayMs(1000);
    // 点击搜索按钮，查找案例
    let searchButton = await driver.findComponent(ON.text('搜索'));
    await searchButton.click();
    await driver.delayMs(2000);
    // 点击案例进入页面
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    await driver.delayMs(1000);
    // 断言记录了登录状态，此时登录可以直接跳转至"我的页面"
    await driver.assertComponentExist(ON.id('homePage'));
    // 断言在"我的页面"存在"退出登录"按钮，并点击后回到主页瀑布流。
    await driver.assertComponentExist(ON.id('exitHomePage'));
    let exitComponent = await driver.findComponent(ON.id('exitHomePage'));
    await driver.delayMs(100);
    await exitComponent.click(); // 退出登录,清除已登陆状态，二次登录需要重新弹出半模态弹窗登录
    done();
  })

  /**
   * 执行步骤：
   * 在进入"我的页面"状态，点击"退出登录"按钮，退出案例，重新点击进入案例，此时重新进入案例，需要重新登录。
   **/
  it('验证路由拦截的退出登录后二次登录功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 重新搜索进入案例
    // 点击“搜索”框
    let search = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(1000);

    // 在搜索框输入需查找的案例名
    let textInput = await driver.findComponent(ON.type('Search'));
    await textInput.inputText('Navigation路由拦截案例');
    await driver.delayMs(1000);

    // 点击搜索按钮，查找案例
    let searchButton = await driver.findComponent(ON.text('搜索'));
    await searchButton.click();
    await driver.delayMs(2000);

    // 点击案例进入页面
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    await driver.delayMs(1000);

    // 断言重新跳转到半模态弹窗的登录页面(半模态标题唯一且存在)，需重新登录
    await driver.assertComponentExist(ON.id('bindSheetExist'));
    await driver.delayMs(1000);
    done();
  })
  exit('Navigation路由拦截案例');
}
