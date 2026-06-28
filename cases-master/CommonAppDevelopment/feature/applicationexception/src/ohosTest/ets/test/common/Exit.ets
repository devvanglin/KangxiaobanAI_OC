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

import { Driver, ON } from '@ohos.UiTest';
import { it } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = '[ApplicationException_Test]';

/**
 * 退出应用异常页面公共测试用例
 * @param CaseName 测试用例名称
 */
export default function exit(CaseName: string) {
  it(CaseName + '_Exit', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CaseName}_Exit begin`);
    let driver = Driver.create();
    // 退出页面
    await driver.pressBack();
    await driver.delayMs(1000);
    // 断言回到瀑布流页面
    await driver.assertComponentExist(ON.type('Search'));
    hilog.info(0x0000, TAG, `${CaseName}_Exit end`);
    done();
  });
}
