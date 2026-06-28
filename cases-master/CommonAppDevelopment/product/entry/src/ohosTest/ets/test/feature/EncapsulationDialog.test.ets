/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
import { Component, Driver, ON } from '@ohos.UiTest';
import { logger } from "utils";
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = '弹窗封装'; // 案例名称

/**
 * 【弹窗封装案例】自动化测试用例
 * 1、添加文件弹窗
 * 2、筛选文件弹窗
 * 3、文件详情弹窗
 * 4、删除文件弹窗
 */
export default function encapsulationDialogTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE);
  const driver = Driver.create();

  /**
   * 添加文件弹窗
   * 执行步骤：
   * 1、点击左上角“+”按钮
   * 2、输入文件名
   * 3、选择文件类型
   * 4、点击确定按钮
   **/
  it(CASE + '添加文件弹窗', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id("add_file_button"));
    let addButton: Component = await driver.findComponent(ON.id("add_file_button"));
    await addButton.click();
    await driver.delayMs(200);
    let fileName: Component = await driver.findComponent(ON.type("TextInput").isAfter(ON.text("文件名：")));
    await fileName.inputText('test');
    await driver.delayMs(500);
    let select: Component = await driver.findComponent(ON.type("Select"));
    await select.click();
    await driver.delayMs(200);
    let ppt: Component = await driver.findComponent(ON.text("ppt"));
    await ppt.click();
    await driver.delayMs(200);

    let confirm: Component = await driver.findComponent(ON.text("确定"));
    await confirm.click();
    await driver.delayMs(200);

    await driver.assertComponentExist(ON.text("test"));

    done();
  })


  /**
   * 筛选文件弹窗
   * 执行步骤：
   * 1、点击右上角筛选按钮
   * 2、选择image类型
   * 3、点击右上角筛选按钮，清除筛选
   **/
  it(CASE + '筛选文件弹窗', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id("sift_button"));
    let siftButton: Component = await driver.findComponent(ON.id("sift_button"));
    await siftButton.click();
    await driver.delayMs(500);
    let image: Component = await driver.findComponent(ON.text("image"));
    await image.click();
    await driver.delayMs(500);
    let files: Component[] = await driver.findComponents(ON.id("file_name"));
    const total: number = files.length;
    let imageFileNum: number = 0;
    for (let i = 0; i < total; i++) {
      let fileName: string = await files[i].getText();
      if (fileName.indexOf("png") > -1) {
        imageFileNum++;
      }
    }

    expect(total).assertEqual(imageFileNum);

    siftButton = await driver.findComponent(ON.id("sift_button"));
    await siftButton.click();
    await driver.delayMs(500);
    let deleteSift: Component = await driver.findComponent(ON.text("清除筛选"));
    await deleteSift.click();
    await driver.delayMs(500);

    done();
  })

  /**
   * 文件详情弹窗
   * 执行步骤：
   * 1、长按列表项
   * 2、点击详情按钮
   * 3、点击关闭按钮
   **/
  it(CASE + '文件详情弹窗', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text("test"));
    let test: Component = await driver.findComponent(ON.text("test"));
    await test.longClick();
    let info: Component = await driver.findComponent(ON.text("详情"));
    await info.click();
    await driver.delayMs(500);

    await driver.assertComponentExist(ON.id("close_button"));

    let closeButton: Component = await driver.findComponent(ON.id("close_button"));
    await closeButton.click();
    await driver.delayMs(200);

    done();
  })


  /**
   * 删除文件弹窗
   * 执行步骤：
   * 1、长按列表项
   * 2、点击删除按钮
   * 3、点击确定按钮
   **/
  it(CASE + '删除文件弹窗', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text("test"));
    let test: Component = await driver.findComponent(ON.text("test"));
    await test.longClick();
    let info: Component = await driver.findComponent(ON.text("删除"));
    await info.click();
    await driver.delayMs(500);

    let deleteButton: Component = await driver.findComponent(ON.text("确定"));
    await deleteButton.click();
    await driver.delayMs(200);

    test = await driver.findComponent(ON.text("test"));
    expect(test).assertNull();

    done();
  })

  // 退出案例
  exit(CASE);

}