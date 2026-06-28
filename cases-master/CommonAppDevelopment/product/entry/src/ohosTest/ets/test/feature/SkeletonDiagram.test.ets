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

const CASE: string = 'SkeletonDiagram'; // 案例名称
const CASE_NAME: string = '骨架屏实现案例'; // 案例中文名称

/**
 * 【骨架屏实现案例】自动化测试用例
 * 1. 进入案例接口加载数据并刷新列表
 * 2. 向上滑动列表
 */
export default function skeletonDiagramTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 骨架屏实现案例只能断言页面加载后的列表是否正常滚动和展示（骨架屏加载动画需手工用例进行测试）
   */
  it(CASE, 0, async (done: Function) => {
    let driver = Driver.create();

    await driver.delayMs(4000); // 留网络加载耗时
    const skeletonDiagram = await driver.findComponent(ON.id('skeleton_diagram'));
    expect(skeletonDiagram).assertEqual(null); // 断言界面数据加载成功，骨架屏移除

    // 向上滑动
    await driver.assertComponentExist(ON.id('skeleton_list')); // 断言数据列表是否存在
    await driver.swipe(200, 800, 200, 100, 1500);
    await driver.delayMs(1000);
    const isScroll = await (await driver.findComponent(ON.id('skeleton_list'))).isScrollable();
    expect(isScroll).assertEqual(true); // 断言数据列表可滚动

    done();
  })
  // 退出案例
  exit(CASE_NAME);
}