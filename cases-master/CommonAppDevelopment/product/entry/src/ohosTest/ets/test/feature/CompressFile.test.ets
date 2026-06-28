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

import { it } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = '文件压缩案例'; // 案例名称

/**
 * 【文件压缩案例】自动化测试用例
 * 1. 点击压缩按钮，压缩结果标题下出现被压缩后的zip文件名
 */
export default function compressFileTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('文件压缩案例');
  let driver = Driver.create();

  /**
   * 主要功能：点击压缩按钮
   * 关联用例：点击压缩按钮，压缩结果标题下出现被压缩后的zip文件名
   * 执行步骤：
   * 1. 点击压缩按钮
   * 2. 查找被压缩后的zip文件名是否出现
   */
  it(CASE, 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言判断压缩按钮是否存在
    await driver.assertComponentExist(ON.id('compressButton'));
    const compressButton = await driver.findComponent(ON.id('compressButton'));
    await compressButton.click();
    await driver.delayMs(1000);
    // 查找被压缩后的zip文件名是否出现
    await driver.assertComponentExist(ON.id('compressZip'));

    done();
  })

  exit('文件压缩案例')
}