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
import exit from '../common/Exit.test';

const CASE: string = 'AddressRecognize'; // 案例名称
const TAG: string = '[AddressRecognize_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟

/**
 * 【AI图片文字智能识别】自动化测试用例
 * 主要功能：按照规范格式输入收获地址信息或者选择含标准地址信息的图片，智能识别为地址数据进行保存
 * 执行步骤：
 * 1.点击新增地址。
 * 2.在地址文本域中输入标准格式的地址信息，当前测试无法模拟打开相机拍照，所以拍照识别用例暂不实现
 * 3.点击"识别"按钮，系统自动进行地址识别，把识别到的姓名、电话、地址分别填入对应的输入框中
 * 4.点击"保存地址"按钮。
 */
export default function addressRecognizeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('AI图片文字智能识别');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  it(CASE + '文字正确智能转换姓名、电话、地址信息', 0, async (done: Function) => {
    // 点击新增地址按钮
    let toolbarAdd = await driver.findComponent(ON.id('toolbarAdd'));
    await toolbarAdd.click();
    //点击文本域并输入地址信息
    let addressTextArea = await driver.findComponent(ON.id('addressTextArea'));
    await addressTextArea.click();
    let isFocused = await addressTextArea.isFocused();
    expect(true).assertEqual(isFocused);
    await addressTextArea.inputText("刘涛涛，18888888888，浙江省杭州市西湖区大唐时光4栋301");
    //点击识别按钮
    let btnRecognizeToAddress = await driver.findComponent(ON.id('btnRecognizeToAddress'));
    await btnRecognizeToAddress.click();
    //等待1000ms
    await driver.delayMs(1000);
    //点击地址标签
    let tagFriend = await driver.findComponent(ON.text('朋友'));
    await tagFriend.click();
    //点击保存地址，如果能保存成功，说明识别到了地址信息（不好意思，AI接口不能保证一定识别正确）
    let btnSaveAddress = await driver.findComponent(ON.id('btnSaveAddress'));
    await btnSaveAddress.click();
    //判断地址识别结果
    let inputName = await driver.findComponent(ON.id('inputName'));
    let inputNameText = await inputName.getText();
    expect(inputNameText).assertEqual("刘涛涛");
    let inputPhone = await driver.findComponent(ON.id('inputPhone'));
    let inputPhoneText = await inputPhone.getText();
    expect(inputPhoneText).assertEqual("18888888888");
    let inputAddress = await driver.findComponent(ON.id('inputAddress'));
    let inputAddressText = await inputAddress.getText();
    expect(inputAddressText).assertEqual("浙江省杭州市西湖区大唐时光4栋301");
    await driver.delayMs(DELAY_MS);
    done();
  })

  // 返回瀑布流主页面
  exit(CASE);

}