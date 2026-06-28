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

import { logger } from "utils";
import { it } from "@ohos/hypium";
import { Driver, ON } from '@ohos.UiTest';

const TAG: string = '[Case_Test]';

/**
 * 主要功能：搜索案例并点击进入
 * @param caseName：案例名
 * 执行步骤：
 * 1.点击“搜索”框
 * 2.在搜索框输入需查找的案例名
 * 3.点击搜索按钮，查找案例
 * 4.点击案例进入页面
 */
export default function searchCaseClickIn(CaseName: string) {
  it(CaseName + '_Find', 0, async (done: Function) => {
    logger.info(TAG, `${CaseName} begin`);
    let driver = Driver.create();

    // 点击“搜索”框
    logger.info(TAG, `${CaseName}_Find begin`);
    let search = await driver.findComponent(ON.type('Search'));
    await search.click();
    await driver.delayMs(1000);

    // 在搜索框输入需查找的案例名
    let textInput = await driver.findComponent(ON.type('Search'));
    await textInput.inputText(CaseName);
    await driver.delayMs(1000);

    // 点击搜索按钮，查找案例
    let searchButton = await driver.findComponent(ON.text('搜索'));
    await searchButton.click();
    await driver.delayMs(2000);

    // 点击案例进入页面
    let searchResult = await driver.findComponent(ON.id('itemId'));
    await searchResult.click();
    logger.info(TAG, `${CaseName}_Find click`);
    await driver.delayMs(1000)
    logger.info(TAG, `${CaseName}_Find end`);

    done();
  })
}
