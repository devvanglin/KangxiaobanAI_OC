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

const CASE: string = 'HighLightGuide'; // 案例
const CASE_NAME: string = '应用新功能引导实现案例'; // 案例名称
const TAG: string = '[HighLightGuide_Test]';

/**
 * 【应用新功能引导实现案例】自动化测试用例，测试步骤如下
 * 1. 进入应用新功能引导实现案例案例主页，查询高亮提示文字"新功能（请点击）"是否存在。
 * 2. 点击高亮提示文字，查询自定义功能介绍提示是否弹出，是否存在"我知道了"按钮。
 * 3. 点击"我知道了"按钮，查询是否弹出完成指导弹窗。
 * 4. 点击"确认"按钮，查询TabBar组件是否存在，点击"菜单2"按钮，查询Tab页是否切换为第二页
 */
export default function highLightGuideTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 首页高亮展示
  showPageCases(driver);

  // 自定义功能介绍弹窗
  introductionDialogCases(driver);

  // 应用引导结束
  finishGuideCases(driver);

  // Tab页切换
  changeTabCases(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"验证应用新功能引导功能"
 * @param { Driver } driver
 */
function showPageCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 高亮提示文字"新功能（请点击）"是否存在。
   */
  it('应用新功能引导功能', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_应用新功能引导功能 begin`);

    // 高亮提示文字"新功能（请点击）"是否存在
    await driver.assertComponentExist(ON.text('新功能（请点击）'));

    logger.info(TAG, `${CASE}_应用新功能引导功能 end`);

    done();
  })
}

/**
 * 用例关联"验证应用新功能引导点击功能"
 * @param { Driver } driver
 */
function introductionDialogCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 点击"模块6"组件。
   * 2. 判断自定义功能介绍提示组件是否弹出。
   */
  it('应用新功能引导点击功能', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_应用新功能引导点击功能 begin`);

    // 获取"模块6"组件
    const moduleComponent: Component = await driver.findComponent(ON.text('模块6'));

    // 点击"模块6"组件
    await moduleComponent.click();
    await driver.delayMs(2000);

    // 判断自定义功能介绍提示组件是否弹出
    await driver.assertComponentExist(ON.id('high_light_guide_introduction_dialog'));

    logger.info(TAG, `${CASE}_应用新功能引导点击功能 end`);

    done();
  })
}

/**
 * 用例关联"验证应用新功能引导结束功能"
 * @param { Driver } driver
 */
function finishGuideCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 点击"我知道了"按钮。
   * 2. 判断引导完成提示框是否弹出。
   */
  it('应用新功能引导结束功能', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_应用新功能引导结束功能 begin`);

    // 获取"我知道了"按钮
    const buttonComponent: Component = await driver.findComponent(ON.text('我知道了'));

    // 点击"我知道了"按钮
    await buttonComponent.click();
    await driver.delayMs(2000);

    // 判断自定义功能介绍提示组件是否弹出
    await driver.assertComponentExist(ON.id('high_light_guide_finish_dialog'));

    logger.info(TAG, `${CASE}_应用新功能引导结束功能 end`);

    done();
  })
}

/**
 * 用例关联"验证应用新功能引导功能页面体验"
 * @param { Driver } driver
 */
function changeTabCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 点击"确认"按钮。
   * 2. 点击"菜单2"按钮。
   * 3. 判断Tab页是否切换为第二页。
   */
  it('应用新功能引导功能页面体验', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_应用新功能引导功能页面体验 begin`);

    // 获取"确定"按钮
    const confirmComponent: Component = await driver.findComponent(ON.text('确定'));

    // 点击"确定"按钮
    await confirmComponent.click();
    await driver.delayMs(3000);

    // 获取"菜单2"按钮
    const menuComponent: Component = await driver.findComponent(ON.text('菜单2'));

    // 点击"菜单2"按钮
    await menuComponent.click();
    await driver.delayMs(2000);

    // 判断Tab页是否切换为第二页
    await driver.assertComponentExist(ON.id('high_light_guide_tab_2'));

    logger.info(TAG, `${CASE}_应用新功能引导功能页面体验 end`);

    done();
  })
}