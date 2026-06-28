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

import { Driver, ON } from '@ohos.UiTest';
import { it } from '@ohos/hypium';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'ContainerNestedSlide';
const TAG: string = '[ContainerNestedSlide_Test]';
const inputMsg: string = '足球加油'; // 需要评论的内容
const inputMsg2: string = '足球加油啊'; // 需要评论的内容

/**
 * 【Scroll容器嵌套多种组件事件处理案例】自动化测试用例
 * 主要功能：（本案例需联网）
 * 1. 页面由父Scroll统一派发偏移量给子组件，从页面顶部使用手势下划滚动直到页面底部，无明显卡顿。
 * 2. 页面由父Scroll统一派发偏移量给子组件，从页面底部使用手势上划滚动直到页面顶部，无明显卡顿。
 * 3. 在案例底部的输入框输入评论内容，评论内容会出现在评论顶的最新一条。
 * 4. 可以在已有评论中，回复他的评论。
 * 执行步骤：
 * 1. 断言存在父容器Scroll，滑动页面从顶部向下滚动到页面底部，断言可以找到最后一条评论内容(即已滑到页面底部)。（是否卡顿需要依赖手工测试用例）
 * 2. 在页面底部向上滚动到页面顶部，断言可以找到新闻标题（即已滑到页面顶部）。（是否卡顿需要依赖手工测试用例）
 * 3. 断言底部存在"发布评论"输入框，输入内容，点击发布按钮，断言新增评论在评论顶最新一条出现。
 * 4. 断言存在某一条评论，评论后，评论内容出现在页面中。
 */
export default function containerNestedSlideTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('Scroll容器嵌套多种组件事件处理案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、进入页面，滑动页面到底部，断言可以滑动到底。
   * 2、在页面底部时，滑动页面到顶部，断言可以滑动到顶。
   **/
  it('验证Scroll的统一派发给子组件偏移量功能', 0, async (done: Function) => {
    await driver.delayMs(5000);
    // 断言存在Scroll父容器
    await driver.assertComponentExist(ON.id('scrollContainer'));
    let scrollBar = await driver.findComponent(ON.type('Scroll'));
    await scrollBar.scrollToBottom(5000); // 控件上滑到底部
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.text('国足必胜，加油加油。')); // 断言页面下划到评论列表底部
    await driver.delayMs(1000);
    await scrollBar.scrollToTop(5000); // 控件上滑动到顶部
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('直播吧')); // 断言页面滑到标题顶部
    done();
  })

  /**
   * 执行步骤：
   * 1、断言底部存在"发布评论"输入框，输入内容.
   * 2、点击发布按钮，断言新增评论在评论顶最新一条出现。
   * 3、点击一条已有评论，点击"回复"。
   * 4、断言评论的文字成功显示，即回复评论成功。
   **/
  it('验证评论功能', 0, async (done: Function) => {
    await driver.delayMs(3000);
    // 断言存在底部评论输入框
    await driver.assertComponentExist(ON.id('publishComment'));
    let inputComponent = await driver.findComponent(ON.text('发布评论'));
    await inputComponent.click();
    await driver.delayMs(1000);
    // 断言拉起了评论输入框
    await driver.assertComponentExist(ON.id('id_text_input'));
    let inputContentComponent = await driver.findComponent(ON.id('id_text_input'));
    // 输入评论内容
    await inputContentComponent.inputText(inputMsg);
    await driver.delayMs(500);
    // 断言存在发布按钮
    await driver.assertComponentExist(ON.text('发布'));
    let publishComponent = await driver.findComponent(ON.text('发布'));
    await publishComponent.click();
    await driver.delayMs(500);
    // 向下滑动Scroll，断言找到刚刚新增的评论内容
    let scrollBar = await driver.findComponent(ON.type('Scroll'));
    // 获取scroll的所占区域的中心点信息。
    let rect = await scrollBar.getBoundsCenter();
    logger.info(TAG, CASE, JSON.stringify(rect));
    // 在指定坐标点注入鼠标滚轮滑动动作，滚轮向下滑动，鼠标滚轮滚动的10格，每格对应目标点位移120个像素点。
    await driver.mouseScroll({ x: rect.x, y: rect.y }, true, 10);
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text(inputMsg));

    // 验证可以回复任一评论功能
    await driver.delayMs(1000);
    // 断言存在某一评论，并点击回复。
    let replyCommentComponent = await driver.findComponent(ON.text('回复 >'));
    await replyCommentComponent.click();
    await driver.delayMs(500);
    // 断言存在底部评论输入框
    await driver.assertComponentExist(ON.id('id_text_input'));
    let inputContentComponent1 = await driver.findComponent(ON.id('id_text_input'));
    await inputContentComponent1.inputText(inputMsg2); // 输入评论内容
    await driver.delayMs(500);
    // 断言存在发布按钮
    await driver.assertComponentExist(ON.text('发布'));
    let publishComponent1 = await driver.findComponent(ON.text('发布'));
    await publishComponent1.click(); // 发布
    // 断言成功评论了新发布的评论
    await driver.assertComponentExist(ON.text(inputMsg2));
    await driver.delayMs(1000);
    done();
  })

  exit('Scroll容器嵌套多种组件事件处理案例');
}
