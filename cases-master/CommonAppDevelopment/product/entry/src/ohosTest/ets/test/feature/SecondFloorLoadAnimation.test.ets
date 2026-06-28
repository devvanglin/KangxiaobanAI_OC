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

const CASE: string = 'SecondFloorLoadAnimation'; // 案例名称
const CASE_NANE: string = '首页下拉进入二楼效果案例'; // 案例中文名称

/**
 * 【首页下拉进入二楼效果案例】自动化测试用例
 * 1. 进入案例检查页面是否正常
 * 2. 下拉距离小于200vp，显示加载动画
 * 3. 下拉距离大于200vp，显示二楼页面
 * 4. 二楼页面向上滑动（小于150vp）进行回弹，依旧显示二楼页面
 * 5. 二楼页面向上滑动（大于150vp）进行收缩，显示一楼列表
 * 6. 退出案例
 */
export default function secondFloorLoadAnimationTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NANE);
  let driver = Driver.create();

  /**
   * 进入首页判断布局
   */
  it('首页页面检查', 0, async (done: Function) => {
    // 断言检查页面相关组件是否都存在
    await driver.assertComponentExist(ON.id('mainPageTitle'));
    await driver.assertComponentExist(ON.id('userInfo'));
    await driver.delayMs(500);
    done();
  })

  /**
   * 下拉距离小于200vp，显示加载动画
   */
  it('下拉页面显示加载动画', 0, async (done: Function) => {
    // 开始的滑动的起始点为(100,200),结束点为(100,1000)，指的是从页面最左边100的地方开始向下滑动800（小于200vp）。2000指的是滑动速率。
    await driver.swipe(100, 200, 100, 1000, 2000);
    await driver.assertComponentExist(ON.id('loading')); // 断言加载动画显示成功
    await driver.delayMs(1000);
    done();
  })

  /**
   * 下拉距离大于200vp，显示二楼页面
   */
  it('下拉首页展示二楼页面', 0, async (done: Function) => {
    // 等待加载动画全部收起
    await driver.delayMs(2000);
    // 开始的滑动的起始点为(100,200),结束点为(100,2200)，指的是从页面最左边100的地方开始向下滑动2000（大于200vp）。2000指的是滑动速率。
    await driver.swipe(100, 200, 100, 2200, 2000);
    await driver.assertComponentExist(ON.id('floorView')); // 断言二楼页面显示
    await driver.delayMs(1000);
    done();
  })

  /**
   * 二楼页面向上滑动（小于150vp）进行回弹，依旧显示二楼页面
   */
  it('二楼页面回弹', 0, async (done: Function) => {
    // 等待二楼页面完全展开
    await driver.delayMs(1000);
    // 开始的滑动的起始点为(100,1000),结束点为(100,300)，指的是从页面最左边100的地方开始向上滑动700（小于150vp）。2000指的是滑动速率。
    await driver.swipe(100, 1000, 100, 300, 2000);
    await driver.assertComponentExist(ON.id('floorView')); // 断言二楼页面显示
    await driver.delayMs(1000);
    done();
  })

  /**
   * 二楼页面向上滑动（大于150vp）进行收缩，显示一楼列表
   */
  it('二楼页面收缩', 0, async (done: Function) => {
    // 等待二楼页面回单完成
    await driver.delayMs(1000);
    // 开始的滑动的起始点为(100,2200),结束点为(100,200)，指的是从页面最左边100的地方开始向上滑动2000（大于150vp）。2000指的是滑动速率。
    await driver.swipe(100, 2200, 100, 200, 2000);
    await driver.assertComponentExist(ON.id('userInfo')); // 断言首页页面显示
    await driver.delayMs(1000);
    done();
  })

  /**
   * 退出案例
   */
  exit(CASE_NANE)

}