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
import { Driver, ON, Component, UIElementInfo, UIEventObserver } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'ListItemOverflow'; // 案例名称
const CASE_NAME: string = '元素超出List区域'; // 案例中文名称
const TAG: string = '[listitemoverflow_Test]';

export default function listItemOverflowTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、向上滑动列表超出区域。
   * 2、点击底部关于列表项。
   */
  it(CASE + '向上滑动列表超出区域', 0, async (done: Function) => {
    logger.info(TAG, `${CASE}listItemOverflow scroll begin`);
    const observer: UIEventObserver = await driver.createUIEventObserver();
    const callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('元素超出List区域案例');
    }
    await driver.swipe(400, 1000, 400, 0, 1000);
    await driver.delayMs(1500);
    await driver.assertComponentExist(ON.text('关于'));
    observer.once('toastShow', callback);
    const aboutMeButton: Component = await driver.findComponent(ON.text('关于'));
    await aboutMeButton.click();


    done();
  })

  exit(CASE_NAME);

}

