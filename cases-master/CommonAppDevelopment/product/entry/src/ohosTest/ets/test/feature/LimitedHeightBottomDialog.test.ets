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
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'LimitedHeightBottomDialog';   // 案例名称
const CASE_NAME: string = '限制高度底部弹窗';         // 案例中文名称

/**
 * 【限制高度底部弹窗】自动化测试用例
 * 1.弹出常用设置底部弹窗，视图内容区域可滚动
 * 2.弹出安全设置底部弹窗，视图内容区域不可滚动
 * 3.点击常用设置底部弹窗关闭图标
 * 4.点击安全设置底部弹窗关闭图标
 */
export default function limitedHeightBottomDialogTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  // 弹出常用设置底部弹窗，视图内容区域可滚动
  showCommonSettingBottomDialog(driver);

  // 弹出安全设置底部弹窗，视图内容区域不可滚动
  showSecuritySettingBottomDialog(driver);

  // 点击常用设置底部弹窗关闭图标
  clickCommonSettingBottomDialogCloseImage(driver);

  // 点击安全设置底部弹窗关闭图标
  clickSecuritySettingBottomDialogCloseImage(driver);

  // 退出案例
  exit(CASE_NAME);
}

/**
 * 关联用例：弹出常用设置底部弹窗，视图内容区域可滚动
 * 执行步骤：
 * 1.点击"常用设置"栏。
 * 2.判断Scroll组件是否存在，如果存在，说明弹窗正常出现。
 * 3.判断Scroll组件是否可滚动，如果可滚动，说明弹窗滚动区域表现正常。
 */
function showCommonSettingBottomDialog(driver: Driver) {
  it(CASE + '_弹出常用设置底部弹窗，视图内容区域可滚动', 0, async (done: Function) => {
    // 点击"常用设置"栏
    const commonSettingText = await driver.findComponent(ON.text('常用设置'));
    await commonSettingText.click();

    await driver.delayMs(1000);

    // 判断Scroll组件是否存在，如果存在，说明弹窗正常出现
    const scroll = await driver.findComponent(ON.id('scroll'));
    expect(scroll !== null).assertEqual(true);

    // 判断Scroll组件是否可滚动，如果可滚动，说明弹窗滚动区域表现正常
    const scrollable = await scroll.isScrollable();
    expect(scrollable).assertEqual(true);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：弹出安全设置底部弹窗，视图内容区域不可滚动
 * 执行步骤：
 * 1.点击"安全设置"栏。
 * 2.判断Scroll组件是否存在，如果存在，说明弹窗正常出现。
 * 3.判断Scroll组件是否可滚动，如果不可滚动，说明弹窗滚动区域表现正常。
 */
function showSecuritySettingBottomDialog(driver: Driver) {
  it(CASE + '_弹出安全设置底部弹窗，视图内容区域不可滚动', 0, async (done: Function) => {
    // 点击"安全设置"栏
    const securitySettingText = await driver.findComponent(ON.text('安全设置'));
    await securitySettingText.click();

    await driver.delayMs(1000);

    // 判断Scroll组件是否存在，如果存在，说明弹窗正常出现
    const scroll = await driver.findComponent(ON.id('scroll'));
    expect(scroll !== null).assertEqual(true);

    // 判断Scroll组件是否可滚动，如果不可滚动，说明弹窗滚动区域表现正常
    const scrollable = await scroll.isScrollable();
    expect(scrollable).assertEqual(false);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：点击常用设置底部弹窗关闭图标
 * 执行步骤：
 * 1.点击"常用设置"栏。
 * 2.判断关闭图标是否存在，如果存在，说明弹窗正常出现。
 * 3.点击关闭图标。
 * 4.判断Scroll组件是否存在，如果不存在，说明弹窗正常关闭。
 */
function clickCommonSettingBottomDialogCloseImage(driver: Driver) {
  it(CASE + '_点击常用设置底部弹窗关闭图标', 0, async (done: Function) => {
    // 点击"常用设置"栏
    const commonSettingText = await driver.findComponent(ON.text('常用设置'));
    await commonSettingText.click();

    await driver.delayMs(1000);

    // 判断关闭图标是否存在，如果存在，说明弹窗正常出现
    const closeImage = await driver.findComponent(ON.id('close_image'));
    expect(closeImage !== null).assertEqual(true);

    // 点击关闭图标
    await closeImage.click();
    await driver.delayMs(1000);

    // 判断Scroll组件是否存在，如果不存在，说明弹窗正常关闭
    const scroll = await driver.findComponent(ON.id('scroll'));
    expect(scroll === null).assertEqual(true);

    done();
  })
}

/**
 * 关联用例：点击安全设置底部弹窗关闭图标
 * 执行步骤：
 * 1.点击"安全设置"栏。
 * 2.判断关闭图标是否存在，如果存在，说明弹窗正常出现。
 * 3.点击关闭图标。
 * 4.判断Scroll组件是否存在，如果不存在，说明弹窗正常关闭。
 */
function clickSecuritySettingBottomDialogCloseImage(driver: Driver) {
  it(CASE + '_点击安全设置底部弹窗关闭图标', 0, async (done: Function) => {
    // 点击"安全设置"栏
    const securitySettingText = await driver.findComponent(ON.text('安全设置'));
    await securitySettingText.click();

    await driver.delayMs(1000);

    // 判断关闭图标是否存在，如果存在，说明弹窗正常出现
    const closeImage = await driver.findComponent(ON.id('close_image'));
    expect(closeImage !== null).assertEqual(true);

    // 点击关闭图标
    await closeImage.click();
    await driver.delayMs(1000);

    // 判断Scroll组件是否存在，如果不存在，说明弹窗正常关闭
    const scroll = await driver.findComponent(ON.id('scroll'));
    expect(scroll === null).assertEqual(true);

    done();
  })
}