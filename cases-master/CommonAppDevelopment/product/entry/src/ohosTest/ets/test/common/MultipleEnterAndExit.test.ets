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

import { it } from "@ohos/hypium";
import searchCaseClickIn from "./SearchCaseClickIn.test";
import { Driver } from '@ohos.UiTest';

/**
 * 主要功能：多次搜索案例并点击进入
 * @param caseName：案例名
 * @param count：退出进入案例次数
 */
export default function multipleEnterAndExit(caseName: string, count: number) {
  let driver = Driver.create();
  it(caseName + '_MultipleFind', 0, async (done: Function) => {
    for (let index = 0; index < count; index++) {
      searchCaseClickIn(caseName);

      // 退出页面
      await driver.pressBack();
      await driver.delayMs(1000);
    }
    done()
  })
}
