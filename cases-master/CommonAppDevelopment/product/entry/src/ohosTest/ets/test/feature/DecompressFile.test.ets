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

import { Driver, ON } from '@kit.TestKit';
import { it } from '@ohos/hypium';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';

/**
 * 【Worker子线程中解压文件】自动化测试用例
 * 主要功能：[Worker子线程使用zlib.decompressfile接口对沙箱目录中的压缩文件进行解压操作，解压成功后将解压路径返回主线程，获取解压文件列表。
 * 执行步骤：
 * 1. 点击解压按钮，解压结果下方显示三个txt文件，页面弹出"文件解压成功"提示。
 */
export default function decompressFileTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('Worker子线程中解压文件');

  const driver = Driver.create();
  it('验证解压功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在解压按钮
    await driver.assertComponentExist(ON.text('解压'));
    let decompressButtonComponent = await driver.findComponent(ON.text('解压'));
    // 点击解压按钮
    await decompressButtonComponent.click();
    await driver.delayMs(300);
    // 断言点击后解压结果下方显示三个txt文件，页面弹出"文件解压成功"提示
    await driver.assertComponentExist(ON.text('文件解压成功'));
    await driver.delayMs(1000);
    for (let i = 0; i < 3; i++) {
      await driver.assertComponentExist(ON.text(`${i+1}.txt`));
    }
    done();
  })

  exit('Worker子线程中解压文件');
}