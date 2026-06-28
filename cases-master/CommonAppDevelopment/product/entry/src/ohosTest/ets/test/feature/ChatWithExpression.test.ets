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
import exit from "../common/Exit.test";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";

/**
 * 【表情聊天案例】自动化测试用例
 */
export default function chatWithExpressionTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('表情聊天案例');

  const driver = Driver.create();
  const inputMsg: string = 'abcdefg'; // 发送的聊天信息

  /**
   * 1. 验证点击表情按钮后有全部表情
   * 2. 验证点击过表情之后有最近使用表情
   * 3. 验证发送表情之后里聊天框最下方有发送的聊天信息
   */
  it("验证表情聊天", 0, async (done: Function) => {
    await driver.delayMs(200);
    const faceBtnComponent = await driver.findComponent(ON.id('faceBtn'));
    await driver.delayMs(200);

    // 验证点击表情按钮后有全部表情
    await faceBtnComponent.click();
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.id('txt_all_face'));
    await driver.assertComponentExist(ON.id('detailId'));

    // 验证点击过表情之后有最近使用表情
    let faceItem = await driver.findComponent(ON.id('detailId'));
    await driver.delayMs(200);
    await faceItem.click(); // 点击一个表情
    await driver.delayMs(200);
    await faceBtnComponent.click();
    await driver.delayMs(200);
    await faceBtnComponent.click();
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.id('txt_last_face'));

    // 发送信息
    const inputComponent = await driver.findComponent(ON.id('msg_input'));
    await inputComponent.inputText(inputMsg); // 输入文字
    await driver.delayMs(500);
    const sendBtnComponent = await driver.findComponent(ON.id('btn_sendMsg'));
    await sendBtnComponent.click();

    // 验证聊天框中有发送的内容
    const listComponent = await driver.findComponent(ON.type('List'));
    await listComponent.scrollToBottom(40000);
    await driver.assertComponentExist(ON.text(inputMsg, MatchPattern.CONTAINS));

    done();
  })

  exit('表情聊天案例');
}