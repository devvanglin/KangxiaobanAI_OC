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

const CASE: string = 'CustomView'; // 案例
const CASE_NAME: string = '自定义视图实现Tab效果'; // 案例名称
const TAG: string = '[CustomView_Test]';

/**
 * 【自定义视图实现Tab效果】自动化测试用例，测试步骤如下
 * 1. 进入自定义视图实现Tab效果案例主页，查询title与下方tab内容显示正常，内容默认显示"后补预测"。
 * 2. 点击title按钮，下方页签显示未对应内容。
 * 3. 向左滑动页签，页签内容显示下一项。
 */
export default function customViewTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 首页展示
  showPageCases(driver);

  // 验证页签点击切换功能
  clickTitleCases(driver);

  // 验证页签滑动切换功能
  slideContentCase(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"验证页签点击切换功能"
 * @param { Driver } driver
 */
function showPageCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 判断title是否存在。
   * 2. 判断页签条是否存在。
   * 3. 判断content是否存在，且显示为"候补预测"。
   */
  it('首页展示', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_首页展示 begin`);

    // 判断title是否存在
    await driver.assertComponentExist(ON.id('custom_view_title'));

    // 判断页签条是否存在
    await driver.assertComponentExist(ON.id('custom_view_title_bar'));

    // 判断content是否存在
    await driver.assertComponentExist(ON.id('custom_view_content'));

    // 判断content是否显示首条
    await driver.assertComponentExist(ON.id('custom_view_content_0'));

    logger.info(TAG, `${CASE}_首页展示 end`);

    done();
  })
}

/**
 * 用例关联"验证页签点击切换功能"
 * @param { Driver } driver
 */
function clickTitleCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. title点击"在线换座"。
   * 2. 判断content是否切换为"在线换座"。
   */
  it('点击切换Tab', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_点击切换Tab begin`);

    // 获取title组件
    const titleComponent: Component = await driver.findComponent(ON.id('custom_view_title_1'));

    // 点击title
    await titleComponent.click();
    await driver.delayMs(1000);

    // 判断content是否切换为"在线换座"
    await driver.assertComponentExist(ON.id('custom_view_content_1'));

    logger.info(TAG, `${CASE}_点击切换Tab end`);

    done();
  })
}

/**
 * 用例关联"验证页签滑动切换功能"
 * @param { Driver } driver
 */
function slideContentCase(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 按住content组件"在线换座"向左滑动。
   * 2. 判断content是否切换为"余票挖掘"。
   */
  it('滑动切换Tab', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_滑动切换Tab begin`);

    // 获取title组件
    const contentComponent: Component = await driver.findComponent(ON.id('custom_view_content_1'));

    // 获取"在线换座"content坐标信息
    const point = await contentComponent.getBoundsCenter();

    // "在线换座"content向左滑动50坐标
    await driver.swipe(point.x, point.y, point.x - 50, point.y);
    await driver.delayMs(1000);

    // 判断content是否切换为"余票挖掘"
    await driver.assertComponentExist(ON.id('custom_view_content_2'));

    logger.info(TAG, `${CASE}_滑动切换Tab end`);

    done();
  })
}