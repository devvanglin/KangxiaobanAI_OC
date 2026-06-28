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

const CASE: string = 'ImageEnableAnalyzer';
const TAG: string = '[ImageEnableAnalyzer_Test]';

/**
 * 【图片拖拽AI抠图案例】自动化测试用例
 * 主要功能：
 * 1. 本案例只能实现长按需要被AI抠图的图片里的元素并可以拖拽。(长按后能否抠图成功需手工用例进行测试)
 * 执行步骤：
 * 1. 断言是否存在图片，需要对图片中的元素进行拖拽AI抠图。
 * 2. 找到图片里的元素，长按被抠图的元素，可以拖拽。(长按后能否抠图成功需手工用例进行测试)
 */
export default function imageEnableAnalyzerTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('图片拖拽AI抠图案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、断言是否存在图片，需要对图片中的元素进行拖拽AI抠图。
   * 2、选中拖拽被抠元素的某一坐标并拖拽。（长按后能否抠图成功需手工用例进行测试）
   **/
  it('验证图片可以拖拽需要AI抠图的元素', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在需要抠图的图片组件
    await driver.assertComponentExist(ON.id('imageAnalyze'));
    let imageAnalyzeComponent = await driver.findComponent(ON.id('imageAnalyze'));
    // 拿到需要抠图的元素上的坐标
    let rect = await imageAnalyzeComponent.getBoundsCenter();
    logger.info(TAG, CASE, JSON.stringify(rect));
    // 以被抠元素上的某一坐标作为起始坐标点拖拽至目的坐标点。
    const position = await driver.mouseDrag({ x: rect.x, y: rect.y }, { x: rect.x + 100, y: rect.y - 50 }, 600);
    logger.info(TAG, JSON.stringify(position));
    await driver.delayMs(500);
    await driver.pressBack(); // 首次退出中转站模式
    await driver.delayMs(1000);

    done();
  })

  exit('图片拖拽AI抠图'); // 退出案例
}
