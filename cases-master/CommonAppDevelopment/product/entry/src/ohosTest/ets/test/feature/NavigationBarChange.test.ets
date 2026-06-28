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

const CASE: string = 'NavigationBarChange'; // 案例名称
const CASE_NAME: string = '状态栏显隐变化'; // 案例
const TAG: string = '[NavigationBarChange_Test]';

/**
 * 【状态栏显隐变化】自动化测试用例，测试步骤如下
 * 1. 进入状态栏显隐变化案例主页，查询页面各组件是否显示正常显示。
 * 2. 向上滑动页面，页面title显示"我的"。
 */
export default function navigationBarChangeTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 首页展示
  showPageCases(driver);

  // 验证状态栏显隐变化能力
  slideContentCase(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"验证状态栏显隐变化能力"
 * @param { Driver } driver
 */
function showPageCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 判断titleBar是否存在。
   * 2. 判断页面内容是否存在。
   */
  it('首页展示', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_首页展示 begin`);

    // 判断titleBar是否存在
    await driver.assertComponentExist(ON.id('navigation_bar_change_title_button'));

    // 判断页面内容是否存在
    await driver.assertComponentExist(ON.id('navigation_bar_change_content'));

    logger.info(TAG, `${CASE}_首页展示 end`);

    done();
  })
}

/**
 * 用例关联"验证状态栏显隐变化能力"
 * @param { Driver } driver
 */
function slideContentCase(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 按住"娱乐区"文本向上滑动。
   * 2. 判断title中是否显示"我的"文本。
   */
  it('页面滑动显示隐藏title', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_页面滑动显示隐藏title begin`);

    // 获取"娱乐区"文本组件
    const textComponent: Component = await driver.findComponent(ON.text('娱乐区'));

    // 获取"娱乐区"文本组件坐标信息
    const point = await textComponent.getBoundsCenter();

    // 娱乐区"文本组件向上滑动60坐标
    await driver.swipe(point.x, point.y, point.x, point.y - 60);
    await driver.delayMs(1000);

    // 判断title中是否显示"我的"文本
    await driver.assertComponentExist(ON.text('我的'));

    logger.info(TAG, `${CASE}_页面滑动显示隐藏title end`);

    done();
  })
}