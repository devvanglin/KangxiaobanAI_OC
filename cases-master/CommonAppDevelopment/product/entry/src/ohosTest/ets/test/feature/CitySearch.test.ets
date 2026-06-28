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

import { Driver, ON } from '@ohos.UiTest';
import { expect, it } from '@ohos/hypium';
import { inputMethod } from '@kit.IMEKit';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'CitySearch';
const TAG: string = '[CitySearch_Test]';
const inputMsg: string = 'a'; // 需要搜索的城市首字母
const cityArray = ['阿尔山', '阿勒泰地区', '安庆', '安阳']; // a开头的相关城市信息

/**
 * 【城市选择案例】自动化测试用例
 * 主要功能：
 * 1. 在搜索框中可以根据城市首字母模糊搜索出相近的城市，例如输入"a",会出现"阿尔山","阿勒泰地区","安庆","安阳"。
 * 2. 下方城市列表通过AlphabetIndexer组件实现拼音索引条，通过滑动选择城市首拼，快速定位相关城市。
 * 执行步骤：
 * 1. 在搜索框输入a，点击搜索，出现"阿尔山","阿勒泰地区","安庆","安阳"城市,通过判断首字母a开头的城市信息是否都显示从而验证城市搜索功能。
 * 2. 下方城市列表滑动左边城市，右边的城市首拼跟着左边滑动的城市联动；下方城市列表滑动右边的城市首拼，左边城市列表快速定位到B开头的城市：北京。
 */
export default function citySearchTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('城市选择案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、点击搜索框，输入"a"。
   * 2、点击"搜索"按钮。
   * 3、通过判断首字母a开头的城市信息是否都显示从而验证城市搜索功能。
   **/
  it('验证首字母搜索城市', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在城市搜索组件
    await driver.assertComponentExist(ON.id('searchCity'));
    let searchCityComponent = await driver.findComponent(ON.id('searchCity'));
    // 输入"a"
    await searchCityComponent.inputText(inputMsg);
    await driver.delayMs(100);
    // 断言存在城市搜索按钮
    await driver.assertComponentExist(ON.text('搜索'));
    let searchCityButton = await driver.findComponent(ON.text('搜索'));
    // 点击搜索按钮
    await searchCityButton.click();
    for (let i = 0; i < cityArray.length; i++) {
      // 判断a开头的城市是否存在
      await driver.assertComponentExist(ON.text(cityArray[i]));
    };
    // 关闭搜索界面
    let rect = await searchCityComponent.getBoundsCenter();
    logger.info(TAG, JSON.stringify(rect));
    await driver.click(rect.x + 310, 399);
    await driver.delayMs(100);
    // 收起键盘
    let inputMethodController = inputMethod.getController();
    inputMethodController.stopInputSession();
    done();
  })

  /**
   * 执行步骤：
   * 1、下方城市列表滑动左边城市，右边的城市首拼跟着左边滑动的城市联动；
   * 2、下方城市列表选中右边导航条的某一个城市首拼，左边城市列表快速定位到选中字母开头的城市。
   **/
  it('验证城市列表联动功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在城市搜索组件
    await driver.assertComponentExist(ON.id('CityList')); // 断言下面的城市列表组件里左边列表是否存在
    await driver.findComponent(ON.id('CityList'));
    // 向上滑动左边的城市列表，滑动到B开头的城市范围内。
    await driver.swipe(300, 2000, 300, 1500, 800);
    await driver.delayMs(500);
    // 1、断言存在右边的城市首拼导航条，导航条联动定位到选中字母B。
    await driver.assertComponentExist(ON.id('AlphabetIndexer'));
    let AlphabetIndexer = await driver.findComponent(ON.id('AlphabetIndexer'));
    const text: string = await AlphabetIndexer.getText();
    await expect(text).assertEqual('B');
    await driver.delayMs(100);
    // 2、下方城市列表选中右边导航条的某一个城市首拼L，断言左边的城市列表联动定位到L开头的城市：兰州。
    let rect2 = await AlphabetIndexer.getBoundsCenter();
    logger.info(TAG, CASE, JSON.stringify(rect2));
    await driver.click(rect2.x, rect2.y);
    await driver.delayMs(100);
    await driver.assertComponentExist(ON.text('兰州'));
    await driver.delayMs(1000);
    done();
  })
  exit('城市选择案例');
}
