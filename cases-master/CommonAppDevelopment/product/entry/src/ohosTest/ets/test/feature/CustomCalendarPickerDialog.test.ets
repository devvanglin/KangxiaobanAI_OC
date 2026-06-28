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
import { Component, Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';


const CASE: string = 'customcalendarpickerdialog'; // 案例名称

/**
 * 【自定义日历选择器案例】自动化测试用例
 * 1、进入到案例后，点击日期，可以显示自定义日选择器
 * 2、自定义日历选择器可滑动
 * 3、点击日期可进行选择
 */
export default function customCalendarPickerDialogTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('自定义日历选择器');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、点击日期拉起自定义日历选择器。通过正常显示日历面板来验证。
   **/
  it(CASE + '显示日历', 0, async (done: Function) => {
    const clickComponent: Component = await driver.findComponent(ON.id('calender_click'));
    await clickComponent.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.type('Text').text('出发日期')); // 通过断言该字符，来判断日历弹窗弹出
    done();
  })

  /**
   * 执行步骤：
   * 1、滑动日历选择弹窗，通过判断是否可以滑动来验证。
   **/
  it(CASE + '日历可上下滑动', 0, async (done: Function) => {
    const clickComponent: Component = await driver.findComponent(ON.id('calender_click'));
    await clickComponent.click();
    await driver.delayMs(500);
    const dialog: Component = await driver.findComponent(ON.id('calender_data_list'));
    expect(await dialog.isScrollable()).assertEqual(true); // 通过判断日期列表是否可以滑动来判断
    done();
  })


  /**
   * 执行步骤：
   * 1、拉起日期选择弹窗后，点击当前日期。通过判断日历弹窗隐藏来判断，且显示出当前日期来验证
   **/
  it(CASE + '点击日期可选择', 0, async (done: Function) => {
    const nowDate = new Date();
    const currentMonth = nowDate.getMonth() + 1; // 获取当前月份，getMonth()获得的值是0~11，实际月份需要+1
    const currentDay = nowDate.getDate();
    await driver.assertComponentExist(ON.text(currentDay.toString()).within(ON.id('calender_data_list')));
    const currentDayCom: Component =
      await driver.findComponent(ON.text(currentDay.toString()).within(ON.id('calender_data_list')));
    await currentDayCom.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text(`${currentMonth}月${currentDay}日`)); // 通过判断日历弹窗隐藏来判断，且显示出当前日期
    done();
  })

  // 退出案例
  exit('自定义日历选择器案例');

}