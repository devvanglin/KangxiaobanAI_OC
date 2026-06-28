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

import { it, expect } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'SearchSwiper'; // 案例名称
const CASE_NAME: string = '搜索框热搜词自动滚动'; // 案例中文名称
const TAG: string = '[searchswiper_Test]';

/**
 * 【搜索框热搜词自动滚动】自动化测试用例
 * 1. 进入页面查找搜索框内热搜词。
 * 2. 判断热搜词是否自动滚动。
 * 3. 判断输入框有值时热搜词是否消失。
 * 4. 判断热搜词重新出现时是否与之前相等。
 */
export default function searchSwiperTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、查找热搜词组件。
   * 2、验证热搜词是否自动滚动。
   **/
  it(CASE + '热搜词滚动', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Search_Roll begin`);
    await driver.assertComponentExist(ON.id('searchText'));
    const searchComponentOne: Component = await driver.findComponent(ON.id('searchText'));
    const hotTextOne: string = await searchComponentOne.getText();
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.id('searchText'));
    const searchComponentTwo: Component = await driver.findComponent(ON.id('searchText'));
    const hotTextTwo: string = await searchComponentTwo.getText();
    // 通过断言判断两次热搜词是否相同
    expect(hotTextOne == hotTextTwo).assertEqual(false);
    done();
  })

  /**
   * 执行步骤：
   * 1、触发输入框，判断热搜词是否消失。
   * 2、取消输入框，判断热搜词是否出现。
   **/
  it(CASE + '热搜词输入消失', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}_Search_Input begin`);
    await driver.assertComponentExist(ON.id('searchText'));
    const searchComponent: Component = await driver.findComponent(ON.id('searchText'));
    const swiperVisible:string = JSON.parse(getInspectorByKey('searchSwiper'))?.$attrs.visibility;
    // 判断输入框无值时热搜词是否存在
    expect(swiperVisible).assertEqual('Visibility.Visible');
    const hotText:string = await searchComponent.getText();
    await driver.assertComponentExist(ON.id('searchInput'));
    const inputComponent: Component = await driver.findComponent(ON.id('searchInput'));
    await inputComponent.inputText('test');
    await driver.delayMs(1500);
    const swiperHidden:object = JSON.parse(getInspectorByKey('searchSwiper'))?.$attrs.visibility;
    // 判断输入框有值时热搜词是否消失
    expect(swiperHidden).assertEqual('Visibility.Hidden');
    await inputComponent.clearText();
    await driver.delayMs(1500);
    await driver.assertComponentExist(ON.id('searchText'));
    const searchComponentBack: Component = await driver.findComponent(ON.id('searchText'));
    const hotTextBack:string = await searchComponentBack.getText();
    // 判断热搜词重现后与之前是否相同
    expect(hotText == hotTextBack).assertEqual(true);
    await driver.delayMs(1000);
    await driver.pressBack();
    await driver.delayMs(1000);
    done();
  })

  // 退出案例页面
  exit(CASE_NAME);
}