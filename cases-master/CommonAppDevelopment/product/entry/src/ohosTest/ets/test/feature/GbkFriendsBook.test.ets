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
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'GbkTranscoding'; // 案例名称
const CASE_NAME: string = 'GBK文本格式解码'; // 案例中文名称
const TAG: string = '[gbktranscoding_Test]';

/**
 * 【GBK文本格式解码】自动化测试用例
 * 1. 进入页面长按屏幕唤起文字编辑菜单。
 * 2. 验证菜单全选、复制、粘贴、剪切功能正常。
 * 2. 验证菜单是否成功拉起。
 * 3. 点击菜单最右侧按钮打开拓展菜单。
 */
export default function gbkTranscodingTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、进入页面等待网络加载数据。
   * 2、验证中文数据是否无乱码。
   */
  it(CASE + '验证GBK转码', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}GBK List begin`);
    await driver.delayMs(4000);
    await driver.assertComponentExist(ON.text('为谁烹过茶'));
    done();
  })

  // 退出案例页面
  exit(CASE_NAME);
}