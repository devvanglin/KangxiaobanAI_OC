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
import { Driver, ON, Component, Point } from '@ohos.UiTest';
import { expect, it } from "@ohos/hypium";
import { logger } from "utils";
import exit from "../common/Exit.test";

const CASE: string = 'IconMainColor'; // 案例名称
const TAG: string = '[IconMainColor_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟
// 案例首页各个组件的ID，用于判断页面中组件是否显示成功
const COMPONENT_ID_LIST: string[] =
  ['id_image_comment_top_image', 'id_image_comment_text_title', 'id_image_comment_list', 'id_image_comment_top_image',
    'id_image_comment_row_publish'];

/**
 * 【发布图片评论】自动化测试用例
 */
export default async function imageCommentComponentTest() {

  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('发布图片评论');

  const driver = Driver.create();
  /**
   * 查看案例页面组件是否正常显示
   */
  it(CASE + '组件正确显示', 0, async (done: Function) => {
    // 根据id查找组件是否存在
    for (let index = 0; index < COMPONENT_ID_LIST.length; index++) {
      await driver.assertComponentExist(ON.id(COMPONENT_ID_LIST[index]));
    }
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('请文明发言'));
    await driver.delayMs(DELAY_MS);
    // 根据id找到List组件，查看是否能正常滑动
    const commentList: Component = await driver.findComponent(ON.id('id_image_comment_list'));
    await driver.delayMs(DELAY_MS);
    await commentList.scrollToBottom();
    await driver.delayMs(DELAY_MS);
    await commentList.scrollToTop();
    logger.info(TAG, `${CASE} end`);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 显示评论输入Dialog
   */
  it(CASE + '显示评论输入Dialog', 0, async (done: Function) => {
    await driver.delayMs(DELAY_MS);
    // 找到输入提示框
    await driver.assertComponentExist(ON.text('请文明发言'));
    await driver.delayMs(DELAY_MS);
    // 点击输入提示框，弹出评论输入Dialog
    const inputHint: Component = await driver.findComponent(ON.text('请文明发言'));
    await driver.delayMs(DELAY_MS);
    await inputHint.click();
    await driver.delayMs(DELAY_MS);
    // 判断Dialog中组件显示是否正常
    await driver.assertComponentExist(ON.id('id_image_comment_text_input'));
    await driver.assertComponentExist(ON.id('id_image_comment_image_camera'));
    await driver.assertComponentExist(ON.id('id_image_comment_text_publish'));
    await driver.delayMs(DELAY_MS);

    logger.info(TAG, `${CASE} end`);
    done();
  })

  /**
   * 拍照，选择图片，然后删除图片
   */
  it(CASE + '拍照并删除图片', 0, async (done: Function) => {
    await driver.delayMs(DELAY_MS);
    // 找到输入框，并输入测试文字
    const input: Component = await driver.findComponent(ON.id('id_image_comment_text_input'));
    await driver.delayMs(DELAY_MS);
    await input.inputText('Test Text')
    await driver.delayMs(DELAY_MS);
    // 找到相机按钮，点击拉起系统相机
    const camera: Component = await driver.findComponent(ON.id('id_image_comment_image_camera'));
    await driver.delayMs(DELAY_MS);
    await camera.click();
    await driver.delayMs(DELAY_MS);
    // 判断是否有安全访问相机提示
    const cameraDialog: Component = await driver.findComponent(ON.text("安全访问相机"));
    await driver.delayMs(DELAY_MS);
    // 如果有安全访问相机提示，则点击“知道了”按钮
    if (cameraDialog) {
      const confirm: Component = await driver.findComponent(ON.text("知道了"));
      await driver.delayMs(DELAY_MS);
      if (confirm) {
        await confirm.click();
        await driver.delayMs(DELAY_MS);
      }
    }
    // 获取屏幕尺寸，点击系统相机中的按钮进行拍照和选择照片
    const screenSize: Point = await driver.getDisplaySize();
    await driver.delayMs(DELAY_MS);
    const width: number = screenSize.x;
    const height: number = screenSize.y;
    await driver.click(width / 2, height - 404);
    await driver.delayMs(DELAY_MS);
    await driver.click(width - 220, height - 404);
    await driver.delayMs(DELAY_MS);
    // 判断是否有图片被选中
    await driver.assertComponentExist(ON.id('id_image_comment_selected_pic'));
    // 判断删除图片按钮是否存在
    await driver.assertComponentExist(ON.id('id_image_comment_delete_pic0'));
    await driver.delayMs(DELAY_MS);
    // 找到删除图片按钮，点击删除选择的图片
    const deleteIcon: Component = await driver.findComponent(ON.id('id_image_comment_delete_pic0'))
    await driver.delayMs(DELAY_MS);
    await deleteIcon.click();
    await driver.delayMs(DELAY_MS);
    expect(await driver.findComponent(ON.id('id_image_comment_selected_pic')) === null);
    await driver.delayMs(DELAY_MS);
    logger.info(TAG, `${CASE} end`);
    done();
  })

  /**
   * 拍照，选择图片，然后发布评论
   */
  it(CASE + '拍照并发布评论', 0, async (done: Function) => {
    await driver.delayMs(DELAY_MS);
    // 找到相机按钮，点击拉起系统相机
    const camera: Component = await driver.findComponent(ON.id('id_image_comment_image_camera'));
    await driver.delayMs(DELAY_MS);
    await camera.click();
    await driver.delayMs(DELAY_MS);
    // 获取屏幕尺寸，点击系统相机中的按钮进行拍照和选择照片
    const screenSize: Point = await driver.getDisplaySize();
    await driver.delayMs(DELAY_MS);
    const width: number = screenSize.x;
    const height: number = screenSize.y;
    await driver.click(width / 2, height - 404);
    await driver.delayMs(DELAY_MS);
    await driver.click(width - 220, height - 404);
    await driver.delayMs(DELAY_MS);
    // 判断是否有图片被选中
    await driver.assertComponentExist(ON.id('id_image_comment_selected_pic'));
    await driver.delayMs(DELAY_MS);
    // 点击发布评论
    const publish: Component = await driver.findComponent(ON.id('id_image_comment_text_publish'));
    await driver.delayMs(DELAY_MS);
    await publish.click();
    await driver.delayMs(DELAY_MS);
    // 查看评论是否发布成功
    await driver.assertComponentExist(ON.text("Test Text"));
    await driver.delayMs(DELAY_MS);
    logger.info(TAG, `${CASE} end`);
    done();
  })

  exit(CASE);
}