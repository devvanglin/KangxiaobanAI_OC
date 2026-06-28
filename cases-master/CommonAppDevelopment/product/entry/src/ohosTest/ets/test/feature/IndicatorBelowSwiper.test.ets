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

const CASE: string = 'IndicatorBelowSwiper'; // 案例
const CASE_NAME: string = 'swiper指示器导航点位于swiper下方'; // 案例名称
const TAG: string = '[IndicatorBelowSwiper_Test]';

/**
 * 【swiper指示器导航点位于swiper下方】自动化测试用例，测试步骤如下
 * 1. 进入指示器导航点位于swiper下方的场景案例主页，查询轮播图显示正常，3秒后自动切换为第二张图片。
 * 2. 轮播图向左滑动，切换为第三张图片。
 */
export default function indicatorBelowSwiperTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver: Driver = Driver.create();

  // 自动切换轮播图
  autoChangeCases(driver);

  // 滑动切换轮播图
  slideChangeCase(driver);

  // 返回瀑布流主页面
  exit(CASE_NAME);
}

/**
 * 用例关联"验证Swiper自动滚动"
 * @param { Driver } driver
 */
function autoChangeCases(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 判断轮播图组件是否存在。
   * 2. 判断当前图片是否为第一张图片。
   * 3. 暂停3秒后，判断第二张图片是否存在。
   */
  it('Swiper自动滚动', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_Swiper自动滚动 begin`);

    // 判断轮播图组件是否存在
    await driver.assertComponentExist(ON.id('indicator_below_swiper_component'));

    // 判断当前图片是否为第一张图片
    await driver.assertComponentExist(ON.id('indicator_below_swiper_image_0'));

    // 暂停3秒后，判断第二张图片是否存在
    await driver.delayMs(3000);
    await driver.assertComponentExist(ON.id('indicator_below_swiper_image_1'));

    logger.info(TAG, `${CASE}_Swiper自动滚动 end`);

    done();
  })
}

/**
 * 用例关联"验证Swiper手动滑动"
 * @param { Driver } driver
 */
function slideChangeCase(driver: Driver): void {
  /**
   * 执行步骤:
   * 1. 第二张图片向左滑动。
   * 2. 判断轮播图展示框是否切换为第三张图片。
   */
  it('Swiper手动滑动', 0, async (done: Function) => {

    logger.info(TAG, `${CASE}_Swiper手动滑动 begin`);

    // 获取swiper item
    const contentComponent: Component = await driver.findComponent(ON.id('indicator_below_swiper_image_1'));

    // 获取第二张图片坐标信息
    const point = await contentComponent.getBoundsCenter();

    // 第二张图片向左快速滑动1000坐标
    await driver.fling({x: point.x + 500, y: point.y}, {x: point.x - 500, y: point.y}, 5, 600)
    await driver.delayMs(1500);

    // 判断轮播图展示框是否切换为第三张图片
    await driver.assertComponentExist(ON.id('indicator_below_swiper_image_2'));

    logger.info(TAG, `${CASE}_Swiper手动滑动 end`);

    done();
  })
}