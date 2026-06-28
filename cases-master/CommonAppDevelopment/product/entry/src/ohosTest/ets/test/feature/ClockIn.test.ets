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

import { Driver, ON, MatchPattern } from '@kit.TestKit';
import { expect, it } from '@ohos/hypium';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';

/**
 * 【地图定位打卡案例】自动化测试用例
 *  执行步骤：
 *  1. 验证是否存在授权弹窗并授予权限，授权成功后地图会自动定位到当前为止，显示打卡区域、用户位置标记及地址窗口。
 *  2. 验证用户地址窗口是否显示
 *  3. 移动地图，然后点击右下角定位按钮，地图会重新定位，用户位置标记会移动到地图中心。
 *  4. 点击上班打卡/下班打卡按钮，验证签到/签退信息存在，签到地址与定位位置的地址相同。
 */
export default function clockInTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('地图定位打卡案例');
  const driver = Driver.create();

  /**
   * 进入场景后需要位置权限信息
   */

  it('验证是否存在授权弹窗并授予权限', 0, async (done: Function) => {
    // 有授权的话，点击授权
    await driver.delayMs(1000);
    let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1000);
    }
    btnPermission = await driver.findComponent(ON.text('允许'));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1000);
    }
    // 断言地图加载成功
    await driver.assertComponentExist(ON.id('map'));

    done();
  });

  /**
   * 授权完成后，地图会自动定位到当前位置，验证地址窗口存在（打卡区域、用户位置标记需手工用例验证）
   */

  it('验证地址窗口存在', 0, async (done: Function) => {
    // 定位耗时较长
    await driver.delayMs(2000);
    // 断言定位成功，位置信息窗口存在
    await driver.assertComponentExist(ON.id('customInfoWindowContainer'));

    done();
  });

  /**
   * 点击右下角定位按钮，地图移动至用户当前位置（用户位置是否正确需要手工用例验证）
   */

  it('验证右下角定位按钮定位功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 按住移动地图使打卡区域和地址窗口离开屏幕中心
    await driver.swipe(600, 600, 600, 1200, 600);
    await driver.delayMs(1000);

    // 断言定位按钮存在
    await driver.assertComponentExist(ON.id('locatingButton'));
    let locatingButton = await driver.findComponent(ON.id('locatingButton'));
    await locatingButton.click();
    await driver.delayMs(1000);

    // 断言位置信息窗口存在
    await driver.assertComponentExist(ON.id('customInfoWindowContainer'));

    done();
  });

  it('验证打卡功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言位置信息窗口中的用户地址信息存在
    await driver.assertComponentExist(ON.id('userAddress'));
    let userAddressComponent = await driver.findComponent(ON.id('userAddress'));
    // 获取当前定位位置的地址
    let userAddress = await userAddressComponent.getText();

    // 断言上班打卡按钮存在
    await driver.assertComponentExist(ON.text('上班打卡'));
    let clockInButton = await driver.findComponent(ON.text('上班打卡'));
    await clockInButton.click();
    await driver.delayMs(2000);

    // 断言签到信息存在
    await driver.assertComponentExist(ON.id('clockInInfo'));
    // 断言签到地址组件存在
    await driver.assertComponentExist(ON.id('clockInAddress'));
    let clockInAddressComponent = await driver.findComponent(ON.id('clockInAddress'));
    // 获取签到地址
    let clockInAddress = await clockInAddressComponent.getText();
    // 验证签到地址与定位位置的地址相同
    expect(clockInAddress).assertEqual(userAddress);

    // 断言下班打卡按钮存在
    await driver.assertComponentExist(ON.text('下班打卡'));
    let clockOutButton = await driver.findComponent(ON.text('下班打卡'));
    await clockOutButton.click();
    await driver.delayMs(2000);

    // 断言签退信息存在
    await driver.assertComponentExist(ON.id('clockOutInfo'));
    // 断言签退地址组件存在
    await driver.assertComponentExist(ON.id('clockOutAddress'));
    let clockOutAddressComponent = await driver.findComponent(ON.id('clockOutAddress'));
    // 获取签退地址
    let clockOutAddress = await clockOutAddressComponent.getText();
    // 验证签退地址与定位位置的地址相同
    expect(clockOutAddress).assertEqual(userAddress);

    // 已进行下班打卡后断言更新打卡按钮存在
    await driver.assertComponentExist(ON.text('更新打卡'));
    let clockOutUpdateButton = await driver.findComponent(ON.text('更新打卡'));
    await clockOutUpdateButton.click();
    await driver.delayMs(2000);

    // 获取更新当前定位位置的地址
    userAddress = await userAddressComponent.getText();

    // 断言签退信息存在
    await driver.assertComponentExist(ON.id('clockOutInfo'));
    // 断言签退地址组件存在
    await driver.assertComponentExist(ON.id('clockOutAddress'));
    // 更新签退地址
    clockOutAddress = await clockOutAddressComponent.getText();
    // 验证更新后的签退地址与定位位置的地址相同
    expect(clockOutAddress).assertEqual(userAddress);

    done();
  });

  exit('地图定位打卡案例');
}