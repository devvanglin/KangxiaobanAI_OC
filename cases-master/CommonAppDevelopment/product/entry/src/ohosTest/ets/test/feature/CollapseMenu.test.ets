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

import { Driver, ON } from '@kit.TestKit';
import { expect, it } from '@ohos/hypium';
import exit from '../common/Exit.test';

/**
 * 【折叠面板案例】自动化测试用例
 * 主要功能：通过定义层级实现多层折叠面板，并在首页性能文章tab实际使用跳转到对应文章的web页面。。
 * 执行步骤：
 * 1. 首页切换到性能文章tab。
 * 2. 点击父级菜单，会展开子菜单。
 * 3. 点击子菜单，跳转到对应文章gitee网页。
 */
export default function collapseMenuTest() {

  const driver = Driver.create();

  it('切换到性能文章tab', 0, async (done: Function) => {
    //切换到性能文章tab
    await driver.assertComponentExist(ON.id('mainPageTabsImage'));
    let extraImage = await driver.findComponent(ON.id('mainPageTabsImage'));
    await extraImage.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('性能文章'));
    let articleTabButton = await driver.findComponent(ON.text('性能文章'));
    await articleTabButton.click();
    await driver.delayMs(1000);

    //展开父级菜单
    await driver.assertComponentExist(ON.text('减少卡顿丢帧'));
    let tabButton = await driver.findComponent(ON.text('减少卡顿丢帧'));
    await tabButton.click();
    await driver.delayMs(1000);

    //打开gitee链接预览
    await driver.assertComponentExist(ON.text('组件复用四板斧'));
    let innerButton = await driver.findComponent(ON.text('组件复用四板斧'));
    await innerButton.click();
    await driver.delayMs(1500);

    //上下滑动预览后返回，收起父级菜单
    await driver.swipe(0, 300, 0, 1800, 600);
    await driver.delayMs(500);
    await driver.swipe(0, 1800, 0, 300, 600);
    await driver.pressBack();

    // 收起父级菜单
    await driver.assertComponentExist(ON.text('减少卡顿丢帧'));
    let tabButton2 = await driver.findComponent(ON.text('减少卡顿丢帧'));
    await tabButton2.click();

    //打开子菜单gitee链接预览
    await driver.assertComponentExist(ON.text('性能优化实操宝典'));
    let outButton = await driver.findComponent(ON.text('性能优化实操宝典'));
    await outButton.click();
    await driver.delayMs(1500);

    //上下滑动预览后返回，回到全部菜单
    await driver.swipe(0, 300, 0, 1800, 600);
    await driver.delayMs(500);
    await driver.swipe(0, 1800, 0, 300, 600);
    await driver.pressBack();
    await driver.delayMs(1000);

    await driver.assertComponentExist(ON.id('mainPageTabsImage'));
    let extraImage2 = await driver.findComponent(ON.id('mainPageTabsImage'));
    await extraImage2.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('全部'))
    let allContentButton = await driver.findComponent(ON.text('全部'));
    await allContentButton.click();
    await driver.delayMs(1000);
    done();
  })

}