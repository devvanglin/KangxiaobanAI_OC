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
import { Component, Driver, ON } from "@kit.TestKit";
import { logger } from "utils";
import { it } from "@ohos/hypium";
import exit from "../common/Exit.test";

const CASE: string = 'WebPageSnapShot'; // 案例名称
const CASE_NAME: string = '页面长截图'; // 案例名称
const TAG: string = '[WebPageSnapShot_Test]';

/**
 * 【页面长截图】自动化测试用例，测试步骤如下
 * 1. 网页长截图。
 * 2. 保存截图到相册。
 */
export default function webPageSnapShotTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 网页长截图
  webPageShotCases(driver);

  // 保存截图到相册
  saveWebShotCases(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"网页长截图"
 * @param { Driver } driver
 */
function webPageShotCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 判断"Web页面长截图"按钮是否存在。
   * 2. 点击"Web页面长截图"按钮。
   * 3. 判断Web页面显示是否正常。
   * 4. 点击"截图"按钮。
   * 5. 判断预览框是否打开。
   * 6. 点击截图预览框。
   * 7. 上下滑动预览框图片。
   */
  it('网页长截图', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_网页长截图 begin`);

    // 判断"Web页面长截图"按钮是否存在
    await driver.assertComponentExist(ON.id('web_page_snap_shot_web_page'));

    // 获取"Web页面长截图"按钮
    const webShotComponent: Component = await driver.findComponent(ON.id('web_page_snap_shot_web_page'));

    // 点击"Web页面长截图"按钮
    await webShotComponent.click();
    await driver.delayMs(4000);

    // 判断"Web组件长截图"文本是否存在
    await driver.assertComponentExist(ON.text('Web组件长截图'));

    // 判断"截图"按钮是否存在
    await driver.assertComponentExist(ON.id('web_page_snap_shot_web_page_shot'));

    // 获取"截图"按钮
    const shotComponent: Component = await driver.findComponent(ON.id('web_page_snap_shot_web_page_shot'));

    // 点击"截图"按钮
    await shotComponent.click();
    await driver.delayMs(4000);

    // 判断预览框是否打开
    await driver.assertComponentExist(ON.id('web_page_snap_shot_preview_component'));

    // 获取预览框组建
    const previewComponent: Component = await driver.findComponent(ON.id('web_page_snap_shot_preview_component'));

    // 点击预览框
    await previewComponent.click();
    await driver.delayMs(1000);

    // 获取预览框中心位置
    const point = await previewComponent.getBoundsCenter();

    // 向上滑动预览框
    await driver.swipe(point.x, point.y, point.x, point.y + 100);

    // 向下滑动预览框
    await driver.swipe(point.x, point.y, point.x, point.y - 100);

    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_网页长截图 end`);

    done();
  })
}

/**
 * 用例关联"保存截图到相册"
 * @param { Driver } driver
 */
function saveWebShotCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 判断"保存图片"按钮是否存在。
   * 2. 点击"保存图片"按钮。
   * 3. 拉起图库应用，判断图库中是否存在保存图片。
   */
  it('保存截图到相册', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_保存截图到相册 begin`);

    // 获取"保存图片"按钮
    const buttonComponent: Component = await driver.findComponent(ON.text('保存图片'));

    if (buttonComponent) {
      // 点击"保存图片"按钮，若可获取保存按钮，点击后即可关闭预览框
      await buttonComponent.click();
      await driver.delayMs(1000);

      // 获取安全弹窗"允许"按钮
      const allowComponent: Component = await driver.findComponent(ON.text('允许'));
      if (allowComponent !== null && allowComponent !== undefined) {
        // 点击"允许"按钮，若可获取保存按钮，点击后即可关闭预览框
        await allowComponent!.click();
        await driver.delayMs(1000);
      }
    } else {
      // 若无法获取按钮，需要通过返回功能关闭预览框
      await driver.pressBack();
      await driver.delayMs(1000);
    }

    // 返回页面长截图案例主页
    await driver.pressBack();
    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_保存截图到相册 end`);

    done();
  })
}