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
import { Driver, ON, Component, Rect, Point } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE_NAME: string = '左右拖动切换图片效果案例'; // 案例名称

/**
 * 【左右拖动切换图片效果案例】自动化测试用例
 */
export default function dragToSwitchPictureTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  let driver = Driver.create();

  /**
   * 1、长按中间按钮向左拖动
   */
  it(CASE_NAME + '_drag_left', 0, async (done: Function) => {
    let leftPicture: Component = await driver.findComponent(ON.id('left_picture'));
    let leftWidthBefore: number = getComponentWidth(await leftPicture.getBounds());
    let rightPicture: Component = await driver.findComponent(ON.id('right_picture'));
    let rightWidthBefore: number = getComponentWidth(await rightPicture.getBounds());
    let dragSwitch: Component = await driver.findComponent(ON.id('drag_switch'));
    let dragSwitchPoint: Point = await dragSwitch.getBoundsCenter();
    await driver.drag(dragSwitchPoint.x, dragSwitchPoint.y, dragSwitchPoint.x - 200, dragSwitchPoint.y, 1000);
    await driver.delayMs(500);

    leftPicture = await driver.findComponent(ON.id('left_picture'));
    let leftWidthAfter: number = getComponentWidth(await leftPicture.getBounds());
    rightPicture = await driver.findComponent(ON.id('right_picture'));
    let rightWidthAfter: number = getComponentWidth(await rightPicture.getBounds());
    // 断言：左边图片宽度变小
    expect(leftWidthAfter).assertLess(leftWidthBefore);
    // 断言：右边图片宽度变大
    expect(rightWidthAfter).assertLarger(rightWidthBefore);

    done();
  })

  /**
   * 2、长按中间按钮向右拖动
   */
  it(CASE_NAME + '_drag_right', 0, async (done: Function) => {
    let leftPicture: Component = await driver.findComponent(ON.id('left_picture'));
    let leftWidthBefore: number = getComponentWidth(await leftPicture.getBounds());
    let rightPicture: Component = await driver.findComponent(ON.id('right_picture'));
    let rightWidthBefore: number = getComponentWidth(await rightPicture.getBounds());
    let dragSwitch: Component = await driver.findComponent(ON.id('drag_switch'));
    let dragSwitchPoint: Point = await dragSwitch.getBoundsCenter();
    await driver.drag(dragSwitchPoint.x, dragSwitchPoint.y, dragSwitchPoint.x + 200, dragSwitchPoint.y, 1000);
    await driver.delayMs(500);

    leftPicture = await driver.findComponent(ON.id('left_picture'));
    let leftWidthAfter: number = getComponentWidth(await leftPicture.getBounds());
    rightPicture = await driver.findComponent(ON.id('right_picture'));
    let rightWidthAfter: number = getComponentWidth(await rightPicture.getBounds());
    // 断言：左边图片宽度变大
    expect(leftWidthAfter).assertLarger(leftWidthBefore);
    // 断言：右边图片宽度变小
    expect(rightWidthAfter).assertLess(rightWidthBefore);


    done();
  })

  exit(CASE_NAME);
}

function getComponentWidth(rect: Rect): number {
  return rect.right - rect.left;
}
