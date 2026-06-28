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
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Component, Driver, MatchPattern, On, ON, UiDirection } from "@kit.TestKit";
import { logger } from "utils";
import { it } from "@ohos/hypium";
import exit from "../common/Exit.test";

const CASE: string = 'GroupAvatar'; // 案例
const CASE_NAME: string = '群头像拼接案例'; // 案例名称
const TAG: string = '[GroupAvatar_Test]';

/**
 * 【群头像拼接案例】自动化测试用例，测试步骤如下
 * 1. 进入群头像案例，查询顶部导航栏、会话列表、底部TabBar组件显示正常。
 * 2. 点击右上角加号，弹出菜单，菜单UX展示正常。
 * 3. 点击发起群聊按钮，跳转至发起群聊页面，勾选用户1~用户5，点击下方完成按钮，返回会话列表页面，且在列表第一条新增“用户1、用户2、用户3、用户4、用户5”会话数据。
 */
export default function groupAvatarTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 会话页面展示
  showSessionPageCase(driver);

  // 菜单列表展示
  showMenuCase(driver);

  // 新增会话
  showAddSessionPageCase(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"会话页面展示"
 * @param { Driver } driver
 */
function showSessionPageCase(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 打开首页即会话页面。
   * 2. 判断顶部导航栏是否存在。
   * 3. 判断会话列表是否存在。
   * 4. 判断底部TabBar是否存在。
   */
  it('会话页面展示', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_会话页面展示 begin`);

    // 判断NavigationBar组件是否存在
    await driver.assertComponentExist(ON.id('group_avatar_title_bar'));

    // 判断会话列表是否存在
    await driver.assertComponentExist(ON.id('group_avatar_session_list'));

    // 判断BottomBar组件是否存在
    await driver.assertComponentExist(ON.id('group_avatar_bottom_bar'));

    logger.info(TAG, `${CASE}_会话页面展示 end`);

    done();
  })
}

/**
 * 用例关联"菜单列表展示“
 * @param { Driver } driver
 */
function showMenuCase(driver: Driver) {
  /**
   * 执行步骤:
   * 1. 点击菜单按钮。
   * 2. 判断菜单组件是否存在。
   * 3. 判断"发起群聊"按钮是否存在。
   * 4. 判断"添加朋友"按钮是否存在。
   * 5. 判断"扫一扫"按钮是否存在。
   * 6. 判断"收付款"按钮是否存在。
   */
  it('菜单列表展示', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_菜单列表展示 begin`);

    // 获取菜单按钮组件
    const menuButton: Component = await driver.findComponent(ON.id('group_avatar_menu_button'));

    // 点击菜单按钮
    await menuButton.click();
    await driver.delayMs(1000);

    // 判断菜单组件是否存在
    await driver.assertComponentExist(ON.id('group_avatar_menu'));

    // 判断"发起群聊"按钮是否存在
    await driver.assertComponentExist(ON.text('发起群聊'));

    // 判断"添加朋友"按钮是否存在
    await driver.assertComponentExist(ON.text('添加朋友'));

    // 判断"扫一扫"按钮是否存在
    await driver.assertComponentExist(ON.text('扫一扫'));

    // 判断"收付款"按钮是否存在
    await driver.assertComponentExist(ON.text('收付款'));

    logger.info(TAG, `${CASE}_菜单列表展示 end`);

    done();
  })
}

/**
 * 用例关联"新增会话数据“
 * @param { Driver } driver
 */
function showAddSessionPageCase(driver: Driver) {
  /**
   * 执行步骤:
   * 1. 点击"发起群聊"按钮。
   * 2. 判断页面是否跳转至"发起群聊"页面。
   * 3. 勾选用户1~用户5。
   * 4. 点击完成按钮。
   * 5. 判断页面是否跳转至"会话"页面。
   * 6. 判断会话列表是否新增会话数据。
   */
  it('新增会话数据', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_新增会话数据 begin`);

    // 获取"发起群聊"按钮组件
    const addSessionButton: Component = await driver.findComponent(ON.text('发起群聊'));

    // 点击"发起群聊"按钮
    await addSessionButton.click();
    await driver.delayMs(1000);

    // 判断页面是否跳转至"发起群聊"页面
    await driver.assertComponentExist(ON.id('group_avatar_add_session_page'));

    // 获取"用户1"前Checkbox组件，并将其选中状态改为true
    const checkbox1: Component = await driver.findComponent(ON.id('group_avatar_person_0'));
    await checkbox1.click();
    await driver.delayMs(300);

    // 获取"用户2"前Checkbox组件，并将其选中状态改为true
    const checkbox2: Component = await driver.findComponent(ON.id('group_avatar_person_1'));
    await checkbox2.click();
    await driver.delayMs(300);

    // 获取"用户3"前Checkbox组件，并将其选中状态改为true
    const checkbox3: Component = await driver.findComponent(ON.id('group_avatar_person_2'));
    await checkbox3.click();
    await driver.delayMs(300);

    // 获取"用户4"前Checkbox组件，并将其选中状态改为true
    const checkbox4: Component = await driver.findComponent(ON.id('group_avatar_person_3'));
    await checkbox4.click();
    await driver.delayMs(300);

    // 获取"用户5"前Checkbox组件，并将其选中状态改为true
    const checkbox5: Component = await driver.findComponent(ON.id('group_avatar_person_4'));
    await checkbox5.click();
    await driver.delayMs(300);

    // 获取"完成"按钮，并点击
    const finishButton: Component = await driver.findComponent(ON.id('group_avatar_finish_button'));
    await finishButton.click();
    await driver.delayMs(3000);

    // 判断页面是否跳转至"会话"页面
    await driver.assertComponentExist(ON.id('group_avatar_session_page'));

    // 判断会话列表是否新增会话数据
    await driver.assertComponentExist(ON.text('用户1、用户2、用户3、用户4、用户5', MatchPattern.CONTAINS));

    logger.info(TAG, `${CASE}_新增会话数据 end`);

    done();
  })
}