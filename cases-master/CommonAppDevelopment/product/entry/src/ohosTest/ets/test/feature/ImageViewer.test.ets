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
import { Driver, ON } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'imageviewer'; // 案例名称
const CASE_NAME: string = '图片缩放效果实现'; // 案例中文名称

/**
 * 【图片缩放效果实现案例】自动化测试用例
 * 1. 搜索进入【图片缩放效果实现】，双指捏合缩放图片
 * 2. 放大状态下，单指可拖动图片
 * 3. 双击图片进行图片的大小切换
 */
export default function imageViewerTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 双指捏合缩放图片
   * 通过图片顶部位置来判断是否缩放
   */
  it(CASE + '双指捏合缩放图片', 0, async (done: Function) => {
    const image = await driver.findComponent(ON.id('scale_image'));
    const beforeTop = (await image.getBounds()).top;
    await image.pinchOut(1.1);
    const afterTop = (await image.getBounds()).top;
    await expect(afterTop < beforeTop).assertEqual(true); // 通过图片顶部位置来判断
    await driver.delayMs(500);
    done();
  })

  /**
   * 放大状态下，单指可拖动图片
   */
  it(CASE + '单指拖动图片', 0, async (done: Function) => {
    const image = await driver.findComponent(ON.id('scale_image'));
    const beforeBottom = (await image.getBounds()).bottom;
    await driver.swipe(600, 1427, 600, 400);
    const afterBottom = (await image.getBounds()).bottom;
    await expect(afterBottom < beforeBottom).assertEqual(true); // 通过图片中部位置来判断是否拖动
    await driver.delayMs(500);
    done();
  })

  /**
   * 双击图片进行图片的大小切换
   */
  it(CASE + '双击图片大小切换', 0, async (done: Function) => {
    const image = await driver.findComponent(ON.id('scale_image'));
    const beforeTop = (await image.getBounds()).top;
    await image.doubleClick();
    const afterTop = (await image.getBounds()).top;
    await expect(afterTop > beforeTop).assertEqual(true); // 通过图片中部位置来判断图片大小是否改变
    await driver.delayMs(500);
    done();
  })

  // 退出案例
  exit(CASE_NAME);
}