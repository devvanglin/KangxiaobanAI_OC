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
import { Driver, ON, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'pendingitems'; // 案例名称

/**
 * 【列表编辑】自动化测试用例
 * 1. 新增代办活动
 * 2、勾选完成活动
 * 3. 编辑代办活动
 * 4. 删除代办活动
 */
export default function pendingItemsTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('列表编辑');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 启动【列表编辑案例】
   * 点击新增按钮
   * 选择任一项后点击确认按钮
   * 通过页面列表中出现刚刚选择的项目名称喝未完成事项来验证
   **/
  it(CASE + '新增代办活动', 0, async (done: Function) => {
    const addItem = await driver.findComponent(ON.id('add_items'));
    await addItem.click();
    await driver.delayMs(1000);
    const confirm = await driver.findComponent(ON.text('确定'));
    await confirm.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('未完成'));
    await driver.assertComponentExist(ON.text('读书')); // 通过页面列表中出现刚刚选择的项目名称喝未完成事项来验证
    done();
  })

  /**
   * 执行步骤：
   * 启动【列表编辑案例】
   * 点击任务签的选择框
   * 通过该任务归纳到已完成列表中来验证
   **/
  it(CASE + '勾选完成活动', 0, async (done: Function) => {
    const choose = await driver.findComponent(ON.id('choose_border'));
    await choose.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('已完成')); // 通过该任务归纳到已完成列表中来验证
    done();
  })

  /**
   * 执行步骤：
   * 启动【列表编辑案例】
   * 点击任务右侧编辑按钮
   * 修改后后点击右侧√
   * 通过列表中存在修改过后的任务来验证
   **/
  it(CASE + '编辑代办活动', 0, async (done: Function) => {
    const editText = await driver.findComponent(ON.text('编辑'));
    await editText.click();
    await driver.delayMs(1000);
    const textInput = await driver.findComponent(ON.type('TextInput'));
    await textInput.inputText('开卷有益');
    const editComplete = await driver.findComponent(ON.id('edit_complete'));
    await editComplete.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('开卷有益')); // 通过列表中存在修改过后的任务来验证
    done();
  })

  /**
   * 执行步骤：
   * 启动【列表编辑案例】
   * 左滑已完成活动，点击删除。通过弹出'删除成功'提示来验证
   **/
  it(CASE + '删除代办活动(已完成事项)', 0, async (done: Function) => {
    await driver.drag(630, 941, 30, 941);
    await driver.delayMs(1000);
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let toast = '删除成功';
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual(toast); // 通过弹出'删除成功'提示来验证
    };
    observer.once('toastShow', callback);
    const deleteImage = await driver.findComponent(ON.id('delete_item'));
    await deleteImage.click();
    done();
  })


  /**
   * 执行步骤：
   * 启动【列表编辑案例】
   * 左滑未完成活动，点击删除。通过弹出'删除成功'提示来验证。
   **/
  it(CASE + '删除代办活动(未完成事项)', 0, async (done: Function) => {
    const addItem = await driver.findComponent(ON.id('add_items'));
    await addItem.click();
    await driver.delayMs(300);
    const confirm = await driver.findComponent(ON.text('确定'));
    await confirm.click();
    await driver.delayMs(300);
    await driver.drag(630, 941, 30, 941);
    await driver.delayMs(500);
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let toast = '删除成功';
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual(toast); // 通过弹出'删除成功'提示来验证
    };
    observer.once('toastShow', callback);
    const deleteImage = await driver.findComponent(ON.id('delete_item'));
    await deleteImage.click();
    done();
  })

  // 退出案例
  exit('列表编辑');
}