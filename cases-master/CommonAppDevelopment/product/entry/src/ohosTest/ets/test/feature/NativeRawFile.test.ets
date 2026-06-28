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
 * 【预加载so并读取RawFile文件】自动化测试用例
 */
export default function nativeRawfileTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('预加载so并读取RawFile文件');

  const driver = Driver.create();

  it("读取RawFile文件部分内容", 0, async (done: Function) => {
    await driver.delayMs(200);
    const contentComponent = await driver.findComponent(ON.id('rawFileContent'));
    // 获取rawFile文件内容
    const rawFileContent: string = await contentComponent!.getText();
    // 获取rawFile文件内容长度
    const lenContent = rawFileContent.length;

    // 开始读取位置
    let startPos: number = 0;
    // 读取的长度
    let readLen: number = 0;
    // 读取rawFile内容按钮
    const btnComponent = await driver.findComponent(ON.id('btnReadRawFile'));
    // 输入条件异常时，读取按钮将不可用，需要重新输入读取位置与长度
    do {
      // 随机输入起始位置
      let textInput = await driver.findComponent(ON.id('startPos'));
      startPos = Math.floor(Math.random() * (lenContent - 1)); // 获取lenContent以内随机数
      await textInput.inputText(startPos.toString());
      await driver.delayMs(500);
      // 随机输入读取长度
      textInput = await driver.findComponent(ON.id('readLen'));
      readLen = Math.floor(Math.random() * (lenContent - 1) + 1); // 获取lenContent以内随机数
      await textInput.inputText(readLen.toString());
      await driver.delayMs(500);
    } while ((await btnComponent.isEnabled()) === false)

    // 点击读取按钮
    await btnComponent.click();
    await driver.delayMs(500);
    // 获取读取结果
    const resultComponent = await driver.findComponent(ON.id('readResult'));
    const readResult: string = await resultComponent!.getText();
    await driver.delayMs(100);

    // 根据输入条件计算预期结果
    const expectResult: string = rawFileContent.slice(startPos, startPos + readLen);
    // 判断读取结果符合预期结果
    expect(readResult).assertEqual(expectResult);

    // 退出输入法
    await driver.pressBack();
    await driver.delayMs(1000);
    done();
  })

  exit('预加载so并读取RawFile文件');
}