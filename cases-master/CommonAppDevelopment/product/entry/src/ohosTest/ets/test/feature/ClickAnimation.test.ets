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

import { Driver, ON } from '@kit.TestKit';
import { expect, it } from '@ohos/hypium';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';

/**
 * 【直播界面双击效果动画实现案例】自动化测试用例
 * 主要功能：使用LazyForEach和transition实现双击或连续快速点击时的图标动画效果，增强用户交互体验。每次用户双击或连续快速点击特定区域时，都会动态显示图标并带有生动的动画效果，如图标放大淡出或向上移动淡出等。
 * 执行步骤：
 * 1. 在点击区域内双击，右下角点赞数加1。
 * 2. 双击后500ms内在点击区域内连续点击5次，点击间隔小于500ms，每次点击，右下角点赞数加1。
 */
export default function clickAnimationTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('直播界面双击效果动画实现案例');

  const driver = Driver.create();
  let likeNumber: number = 0;
  it('验证双击动画', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在点赞数组件
    await driver.assertComponentExist(ON.id('likeNumber'));
    let likeNumberComponent = await driver.findComponent(ON.id('likeNumber'));
    // 双击
    await driver.doubleClick(600, 700);
    await driver.delayMs(100);
    // 断言点击后点赞数的值是否加1
    likeNumber++;
    const text: string = await likeNumberComponent.getText();
    await expect(Number(text)).assertEqual(likeNumber);
    done();
  })

  it('验证连续点击动画', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在点赞数组件
    await driver.assertComponentExist(ON.id('likeNumber'));
    let likeNumberComponent = await driver.findComponent(ON.id('likeNumber'));
    // 连续点击5次，点击间隔大于500ms
    for (let index = 0; index < 5; index++) {
      await driver.click(600 + index * 100, 800 + index * 100);
      await driver.delayMs(500);
      // 断言点击后点赞数不变
      const text: string = await likeNumberComponent.getText();
      await expect(Number(text)).assertEqual(likeNumber);
      await driver.delayMs(100);
    }
    // 连续点击5次，点击间隔小于500ms
    for (let index = 0; index < 5; index++) {
      await driver.click(600 + index * 100, 800 + index * 100);
      await driver.delayMs(100);
      // 断言第一次点击后每次点击点赞数的值是否加1
      if (index > 0) {
        likeNumber++;
        const text: string = await likeNumberComponent.getText();
        await expect(Number(text)).assertEqual(likeNumber);
        await driver.delayMs(100);
      }
    }
    done();
  })

  exit('直播界面双击效果动画实现案例');
}