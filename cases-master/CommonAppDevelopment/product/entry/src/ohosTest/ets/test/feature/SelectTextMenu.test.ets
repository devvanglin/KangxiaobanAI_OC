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
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'SelectTextMenu'; // 案例名称
const CASE_NAME: string = '文本选择菜单案例'; // 案例中文名称
const TAG: string = '[selecttextmenu_Test]';

/**
 * 【文本选择菜单案例】自动化测试用例
 * 1. 进入页面长按屏幕唤起文字编辑菜单。
 * 2. 验证菜单全选、复制、粘贴、剪切功能正常。
 * 2. 验证菜单是否成功拉起。
 * 3. 点击菜单最右侧按钮打开拓展菜单。
 */

export default function selectTextMenuTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、点击文本打开编辑菜单。
   * 2、点击全选按钮。
   * 2、点击复制按钮。
   * 3、清除文本。
   * 4、点击粘贴按钮。
   */
  it(CASE + '验证全选复制粘贴', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}SelectTextMenu copy begin`);
    await driver.assertComponentExist(ON.id('RichEditor'));
    const richEditor: Component = await driver.findComponent(ON.id('RichEditor'));
    await driver.doubleClick(500,1000);
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('全选'));
    const selectAllButton: Component = await driver.findComponent(ON.text('全选'));
    await selectAllButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('复制'));
    const copyAllButton: Component = await driver.findComponent(ON.text('复制'));
    await copyAllButton.click();
    await driver.delayMs(500);
    await richEditor.clearText();
    await driver.delayMs(1000);
    await driver.click(500,1000);
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('粘贴'));
    const pasteButton: Component = await driver.findComponent(ON.text('粘贴'));
    await pasteButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('请长按本文打开编辑菜单'));
    done();
  })

  /**
   * 执行步骤：
   * 1、点击文本打开编辑菜单。
   * 2、点击全选按钮。
   * 3、点击剪切按钮。
   * 4、点击粘贴按钮。
   */
  it(CASE + '验证剪切', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}SelectTextMenu cut begin`);
    await driver.doubleClick(500,1000);
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('全选'));
    const selectAllButton: Component = await driver.findComponent(ON.text('全选'));
    await selectAllButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('剪切'));
    const copyAllButton: Component = await driver.findComponent(ON.text('剪切'));
    await copyAllButton.click();
    await driver.delayMs(500);
    await driver.click(500,1000);
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('粘贴'));
    const pasteButton: Component = await driver.findComponent(ON.text('粘贴'));
    await pasteButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('请长按本文打开编辑菜单'));
    done();
  })

  /**
   * 执行步骤：
   * 1、长按选择文字拉起编辑菜单
   * 2、点击更多按钮
   * 3、验证是否成功打开拓展菜单
   **/
  it(CASE + '验证是否成功打开拓展菜单', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}SelectTextMenu expend  begin`);
    await driver.assertComponentExist(ON.text('请长按本文打开编辑菜单'));
    await driver.doubleClick(500,1000);
    await driver.delayMs(1500);
    await driver.assertComponentExist(ON.text('搜索'));
    const moreButton: Component = await driver.findComponent(ON.isAfter(ON.text('搜索')));
    await moreButton.click();
    await driver.delayMs(1500);
    await driver.assertComponentExist(ON.text('分享'));
    await driver.delayMs(500);
    // 退出编辑
    await driver.pressBack();
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(1000);
    done();
  })

  // 退出案例页面
  exit(CASE_NAME)
}