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

import { Driver, ON } from "@kit.TestKit";
import { expect, it } from "@ohos/hypium";
import exit from "../common/Exit.test";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";

/**
 * 【Navigation页面跳转对象传递案例】自动化测试用例
 */
export default function navigationParameterTransferTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('Navigation页面跳转对象传递');

  const driver = Driver.create();

  it("Navigation页面跳转对象传递", 0, async (done: Function) => {
    await driver.delayMs(500);
    // 判断出发日期参数传递正确
    let component = await driver.findComponent(ON.id('departure_time'));
    const departure_time: string = await component!.getText();
    await driver.delayMs(200);
    expect(departure_time).assertEqual('6月8日');

    // 判断姓名参数传递正确
    component = await driver.findComponent(ON.id('user_name'));
    const user_name: string = await component!.getText();
    await driver.delayMs(200);
    expect(user_name).assertEqual('张山');

    // 判断证件号参数传递正确
    component = await driver.findComponent(ON.id('user_id'));
    const user_id: string = await component!.getText();
    await driver.delayMs(200);
    expect(user_id).assertEqual('332212199507270611');

    // 判断获取到1-200随机座位号
    component = await driver.findComponent(ON.id('seatNo'));
    let seatNo: string = await component!.getText();
    await driver.delayMs(200);
    expect(Number(seatNo) >= 1 && Number(seatNo) <= 200).assertEqual(true);

    // 点击换个位置重新获取随机位置，循环三次
    for (let index = 0; index < 3; index++) {
      let btn_ChangeSeatNo = await driver.findComponent(ON.id('btn_ChangeSeatNo'));
      await btn_ChangeSeatNo.click();
      await driver.delayMs(200);
      let newSeatNo: string = await component!.getText();
      // 判断重新获取到1-200随机座位号
      expect(Number(newSeatNo) >= 1 && Number(newSeatNo) <= 200).assertEqual(true);
      // 判断新旧座位号不一致
      expect(seatNo !== newSeatNo).assertEqual(true);
      // 重新赋值座位号
      seatNo = newSeatNo;
    }
    done();
  })
  exit('Navigation页面跳转对象传递');
}