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
import { Component, Driver, ON } from "@kit.TestKit";
import { logger } from "utils";
import { it } from "@ohos/hypium";
import exit from "../common/Exit.test";

const CASE: string = 'WebCustomPressMenu'; // 案例
const CASE_NAME: string = 'Web自定义长按菜单案例'; // 案例名称
const TAG: string = '[WebCustomPressMenu_Test]';

/**
 * 【Web自定义长按菜单案例】自动化测试用例，测试步骤如下
 * 1. 进入Web自定义长按菜单案例主页。
 * 2. 长按"链接元素"按钮，查询是否弹出菜单弹框"浏览器打开","复制链接"。
 * 3. 长按页面中间图标，查询是否弹出菜单弹框"复制图片"。
 */
export default function webCustomPressMenuTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 长按"链接元素"按钮
  longClickLinkCases(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"长按链接元素，弹出自定义弹窗"
 * @param { Driver } driver
 */
function longClickLinkCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 长按"链接元素"按钮。
   * 2. 判断是否弹出菜单弹框"浏览器打开","复制链接"。
   */
  it('长按链接元素', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_长按链接元素 begin`);

    // 获取"链接元素"按钮
    const linkComponent: Component = await driver.findComponent(ON.text('链接元素'));

    // 长按"链接元素"按钮
    await linkComponent.longClick();
    await driver.delayMs(1000);

    // 判断是否弹出菜单弹框"浏览器打开"
    await driver.assertComponentExist(ON.text('浏览器打开'));
    // 判断是否弹出菜单弹框"复制链接"
    await driver.assertComponentExist(ON.text('复制链接'));

    // 点击返回关闭菜单
    await driver.pressBack();
    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_长按链接元素 end`);

    done();
  })
}

/**
 * 用例关联"长按图片元素，弹出自定义弹窗"，暂无法获取H5图片
 * @param { Driver } driver
 */
function longClickImageCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 长按图片元素。
   * 2. 判断是否弹出菜单弹框"复制图片"。
   */
  it('长按图片元素', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_长按图片元素 begin`);

    // 获取image组件
    const imageComponent: Component = await driver.findComponent(ON.id('web_custom_press_menu_link'));

    // 点击title
    await imageComponent.longClick();
    await driver.delayMs(1000);

    // 判断是否弹出菜单弹框"复制图片"
    await driver.assertComponentExist(ON.text('复制图片'));

    // 点击返回关闭菜单
    await driver.pressBack();
    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_长按图片元素 end`);

    done();
  })
}