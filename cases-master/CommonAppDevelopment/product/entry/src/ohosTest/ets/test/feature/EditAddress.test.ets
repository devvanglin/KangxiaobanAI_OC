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
import { inputMethod } from '@kit.IMEKit';
import { Driver, ON, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';

const Address: string = '辽宁省沈阳市浑南区';
const inputRecipientMsg: string = '小明'; // 收件人名字
const inputPhoneNumber: string = '13111111111'; // 手机号
const detailAddress: string = '圣诞小区一颗大树下3号门23号1402'; // 详细地址

/**
 * 【编辑收货地址案例】自动化测试用例
 * 主要功能：
 * 1. 省市区地区的数据在滑动选择器中选择确认后可以回填到输入框。
 * 2. 输入框中可以输入内容，并做表单必填内容校验。
 * 执行步骤：
 * 1. 点击"所在地区"输入框，弹出地区选择滑动选择器，滑动选择省市区等待滑动结束静止后，点击确认，断言选择的城市可以回填到输入框中。
 * 2. 从上到下对每条必填的输入框都输入内容，并点击"保存"按钮，断言出现弹窗"保存成功，此样式仅为案例展示"。
 */
export default function editAddressTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('编辑收货地址案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、断言存在"所在地区"输入框。
   * 2、点击"所在地区"输入框，断言弹出地区滑动地址选择器，滑动省市区。
   * 3、省市区等待滑动结束静止后，点击确认，断言选择的城市可以回填到输入框中。
   **/
  it('验证滑动选择器回填输入框功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在"所在地区"输入框。
    await driver.assertComponentExist(ON.id('selectAddress'));
    let inputAddressComponent = await driver.findComponent(ON.id('selectAddress'));
    await driver.delayMs(100);
    // 点击"所在地区"输入框
    await inputAddressComponent.click();
    await driver.delayMs(100);
    // 断言弹出地区滑动地址选择器
    await driver.assertComponentExist(ON.id('chooseAddressPicker'));
    await driver.findComponent(ON.id('chooseAddressPicker'));
    // 断言存在区地址"浑南区"并选中
    await driver.assertComponentExist(ON.text('浑南区'));
    let pickAddress = await driver.findComponent(ON.text('浑南区'));
    await pickAddress.click();
    await driver.delayMs(3000);
    // 断言存在"确定"按钮
    await driver.assertComponentExist(ON.text('确认'));
    let verifyButton = await driver.findComponent(ON.text('确认'));
    await verifyButton.click();
    // 断言地址回填成功
    await driver.assertComponentExist(ON.text(Address));
    done();
  })

  /**
   * 执行步骤：
   * 1、断言存在必填输入框。
   * 2、从上到下对每条必填的输入框都输入内容，并点击"保存"按钮，
   * 3、断言出现弹窗"保存成功，此样式仅为案例展示"。
   **/
  it('验证输入框必填功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在"收件人"输入框。
    await driver.assertComponentExist(ON.id('recipient'));
    let recipientComponent = await driver.findComponent(ON.id('recipient'));
    // 在"收件人"输入框，输入"小明"
    await recipientComponent.inputText(inputRecipientMsg);
    await driver.delayMs(1000);
    // 断言存在"手机号"输入框。
    await driver.assertComponentExist(ON.id('phoneNumber'));
    let phoneNumberComponent = await driver.findComponent(ON.id('phoneNumber'));
    // 在"手机号"输入框，输入"13111111111"
    await phoneNumberComponent.inputText(inputPhoneNumber);
    await driver.delayMs(1000);
    // 断言存在"详细地址"输入框。
    await driver.assertComponentExist(ON.id('detailAddress'));
    let detailAddressComponent = await driver.findComponent(ON.id('detailAddress'));
    // 在"详细地址"输入框，输入详细地址。
    await detailAddressComponent.inputText(detailAddress);
    // 收起键盘
    let inputMethodController = inputMethod.getController();
    inputMethodController.stopInputSession();
    await driver.delayMs(1000);
    // 断言存在保存按钮，并点击
    await driver.assertComponentExist(ON.text('保存'));
    // 断言保存成功
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('保存成功，此样式仅为案例展示');
    };
    observer.once('toastShow', callback);
    let saveButtonComponent = await driver.findComponent(ON.text('保存'));
    await saveButtonComponent.click();
    await driver.delayMs(1000);

    await driver.delayMs(1000);

    done();
  })

  exit('编辑收货地址案例');
}
