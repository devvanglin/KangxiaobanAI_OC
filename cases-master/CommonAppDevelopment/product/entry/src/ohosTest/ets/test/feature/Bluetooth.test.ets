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

import { Driver, ON, MatchPattern } from "@kit.TestKit";
import { expect, it } from "@ohos/hypium";
import { logger } from 'utils';
import exit from "../common/Exit.test";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";

const CASE: string = 'Bluetooth'; // 案例名称
const TAG: string = '[Bluetooth_Test]';

/**
 * 【蓝牙实现服务端和客户端通讯】自动化测试用例
 *  测试前请确保其他设备已经开启蓝牙心率服务
 */
export default function bluetoothTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('蓝牙实现服务端和客户端通讯');
  const driver = Driver.create();

  /**
   * 进入场景后需要验证一些蓝牙授权信息
   */
  it("进入蓝牙服务端场景", 0, async (done: Function) => {
    // 进入服务端模块
    await driver.assertComponentExist(ON.id('btn_ble_server'));
    const btnBleServer = await driver.findComponent(ON.id('btn_ble_server'));
    await btnBleServer.click();

    // 有授权的话，点击授权
    // rk设备弹出鉴权信息较慢，增大延迟时间
    await driver.delayMs(1500);
    let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1500);
    }
    btnPermission = await driver.findComponent(ON.text('允许'));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1500);
    }
    // 断言进入蓝牙服务场景成功
    await driver.assertComponentExist(ON.id('btn_start_ble_server'));
    done();
  })

  /**
   * 验证开启蓝牙服务后心跳数据有变动
   */
  it("开启蓝牙服务", 0, async (done: Function) => {
    // 开启蓝牙服务
    const btnStartBleServer = await driver.findComponent(ON.id('btn_start_ble_server'));
    await btnStartBleServer.click();
    await driver.delayMs(1500);

    // 获取心率信息
    let heartRate: string = '-bpm'; // 前一次心跳数据
    let heartRate2: string = '-bpm'; // 后一次心跳数据
    await driver.assertComponentExist(ON.id('txt_heartRate'));
    const txtHeartRate = await driver.findComponent(ON.id('txt_heartRate'));
    // 获取第一次心跳数据
    heartRate = await txtHeartRate.getText();
    // 断言心跳数据不为空
    expect(heartRate !== '-bpm').assertEqual(true);

    // 获取第二次心跳数据
    await driver.delayMs(1500);
    heartRate2 = await txtHeartRate.getText();
    // 断言心跳数据不为空
    expect(heartRate2 !== '-bpm').assertEqual(true);
    // 断言两次获取到的数据不一致
    expect(heartRate2 !== heartRate).assertEqual(true);
    done();
  })

  /**
   * 验证关闭蓝牙服务后心跳数据不再变动
   */
  it("关闭蓝牙服务", 0, async (done: Function) => {
    let heartRate: string = '-bpm'; // 关闭蓝牙服务前心跳数据
    let heartRate2: string = '-bpm'; // 关闭蓝牙服务后心跳数据
    // 关闭蓝牙服务
    const btnStartBleServer = await driver.findComponent(ON.id('btn_start_ble_server'));
    await btnStartBleServer.click();
    // 获取关闭蓝牙服务时的心跳数据
    const txtHeartRate = await driver.findComponent(ON.id('txt_heartRate'));
    heartRate = await txtHeartRate.getText();

    await driver.delayMs(1500);
    // 获取关闭蓝牙服务后的心跳数据
    heartRate2 = await txtHeartRate.getText();

    // 断言两次获取到的数据是一样的
    expect(heartRate2 === heartRate).assertEqual(true);

    // 退出蓝牙页面
    await driver.pressBack();
    await driver.delayMs(1500);
    done();
  })

  /**
   * 进入场景后需要验证一些蓝牙授权信息
   */
  it("进入蓝牙客户端场景", 0, async (done: Function) => {
    // 进入服务端模块
    await driver.assertComponentExist(ON.id('btn_ble_client'));
    const btnBleClient = await driver.findComponent(ON.id('btn_ble_client'));
    await btnBleClient.click();

    // 有授权的话，点击授权
    // rk设备弹出鉴权信息较慢，增大延迟时间
    await driver.delayMs(1500);
    let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1500);
    }
    btnPermission = await driver.findComponent(ON.text('允许'));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1500);
    }
    // 断言存在搜索蓝牙服务按钮
    await driver.assertComponentExist(ON.id('btn_start_scan'));
    done();
  })

  /**
   * 搜索蓝牙服务，如果其他设备没有开启蓝牙服务端的话，后面的蓝牙测试用例会执行失败
   */
  it("搜索蓝牙服务", 0, async (done: Function) => {
    const btnBleScan = await driver.findComponent(ON.id('btn_start_scan'));
    await btnBleScan.click();
    await driver.delayMs(1500);

    let isFindBleServer: boolean = false; // 是否搜索到ble服务器
    let findNum: number = 3;
    // 搜索三次
    do {
      let itemList = await driver.findComponent(ON.id('list_item0'));
      if (itemList !== null && itemList !== undefined) {
        isFindBleServer = true;
        logger.info(TAG, `${CASE} find ble server`);
      } else {
        logger.warn(TAG, `${CASE} not find ble server`);
      }
      await driver.delayMs(1500);
      findNum--;
    } while (isFindBleServer === false && findNum > 0)

    // 其他设备没有开启蓝牙服务端的话，直接返回，避免影响其他用例测试
    if (!isFindBleServer) {
      logger.warn(TAG, `${CASE} 找不到可用的蓝牙服务`);
      // 回到蓝牙首页场景
      await driver.pressBack();
      await driver.delayMs(500);

      // 退出蓝牙场景
      await driver.pressBack();
      await driver.delayMs(500);
      done();
    } else {
      // 断言找到蓝牙服务器
      expect(isFindBleServer).assertEqual(true);
    }
    done();
  })

  /**
   * 连接蓝牙服务
   */
  it("连接蓝牙服务设备", 0, async (done: Function) => {
    // 连接蓝牙服务
    await driver.assertComponentExist(ON.text('连接').type('Button'));
    const btnConn = await driver.findComponent(ON.text('连接').type('Button'));
    await btnConn.click();
    await driver.delayMs(2500);
    // 断言连接成功
    await driver.assertComponentExist(ON.text('已连接').type('Text'));
    done();
  })

  /**
   * 进入心率跳动页面
   */
  it("进入心率跳动页面", 0, async (done: Function) => {
    const btnText = await driver.findComponent(ON.text('已连接').type('Text'));
    await btnText.click();
    await driver.delayMs(1500);
    // 断言进入成功
    await driver.assertComponentExist(ON.id('Realtime_heart_rate'));
    done();
  })

  /**
   * 侦听实时心率
   */
  it("侦听实时心率", 0, async (done: Function) => {
    // 获取实时心率组件
    const txtRealtimeHeartRate = await driver.findComponent(ON.id('Realtime_heart_rate'));
    // 获取第1次心率信息
    let heartRate: string = await txtRealtimeHeartRate.getText();
    logger.info(TAG, `${CASE} heartRate:${heartRate}`);

    // 此处设备不同延时有差异，rk设备较慢，为保证rk设备验证正常，加大延时时间
    await driver.delayMs(11000);

    // 获取第2次心率信息
    let heartRate2: string = await txtRealtimeHeartRate.getText();
    logger.info(TAG, `${CASE} heartRate2:${heartRate2}`);
    // 断言两次获取到的数据是不一样的
    expect(heartRate2 !== heartRate).assertEqual(true);
    done();
  })

  /**
   * 断开连接
   */
  it("断开连接", 0, async (done: Function) => {
    // 断开连接，回到蓝牙客户端场景
    await driver.assertComponentExist(ON.text('断开连接'));
    const btnStopConn = await driver.findComponent(ON.text('断开连接'));
    await btnStopConn!.click();
    await driver.delayMs(1000);
    // 断言存在搜索蓝牙服务按钮
    await driver.assertComponentExist(ON.id('btn_start_scan'));

    // 回到蓝牙首页场景
    await driver.pressBack();
    await driver.delayMs(500);

    done();
  })

  exit('蓝牙实现服务端和客户端通讯');
}