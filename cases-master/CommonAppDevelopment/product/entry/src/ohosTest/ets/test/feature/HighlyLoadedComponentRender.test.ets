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
import { Driver, ON, Component } from '@ohos.UiTest';
import { it } from "@ohos/hypium";
import { logger } from "utils";
import exit from "../common/Exit.test";

const CASE: string = 'HighlyLoadedComponentRender'; // 案例名称
const TAG: string = '[HighlyLoadedComponentRender_Test]';
const DELAY_MS_500: number = 500; // 指定500ms的延迟
const DELAY_MS_2000: number = 2000; // 指定2000ms的延迟
const SCROLL_SPEED: number = 20000; // 列表滑动速率，单位：像素点/秒
const ITEM_NAME_TEXT: string[] = ['普通列表数据加载', '通过DisplaySync优化列表数据加载'];

/**
 * 【合理处理高负载组件的渲染文章示例代码】自动化测试用例
 */
export default async function highlyLoadedComponentRenderTest() {

  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('合理处理高负载组件的渲染文章示例代码');

  const driver = Driver.create();
  /**
   * 查看案例页面列表是否存在，其中的item是否正常显示
   */
  it(CASE + '合理处理高负载组件的渲染文章示例代码', 0, async (done: Function) => {

    for (let index = 0; index < ITEM_NAME_TEXT.length; index++) {
      // 判断案例首页按钮是否正常显示
      await driver.assertComponentExist(ON.text(ITEM_NAME_TEXT[index]));
      // 点击首页按钮
      const normalButton: Component = await driver.findComponent(ON.text(ITEM_NAME_TEXT[index]));
      await driver.delayMs(DELAY_MS_500);
      await normalButton.click();
      await driver.delayMs(DELAY_MS_2000);
      // 判断页面组件是否正常显示
      await driver.assertComponentExist(ON.id('id_highly_loaded_component_render_title'));
      await driver.assertComponentExist(ON.id('id_highly_loaded_component_render_list'));
      await driver.delayMs(DELAY_MS_500);
      // 判断列表是否可以正常滑动
      const listComponent: Component = await driver.findComponent(ON.id('id_highly_loaded_component_render_list'));
      await driver.delayMs(DELAY_MS_500);
      // 设置列表滑动速度
      await listComponent.scrollToBottom(SCROLL_SPEED);
      await driver.pressBack();
      await driver.delayMs(1000);
    }
    logger.info(TAG, `${CASE} end`);
    done();
  })

  exit(CASE);
}