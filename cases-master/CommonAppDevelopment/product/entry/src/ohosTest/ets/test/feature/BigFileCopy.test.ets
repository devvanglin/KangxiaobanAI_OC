/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { it, expect } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'BigFileCopy'; // 案例名称
const CASE_NAME: string = '大文件拷贝案例'; // 案例中文名称
const TAG: string = '[bigfilecopy_Test]';

/**
 * 【大文件拷贝案例】自动化测试用例
 * 1. 进入页面点击Start Copy按钮。
 * 2. 等待复制大文件完成后点击Preview按钮预览。
 * 3. 点击Reset按钮重置。
 */

export default function bigFileCopyTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1. 进入页面点击Start Copy按钮。
   * 2. 等待复制大文件完成后点击Preview按钮预览。
   * 3. 点击Reset按钮重置。
   */
  it(CASE + '验证大文件拷贝', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}bigfile copy begin`);
    await driver.assertComponentExist(ON.text('当前复制进度：0%'));
    await driver.assertComponentExist(ON.text('Start Copy'));
    const startButton: Component = await driver.findComponent(ON.text('Start Copy'));
    await startButton.click();
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.text('当前复制进度：100%'));
    await driver.assertComponentExist(ON.text('Preview'));
    const previewButton: Component = await driver.findComponent(ON.text('Preview'));
    await previewButton.click();
    await driver.delayMs(1000);
    const imageSrc: string = JSON.parse(getInspectorByKey('bigFileImage'))?.$attrs.rawSrc;
    expect(imageSrc === 'file:///data/storage/el2/base/haps/entry/files/bigfilecopy_test.jpg').assertEqual(true);
    await driver.assertComponentExist(ON.text('Reset'));
    const resetButton: Component = await driver.findComponent(ON.text('Reset'));
    await resetButton.click();
    await driver.delayMs(1500);
    await driver.assertComponentExist(ON.text('当前复制进度：0%'));
    done();
  })

  exit(CASE_NAME);
}