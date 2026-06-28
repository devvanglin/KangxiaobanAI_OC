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

const CASE: string = 'photopickandsave'; // 案例名称
const TAG: string = '[photopickandsave_Test]';

/**
 * 【图片选择和下载保存案例】自动化测试用例
 * 1. 点击'下载保存图片'tab下的'下载'按钮，下载图片到图库。
 * 2. 点击'下载保存图片'tab下的'下载到指定路径'按钮，下载图片到用户选择的路径。
 * 3. 点击'选择图片'tab下的'+'图片，从图库选择相片并展示在页面中。
 * 4. 长按web图片，弹出“是否保存图片”弹窗，点击“保存图片”后，弹出权限获取弹窗，点击允许，保存图片到图库。
 */
export default function photoPickAndSaveTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('图片选择和下载保存案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、点击'下载保存图片'tab下的'下载'按钮
   * 2、点击权限弹窗中的允许
   * 3、通过判断是否弹出‘图片下载到图库成功’弹窗来验证
   **/
  it(CASE + '下载图片到图库', 0, async (done: Function) => {
    const saveButton = await driver.findComponent(ON.text('下载'));
    await saveButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.type('Button').text('允许'));
    await driver.delayMs(500);
    const permission = await driver.findComponent(ON.type('Button').text('允许'));
    if (permission !== null && permission !== undefined) {
      await permission!.click();
      await driver.delayMs(1000);
    }
    await driver.assertComponentExist(ON.text('图片下载成功')); // 通过断言是否弹出‘图片下载到图库成功’弹窗来验证
    await driver.delayMs(500);
    done();
  })

  /**
   * 执行步骤：
   * 1、点击'下载保存图片'tab下的'下载到指定路径'按钮
   * 2、选择列表中第一个位置
   * 3、通过判断是否弹出‘下载保存图片到指定路径成功’弹窗来验证
   **/
  it(CASE + '下载图片到指定路径', 0, async (done: Function) => {
    const downloadButton = await driver.findComponent(ON.text('下载到指定路径'));
    await downloadButton.click();
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('我的手机'));
    const path = await driver.findComponent(ON.text('Download').isAfter(ON.text('我的手机')));
    await driver.click(1147, 240); // 只能测试60pro，使用绝对坐标点
    await driver.delayMs(500);
    await driver.assertComponentExist(ON.text('下载保存图片到指定路径成功')); // 通过断言是否弹出‘下载保存图片到指定路径成功’弹窗来验证
    await driver.delayMs(500);
    done();
  })


  /**
   * 执行步骤：
   * 1、点击'下载保存图片'tab下的'下载到指定路径'按钮
   * 2、选择列表中第一个位置
   * 3、通过判断是否显示出选择的图片来验证
   **/
  it(CASE + '选择图片', 0, async (done: Function) => {
    const tab = await driver.findComponent(ON.text('选择图片'));
    await tab.click();
    await driver.delayMs(1000);
    const add = await driver.findComponent(ON.id('select_photo'));
    await add.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('拍照')); // 通过断言查找文字判断是否拉起 picker
    const photo = await driver.findComponent(ON.text('拍照'));
    await photo.click();
    await driver.delayMs(1000);
    if (await driver.findComponent(ON.text('知道了'))) {
      const allow = await driver.findComponent(ON.text('知道了'));
      await allow.click();
      await driver.delayMs(300);
    }
    await driver.click(630, 2317); // 点击拍照
    await driver.delayMs(1500);
    await driver.click(1045, 2317); // 点击对号
    await driver.delayMs(1000);
    const complete = await driver.findComponent(ON.text('完成'));
    await complete.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('select_photo')); // 通过判断是否显示出选择的图片来判断
    await driver.delayMs(500);
    done();
  })

  /**
   * 执行步骤：
   * 1. 长按web图片
   * 2. 弹出“是否保存图片”弹窗，点击“保存图片”
   * 3. 弹出权限获取弹窗，点击允许
   * 4. 判断是否出现“保存成功”的弹窗
   */
  it(CASE + '从web页面下载图片到图库', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('从web页面下载保存图片'));
    const downloadButton = await driver.findComponent(ON.text('从web页面下载保存图片'));
    await driver.delayMs(1000);

    await downloadButton.click();
    await driver.delayMs(200);
    const webComponent = await driver.findComponent(ON.id('web'));
    await webComponent.longClick();
    await driver.delayMs(2000);

    const saveButton = await driver.findComponent(ON.text('保存图片'));
    await saveButton.click();
    await driver.delayMs(2000);

    const allowButton = await driver.findComponent(ON.text('允许'));
    await allowButton.click();
    await driver.delayMs(1000);
    // 通过断言是否弹出“保存成功”弹窗来验证
    await driver.assertComponentExist(ON.text('保存成功'));

    done();
  })

  // 退出案例
  exit('图片选择和下载保存案例');
}