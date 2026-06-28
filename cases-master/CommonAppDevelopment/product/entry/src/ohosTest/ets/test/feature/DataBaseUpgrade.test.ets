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

const CASE: string = 'DatabaseUpgrade'; // 案例名称
const CASE_NAME: string = '数据库版本升级案例';

/**
 * 【数据库版本升级案例】自动化测试用例
 */
export default function databaseUpgradeTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 点击版本升级下的“升级至V2”按钮，数据库版本会从V1升级至V2，且在表格处显示V1和V2版本字段对比
   */
  it(CASE + '_V1_upgrade_to_V2', 0, async (done: Function) => {
    let upgradeToV2 = await driver.findComponent(ON.text('升级至V2'));
    // 点击升级至V2按钮
    await upgradeToV2.click();
    await driver.delayMs(200);
    // 断言，升级至V2时，'回退至V2'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V2').enabled(false));
    // 断言，升级至V2时，'升级至V2'按钮不可点击
    await driver.assertComponentExist(ON.text('升级至V2').enabled(false));

    done();
  })

  /**
   * 点击版本升级下的“升级至V3”按钮，数据库版本会从V2升级至V3，且在表格处显示V2和V3版本字段对比
   */
  it(CASE + '_V2_upgrade_to_V3', 0, async (done: Function) => {
    let upgradeToV3 = await driver.findComponent(ON.text('升级至V3'));
    // 点击升级至V3按钮
    await upgradeToV3.click();
    await driver.delayMs(200);
    // 断言，升级至V3时，'升级至V3'按钮不可点击
    await driver.assertComponentExist(ON.text('升级至V3').enabled(false));
    // 断言，升级至V3时，'升级至V2'按钮不可点击
    await driver.assertComponentExist(ON.text('升级至V2').enabled(false));

    done();
  })

  /**
   * 点击版本回退下的“回退到V2”按钮，数据库版本会从V3回退至V2，且在表格处显示V1和V2版本字段对比
   */
  it(CASE + '_V3_reverse_to_V2', 0, async (done: Function) => {
    let reverseToV2 = await driver.findComponent(ON.text('回退到V2'));
    // 点击回退到V2按钮
    await reverseToV2.click();
    await driver.delayMs(200);
    // 断言，回退到V2，'回退至V2'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V2').enabled(false));
    // 断言，回退到V2，'升级至V2'按钮不可点击
    await driver.assertComponentExist(ON.text('升级至V2').enabled(false));

    done();
  })

  /**
   * 点击版本回退下的“回退到V1”按钮，数据库版本会从V2回退至V1，且在表格处只显示V1版本字段
   */
  it(CASE + '_V2_reverse_to_V1', 0, async (done: Function) => {
    let reverseToV1 = await driver.findComponent(ON.text('回退到V1'));
    // 点击回退到V1按钮
    await reverseToV1.click();
    await driver.delayMs(200);

    // 断言，回退到V1，'回退至V1'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V1').enabled(false));
    // 断言，回退到V1，'回退到V2'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V2').enabled(false));

    done();
  })

  /**
   * 点击版本升级下的“升级至V3”按钮，数据库版本会从V1升级至V3，且在表格处显示V1和V3版本字段对比
   */
  it(CASE + '_V1_upgrade_to_V3', 0, async (done: Function) => {
    let upgradeToV3 = await driver.findComponent(ON.text('升级至V3'));
    // 点击升级至V3按钮
    await upgradeToV3.click();
    await driver.delayMs(200);
    // 断言，V1跨版本升级至V3，'升级至V2'按钮不可点击
    await driver.assertComponentExist(ON.text('升级至V2').enabled(false));
    // 断言，V1跨版本升级至V3，'升级至V3'按钮不可点击
    await driver.assertComponentExist(ON.text('升级至V3').enabled(false));
    // 断言，V1跨版本升级至V3，'回退到V2'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V2').enabled(false));

    done();
  })

  /**
   * 点击版本回退下的“回退到V1”按钮，数据库版本会从V3回退至V1，且在表格处只显示V1版本字段
   */
  it(CASE + '_V3_reverse_to_V1', 0, async (done: Function) => {
    let reverseToV1 = await driver.findComponent(ON.text('回退到V1'));
    // 点击回退到V1按钮
    await reverseToV1.click();
    await driver.delayMs(200);
    // 断言，回退到V1，'回退至V1'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V1').enabled(false));
    // 断言，回退到V1，'回退到V2'按钮不可点击
    await driver.assertComponentExist(ON.text('回退到V2').enabled(false));

    done();
  })

  exit(CASE_NAME);
}