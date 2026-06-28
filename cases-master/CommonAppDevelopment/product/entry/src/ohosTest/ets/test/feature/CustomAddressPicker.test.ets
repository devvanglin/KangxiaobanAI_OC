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
import { logger } from 'utils';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'CustomAddressPicker'; // 案例名称
const TAG: string = '[CustomAddressPicker_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟

/**
 * 【自定义地址选择案例】自动化测试用例
 * 主要功能：提供带切换动效的自定义地址选择组件
 * 执行步骤：
 * 1.点击场景一自定义地址选择组件CustomAddressPicker，拉起地址选择半模态弹窗页面。
 * 2.在地址选择半模态弹窗页面中依次点击省，市，区名后，地址选择半模态弹窗页面会自动关闭
 * 3.点击场景一中的"获取地址信息"按钮
 * 4.点击场景二自定义地址选择组件CustomAddressPicker，拉起地址选择半模态弹窗页面。
 * 5.在地址选择半模态弹窗页面中，先点击"浙江省"，切换到省列表，然后再依次点击省，市，区名后，地址选择半模态弹窗页面会自动关闭
 * 6.点击场景二中的"获取地址信息"按钮
 */
export default function customAddressPickerTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('自定义地址选择案例');
  let isShow: boolean = false;
  let addressInfo: string = '';
  // 构造一个操作对象。Driver类为uitest测试框架的总入口，提供控件匹配/查找，按键注入，坐标点击/滑动，截图等能力。
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);
  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    isShow = data.data?.isShow;
    addressInfo = data.data?.addressInfo;
  })

  /**
   * 点击场景一自定义地址选择组件CustomAddressPicker，拉起地址选择半模态弹窗页面。
   */
  it(CASE + 'CustomAddressPicker_001', 0, async (done: Function) => {
    // 点击场景一的"所在地区"一栏（自定义地址选择组件CustomAddressPicker），拉起地址选择半模态弹窗页面
    let scenarioOne = await driver.findComponent(ON.id('scenarioOne'));
    await scenarioOne.click();
    await driver.delayMs(DELAY_MS);
    // 判断半模态页面是否存在
    expect(isShow).assertEqual(true); // 判断是否拉起半模态弹窗页面
    done();
  })

  /**
   * 在地址选择半模态弹窗页面中依次点击省，市，区名后，地址选择半模态弹窗页面会自动关闭
   */
  it(CASE + 'CustomAddressPicker_002', 0, async (done: Function) => {
    // 点击省市区（点到区名后，地址选择半模态弹窗页面会自动关闭）
    let scenarioOneProvince = await driver.findComponent(ON.text('河北省'));
    await scenarioOneProvince.click();
    await driver.delayMs(DELAY_MS);
    let scenarioOneCity = await driver.findComponent(ON.text('保定市'));
    await scenarioOneCity.click();
    await driver.delayMs(DELAY_MS);
    let scenarioOneRegion = await driver.findComponent(ON.text('清苑区'));
    await scenarioOneRegion.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('河北省保定市清苑区'));
    done();
  })

  /**
   * 点击场景一中的"获取地址信息"按钮
   */
  it(CASE + 'CustomAddressPicker_003', 0, async (done: Function) => {
    // 点击场景一中的"获取地址信息"按钮,弹框，再弹窗外点击一次（这里用再点一次按钮代替），退出弹框
    let scenarioOneBtn = await driver.findComponent(ON.id('scenarioOneBtn'));
    await scenarioOneBtn.click();
    await driver.delayMs(DELAY_MS);
    await scenarioOneBtn.click();
    expect(addressInfo)
      .assertEqual('{"province":"河北省","city":"保定市","region":"清苑区","provinceId":"13","cityId":"1306","regionId":"130608"}');
    done();
  })

  /**
   * 点击场景二自定义地址选择组件CustomAddressPicker，拉起地址选择半模态弹窗页面。
   */
  it(CASE + 'CustomAddressPicker_004', 0, async (done: Function) => {
    // 点击场景二的"所在地区"一栏（自定义地址选择组件CustomAddressPicker），拉起地址选择半模态弹窗页面
    let scenarioTwo = await driver.findComponent(ON.id('scenarioTwo'));
    await scenarioTwo.click();
    await driver.delayMs(DELAY_MS);
    expect(isShow).assertEqual(true); // 判断是否拉起半模态弹窗页面
    done();
  })

  /**
   * 在地址选择半模态弹窗页面中，先点击"浙江省"，切换到省列表，然后再依次点击省，市，区名后，地址选择半模态弹窗页面会自动关闭
   */
  it(CASE + 'CustomAddressPicker_005', 0, async (done: Function) => {
    // 场景二打开的时候默认展示"浙江省，杭州市，余杭区"，所以需要先切到省页面，这里点击"浙江省"进行切换
    let scenarioTwoToProvince = await driver.findComponent(ON.text('浙江省'));
    await scenarioTwoToProvince.click();
    await driver.delayMs(DELAY_MS);
    // 点击省市区（点到区名后，地址选择半模态弹窗页面会自动关闭）
    let scenarioTwoProvince = await driver.findComponent(ON.text('河北省'));
    await scenarioTwoProvince.click();
    await driver.delayMs(DELAY_MS);
    let scenarioTwoCity = await driver.findComponent(ON.text('保定市'));
    await scenarioTwoCity.click();
    await driver.delayMs(DELAY_MS);
    let scenarioTwoRegion = await driver.findComponent(ON.text('清苑区'));
    await scenarioTwoRegion.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('河北省保定市清苑区'));
    done();
  })

  /**
   * 点击场景二中的"获取地址信息"按钮
   */
  it(CASE + 'CustomAddressPicker_006', 0, async (done: Function) => {
    // 点击场景二中的"获取地址信息"按钮,弹框，再弹窗外点击一次（这里用再点一次按钮代替），退出弹框
    let scenarioTwoBtn = await driver.findComponent(ON.id('scenarioTwoBtn'));
    await scenarioTwoBtn.click();
    await driver.delayMs(DELAY_MS);
    await scenarioTwoBtn.click();
    await driver.delayMs(DELAY_MS);
    expect(addressInfo)
      .assertEqual('{"province":"河北省","city":"保定市","region":"清苑区","provinceId":"13","cityId":"1306","regionId":"130608"}');
    logger.info(TAG, `${CASE} end`);
    done();
  })

  exit('自定义地址选择案例');
}