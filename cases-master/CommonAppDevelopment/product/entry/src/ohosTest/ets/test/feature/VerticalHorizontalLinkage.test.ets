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
import { Driver, ON, Component, UiDirection } from '@ohos.UiTest';

import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'VerticalHorizontalLinkage'; // 案例名称
const DELAY_MS: number = 500; // 指定500ms的延迟

/**
 * 【纵向横向列表联动】 自动化测试用例
 * 1. 手指横向划动列表，上下列表划动距离保持一致
 * 2. 手指纵向划动列表，左右列表划动距离保持一致
 */
export default function verticalHorizontalLinkageTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('纵向横向列表联动');
  let driver = Driver.create();

  /**
   * 主要功能：手指横向划动列表，列表可以联动
   * 关联用例：手指横向划动列表，上下列表划动距离保持一致
   * 执行步骤：
   * 1. 横向划动列表
   * 2.通过对比上下列表同一列的listItem控件边框的左上角x坐标是否一致去判断是否处于联动状态
   */
  it(CASE + '_vertical_move_list', 0, async (done: Function) => {
    // 横向划动列表
    await driver.fling(UiDirection.RIGHT, 1000);
    let topListItem: Component = await driver.findComponent(ON.id('topListItem2'));
    // 获取左上角x坐标
    const topListItemRectLeft = (await topListItem.getBounds()).left;
    // 获取视图内同一列的所有listItem
    let contentListItems: Component[] = await driver.findComponents(ON.id('everyLineListItem2'));
    // 避免接口并发调用，使用for循环
    for (let i = 0; i < contentListItems.length; i++) {
      const left = (await contentListItems[i].getBounds()).left;
      // 判断同一列listItem的x轴坐标是否一致
      expect(left).assertEqual(topListItemRectLeft);
    }
    done();
  })

  /**
   * 主要功能：手指纵向划动列表，列表可以联动
   * 关联用例：手指横向划动列表，左右列表划动距离保持一致
   * 执行步骤：
   * 1. 纵向划动列表
   * 2.通过对比左右列表同一行的listItem控件边框的右下角y坐标是否一致去判断是否处于联动状态
   */
  it(CASE + '_horizontal_move_list', 0, async (done: Function) => {
    // 横向划动列表
    await driver.fling(UiDirection.DOWN, 10000);
    await driver.delayMs(DELAY_MS);
    let bottomLeftListItem: Component = await driver.findComponent(ON.id('bottomLeftListItem8'));
    // 获取右下角y坐标
    const bottomLeftListItemRectBottom = (await bottomLeftListItem.getBounds()).bottom;
    let bottomRightListItem: Component = await driver.findComponent(ON.id('bottomRightListItem8'));
    // 获取右下角y坐标
    let bottomRightListItemRectBottom: number = (await bottomRightListItem.getBounds()).bottom;
    // 判断同一行listItem的y轴坐标是否一致
    expect(bottomLeftListItemRectBottom).assertEqual(bottomRightListItemRectBottom);

    done();
  })

  exit('纵向横向列表联动');
}