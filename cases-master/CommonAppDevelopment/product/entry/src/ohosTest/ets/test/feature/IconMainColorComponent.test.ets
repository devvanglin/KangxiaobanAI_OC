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

import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Driver, ON } from '@ohos.UiTest';
import { it } from "@ohos/hypium";
import { logger } from "utils";
import exit from "../common/Exit.test";

const CASE: string = 'IconMainColor'; // 案例名称
const TAG: string = '[IconMainColor_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟
const ITEM_NAME_TEXT: string[] = ['云空间', '邮箱', '运动健康', 'WifiLink', '商城'];

/**
 * 【根据icon自适应背景颜色】自动化测试用例
 */
export default async function iconMainColorComponentTest() {

  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('根据icon自适应背景颜色');

  const driver = Driver.create();
  /**
   * 查看案例页面列表是否存在，其中的item是否正常显示
   */
  it(CASE + '根据icon自适应背景颜色', 0, async (done: Function) => {
    // 判断是否存在列表
    await driver.assertComponentExist(ON.id('icon_main_color_list'));
    await driver.delayMs(DELAY_MS);
    // 循环判断列表中每个item是否存在
    for (let index = 0; index < ITEM_NAME_TEXT.length; index++) {
      await driver.assertComponentExist(ON.text(ITEM_NAME_TEXT[index]));
    }
    await driver.delayMs(DELAY_MS);
    logger.info(TAG, `${CASE} end`);

    done();
  })

  exit('根据icon自适应背景颜色');
}