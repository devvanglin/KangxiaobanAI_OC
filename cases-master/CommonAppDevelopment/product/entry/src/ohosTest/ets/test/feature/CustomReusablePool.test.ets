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

const CASE: string = 'CustomReusablePool'; // 案例名称
const TAG: string = '[CustomReusablePool_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟
const ITEM_NAME_TEXT: string[] = ['首页', '风景', '商品', '旅游', '头像'];

/**
 * 【全局自定义组件复用实现案例】自动化测试用例
 */
export default async function customReusablePoolTest() {

  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('全局自定义组件复用实现案例');

  const driver = Driver.create();
  /**
   * 查看案例页面列表是否存在，其中的item是否正常显示
   */
  it(CASE + '查看案例页面是否正常显示', 0, async (done: Function) => {
    // 判断标题列表是否存在
    await driver.assertComponentExist(ON.id('id_custom_reusable_pool_title_list'));
    // 判断最外层Swiper是否存在
    await driver.assertComponentExist(ON.id('id_custom_reusable_pool_main_swiper'));
    // 循环判断标题列表中每个item是否存在
    for (let index = 0; index < ITEM_NAME_TEXT.length; index++) {
      await driver.assertComponentExist(ON.text(ITEM_NAME_TEXT[index]));
    }
    // 判断Swiper首页的banner是否存在
    await driver.assertComponentExist(ON.id('id_custom_reusable_pool_banner'));
    // 判断Swiper首页的列表是否存在
    await driver.assertComponentExist(ON.id('id_custom_reusable_pool_list'));
    logger.info(TAG, `${CASE} end`);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 点击标题，查看页面是否正常显示
   */
  it(CASE + '查看每个子页面是否正常显示', 0, async (done: Function) => {
    await driver.delayMs(DELAY_MS);
    // 循环判断标题列表中每个item是否存在
    for (let index = 0; index < ITEM_NAME_TEXT.length; index++) {
      await (await driver.findComponent(ON.text(ITEM_NAME_TEXT[index]))).click();
      await driver.delayMs(DELAY_MS);
      // 判断Swiper首页的banner是否存在
      await driver.assertComponentExist(ON.id('id_custom_reusable_pool_banner'));
      // 判断Swiper首页的列表是否存在
      await driver.assertComponentExist(ON.id('id_custom_reusable_pool_list'));
    }
    await driver.delayMs(DELAY_MS);
    logger.info(TAG, `${CASE} end`);
    done();
  })

  exit('全局自定义组件复用实现案例');
}