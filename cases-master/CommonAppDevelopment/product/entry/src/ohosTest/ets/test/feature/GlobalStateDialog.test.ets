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

const CASE: string = 'GlobalStateDialog'; // 案例名称
const CASE_NAME: string = '短视频切换';

/**
 * 【全局状态保留能力弹窗】自动化测试用例
 */
export default function globalStateDialogTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  /**
   * 点击评论按钮打开评论列表
   */
  it(CASE + "open_comment", 0, async (done: Function) => {
    // 点击评论按钮
    let commentButton = await driver.findComponent(ON.id('comment_button'));
    await commentButton.click();
    await driver.delayMs(1000);
    // 断言：需存在id为‘comment_list’的组件
    await driver.assertComponentExist(ON.id('comment_list'));

    done();
  })

  /**
   * 向上滑动评论列表
   */
  it(CASE + "scroll_comment_list", 0, async (done: Function) => {
    let scrollerInComment = await driver.findComponent(ON.id('comment_list'));
    await scrollerInComment.scrollToBottom(40000);
    await driver.delayMs(500);
    // 断言：需存在id为‘close_global_state_dialog’的组件
    await driver.assertComponentExist(ON.id('close_global_state_dialog'));
    // 断言：需存评论列表尾项组件
    await driver.assertComponentExist(ON.text('精灵球收七龙珠99'));

    done();
  })

  /**
   * 关闭评论列表
   */
  it(CASE + "close_comment", 0, async (done: Function) => {
    let closeButton = await driver.findComponent(ON.id('close_global_state_dialog'));
    await closeButton.click();
    await driver.delayMs(1000);
    // 断言：需存在id为‘comment_button’的组件
    await driver.assertComponentExist(ON.id('comment_button'));

    done();
  })

  /**
   * 再次点击评论按钮打开评论列表且恢复至关闭前浏览的位置
   */
  it(CASE + "open_comment_again", 0, async (done: Function) => {
    // 点击评论按钮
    let commentButton = await driver.findComponent(ON.id("comment_button"));
    await commentButton.click();
    await driver.delayMs(1000);
    // 断言：需存在id为‘close_global_state_dialog’的组件
    await driver.assertComponentExist(ON.id('close_global_state_dialog'));
    // 断言：需存评论列表尾项组件
    await driver.assertComponentExist(ON.text('精灵球收七龙珠99'));

    // 关闭评论列表
    let closeButton = await driver.findComponent(ON.id('close_global_state_dialog'));
    await closeButton.click();
    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })

  exit(CASE_NAME);
}