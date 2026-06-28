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

import { expect, it } from '@ohos/hypium';
import { emitter } from '@kit.BasicServicesKit';
import { Driver, ON } from '@ohos.UiTest';
import { MouseButton } from '@kit.TestKit';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';

const inputMsg: string = '是棉的吗'; // 需要评论的内容
const inputMsg2: string = '我是一条单独的评论'; // 需要评论的内容

/**
 * 【textOverflow长文本省略案例】自动化测试用例
 * 主要功能：
 * 1. 在案例底部的输入框输入评论内容，评论内容会出现在评论顶的最新一条。
 * 2. 可以在已有评论中，回复他的评论。
 * 3. 断言回复后新增的那条子回复的回复人名字那行，展示样式为xxx＞xxx...(被回复人的名字过长有省略号)(本用例仅能判断回复人的名字是否正确，省略功能需要依赖手工用例验证)
 * 执行步骤：
 * 1. 断言存在某一条评论，点击回复按钮，断言底部存在"发布商品评价"输入框，输入内容点击发布按钮，断言新增评论的被回复人名字回显正确。
 * 2. 评论后，评论内容出现在页面中。
 * 3. 断言字被回复人名字的样式，是否为省略格式。
 */
export default function textOverflowTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('textOverflow长文本省略');
  const driver = Driver.create();

  let userId1:string = 'none';
  let userId2:string = '';

  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    userId1 = data.data?.newId1;
    userId2 = data.data?.newId12;
  })

  /**
   * 执行步骤：
   * 1. 断言存在某一条评论，点击回复按钮，断言底部存在"发布商品评价"输入框。
   * 2. 输入内容点击发布按钮，断言新增评论的被回复人回显名字正确。
   **/
  it('验证被回复人名称是否回显正确', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 选择首条评论，点击回复。
    await driver.mouseClick({ x: 580, y: 610 }, MouseButton.MOUSE_BUTTON_LEFT);
    await driver.delayMs(500);
    // 断言存在底部评论输入框
    await driver.assertComponentExist(ON.id('id_text_input'));
    let inputContentComponent1 = await driver.findComponent(ON.id('id_text_input'));
    await inputContentComponent1.inputText(inputMsg); // 输入评论内容
    await driver.delayMs(500);
    // 断言存在发布按钮
    await driver.assertComponentExist(ON.text('发布'));
    let publishComponent1 = await driver.findComponent(ON.text('发布'));
    await publishComponent1.click(); // 点击发布
    // 断言成功评论且被回复人的名字回显正确(本用例仅能判断被回复人的名字回显是否正确，textOverflow省略功能需要依赖手工用例验证)
    const textOverflow = await (await driver.findComponent(ON.isAfter(ON.id('reply')).type('Text'))).getText();
    await expect(textOverflow).assertEqual('你若安好便是晴天');
    await driver.delayMs(1000);
    done();
  })

  /**
   * 执行步骤：
   * 1、断言底部存在"发布评论"输入框，输入内容.
   * 2、点击发布按钮，断言新增评论在评论顶最新一条出现。
   **/
  it('验证评论置顶功能', 0, async (done: Function) => {
    await driver.delayMs(3000);
    // 断言存在底部评论输入框
    await driver.assertComponentExist(ON.id('inputComment'));
    let inputComponent = await driver.findComponent(ON.text('发表商品评价'));
    await inputComponent.click();
    await driver.delayMs(1000);
    // 断言拉起了评论输入框
    await driver.assertComponentExist(ON.id('id_text_input'));
    let inputContentComponent = await driver.findComponent(ON.id('id_text_input'));
    // 输入评论内容
    await inputContentComponent.inputText(inputMsg2);
    await driver.delayMs(500);
    // 断言存在发布按钮
    await driver.assertComponentExist(ON.text('发布'));
    let publishComponent = await driver.findComponent(ON.text('发布'));
    await publishComponent.click();
    await driver.delayMs(500);
    await expect(userId1).assertEqual(userId2); // 断言新增的单独评论的id等于唯一的uuid
    await driver.delayMs(500);
    done();
  })

  exit('textOverflow长文本省略');
}
